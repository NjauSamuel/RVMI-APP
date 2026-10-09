import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/roles_repository.dart';
import '../providers/users_repository.dart';

/// Admin-provisioned accounts only - there is no public self-registration.
/// An admin creates the account here (with a temporary password) and the
/// member signs in with that password or with Google using the same
/// email.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: () => _createUser(context, ref)),
        ],
      ),
      body: users.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final user = list[index];
            final dark = Theme.of(context).brightness == Brightness.dark;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: user.isActive
                    ? (dark ? AppColors.brand800 : AppColors.brand100)
                    : (dark ? AppColors.surfaceBaseDark : AppColors.surfaceAlt),
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0] : '?',
                        style: TextStyle(
                          color: user.isActive
                              ? (dark ? Colors.white : AppColors.brand800)
                              : (dark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              title: Text(user.name),
              subtitle: Text('${user.email} · ${user.roles.join(', ')}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'deactivate') {
                    await ref.read(usersRepositoryProvider).deactivate(user.id);
                    ref.invalidate(usersListProvider);
                  } else {
                    await ref.read(usersRepositoryProvider).updateRole(user.id, value);
                    ref.invalidate(usersListProvider);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'Developer', child: Text('Set role: Developer')),
                  const PopupMenuItem(value: 'Senior Admin', child: Text('Set role: Senior Admin')),
                  const PopupMenuItem(value: 'Member', child: Text('Set role: Member')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Text('Deactivate', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load users.')),
      ),
    );
  }

  Future<void> _createUser(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String role = 'Member';

    final roles = await ref.read(rolesRepositoryProvider).list();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: roles.roles.map((r) => DropdownMenuItem(value: r.name, child: Text(r.name))).toList(),
                onChanged: (v) => setState(() => role = v ?? role),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty && emailController.text.trim().isNotEmpty) {
      final tempPassword = await ref.read(usersRepositoryProvider).create(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        role: role,
      );
      ref.invalidate(usersListProvider);
      final memberName = nameController.text.trim();
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            var copied = false;
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: const Text('Account created'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Temporary password'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            tempPassword,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: copied ? 'Copied' : 'Copy password',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: tempPassword));
                            setState(() => copied = true);
                          },
                          icon: Icon(copied ? Icons.check : Icons.copy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Share this with $memberName, or they can sign in with Google using this same email instead.',
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
                ],
              ),
            );
          },
        );
      }
    }
  }
}
