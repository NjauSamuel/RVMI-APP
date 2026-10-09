import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_settings.dart';

/// Thin wrapper over `google_sign_in` v7's singleton API, producing the
/// Google ID token that `POST /api/auth/login/google` verifies
/// server-side.
///
/// [serverClientId] must be the Web-application OAuth client (not the
/// Android one) - passing it as `serverClientId` is what makes
/// `google_sign_in` mint an ID token whose audience the backend accepts.
class GoogleAuthService {
  GoogleAuthService();

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppSettings.googleServerClientId.isEmpty
          ? null
          : AppSettings.googleServerClientId,
    );
    _initialized = true;
  }

  /// Returns the ID token for a freshly-authenticated Google account, or
  /// null if the user cancelled the picker.
  Future<String?> signInAndGetIdToken() async {
    await _ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('Google Sign-In is not supported on this platform.');
    }

    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    await GoogleSignIn.instance.signOut();
  }
}

final googleAuthServiceProvider = Provider<GoogleAuthService>(
  (ref) => GoogleAuthService(),
);
