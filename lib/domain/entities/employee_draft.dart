import 'package:warehouse_manager_app/core/constants/app_enums.dart';

class EmployeeDraft {
  const EmployeeDraft({
    this.id,
    required this.name,
    required this.email,
    this.password,
    required this.role,
    required this.permissions,
    this.isActive = true,
  });

  final String? id;
  final String name;
  final String email;
  final String? password;
  final UserRole role;
  final Set<AppPermission> permissions;
  final bool isActive;
}
