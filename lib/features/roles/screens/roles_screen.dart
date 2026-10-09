import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/role.dart';
import '../providers/roles_repository.dart';

/// Developer and Senior Bishop are full-access built-ins and can't be
/// edited/deleted here; anything else is a free combination of checkbox
/// permissions the Senior Bishop can define for the church's own
/// ministry structure.
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesData = ref.watch(rolesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles & permissions'),
        actions: [
          rolesData.maybeWhen(
            data: (data) => IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _editRole(context, ref, data, null),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: rolesData.when(
        data: (data) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: data.roles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final role = data.roles[index];
            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Text(role.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (role.isBuiltIn) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, size: 14, color: AppColors.brand600),
                    ],
                  ],
                ),
                subtitle: Text('${role.permissions.length} permission(s) · ${role.usersCount ?? 0} user(s)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editRole(context, ref, data, role),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load roles.')),
      ),
    );
  }

  Future<void> _editRole(
    BuildContext context,
    WidgetRef ref,
    RolesData data,
    AppRole? role,
  ) async {
    final nameController = TextEditingController(text: role?.name ?? '');
    final permissions = {...(role?.permissions ?? <String>{})};
    final readOnly = role?.isBuiltIn ?? false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role == null ? 'New role' : role.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (role == null)
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Role name'),
                  ),
                if (readOnly)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Built-in roles have every permission and can\'t be edited.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: data.availablePermissions.map((permission) {
                      return CheckboxListTile(
                        value: permissions.contains(permission),
                        title: Text(PermissionCatalog.label(permission)),
                        onChanged: readOnly
                            ? null
                            : (checked) => setState(() {
                                if (checked ?? false) {
                                  permissions.add(permission);
                                } else {
                                  permissions.remove(permission);
                                }
                              }),
                      );
                    }).toList(),
                  ),
                ),
                if (!readOnly)
                  Row(
                    children: [
                      if (role != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await ref.read(rolesRepositoryProvider).delete(role.id);
                              ref.invalidate(rolesListProvider);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                            child: const Text('Delete'),
                          ),
                        ),
                      if (role != null) const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () async {
                            if (role == null) {
                              if (nameController.text.trim().isEmpty) return;
                              await ref.read(rolesRepositoryProvider).create(
                                nameController.text.trim(),
                                permissions,
                              );
                            } else {
                              await ref.read(rolesRepositoryProvider).updatePermissions(role.id, permissions);
                            }
                            ref.invalidate(rolesListProvider);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
