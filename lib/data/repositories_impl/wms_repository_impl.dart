import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/data/datasources/remote/backend_data_source.dart';
import 'package:warehouse_manager_app/domain/entities/activity_log.dart';
import 'package:warehouse_manager_app/domain/entities/app_notification.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/entities/dashboard_snapshot.dart';
import 'package:warehouse_manager_app/domain/entities/employee_draft.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/domain/entities/product.dart';
import 'package:warehouse_manager_app/domain/entities/product_draft.dart';
import 'package:warehouse_manager_app/domain/repositories/wms_repository.dart';

class WmsRepositoryImpl implements WmsRepository {
  const WmsRepositoryImpl(this._dataSource);

  final BackendDataSource _dataSource;

  @override
  Future<void> createOrder({
    required AppUser actor,
    required String customerName,
    required String customerPhone,
    required String? notes,
    required List<OrderItem> items,
  }) {
    return _dataSource.createOrder(
      actor: actor,
      customerName: customerName,
      customerPhone: customerPhone,
      notes: notes,
      items: items,
    );
  }

  @override
  Future<void> updateOrder({
    required AppUser actor,
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String? notes,
    required List<OrderItem> items,
  }) {
    return _dataSource.updateOrder(
      actor: actor,
      orderId: orderId,
      customerName: customerName,
      customerPhone: customerPhone,
      notes: notes,
      items: items,
    );
  }

  @override
  Future<void> deleteOrder({
    required AppUser actor,
    required String orderId,
  }) {
    return _dataSource.deleteOrder(actor: actor, orderId: orderId);
  }

  @override
  Future<void> markNotificationRead(String notificationId) =>
      _dataSource.markNotificationRead(notificationId);

  @override
  Future<void> transitionOrder({
    required AppUser actor,
    required String orderId,
    required OrderStatus nextStatus,
    String? note,
  }) {
    return _dataSource.transitionOrder(
      actor: actor,
      orderId: orderId,
      nextStatus: nextStatus,
      note: note,
    );
  }

  @override
  Future<void> overrideOrderStatus({
    required AppUser actor,
    required String orderId,
    required OrderStatus nextStatus,
    String? note,
  }) {
    return _dataSource.overrideOrderStatus(
      actor: actor,
      orderId: orderId,
      nextStatus: nextStatus,
      note: note,
    );
  }

  @override
  Future<void> upsertProduct({
    required AppUser actor,
    required ProductDraft product,
  }) {
    return _dataSource.upsertProduct(actor: actor, product: product);
  }

  @override
  Future<void> deleteProduct({
    required AppUser actor,
    required String productId,
  }) {
    return _dataSource.deleteProduct(actor: actor, productId: productId);
  }

  @override
  Future<void> adjustInventory({
    required AppUser actor,
    required String productId,
    required int quantityDelta,
    required String reason,
  }) {
    return _dataSource.adjustInventory(
      actor: actor,
      productId: productId,
      quantityDelta: quantityDelta,
      reason: reason,
    );
  }

  @override
  Future<void> createEmployee({
    required AppUser actor,
    required EmployeeDraft employee,
  }) {
    return _dataSource.createEmployee(actor: actor, employee: employee);
  }

  @override
  Future<void> updateEmployee({
    required AppUser actor,
    required EmployeeDraft employee,
  }) {
    return _dataSource.updateEmployee(actor: actor, employee: employee);
  }

  @override
  Future<void> deactivateEmployee({
    required AppUser actor,
    required String employeeId,
    required bool isActive,
  }) {
    return _dataSource.deactivateEmployee(
      actor: actor,
      employeeId: employeeId,
      isActive: isActive,
    );
  }

  @override
  Future<void> deleteEmployee({
    required AppUser actor,
    required String employeeId,
  }) {
    return _dataSource.deleteEmployee(actor: actor, employeeId: employeeId);
  }

  @override
  Stream<DashboardSnapshot> watchDashboardSnapshot() =>
      _dataSource.watchDashboardSnapshot();

  @override
  Stream<List<ActivityLog>> watchActivityLogs() => _dataSource.watchActivityLogs();

  @override
  Stream<List<EmployeeReport>> watchEmployeeReports() =>
      _dataSource.watchEmployeeReports();

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) =>
      _dataSource.watchNotifications(userId);

  @override
  Stream<List<OrderEntity>> watchOrders() => _dataSource.watchOrders();

  @override
  Stream<List<Product>> watchProducts() => _dataSource.watchProducts();

  @override
  Stream<List<AppUser>> watchUsers() => _dataSource.watchUsers();
}
