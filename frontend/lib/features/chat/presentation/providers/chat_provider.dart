import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';

class ChatMessageModel {
  final int id;
  final int senderId;
  final String senderName;
  final int recipientId;
  final String recipientName;
  final String message;
  final double? latitude;
  final double? longitude;
  final bool isSos;
  final String createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.message,
    this.latitude,
    this.longitude,
    required this.isSos,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int? ?? 0,
      senderId: json['senderId'] as int? ?? 0,
      senderName: json['senderName'] ?? '',
      recipientId: json['recipientId'] as int? ?? 0,
      recipientName: json['recipientName'] ?? '',
      message: json['message'] ?? '',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      isSos: json['isSos'] as bool? ?? false,
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class SearchedUser {
  final int id;
  final String fullName;
  final String mobileNumber;
  final String role;

  SearchedUser({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.role,
  });

  factory SearchedUser.fromJson(Map<String, dynamic> json) {
    return SearchedUser(
      id: json['id'] as int? ?? 0,
      fullName: json['fullName'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessageModel>>> {
  final ApiClient _apiClient = ApiClient();
  final int _recipientId;

  ChatNotifier(this._recipientId) : super(const AsyncValue.loading()) {
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    try {
      final response = await _apiClient.dio.get('/api/chat/history/$_recipientId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data.map((json) => ChatMessageModel.fromJson(json)).toList();
        state = AsyncValue.data(list);
      } else {
        state = AsyncValue.error("Failed to load chat history", StackTrace.current);
      }
    } catch (e) {
      debugPrint("Error fetching chat: $e");
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> sendMessage(String text, {double? latitude, double? longitude, bool isSos = false}) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/chat/send',
        data: {
          'recipientId': _recipientId,
          'message': text,
          'latitude': latitude,
          'longitude': longitude,
          'isSos': isSos,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newMsg = ChatMessageModel.fromJson(response.data);
        if (state.hasValue) {
          state = AsyncValue.data([...state.value!, newMsg]);
        } else {
          state = AsyncValue.data([newMsg]);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error sending message: $e");
      return false;
    }
  }
}

// Family provider to manage chat logs for independent recipients
final chatHistoryProvider = StateNotifierProvider.family<ChatNotifier, AsyncValue<List<ChatMessageModel>>, int>((ref, recipientId) {
  return ChatNotifier(recipientId);
});

// Search provider
final userSearchProvider = FutureProvider.family<List<SearchedUser>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final apiClient = ApiClient();
  try {
    final response = await apiClient.dio.get('/api/users/search', queryParameters: {'query': query});
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => SearchedUser.fromJson(json)).toList();
    }
  } catch (e) {
    debugPrint("Error searching users: $e");
  }
  return [];
});
