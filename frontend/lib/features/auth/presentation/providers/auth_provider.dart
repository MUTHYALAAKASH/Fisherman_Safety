import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../domain/user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final UserModel? user;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    UserModel? user,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient = ApiClient();

  AuthNotifier() : super(AuthState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final authBox = await Hive.openBox('auth_box');
      final token = authBox.get('jwt_token');
      final userJson = authBox.get('user_profile');

      if (token != null && userJson != null) {
        final Map<String, dynamic> userMap = Map<String, dynamic>.from(jsonDecode(userJson));
        state = AuthState(
          isAuthenticated: true,
          user: UserModel.fromJson(userMap),
        );
      } else {
        state = AuthState(isAuthenticated: false);
      }
    } catch (e) {
      state = AuthState(errorMessage: e.toString());
    }
  }

  Future<bool> login(String mobileNumber, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.post('/api/auth/signin', data: {
        'mobileNumber': mobileNumber,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final fullName = response.data['fullName'];
        final role = response.data['role'];

        final authBox = await Hive.openBox('auth_box');
        await authBox.put('jwt_token', token);

        // Fetch full profile from server
        final profileResponse = await _apiClient.dio.get('/api/users/profile', options: Options(
          headers: {'Authorization': 'Bearer $token'}
        ));

        if (profileResponse.statusCode == 200) {
          final userModel = UserModel.fromJson(profileResponse.data);
          await authBox.put('user_profile', jsonEncode(userModel.toJson()));
          state = AuthState(isAuthenticated: true, user: userModel);
          return true;
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: "Failed to load profile");
      return false;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? e.message ?? "Authentication failed";
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String mobileNumber,
    required String password,
    String? email,
    String? boatName,
    String? registrationNumber,
    String? harborLocation,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.post('/api/auth/signup', data: {
        'fullName': fullName,
        'mobileNumber': mobileNumber,
        'email': email,
        'password': password,
        'role': 'FISHERMAN',
        'boatName': boatName,
        'registrationNumber': registrationNumber,
        'harborLocation': harborLocation,
      });

      if (response.statusCode == 201) {
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: "Registration failed");
      return false;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? e.message ?? "Registration failed";
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String mobileNumber,
    String? email,
    String? boatName,
    String? registrationNumber,
    String? harborLocation,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.put('/api/users/profile', data: {
        'fullName': fullName,
        'mobileNumber': mobileNumber,
        'email': email,
        'role': state.user?.role ?? 'FISHERMAN',
        'boatName': boatName,
        'registrationNumber': registrationNumber,
        'harborLocation': harborLocation,
      });

      if (response.statusCode == 200) {
        final userModel = UserModel.fromJson(response.data);
        final authBox = await Hive.openBox('auth_box');
        await authBox.put('user_profile', jsonEncode(userModel.toJson()));
        state = AuthState(isAuthenticated: true, user: userModel);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: "Failed to update profile");
      return false;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? e.message ?? "Profile update failed";
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    final authBox = await Hive.openBox('auth_box');
    await authBox.clear();
    state = AuthState(isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
