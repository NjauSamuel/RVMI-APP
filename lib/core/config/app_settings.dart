/// Compile-time, non-secret app configuration.
///
/// Override at build/run time with `--dart-define`, e.g.:
///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
class AppSettings {
  const AppSettings._();

  /// The Web-application OAuth client id (not the Android one) - this is
  /// what makes `google_sign_in` mint an ID token the Laravel backend can
  /// verify server-side. See ../../../../GOOGLE.md.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
}
