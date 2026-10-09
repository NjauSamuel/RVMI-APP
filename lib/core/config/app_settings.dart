/// Compile-time, non-secret app configuration.
///
/// The Web client ID is the default, so a plain `flutter run` signs in
/// with Google. Override it with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
/// if you need a different client.
class AppSettings {
  const AppSettings._();

  /// The Web-application OAuth client id (not the Android one) - this is
  /// what makes `google_sign_in` mint an ID token the Laravel backend can
  /// verify server-side. See ../../../../GOOGLE.md.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '747925347975-trtoqopcrbkuhlfccgo7p4gsprt5dbrj.apps.googleusercontent.com',
  );
}
