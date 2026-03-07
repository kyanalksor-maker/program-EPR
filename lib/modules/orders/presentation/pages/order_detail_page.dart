import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/core/utils/formatters.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/modules/orders/presentation/pages/create_order_page.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';
import 'package:warehouse_manager_app/presentation/widgets/common_widgets.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));
    if (order == null) {
      return const Scaffold(
        body: EmptyPlaceholder(
          title: 'Order not found',
          subtitle: 'The selected order could not be loaded.',
        ),
      );
    }

    final availableTransitions = ref.watch(availableTransitionsProvider(order));
    final operationState = ref.watch(operationsControllerProvider);
    final user = ref.watch(currentUserProvider)!;
    final canEdit = user.hasPermission(AppPermission.ordersEdit);
    final canDelete = user.hasPermission(AppPermission.ordersDelete);
    final canOverride = user.hasPermission(AppPermission.ordersOverride);

    return Scaffold(
      appBar: AppBar(title: Text(order.id)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionPanel(
            title: 'Overview',
            trailing: StatusBadge(order.status),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Info(label: 'Customer', value: order.customerName),
                _Info(label: 'Phone', value: order.customerPhone),
                _Info(label: 'Created By', value: order.createdByName),
                _Info(label: 'Date', value: AppFormatters.shortDateTime(order.orderDate)),
                _Info(label: 'Total Cost', value: AppFormatters.currency(order.totalCost)),
                _Info(label: 'Revenue', value: AppFormatters.currency(order.totalRevenue)),
                _Info(label: 'Profit', value: AppFormatters.currency(order.profit)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionPanel(
            title: 'Administration',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateOrderPage(orderId: order.id),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Order'),
                  ),
                if (canDelete)
                  OutlinedButton.icon(
                    onPressed: operationState.isLoading
                        ? null
                        : () => _deleteOrder(context, ref, order.id),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Order'),
                  ),
                if (canOverride)
                  PopupMenuButton<OrderStatus>(
                    onSelected: (status) => _overrideOrder(context, ref, order.id, status),
                    itemBuilder: (context) => [
                      for (final status in OrderStatus.values)
                        PopupMenuItem(
                          value: status,
                          child: Text('Override to ${status.name.toUpperCase()}'),
                        ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.admin_panel_settings_outlined),
                          SizedBox(width: 8),
                          Text('Override Status'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionPanel(
            title: 'Order Items',
            child: Column(
              children: order.items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text('Qty ${item.quantity} • ${AppFormatters.currency(item.salePrice)}'),
                      trailing: Text(AppFormatters.currency(item.totalRevenue)),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          SectionPanel(
            title: 'Workflow Timeline',
            child: Column(
              children: order.history
                  .map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timeline),
                      title: Text(entry.status.name.toUpperCase()),
                      subtitle: Text('${entry.changedByName} • ${AppFormatters.shortDateTime(entry.changedAt)}'),
                      trailing: entry.note == null ? null : Text(entry.note!),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (availableTransitions.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionPanel(
              title: 'Next Actions',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: availableTransitions
                    .map(
                      (status) => FilledButton.icon(
                        onPressed: operationState.isLoading
                            ? null
                            : () => _transition(context, ref, order, status),
                        icon: const Icon(Icons.sync_alt),
                        label: Text('Move to ${status.name.toUpperCase()}'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    OrderEntity order,
    OrderStatus status,
  ) async {
    await ref.read(operationsControllerProvider.notifier).transitionOrder(
          order: order,
          nextStatus: status,
        );
    final state = ref.read(operationsControllerProvider);
    if (!context.mounted) {
      return;
    }
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString())),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order updated successfully.')),
    );
  }

  Future<void> _overrideOrder(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    OrderStatus status,
  ) async {
    await ref.read(operationsControllerProvider.notifier).overrideOrderStatus(
          orderId: orderId,
          nextStatus: status,
        );
    final state = ref.read(operationsControllerProvider);
    if (!context.mounted) {
      return;
    }
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString())),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Override applied.')),
    );
  }

  Future<void> _deleteOrder(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) async {
    await ref.read(operationsControllerProvider.notifier).deleteOrder(orderId);
    final state = ref.read(operationsControllerProvider);
    if (!context.mounted) {
      return;
    }
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString())),
      );
      return;
    }
    Navigator.of(context).pop();
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
