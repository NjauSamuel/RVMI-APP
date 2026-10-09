import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../storage/providers.dart';
import 'api_client.dart';

/// Fired when a 401 clears the stored token mid-session, so the session
/// controller (which can't be imported here without a cycle - it depends
/// on [apiClientProvider] itself) can notice and drop to the logged-out
/// state. Listened to via `ref.listen` in the auth feature.
final unauthorizedSignalProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStore = ref.watch(secureTokenStoreProvider);

  return ApiClient(
    tokenStore: tokenStore,
    onUnauthorized: () async {
      await tokenStore.clear();
      ref.read(unauthorizedSignalProvider.notifier).state++;
    },
  );
});
