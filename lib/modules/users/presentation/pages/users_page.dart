import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/core/utils/formatters.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/entities/employee_draft.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';
import 'package:warehouse_manager_app/presentation/widgets/common_widgets.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final canView = currentUser?.hasPermission(AppPermission.usersView) ?? false;
    if (!canView) {
      return const EmptyPlaceholder(
        title: 'Restricted area',
        subtitle: 'You do not have permission to access employee management.',
        icon: Icons.lock_outline,
      );
    }

    final canCreate = currentUser?.hasPermission(AppPermission.usersCreate) ?? false;
    final canEdit = currentUser?.hasPermission(AppPermission.usersEdit) ?? false;
    final canDelete = currentUser?.hasPermission(AppPermission.usersDelete) ?? false;
    final canAssign =
        currentUser?.hasPermission(AppPermission.usersAssignPermissions) ?? false;

    final usersValue = ref.watch(usersProvider);
    final activityValue = ref.watch(activityLogsProvider);

    return usersValue.when(
      data: (users) {
        final logs = activityValue.valueOrNull ?? const [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (canCreate)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _openEmployeeDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Create Employee'),
                ),
              ),
            const SizedBox(height: 16),
            ...users.map(
              (user) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(user.name),
                  subtitle: Text(
                    '${user.email}\n${user.role.label} • ${user.isActive ? 'Active' : 'Inactive'}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        child: Text(
                          'Permissions: ${user.permissions.map((item) => item.code).join(', ')}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        user.lastActive == null
                            ? 'No recent activity'
                            : AppFormatters.shortDateTime(user.lastActive!),
                      ),
                      if (canEdit)
                        IconButton(
                          onPressed: () => _openEmployeeDialog(context, ref, user: user),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      if (canEdit)
                        IconButton(
                          onPressed: () => _toggleActive(ref, user),
                          icon: Icon(
                            user.isActive ? Icons.person_off_outlined : Icons.person_outline,
                          ),
                        ),
                      if (canDelete)
                        IconButton(
                          onPressed: () => _deleteUser(ref, user.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SectionPanel(
              title: 'Recent Activity',
              child: Column(
                children: logs.take(12).map((log) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${log.actorName} • ${log.action}'),
                    subtitle: Text('${log.entityType} • ${AppFormatters.shortDateTime(log.createdAt)}'),
                  );
                }).toList(),
              ),
            ),
            if (!canAssign)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Permission assignment is disabled for your account.',
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }

  Future<void> _openEmployeeDialog(
    BuildContext context,
    WidgetRef ref, {
    AppUser? user,
  }) async {
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    UserRole selectedRole = user?.role ?? UserRole.orderEntry;
    final selectedPermissions = <AppPermission>{...user?.permissions ?? {}};

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(user == null ? 'Create Employee' : 'Edit Employee'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 12),
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: user == null ? 'Password' : 'Password (leave blank to keep)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    items: UserRole.values
                        .map((role) => DropdownMenuItem(value: role, child: Text(role.label)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedRole = value ?? selectedRole),
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Permissions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppPermission.values.map((permission) {
                      final selected = selectedPermissions.contains(permission);
                      return FilterChip(
                        label: Text(permission.code),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              selectedPermissions.add(permission);
                            } else {
                              selectedPermissions.remove(permission);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    final payload = EmployeeDraft(
      id: user?.id,
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim().isEmpty
          ? null
          : passwordController.text.trim(),
      role: selectedRole,
      permissions: selectedPermissions,
      isActive: user?.isActive ?? true,
    );

    if (user == null) {
      await ref.read(operationsControllerProvider.notifier).createEmployee(payload);
    } else {
      await ref.read(operationsControllerProvider.notifier).updateEmployee(payload);
    }

    if (!context.mounted) {
      return;
    }
    _showResult(context, ref);
  }

  Future<void> _toggleActive(WidgetRef ref, AppUser user) async {
    await ref.read(operationsControllerProvider.notifier).deactivateEmployee(
          employeeId: user.id,
          isActive: !user.isActive,
        );
  }

  Future<void> _deleteUser(WidgetRef ref, String userId) async {
    await ref.read(operationsControllerProvider.notifier).deleteEmployee(userId);
  }

  void _showResult(BuildContext context, WidgetRef ref) {
    final state = ref.read(operationsControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.hasError ? state.error.toString() : 'Employee operation completed.',
        ),
      ),
    );
  }
}
