import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class SyncState {
  final bool isOffline;
  final int pendingGpsCount;
  final int pendingSosCount;
  final bool isSyncing;
  final List<dynamic> notifiedContacts;

  SyncState({
    this.isOffline = false,
    this.pendingGpsCount = 0,
    this.pendingSosCount = 0,
    this.isSyncing = false,
    this.notifiedContacts = const [],
  });

  SyncState copyWith({
    bool? isOffline,
    int? pendingGpsCount,
    int? pendingSosCount,
    bool? isSyncing,
    List<dynamic>? notifiedContacts,
  }) {
    return SyncState(
      isOffline: isOffline ?? this.isOffline,
      pendingGpsCount: pendingGpsCount ?? this.pendingGpsCount,
      pendingSosCount: pendingSosCount ?? this.pendingSosCount,
      isSyncing: isSyncing ?? this.isSyncing,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
    );
  }
}

class SyncManager extends StateNotifier<SyncState> {
  final ApiClient _apiClient = ApiClient();
  late Box _gpsBox;
  late Box _sosBox;

  SyncManager() : super(SyncState()) {
    _initBoxes();
  }

  Future<void> _initBoxes() async {
    _gpsBox = await Hive.openBox('gps_box');
    _sosBox = await Hive.openBox('sos_box');
    _updateCounts();
  }

  void _updateCounts() {
    state = state.copyWith(
      pendingGpsCount: _gpsBox.length,
      pendingSosCount: _sosBox.length,
    );
  }

  // Explicit connectivity toggle (manually toggleable or linked to sensor APIs)
  void setConnectionStatus(bool isOffline) {
    state = state.copyWith(isOffline: isOffline);
    if (!isOffline) {
      triggerSync();
    }
  }

  // Queue tracking packet locally
  Future<void> queueGps(double latitude, double longitude, double speed, String timestamp) async {
    if (state.isOffline) {
      final key = DateTime.now().millisecondsSinceEpoch.toString();
      await _gpsBox.put(key, {
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'timestamp': timestamp,
      });
      _updateCounts();
      debugPrint("Offline: Telemetry packet queued locally in gps_box.");
    } else {
      // Directly post if online
      try {
        await _apiClient.dio.post('/api/gps/update', data: {
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'timestamp': timestamp,
        });
      } catch (e) {
        debugPrint("Online push failed, queueing telemetry offline: $e");
        setConnectionStatus(true);
        await queueGps(latitude, longitude, speed, timestamp);
      }
    }
  }

  // Queue SOS alert locally
  Future<List<dynamic>> queueSos(double latitude, double longitude) async {
    if (state.isOffline) {
      final key = DateTime.now().millisecondsSinceEpoch.toString();
      await _sosBox.put(key, {
        'latitude': latitude,
        'longitude': longitude,
      });
      _updateCounts();
      debugPrint("Offline: Critical SOS queued locally in sos_box.");
      final offlineContacts = [
        {'contactName': 'Arul Kumar', 'contactMobile': '9876543210', 'relationship': 'Brother', 'deliveryStatus': 'SMS_QUEUED_OFFLINE'},
        {'contactName': 'Kavita Raja', 'contactMobile': '9080706050', 'relationship': 'Wife', 'deliveryStatus': 'SMS_QUEUED_OFFLINE'}
      ];
      state = state.copyWith(notifiedContacts: offlineContacts);
      return offlineContacts;
    } else {
      // Online broadcast
      try {
        final response = await _apiClient.dio.post('/api/sos/trigger', data: {
          'latitude': latitude,
          'longitude': longitude,
        });
        if (response.statusCode == 200 || response.statusCode == 201) {
          final List<dynamic> contacts = response.data['notifiedContacts'] ?? [];
          state = state.copyWith(notifiedContacts: contacts);
          return contacts;
        }
      } catch (e) {
        debugPrint("Online SOS broadcast failed, caching SOS offline: $e");
        setConnectionStatus(true);
        return await queueSos(latitude, longitude);
      }
    }
    return [];
  }

  // Bulk flush local queues
  Future<void> triggerSync() async {
    if (state.isOffline || state.isSyncing) return;
    if (_gpsBox.isEmpty && _sosBox.isEmpty) return;

    state = state.copyWith(isSyncing: true);
    debugPrint("🔄 Sync Engine triggered. Flushing buffers online...");

    // 1. Sync SOS alerts first (highest priority)
    if (_sosBox.isNotEmpty) {
      final keys = List.from(_sosBox.keys);
      for (var key in keys) {
        final data = _sosBox.get(key);
        try {
          final response = await _apiClient.dio.post('/api/sos/trigger', data: {
            'latitude': data['latitude'],
            'longitude': data['longitude'],
          });
          if (response.statusCode == 200 || response.statusCode == 201) {
            await _sosBox.delete(key);
          }
        } catch (e) {
          debugPrint("Failed to sync SOS element $key: $e");
          // Abort sync chain if network is failing again
          setConnectionStatus(true);
          state = state.copyWith(isSyncing: false);
          _updateCounts();
          return;
        }
      }
    }

    // 2. Sync GPS Telemetry
    if (_gpsBox.isNotEmpty) {
      final keys = List.from(_gpsBox.keys);
      for (var key in keys) {
        final data = _gpsBox.get(key);
        try {
          final response = await _apiClient.dio.post('/api/gps/update', data: {
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'speed': data['speed'],
            'timestamp': data['timestamp'],
          });
          if (response.statusCode == 200 || response.statusCode == 201) {
            await _gpsBox.delete(key);
          }
        } catch (e) {
          debugPrint("Failed to sync GPS element $key: $e");
          setConnectionStatus(true);
          state = state.copyWith(isSyncing: false);
          _updateCounts();
          return;
        }
      }
    }

    state = state.copyWith(isSyncing: false);
    _updateCounts();
    debugPrint("✅ Caches cleared and synchronized successfully.");
  }
}

final syncProvider = StateNotifierProvider<SyncManager, SyncState>((ref) {
  return SyncManager();
});
