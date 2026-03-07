import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/modules/auth/presentation/pages/login_page.dart';
import 'package:warehouse_manager_app/modules/dashboard/presentation/pages/dashboard_page.dart';
import 'package:warehouse_manager_app/modules/inventory/presentation/pages/inventory_page.dart';
import 'package:warehouse_manager_app/modules/notifications/presentation/pages/notifications_page.dart';
import 'package:warehouse_manager_app/modules/orders/presentation/pages/create_order_page.dart';
import 'package:warehouse_manager_app/modules/orders/presentation/pages/order_detail_page.dart';
import 'package:warehouse_manager_app/modules/orders/presentation/pages/orders_page.dart';
import 'package:warehouse_manager_app/modules/reports/presentation/pages/reports_page.dart';
import 'package:warehouse_manager_app/modules/users/presentation/pages/users_page.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const LoginPage();
    }

    final destinations = _buildDestinations(user);
    if (_selectedIndex >= destinations.length) {
      _selectedIndex = 0;
    }

    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final wide = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[_selectedIndex].label),
        actions: [
          Chip(label: Text(user.role.label)),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            child: IconButton(
              onPressed: () => _goTo('Notifications', destinations),
              icon: const Icon(Icons.notifications_none_outlined),
            ),
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) => setState(() => _selectedIndex = value),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: destinations[_selectedIndex].page),
              ],
            )
          : destinations[_selectedIndex].page,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) => setState(() => _selectedIndex = value),
              destinations: [
                for (final item in destinations)
                  NavigationDestination(icon: Icon(item.icon), label: item.label),
              ],
            ),
    );
  }

  List<_AppDestination> _buildDestinations(AppUser user) {
    final all = <_AppDestination>[
      _AppDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        page: DashboardPage(onOpenOrder: _openOrder),
        visibleWhen: (candidate) => candidate.hasPermission(AppPermission.dashboardView),
      ),
      _AppDestination(
        label: 'Orders',
        icon: Icons.receipt_long_outlined,
        page: OrdersPage(
          onOpenOrder: _openOrder,
          onCreateOrder: _openCreateOrder,
        ),
        visibleWhen: (candidate) =>
            candidate.hasPermission(AppPermission.ordersView) ||
            candidate.hasPermission(AppPermission.ordersCreate) ||
            candidate.hasPermission(AppPermission.ordersApprove) ||
            candidate.hasPermission(AppPermission.ordersShip),
      ),
      _AppDestination(
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        page: const InventoryPage(),
        visibleWhen: (candidate) =>
            candidate.hasPermission(AppPermission.inventoryView) ||
            candidate.hasPermission(AppPermission.productsView),
      ),
      _AppDestination(
        label: 'Reports',
        icon: Icons.assessment_outlined,
        page: const ReportsPage(),
        visibleWhen: (candidate) => candidate.hasPermission(AppPermission.reportsView),
      ),
      _AppDestination(
        label: 'Notifications',
        icon: Icons.notifications_none_outlined,
        page: NotificationsPage(onOpenOrder: _openOrder),
        visibleWhen: (candidate) => candidate.hasPermission(AppPermission.notificationsView),
      ),
      _AppDestination(
        label: 'Employees',
        icon: Icons.group_outlined,
        page: const UsersPage(),
        visibleWhen: (candidate) =>
            candidate.hasPermission(AppPermission.usersView) ||
            candidate.hasPermission(AppPermission.usersCreate),
      ),
    ];

    return all.where((item) => item.visibleWhen(user)).toList();
  }

  void _goTo(String label, List<_AppDestination> destinations) {
    final index = destinations.indexWhere((item) => item.label == label);
    if (index >= 0) {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _openOrder(String orderId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(orderId: orderId),
      ),
    );
  }

  Future<void> _openCreateOrder() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateOrderPage(),
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.page,
    required this.visibleWhen,
  });

  final String label;
  final IconData icon;
  final Widget page;
  final bool Function(AppUser user) visibleWhen;
}
