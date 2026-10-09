/// The signed-in member's identity + permission set, exactly as returned by
/// `/api/auth/login`, `/api/auth/login/google`, and `/api/auth/me`.
class Session {
  const Session({
    required this.userId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.roles,
    required this.permissions,
    required this.navPermissions,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] as Map);

    return Session(
      userId: user['id'] as int,
      name: user['name'] as String? ?? '',
      email: user['email'] as String? ?? '',
      avatarUrl: user['avatar_url'] as String?,
      roles:
          (user['roles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      permissions:
          (json['permissions'] as List?)?.map((e) => e.toString()).toSet() ??
          const {},
      navPermissions:
          (json['nav_permissions'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const {},
    );
  }

  final int userId;
  final String name;
  final String email;
  final String? avatarUrl;
  final List<String> roles;
  final Set<String> permissions;

  /// The full universe of permissions that gate a nav item - used so the UI
  /// can tell "member with nothing extra" apart from "permission list
  /// hasn't loaded yet" when deciding what to hide.
  final Set<String> navPermissions;

  bool can(String permission) => permissions.contains(permission);

  bool get canUpload => can('upload-media');
  bool get canApprove => can('approve-media');
  bool get canManageEvents => can('manage-events');
  bool get canManagePeople => can('manage-people');
  bool get canViewPrivate => can('view-private-media');
  bool get canManageInventory => can('manage-inventory');
  bool get canManageUsers => can('manage-users');
  bool get canManageRoles => can('manage-roles');

  Map<String, dynamic> toJson() => {
    'user': {
      'id': userId,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'roles': roles,
    },
    'permissions': permissions.toList(),
    'nav_permissions': navPermissions.toList(),
  };
}
