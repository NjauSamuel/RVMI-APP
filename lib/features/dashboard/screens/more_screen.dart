import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/session_controller.dart';

/// The "everything else" tab: profile, favorites shortcut, and the
/// admin-only management screens (People, Users, Roles). Every entry here
/// is gated by permission and simply doesn't render for a normal Member -
/// there's no disabled/greyed-out state, the row doesn't exist at all.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final s = session is SessionAuthenticated ? session.session : null;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          if (s != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.brand100,
                backgroundImage: s.avatarUrl != null ? NetworkImage(s.avatarUrl!) : null,
                child: s.avatarUrl == null ? Text(s.name.isNotEmpty ? s.name[0] : '?') : null,
              ),
              title: Text(s.name),
              subtitle: Text(s.roles.isNotEmpty ? s.roles.join(', ') : s.email),
            ),
          const Divider(),
          if (s?.canManagePeople ?? false)
            ListTile(
              leading: const Icon(Icons.face_outlined),
              title: const Text('People'),
              subtitle: const Text('Reference photos for face recognition'),
              onTap: () => context.push('/people'),
            ),
          if (s?.canManageUsers ?? false)
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Users'),
              onTap: () => context.push('/admin/users'),
            ),
          if (s?.canManageRoles ?? false)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Roles & permissions'),
              onTap: () => context.push('/admin/roles'),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Log out', style: TextStyle(color: AppColors.error)),
            onTap: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
