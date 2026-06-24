import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  final Dio _dio = Dio();
  static String get baseUrl {
    return 'http://localhost:8080';
  }

  ApiClient() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Dynamic JWT injector interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final authBox = await Hive.openBox('auth_box');
            final token = authBox.get('jwt_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            debugPrint("Interceptors error fetching token: $e");
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          debugPrint("API Error: ${e.response?.statusCode} - ${e.message}");
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
