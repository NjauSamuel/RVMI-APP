import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_mode_controller.dart';
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
    final themeMode = ref.watch(themeModeControllerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canManagePeople = s?.canManagePeople ?? false;
    final canManageAccounts = (s?.canManageUsers ?? false) || (s?.canManageRoles ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          if (s != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: dark ? AppColors.brand800 : AppColors.brand100,
                foregroundColor: dark ? Colors.white : AppColors.brand800,
                backgroundImage: s.avatarUrl != null ? NetworkImage(s.avatarUrl!) : null,
                child: s.avatarUrl == null
                    ? Text(
                        s.name.isNotEmpty ? s.name[0] : '?',
                        style: TextStyle(
                          color: dark ? Colors.white : AppColors.brand800,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              title: Text(s.name),
              subtitle: Text(s.roles.isNotEmpty ? s.roles.join(', ') : s.email),
            ),
          if (canManagePeople || canManageAccounts) const Divider(),
          if (canManagePeople) ...[
            const ListTile(
              title: Text('Recognition'),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.face_outlined),
              title: const Text('People'),
              subtitle: const Text('Reference photos for face recognition'),
              onTap: () => context.push('/people'),
            ),
          ],
          if (canManageAccounts) ...[
            if (canManagePeople) const Divider(),
            const ListTile(
              title: Text('Accounts'),
              dense: true,
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
          ],
          const Divider(),
          const ListTile(
            title: Text('Appearance'),
            dense: true,
          ),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) => ref
                .read(themeModeControllerProvider.notifier)
                .setThemeMode(mode!),
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Light'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Dark'),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Match device'),
                  value: ThemeMode.system,
                ),
              ],
            ),
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
