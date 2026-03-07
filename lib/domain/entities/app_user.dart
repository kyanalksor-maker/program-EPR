import 'package:warehouse_manager_app/core/constants/app_enums.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roleId,
    required this.role,
    required this.permissions,
    required this.createdAt,
    required this.isActive,
    this.lastActive,
  });

  final String id;
  final String name;
  final String email;
  final String roleId;
  final UserRole role;
  final Set<AppPermission> permissions;
  final DateTime createdAt;
  final bool isActive;
  final DateTime? lastActive;

  bool hasPermission(AppPermission permission) =>
      role == UserRole.admin || permissions.contains(permission);

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? roleId,
    UserRole? role,
    Set<AppPermission>? permissions,
    DateTime? createdAt,
    bool? isActive,
    DateTime? lastActive,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
