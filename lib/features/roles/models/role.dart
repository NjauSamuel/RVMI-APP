class AppRole {
  const AppRole({
    required this.id,
    required this.name,
    required this.isBuiltIn,
    required this.permissions,
    required this.usersCount,
  });

  factory AppRole.fromJson(Map<String, dynamic> json) => AppRole(
    id: json['id'] as int,
    name: json['name'] as String,
    isBuiltIn: json['is_built_in'] as bool? ?? false,
    permissions: (json['permissions'] as List? ?? []).map((e) => e.toString()).toSet(),
    usersCount: json['users_count'] as int?,
  );

  final int id;
  final String name;
  final bool isBuiltIn;
  final Set<String> permissions;
  final int? usersCount;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isActive,
    required this.roles,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    avatarUrl: json['avatar_url'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    roles: (json['roles'] as List? ?? []).map((e) => e.toString()).toList(),
  );

  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isActive;
  final List<String> roles;
}

/// Mirrors `App\Support\Permissions::all()` on the backend - kept here so
/// the roles screen can render friendly checkbox labels without a
/// round-trip just to know the universe of permissions (the actual list
/// returned by `/admin/roles` is still the source of truth and is what
/// gets displayed/sent).
class PermissionCatalog {
  static const labels = {
    'upload-media': 'Upload media',
    'approve-media': 'Review & approve media',
    'manage-events': 'Create & manage events',
    'manage-people': 'Manage recognized people',
    'view-private-media': 'View private media',
    'comment': 'Comment on events',
    'manage-inventory': 'Manage inventory',
    'manage-users': 'Manage users',
    'manage-roles': 'Manage roles & permissions',
    'manage-settings': 'Manage app settings',
  };

  static String label(String permission) => labels[permission] ?? permission;
}
