import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the Sanctum bearer token issued by `POST /api/auth/login`(`/google`)
/// in the platform keystore/keychain, with the last successful session JSON
/// cached alongside it so a cold start without internet still knows who's
/// signed in and what they're allowed to see.
class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  static const _tokenKey = 'rvmi_media.token';
  static const _sessionKey = 'rvmi_media.cached_session';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<Map<String, dynamic>?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> writeSession(Map<String, dynamic> session) {
    return _storage.write(key: _sessionKey, value: jsonEncode(session));
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionKey);
  }
}
