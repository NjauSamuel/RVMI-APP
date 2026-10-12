import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/session_controller.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/dashboard/screens/home_shell_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/gallery/screens/media_viewer_screen.dart';
import '../features/gallery/screens/tag_timeline_screen.dart';
import '../features/inventory/screens/asset_form_screen.dart';
import '../features/inventory/screens/inventory_screen.dart';
import '../features/people/screens/people_screen.dart';
import '../features/review/screens/review_screen.dart';
import '../features/roles/screens/roles_screen.dart';
import '../features/roles/screens/users_screen.dart';
import '../features/uploads/screens/upload_picker_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<SessionState>(const SessionUnknown());
  ref.listen(sessionControllerProvider, (previous, next) {
    notifier.value = next;
  }, fireImmediately: true);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = notifier.value;
      final atLogin = state.matchedLocation == '/login';

      if (session is SessionUnknown) {
        return null; // splash is rendered by `/`
      }
      if (session is SessionUnauthenticated) {
        return atLogin ? null : '/login';
      }
      if (session is SessionAuthenticated && atLogin) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SessionGate()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/media/:id',
        builder: (context, state) {
          final extra = state.extra;
          final args = extra is MediaViewerArgs ? extra : null;
          return MediaViewerScreen(
            initialMediaId: int.parse(state.pathParameters['id']!),
            items: args?.items,
            initialIndex: args?.index ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/tags/:id',
        builder: (context, state) => TagTimelineScreen(
          tagId: int.parse(state.pathParameters['id']!),
          tagName: state.uri.queryParameters['name'] ?? 'Tag',
        ),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) => EventDetailScreen(
          eventId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/upload',
        builder: (context, state) => UploadPickerScreen(
          eventId: int.tryParse(state.uri.queryParameters['event_id'] ?? ''),
        ),
      ),
      GoRoute(path: '/review', builder: (context, state) => const ReviewScreen()),
      GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen()),
      GoRoute(
        path: '/inventory/new',
        builder: (context, state) => const AssetFormScreen(),
      ),
      GoRoute(
        path: '/inventory/:id/edit',
        builder: (context, state) => AssetFormScreen(
          assetId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/people', builder: (context, state) => const PeopleScreen()),
      GoRoute(path: '/admin/users', builder: (context, state) => const UsersScreen()),
      GoRoute(path: '/admin/roles', builder: (context, state) => const RolesScreen()),
    ],
  );
});

/// `/` stays the current location when a saved session finishes loading, so
/// GoRouter does not rebuild a one-shot builder. Watch the session directly.
class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is SessionAuthenticated) return const HomeShellScreen();
    return const SplashScreen();
  }
}
