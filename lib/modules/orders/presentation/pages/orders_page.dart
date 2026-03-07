import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/modules/orders/presentation/widgets/order_card.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';
import 'package:warehouse_manager_app/presentation/widgets/common_widgets.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({
    super.key,
    required this.onOpenOrder,
    required this.onCreateOrder,
  });

  final ValueChanged<String> onOpenOrder;
  final VoidCallback onCreateOrder;

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final _searchController = TextEditingController();
  OrderStatus? _status;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersValue = ref.watch(ordersProvider);
    final user = ref.watch(currentUserProvider);
    final canCreate = user?.hasPermission(AppPermission.ordersCreate) ?? false;

    return ordersValue.when(
      data: (orders) {
        final filtered = _applyFilters(orders);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search by customer, phone, or order ID',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: widget.onCreateOrder,
                    icon: const Icon(Icons.add),
                    label: const Text('New Order'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _status == null,
                  onSelected: (_) => setState(() => _status = null),
                ),
                ...OrderStatus.values.map(
                  (status) => FilterChip(
                    label: Text(status.name.toUpperCase()),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const SizedBox(
                height: 360,
                child: EmptyPlaceholder(
                  title: 'No matching orders',
                  subtitle: 'Adjust the search query or status filter.',
                ),
              )
            else
              ...filtered.map(
                (order) => OrderCard(
                  order: order,
                  onTap: () => widget.onOpenOrder(order.id),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }

  List<OrderEntity> _applyFilters(List<OrderEntity> orders) {
    final query = _searchController.text.trim().toLowerCase();
    return orders.where((order) {
      final matchesStatus = _status == null || order.status == _status;
      final matchesQuery = query.isEmpty ||
          order.id.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          order.customerPhone.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();
  }
}
