import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences.dart';
import 'secure_token_store.dart';

/// Created once in `main()` and overridden into the root [ProviderScope].
final appPreferencesProvider = Provider<AppPreferences>((ref) {
  throw UnimplementedError('appPreferencesProvider must be overridden in main()');
});

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return SecureTokenStore();
});
