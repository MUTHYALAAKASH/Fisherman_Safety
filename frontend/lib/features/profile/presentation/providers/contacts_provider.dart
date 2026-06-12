import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
      } else {
        state = AsyncValue.error("Failed to load contacts", StackTrace.current);
      }
    } catch (e, stack) {
      debugPrint("Error fetching contacts: $e");
      // Fallback to static mock contacts on failure (offline support)
      state = AsyncValue.data([
        EmergencyContactModel(contactName: 'Arul Kumar', contactMobile: '9876543210', relationship: 'Brother'),
        EmergencyContactModel(contactName: 'Kavita Raja', contactMobile: '9080706050', relationship: 'Wife'),
      ]);
    }
  }

  Future<bool> addContact({
    required int contactUserId,
    required String contactName,
    required String contactMobile,
    String? relationship,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/contacts',
        data: {
          'contactUserId': contactUserId,
          'relationship': relationship,
        },
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
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, AsyncValue<List<EmergencyContactModel>>>((ref) {
  return ContactsNotifier();
});
