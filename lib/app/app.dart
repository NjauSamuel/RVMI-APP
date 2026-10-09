import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/providers/session_controller.dart';
import '../features/push/providers/push_service.dart';
import 'router.dart';

class RvmiMediaApp extends ConsumerWidget {
  const RvmiMediaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Push is only meaningful once we know who's signed in (the FCM token
    // is registered against the user) - start it the moment a session
    // becomes authenticated, not eagerly at app boot.
    ref.listen(sessionControllerProvider, (previous, next) {
      if (next is SessionAuthenticated) {
        ref.read(pushServiceProvider).start();
      }
    });

    return MaterialApp.router(
      title: 'RVMI Media',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
