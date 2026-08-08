import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/constants/api_endpoints.dart';
import 'package:shadja/core/storage/token_storage.dart';

final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '${ApiEndpoints.baseUrl}${ApiEndpoints.apiPrefix}',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        if (kDebugMode) {
          debugPrint('[DIO ERROR] ${e.requestOptions.path} → ${e.message}');
        }
        if (e.response?.statusCode == 401) {
          TokenStorage.clear();
        }
        handler.next(e);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint(
            '[DIO ${response.statusCode}] ${response.requestOptions.path}',
          );
        }
        handler.next(response);
      },
    ),
  );

  return dio;
});

class DioClient {
  DioClient._();

  static Dio create() {
    throw UnsupportedError('Use dioClientProvider instead');
  }
}