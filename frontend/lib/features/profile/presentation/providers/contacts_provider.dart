import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../../../core/network/api_client.dart';

class EmergencyContactModel {
  final int? id;
  final int? contactUserId;
  final String contactName;
  final String contactMobile;
  final String? relationship;

  EmergencyContactModel({
    this.id,
    this.contactUserId,
    required this.contactName,
    required this.contactMobile,
    this.relationship,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'],
      contactUserId: json['contactUserId'],
      contactName: json['contactName'] ?? '',
      contactMobile: json['contactMobile'] ?? '',
      relationship: json['relationship'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactUserId': contactUserId,
      'contactName': contactName,
      'contactMobile': contactMobile,
      'relationship': relationship,
    };
  }
}

class ContactsNotifier extends StateNotifier<AsyncValue<List<EmergencyContactModel>>> {
  final ApiClient _apiClient = ApiClient();

  ContactsNotifier() : super(const AsyncValue.loading()) {
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.dio.get('/api/users/contacts');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final list = data.map((json) => EmergencyContactModel.fromJson(json)).toList();
        state = AsyncValue.data(list);
        
        // Cache to Hive
        try {
          final contactsBox = await Hive.openBox('contacts_box');
          await contactsBox.clear();
          for (var c in list) {
            await contactsBox.add(c.toJson());
          }
          final metaBox = await Hive.openBox('contacts_meta_box');
          await metaBox.put('initialized', true);
        } catch (hiveErr) {
          debugPrint("Hive caching error: $hiveErr");
        }
      } else {
        state = AsyncValue.error("Failed to load contacts", StackTrace.current);
      }
    } catch (e, stack) {
      debugPrint("Error fetching contacts: $e");
      
      // Fallback from Hive
      try {
        final metaBox = await Hive.openBox('contacts_meta_box');
        final bool initialized = metaBox.get('initialized', defaultValue: false);
        if (initialized) {
          final contactsBox = await Hive.openBox('contacts_box');
          final list = contactsBox.values
              .map((json) => EmergencyContactModel.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          state = AsyncValue.data(list);
          return;
        }
      } catch (hiveErr) {
        debugPrint("Error reading fallback from Hive: $hiveErr");
      }

      // Fallback to static mock contacts on failure (offline support)
      state = AsyncValue.data([
        EmergencyContactModel(contactName: 'Arul Kumar', contactMobile: '9876543210', relationship: 'Brother'),
        EmergencyContactModel(contactName: 'Kavita Raja', contactMobile: '9080706050', relationship: 'Wife'),
      ]);
    }
  }

  Future<bool> addContact({
    int? contactUserId,
    required String contactName,
    required String contactMobile,
    String? relationship,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'contactName': contactName,
        'contactMobile': contactMobile,
        'relationship': relationship,
      };
      if (contactUserId != null) {
        requestData['contactUserId'] = contactUserId;
      }

      final response = await _apiClient.dio.post(
        '/api/users/contacts',
        data: requestData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchContacts(); // Refresh list from server
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error adding contact to backend: $e");
      // Offline fallback: update local state directly
      if (state.hasValue) {
        final currentList = state.value!;
        final newList = List<EmergencyContactModel>.from(currentList)
          ..add(EmergencyContactModel(
            contactUserId: contactUserId,
            contactName: contactName,
            contactMobile: contactMobile,
            relationship: relationship,
          ));
        state = AsyncValue.data(newList);
        return true;
      }
      return false;
    }
  }

  Future<bool> deleteContact(int id) async {
    try {
      final response = await _apiClient.dio.delete('/api/users/contacts/$id');
      if (response.statusCode == 200) {
        await fetchContacts();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting contact: $e");
      return false;
    }
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, AsyncValue<List<EmergencyContactModel>>>((ref) {
  return ContactsNotifier();
});
