import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../auth/providers/auth_api.dart';
import '../../auth/providers/session_controller.dart';

/// Push is deliberately low-key: the only push members ever get is the
/// batched per-event comment digest (see `notifications:dispatch-digest`
/// on the server) - never a per-comment/per-like ping. Tapping one just
/// opens that event's thread.
class PushService {
  PushService(this.ref);

  final Ref ref;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      _tokenRefreshSub = messaging.onTokenRefresh.listen(_registerToken);

      // App opened from a terminated state by tapping a notification.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      // App was backgrounded and brought back to the foreground via a tap.
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    } catch (_) {
      // No Firebase config in this environment (e.g. local dev without
      // google-services.json yet) - push just silently stays off.
    }
  }

  Future<void> _registerToken(String token) async {
    final session = ref.read(sessionControllerProvider);
    if (session is! SessionAuthenticated) return;

    try {
      await ref.read(authApiProvider).updatePushToken(token);
    } catch (_) {
      // Best-effort; will retry next app start / token refresh.
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final type = message.data['type'];
    final eventId = message.data['event_id'];

    if (type == 'event_comment_digest' && eventId != null) {
      ref.read(routerProvider).push('/events/$eventId');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _openedAppSub?.cancel();
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(service.dispose);
  return service;
});
