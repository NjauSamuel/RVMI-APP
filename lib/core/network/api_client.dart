import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_token_store.dart';
import 'endpoints.dart';
import 'interceptors/auth_interceptor.dart';

/// A thin, typed-error wrapper around [Dio] for the RVMI Media API. Every
/// screen talks to the backend through this, never `Dio` directly, so auth
/// headers, base URL and error shape stay in one place.
class ApiClient {
  ApiClient({
    required SecureTokenStore tokenStore,
    Future<void> Function()? onUnauthorized,
    void Function()? onNetworkError,
  }) : _onNetworkError = onNetworkError,
       _dio = Dio(
         BaseOptions(
           baseUrl: Endpoints.baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
           contentType: 'application/json',
         ),
       ) {
    _dio.interceptors.add(
      AuthInterceptor(tokenStore: tokenStore, onUnauthorized: onUnauthorized),
    );
  }

  final Dio _dio;
  final void Function()? _onNetworkError;

  Dio get raw => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return _guard(() => _dio.get<T>(path, queryParameters: query));
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Duration? receiveTimeout,
  }) {
    return _guard(
      () => _dio.post<T>(
        path,
        data: data,
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      ),
    );
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) {
    return _guard(() => _dio.patch<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path, {Object? data}) {
    return _guard(() => _dio.delete<T>(path, data: data));
  }

  /// Direct PUT of raw bytes to a presigned S3 URL - deliberately bypasses
  /// the base URL/auth header, since S3 authenticates via the signature
  /// baked into the URL itself.
  Future<void> putToPresignedUrl(
    String url,
    List<int> bytes,
    String contentType,
  ) async {
    final client = Dio();
    await client.put<void>(
      url,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
  }

  Future<Response<T>> _guard<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      final response = await request();
      return response;
    } on DioException catch (e) {
      final error = ApiException.fromDioException(e);
      if (error.isNetworkError) {
        _onNetworkError?.call();
      }
      throw error;
    }
  }
}

/// Normalizes Laravel's validation/error JSON shape
/// (`{"message": "...", "errors": {"field": ["..."]}}`) into something
/// screens can branch on without touching Dio types.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
    this.data,
  });

  factory ApiException.fromDioException(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    debugPrint(
      'API ${e.requestOptions.method} ${e.requestOptions.uri} '
      'failed (${e.type.name}${status == null ? '' : ', HTTP $status'}): $body',
    );

    if (body is Map) {
      final rawMessage = body['message'];
      final serverMessage = rawMessage is String ? rawMessage.trim() : '';
      final message = _isGenericServerMessage(serverMessage)
          ? _fallbackMessage(e)
          : serverMessage;
      final rawErrors = body['errors'];
      final fieldErrors = <String, List<String>>{};

      if (rawErrors is Map) {
        for (final entry in rawErrors.entries) {
          final values = entry.value;
          fieldErrors[entry.key.toString()] = values is List
              ? values.map((v) => v.toString()).toList()
              : [values.toString()];
        }
      }

      return ApiException(
        statusCode: status ?? 0,
        message: message,
        fieldErrors: fieldErrors,
        data: Map<String, dynamic>.from(body),
      );
    }

    return ApiException(statusCode: status ?? 0, message: _fallbackMessage(e));
  }

  final int statusCode;
  final String message;
  final Map<String, List<String>> fieldErrors;
  final Map<String, dynamic>? data;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNetworkError => statusCode == 0;
  bool get isValidationError => statusCode == 422;

  static String _fallbackMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The connection timed out. Check your internet and try again.',
      DioExceptionType.connectionError =>
        'Could not reach RVMI Media. Check your internet connection.',
      DioExceptionType.badCertificate =>
        'The secure connection to RVMI Media failed.',
      DioExceptionType.badResponse => _unexpectedResponse(e),
      _ => 'Could not sign in (${e.type.name}${_statusSuffix(e)}).',
    };
  }

  static bool _isGenericServerMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.isEmpty ||
        normalized == 'server error' ||
        normalized == 'something went wrong. please try again.';
  }

  static String _statusSuffix(DioException e) {
    final status = e.response?.statusCode;
    return status == null ? '' : ', HTTP $status';
  }

  static String _unexpectedResponse(DioException e) {
    final status = e.response?.statusCode;
    final code = status == null ? '' : ' (HTTP $status)';
    final body = e.response?.data;
    if (body is String && body.contains('<')) {
      return 'The server returned a web page$code instead of a login response.';
    }
    return 'Could not sign in$code.';
  }

  @override
  String toString() => message;
}
