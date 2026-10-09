import 'package:dio/dio.dart';

import '../../storage/secure_token_store.dart';

/// Attaches the stored Sanctum bearer token to every request, and notifies
/// [onUnauthorized] on a 401 so the app can drop back to the login screen.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenStore, this.onUnauthorized});

  final SecureTokenStore tokenStore;
  final Future<void> Function()? onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStore.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await onUnauthorized?.call();
    }
    handler.next(err);
  }
}
