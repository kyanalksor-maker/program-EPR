import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';

class UserActivitySummary {
  const UserActivitySummary({
    required this.userName,
    required this.role,
    required this.totalActions,
  });

  final String userName;
  final UserRole role;
  final int totalActions;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalOrders,
    required this.ordersByStatus,
    required this.revenue,
    required this.profit,
    required this.inventoryValue,
    required this.lowStockAlerts,
    required this.recentOrders,
    required this.userActivity,
  });

  final int totalOrders;
  final Map<OrderStatus, int> ordersByStatus;
  final double revenue;
  final double profit;
  final double inventoryValue;
  final int lowStockAlerts;
  final List<OrderEntity> recentOrders;
  final List<UserActivitySummary> userActivity;
}

class EmployeeReport {
  const EmployeeReport({
    required this.userId,
    required this.userName,
    required this.role,
    required this.ordersEntered,
    required this.ordersReviewed,
    required this.ordersShipped,
    required this.ordersReturned,
  });

  final String userId;
  final String userName;
  final UserRole role;
  final int ordersEntered;
  final int ordersReviewed;
  final int ordersShipped;
  final int ordersReturned;
}
