import 'package:dio/dio.dart';
import 'package:shadja/core/constants/api_endpoints.dart';
import 'package:shadja/core/storage/token_storage.dart';
import 'package:shadja/features/auth/data/auth_model.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        if (data['message'] is String) return data['message'];
        if (data['message'] is Map) {
          final first = data['message'].values.first;
          return first is List ? first.first.toString() : first.toString();
        }
      }
      return '${e.response?.statusCode}: ${e.message}';
    }
    return e.toString();
  }

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      final auth = AuthResponseModel.fromJson(data);

      await TokenStorage.saveAuth(
        token: auth.token,
        userId: auth.user.id,
        name: auth.user.name,
        email: auth.user.email,
        role: auth.user.role,
      );

      return auth;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        throw AuthException('Email atau password salah.');
      }
      throw AuthException(_extractError(e));
    }
  }

  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          phone: phone,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final auth = AuthResponseModel.fromJson(data);

      await TokenStorage.saveAuth(
        token: auth.token,
        userId: auth.user.id,
        name: auth.user.name,
        email: auth.user.email,
        role: auth.user.role,
      );

      return auth;
    } catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {} finally {
      await TokenStorage.clear();
    }
  }

  Future<UserModel?> currentUser() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) return null;
    final name = await TokenStorage.getUserName();
    final email = await TokenStorage.getUserEmail();
    final role = await TokenStorage.getUserRole();
    final idStr = await TokenStorage.getUserId();
    if (name == null || email == null) return null;
    return UserModel(
      id: int.tryParse(idStr ?? '') ?? 1,
      name: name,
      email: email,
      phone: '08123456789',
      role: role,
    );
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
