import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/domain/entities/activity_log.dart';
import 'package:warehouse_manager_app/domain/entities/app_notification.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/entities/dashboard_snapshot.dart';
import 'package:warehouse_manager_app/domain/entities/employee_draft.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/domain/entities/product.dart';
import 'package:warehouse_manager_app/domain/entities/product_draft.dart';

abstract class WmsRepository {
  Stream<List<OrderEntity>> watchOrders();
  Stream<List<Product>> watchProducts();
  Stream<List<AppNotification>> watchNotifications(String userId);
  Stream<List<AppUser>> watchUsers();
  Stream<List<ActivityLog>> watchActivityLogs();
  Stream<DashboardSnapshot> watchDashboardSnapshot();
  Stream<List<EmployeeReport>> watchEmployeeReports();
  Future<void> createOrder({
    required AppUser actor,
    required String customerName,
    required String customerPhone,
    required String? notes,
    required List<OrderItem> items,
  });
  Future<void> updateOrder({
    required AppUser actor,
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String? notes,
    required List<OrderItem> items,
  });
  Future<void> deleteOrder({
    required AppUser actor,
    required String orderId,
  });
  Future<void> transitionOrder({
    required AppUser actor,
    required String orderId,
    required OrderStatus nextStatus,
    String? note,
  });
  Future<void> overrideOrderStatus({
    required AppUser actor,
    required String orderId,
    required OrderStatus nextStatus,
    String? note,
  });
  Future<void> upsertProduct({
    required AppUser actor,
    required ProductDraft product,
  });
  Future<void> deleteProduct({
    required AppUser actor,
    required String productId,
  });
  Future<void> adjustInventory({
    required AppUser actor,
    required String productId,
    required int quantityDelta,
    required String reason,
  });
  Future<void> createEmployee({
    required AppUser actor,
    required EmployeeDraft employee,
  });
  Future<void> updateEmployee({
    required AppUser actor,
    required EmployeeDraft employee,
  });
  Future<void> deactivateEmployee({
    required AppUser actor,
    required String employeeId,
    required bool isActive,
  });
  Future<void> deleteEmployee({
    required AppUser actor,
    required String employeeId,
  });
  Future<void> markNotificationRead(String notificationId);
}
