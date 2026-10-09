import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Base URL + path constants for the RVMI Media API.
///
/// Same split as DeskCheque-Mobile: production is
/// `https://rvmi.deskcheque.top`. Debug `flutter run` probes
/// `http://10.0.2.2:8000/up` once; if local Laravel is down it falls
/// back to production. Override with
/// `--dart-define=API_BASE_URL=https://...` (host only, no trailing
/// `/api` — that's appended automatically).
class Endpoints {
  const Endpoints._();

  static const _override = String.fromEnvironment('API_BASE_URL');
  static const _production = 'https://rvmi.deskcheque.top';
  static const _localDebug = 'http://10.0.2.2:8000';

  static String? _resolvedHost;

  static String get baseUrl => '${_host()}/api';

  static String _host() {
    if (_override.isNotEmpty) return _override;
    if (kReleaseMode) return _production;
    return _resolvedHost ?? _localDebug;
  }

  /// Once per process. Call from [main] before [runApp] so [ApiClient]
  /// uses the chosen host.
  ///
  /// Release builds and `--dart-define=API_BASE_URL` skip the local `/up`
  /// check entirely.
  static Future<void> resolve() async {
    if (_override.isNotEmpty) {
      debugPrint('RVMI Media API: $_override');
      return;
    }
    if (kReleaseMode) {
      debugPrint('RVMI Media API: $_production');
      return;
    }
    if (_resolvedHost != null) return;

    final reachable = await _localServerUp();
    if (reachable) {
      _resolvedHost = _localDebug;
      debugPrint('RVMI Media API: $_localDebug');
      return;
    }
    _resolvedHost = _production;
    debugPrint('RVMI Media API: $_production (local unreachable)');
  }

  static Future<bool> _localServerUp() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: 1500),
          receiveTimeout: const Duration(milliseconds: 1500),
        ),
      );
      final response = await dio.get<void>('$_localDebug/up');
      final code = response.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (_) {
      return false;
    }
  }
}
