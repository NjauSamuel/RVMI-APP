import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../models/session.dart';

/// Raw HTTP calls for the auth endpoints - [SessionController] owns what to
/// do with the results (persist token, update state, etc).
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<(String token, Session session)> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password, 'device_name': 'Android'},
    );
    return _parse(response.data!);
  }

  Future<(String token, Session session)> loginWithGoogle(
    String idToken,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/login/google',
      data: {'id_token': idToken, 'device_name': 'Android'},
    );
    return _parse(response.data!);
  }

  Future<Session> me() async {
    final response = await _client.get<Map<String, dynamic>>('/auth/me');
    return Session.fromJson(response.data!);
  }

  Future<void> logout() async {
    await _client.post<void>('/auth/logout');
  }

  Future<void> updatePushToken(String fcmToken) async {
    await _client.post<void>('/auth/push-token', data: {'fcm_token': fcmToken});
  }

  (String, Session) _parse(Map<String, dynamic> json) {
    final token = json['token'] as String;
    return (token, Session.fromJson(json));
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});
