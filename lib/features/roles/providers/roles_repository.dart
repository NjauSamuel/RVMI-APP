import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../models/role.dart';

class RolesData {
  const RolesData(this.roles, this.availablePermissions, this.builtInRoles);
  final List<AppRole> roles;
  final List<String> availablePermissions;
  final List<String> builtInRoles;
}

class RolesRepository {
  RolesRepository(this.ref);

  final Ref ref;

  Future<RolesData> list() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/admin/roles');
    final data = response.data!;
    return RolesData(
      (data['data'] as List).map((e) => AppRole.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      (data['available_permissions'] as List? ?? []).map((e) => e.toString()).toList(),
      (data['built_in_roles'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  Future<AppRole> create(String name, Set<String> permissions) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>(
      '/admin/roles',
      data: {'name': name, 'permissions': permissions.toList()},
    );
    return AppRole.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  Future<AppRole> updatePermissions(int roleId, Set<String> permissions) async {
    final client = ref.read(apiClientProvider);
    final response = await client.patch<Map<String, dynamic>>(
      '/admin/roles/$roleId',
      data: {'permissions': permissions.toList()},
    );
    return AppRole.fromJson(Map<String, dynamic>.from(response.data!['data'] as Map));
  }

  Future<void> delete(int roleId) async {
    final client = ref.read(apiClientProvider);
    await client.delete<void>('/admin/roles/$roleId');
  }
}

final rolesRepositoryProvider = Provider<RolesRepository>((ref) {
  return RolesRepository(ref);
});

final rolesListProvider = FutureProvider.autoDispose<RolesData>((ref) {
  return ref.read(rolesRepositoryProvider).list();
});
