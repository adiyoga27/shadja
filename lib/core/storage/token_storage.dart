import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  // On Windows, flutter_secure_storage_windows stores all values in a single
  // encrypted file and each write does load -> modify -> save of the whole map.
  // Concurrent writes race and drop values, so all writes must be serialized.
  static Future<void> _writeQueue = Future.value();

  static Future<void> _serialized(Future<void> Function() action) {
    final previous = _writeQueue;
    final gate = Completer<void>();
    _writeQueue = gate.future;
    return previous.then((_) => action()).whenComplete(gate.complete);
  }

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
    // Writes must be sequential: on Windows the map-file rewrite would race
    // otherwise and drop keys (e.g. the auth token).
    await _serialized(() => _storage.write(key: _keyToken, value: token));
    await _serialized(
        () => _storage.write(key: _keyUserId, value: userId.toString()));
    await _serialized(() => _storage.write(key: _keyUserName, value: name));
    await _serialized(() => _storage.write(key: _keyUserEmail, value: email));
    await _serialized(
        () => _storage.write(key: _keyUserRole, value: role ?? ''));
  }

  static Future<String?> getToken() => _storage.read(key: _keyToken);

  // clear() dipakai saat logout & saat 401. Jangan pernah membiarkan error
  // keluar dari sini agar logout tidak gagal karena masalah storage lokal.
  static Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[TokenStorage] clear gagal: $e');
    }
  }

  // setters used by mock repository
  static Future<void> setToken(String value) =>
      _serialized(() => _storage.write(key: _keyToken, value: value));
  static Future<void> setUserId(String value) =>
      _serialized(() => _storage.write(key: _keyUserId, value: value));
  static Future<void> setUserName(String value) =>
      _serialized(() => _storage.write(key: _keyUserName, value: value));
  static Future<void> setUserEmail(String value) =>
      _serialized(() => _storage.write(key: _keyUserEmail, value: value));
  static Future<void> setUserRole(String value) =>
      _serialized(() => _storage.write(key: _keyUserRole, value: value));

  static Future<String?> getUserId() => _storage.read(key: _keyUserId);
  static Future<String?> getUserName() => _storage.read(key: _keyUserName);
  static Future<String?> getUserEmail() => _storage.read(key: _keyUserEmail);
  static Future<String?> getUserRole() => _storage.read(key: _keyUserRole);

  // Generic key-value storage (used by printer settings, etc.)
  static Future<String?> read(String key) => _storage.read(key: key);
  static Future<void> write(String key, String value) =>
      _serialized(() => _storage.write(key: key, value: value));
  static Future<void> delete(String key) =>
      _serialized(() => _storage.delete(key: key));
}