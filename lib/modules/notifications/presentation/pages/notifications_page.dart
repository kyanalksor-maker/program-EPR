import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/utils/formatters.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';
import 'package:warehouse_manager_app/presentation/widgets/common_widgets.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({
    super.key,
    required this.onOpenOrder,
  });

  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsValue = ref.watch(notificationsProvider);

    return notificationsValue.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return const EmptyPlaceholder(
            title: 'No notifications',
            subtitle: 'Workflow and alert notifications will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: notifications.map((notification) {
            return Card(
              child: ListTile(
                title: Text(notification.title),
                subtitle: Text(
                  '${notification.message}\n${AppFormatters.shortDateTime(notification.createdAt)}',
                ),
                isThreeLine: true,
                leading: Badge(
                  isLabelVisible: !notification.isRead,
                  child: const Icon(Icons.notifications_none_outlined),
                ),
                trailing: TextButton(
                  onPressed: notification.isRead
                      ? null
                      : () => ref
                          .read(operationsControllerProvider.notifier)
                          .markNotificationRead(notification.id),
                  child: const Text('Mark Read'),
                ),
                onTap: notification.referenceId?.startsWith('ORD-') == true
                    ? () => onOpenOrder(notification.referenceId!)
                    : null,
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }
}
