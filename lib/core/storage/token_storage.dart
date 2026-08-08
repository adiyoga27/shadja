import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserRole = 'user_role';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveAuth({
    required String token,
    required int userId,
    required String name,
    required String email,
    String? role,
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyUserId, value: userId.toString()),
      _storage.write(key: _keyUserName, value: name),
      _storage.write(key: _keyUserEmail, value: email),
      _storage.write(key: _keyUserRole, value: role ?? ''),
    ]);
  }

  static Future<String?> getToken() => _storage.read(key: _keyToken);

  static Future<void> clear() async => _storage.deleteAll();

  // setters used by mock repository
  static Future<void> setToken(String value) =>
      _storage.write(key: _keyToken, value: value);
  static Future<void> setUserId(String value) =>
      _storage.write(key: _keyUserId, value: value);
  static Future<void> setUserName(String value) =>
      _storage.write(key: _keyUserName, value: value);
  static Future<void> setUserEmail(String value) =>
      _storage.write(key: _keyUserEmail, value: value);
  static Future<void> setUserRole(String value) =>
      _storage.write(key: _keyUserRole, value: value);

  static Future<String?> getUserId() => _storage.read(key: _keyUserId);
  static Future<String?> getUserName() => _storage.read(key: _keyUserName);
  static Future<String?> getUserEmail() => _storage.read(key: _keyUserEmail);
  static Future<String?> getUserRole() => _storage.read(key: _keyUserRole);

  // Generic key-value storage (used by printer settings, etc.)
  static Future<String?> read(String key) => _storage.read(key: key);
  static Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  static Future<void> delete(String key) => _storage.delete(key: key);
}