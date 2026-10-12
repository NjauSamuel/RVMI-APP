import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../models/role.dart';

class UsersRepository {
  UsersRepository(this.ref);

  final Ref ref;

  Future<List<AppUser>> list() async {
    final client = ref.read(apiClientProvider);
    final response = await client.get<Map<String, dynamic>>('/admin/users');
    return (response.data!['data'] as List)
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Returns the one-time temporary password (there's no outbound mail
  /// pipeline on Namecheap shared hosting) - the admin relays it to the
  /// new member directly, who can also just sign in with Google instead.
  Future<String> create({required String name, required String email, required String role}) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>(
      '/admin/users',
      data: {'name': name, 'email': email, 'role': role},
    );
    return response.data!['temporary_password'] as String;
  }

  Future<void> updateRole(int userId, String role) async {
    final client = ref.read(apiClientProvider);
    await client.patch<void>('/admin/users/$userId', data: {'role': role});
  }

  Future<void> setActive(int userId, bool active) async {
    final client = ref.read(apiClientProvider);
    await client.patch<void>('/admin/users/$userId', data: {'is_active': active});
  }

  Future<void> delete(int userId) async {
    final client = ref.read(apiClientProvider);
    await client.delete<void>('/admin/users/$userId');
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref);
});

final usersListProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.read(usersRepositoryProvider).list();
});
