import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../../core/storage/providers.dart';
import '../models/session.dart';
import 'auth_api.dart';

sealed class SessionState {
  const SessionState();
}

/// Checking for a stored token / calling `GET /me` to validate it. Shown
/// as the splash screen.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.session);
  final Session session;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // A 401 anywhere in the app clears the token; react by dropping to the
    // logged-out state so the router redirect sends the user back to Login.
    ref.listen(unauthorizedSignalProvider, (previous, next) {
      if (previous != null && next != previous) {
        state = const SessionUnauthenticated();
      }
    });
    Future.microtask(restore);
    return const SessionUnknown();
  }

  AuthApi get _api => ref.read(authApiProvider);

  Future<void> restore() async {
    final store = ref.read(secureTokenStoreProvider);
    final token = await store.read();
    if (token == null || token.isEmpty) {
      state = const SessionUnauthenticated();
      return;
    }

    try {
      final session = await _api.me();
      await store.writeSession(session.toJson());
      state = SessionAuthenticated(session);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await store.clear();
        state = const SessionUnauthenticated();
        return;
      }

      final cached = await store.readSession();
      if (cached != null) {
        state = SessionAuthenticated(Session.fromJson(cached));
        return;
      }

      if (e.isNetworkError) {
        return;
      }

      await store.clear();
      state = const SessionUnauthenticated();
    }
  }

  Future<void> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final (token, session) = await _api.login(email: email, password: password);
    await _apply(token, session);
  }

  Future<void> loginWithGoogle(String idToken) async {
    final (token, session) = await _api.loginWithGoogle(idToken);
    await _apply(token, session);
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Best-effort: still clear local state even if the request fails.
    }
    await forceLogout();
  }

  Future<void> forceLogout() async {
    await ref.read(secureTokenStoreProvider).clear();
    state = const SessionUnauthenticated();
  }

  Future<void> _apply(String token, Session session) async {
    await ref.read(secureTokenStoreProvider).write(token);
    await ref.read(secureTokenStoreProvider).writeSession(session.toJson());
    state = SessionAuthenticated(session);
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
