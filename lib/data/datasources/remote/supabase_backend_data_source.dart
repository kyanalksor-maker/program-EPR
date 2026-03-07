import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/core/errors/app_exception.dart';
import 'package:warehouse_manager_app/data/datasources/remote/backend_data_source.dart';
import 'package:warehouse_manager_app/data/models/remote_dtos.dart';
import 'package:warehouse_manager_app/domain/entities/activity_log.dart';
import 'package:warehouse_manager_app/domain/entities/app_notification.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/entities/dashboard_snapshot.dart';
import 'package:warehouse_manager_app/domain/entities/employee_draft.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/domain/entities/product.dart';
import 'package:warehouse_manager_app/domain/entities/product_draft.dart';

class SupabaseBackendDataSource implements BackendDataSource {
  SupabaseBackendDataSource() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Stream<AppUser?> watchSession() async* {
    yield await getCurrentUser();
    yield* _client.auth.onAuthStateChange.asyncMap((_) => getCurrentUser());
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      return null;
    }

    final response = await _client
        .from('v_users_with_permissions')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return RemoteMapper.appUser(Map<String, dynamic>.from(response));
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw AppException('Unable to sign in.');
    }

    try {
      await _client.rpc('record_user_login');
    } catch (error) {
      await _client.auth.signOut();
      throw AppException(error.toString());
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Stream<List<OrderEntity>> watchOrders() => _watchComputed(
        tables: const ['orders', 'order_items', 'order_status_history'],
        fetch: _fetchOrders,
      );

  @override
  Stream<List<Product>> watchProducts() => _watchComputed(
        tables: const ['products', 'inventory'],
        fetch: _fetchProducts,
      );

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) => _watchComputed(
        tables: const ['notifications'],
        fetch: () => _fetchNotifications(userId),
      );

  @override
  Stream<List<AppUser>> watchUsers() => _watchComputed(
        tables: const ['users', 'user_permissions', 'roles', 'role_permissions'],
        fetch: _fetchUsers,
      );

  @override
  Stream<List<ActivityLog>> watchActivityLogs() => _watchComputed(
        tables: const ['activity_logs'],
        fetch: _fetchActivityLogs,
      );

  @override
  Stream<DashboardSnapshot> watchDashboardSnapshot() => _watchComputed(
        tables: const [
          'orders',
          'order_items',
          'order_status_history',
          'products',
          'inventory',
          'activity_logs',
        ],
        fetch: _buildDashboard,
      );

  @override
  Stream<List<EmployeeReport>> watchEmployeeReports() => _watchComputed(
        tables: const ['orders', 'order_status_history', 'users', 'user_permissions'],
        fetch: _buildReports,
      );

  @override
  Future<void> createOrder({
    required AppUser actor,
    required String customerName,
    required String customerPhone,
    required String? notes,
    required List<OrderItem> items,
  }) async {
    await _client.rpc(
      'create_order',
      params: {
        'p_customer_name': customerName,
        'p_customer_phone': customerPhone,
        'p_order_notes': notes,
        'p_items': items
            .map((item) => {'product_id': item.productId, 'quantity': item.quantity})
            .toList(),
      },
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
  }) async {
    await _client.rpc(
      'update_order',
      params: {
        'p_order_id': orderId,
        'p_customer_name': customerName,
        'p_customer_phone': customerPhone,
        'p_order_notes': notes,
        'p_items': items
            .map((item) => {'product_id': item.productId, 'quantity': item.quantity})
            .toList(),
      },
    );
  }

  @override
  Future<void> deleteOrder({
    required AppUser actor,
    required String orderId,
  }) {
    return _client.rpc(
      'delete_order',
      params: {'p_order_id': orderId},
    );
  }

  @override
  Future<void> transitionOrder({
    required AppUser actor,
    required String orderId,
    required OrderStatus nextStatus,
    String? note,
  }) {
    return _client.rpc(
      'transition_order',
      params: {
        'p_order_id': orderId,
        'p_next_status': nextStatus.name,
        'p_note': note,
      },
    );
  }

  @override
  Future<void> overrideOrderStatus({
    required AppUser actor,
    required String orderId,
    required OrderStatus nextStatus,
    String? note,
  }) {
    return _client.rpc(
      'override_order_status',
      params: {
        'p_order_id': orderId,
        'p_next_status': nextStatus.name,
        'p_note': note,
      },
    );
  }

  @override
  Future<void> upsertProduct({
    required AppUser actor,
    required ProductDraft product,
  }) async {
    await _client.rpc(
      'upsert_product',
      params: {
        'p_product_id': product.id,
        'p_name': product.name,
        'p_sku': product.sku,
        'p_category': product.category,
        'p_purchase_price': product.purchasePrice,
        'p_sale_price': product.salePrice,
        'p_stock': product.stock,
        'p_min_stock': product.minStockLevel,
      },
    );
  }

  @override
  Future<void> deleteProduct({
    required AppUser actor,
    required String productId,
  }) {
    return _client.rpc(
      'delete_product',
      params: {'p_product_id': productId},
    );
  }

  @override
  Future<void> adjustInventory({
    required AppUser actor,
    required String productId,
    required int quantityDelta,
    required String reason,
  }) {
    return _client.rpc(
      'adjust_inventory',
      params: {
        'p_product_id': productId,
        'p_quantity_delta': quantityDelta,
        'p_reason': reason,
      },
    );
  }

  @override
  Future<void> createEmployee({
    required AppUser actor,
    required EmployeeDraft employee,
  }) {
    return _invokeEmployeeManager(
      action: 'create',
      employee: employee,
    );
  }

  @override
  Future<void> updateEmployee({
    required AppUser actor,
    required EmployeeDraft employee,
  }) {
    return _invokeEmployeeManager(
      action: 'update',
      employee: employee,
    );
  }

  @override
  Future<void> deactivateEmployee({
    required AppUser actor,
    required String employeeId,
    required bool isActive,
  }) {
    return _invokeEmployeeManager(
      action: 'deactivate',
      employeeId: employeeId,
      isActive: isActive,
    );
  }

  @override
  Future<void> deleteEmployee({
    required AppUser actor,
    required String employeeId,
  }) {
    return _invokeEmployeeManager(
      action: 'delete',
      employeeId: employeeId,
    );
  }

  @override
  Future<void> markNotificationRead(String notificationId) {
    return _client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }

  Future<void> _invokeEmployeeManager({
    required String action,
    EmployeeDraft? employee,
    String? employeeId,
    bool? isActive,
  }) async {
    final response = await _client.functions.invoke(
      'admin-manage-employee',
      body: {
        'action': action,
        'employeeId': employeeId ?? employee?.id,
        'name': employee?.name,
        'email': employee?.email,
        'password': employee?.password,
        'roleName': employee?.role.label,
        'permissions': employee?.permissions.map((item) => item.code).toList(),
        'isActive': isActive ?? employee?.isActive,
      },
    );

    if (response.status >= 400) {
      throw AppException(response.data.toString());
    }
  }

  Stream<T> _watchComputed<T>({
    required List<String> tables,
    required Future<T> Function() fetch,
  }) {
    late StreamController<T> controller;
    final channels = <RealtimeChannel>[];

    Future<void> emit() async {
      if (controller.isClosed) {
        return;
      }
      try {
        controller.add(await fetch());
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<T>.broadcast(
      onListen: () async {
        await emit();
        for (final table in tables) {
          final channel = _client
              .channel('watch:$table:${DateTime.now().microsecondsSinceEpoch}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: table,
                callback: (_) async => emit(),
              )
              .subscribe();
          channels.add(channel);
        }
      },
      onCancel: () async {
        for (final channel in channels) {
          await channel.unsubscribe();
        }
      },
    );

    return controller.stream;
  }

  Future<List<AppUser>> _fetchUsers() async {
    final response = await _client
        .from('v_users_with_permissions')
        .select()
        .order('created_at', ascending: false);

    return response
        .map((row) => RemoteMapper.appUser(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Product>> _fetchProducts() async {
    final response = await _client
        .from('v_products')
        .select()
        .order('name');

    return response
        .map((row) => RemoteMapper.product(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<OrderEntity>> _fetchOrders() async {
    final response = await _client.from('orders').select(
          'id, customer_name, customer_phone, order_date, order_notes, status, '
          'created_by, created_by_name, '
          'order_items(id, product_id, product_name, quantity, purchase_price, sale_price, profit), '
          'order_status_history(id, status, changed_by, changed_by_name, changed_at, note)',
        ).order('order_date', ascending: false);

    return response
        .map((row) => RemoteMapper.order(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<AppNotification>> _fetchNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id, user_id, title, message, type, read, created_at, reference_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response
        .map((row) => RemoteMapper.notification(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<ActivityLog>> _fetchActivityLogs() async {
    final response = await _client
        .from('activity_logs')
        .select('id, actor_id, actor_name, action, entity_type, entity_id, metadata, created_at')
        .order('created_at', ascending: false)
        .limit(40);

    return response
        .map((row) => RemoteMapper.activityLog(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<DashboardSnapshot> _buildDashboard() async {
    final orders = await _fetchOrders();
    final products = await _fetchProducts();
    final activityLogs = await _safeFetch(_fetchActivityLogs, const <ActivityLog>[]);

    final ordersByStatus = {
      for (final status in OrderStatus.values)
        status: orders.where((order) => order.status == status).length,
    };

    final realizedOrders = orders.where(
      (order) =>
          order.status == OrderStatus.shipped ||
          order.status == OrderStatus.completed,
    );

    final groupedActivity = <String, UserActivitySummary>{};
    for (final log in activityLogs) {
      final current = groupedActivity[log.actorId];
      if (current == null) {
        groupedActivity[log.actorId] = UserActivitySummary(
          userName: log.actorName,
          role: UserRole.orderEntry,
          totalActions: 1,
        );
      } else {
        groupedActivity[log.actorId] = UserActivitySummary(
          userName: current.userName,
          role: current.role,
          totalActions: current.totalActions + 1,
        );
      }
    }

    return DashboardSnapshot(
      totalOrders: orders.length,
      ordersByStatus: ordersByStatus,
      revenue: realizedOrders.fold<double>(0, (sum, order) => sum + order.totalRevenue),
      profit: realizedOrders.fold<double>(0, (sum, order) => sum + order.profit),
      inventoryValue: products.fold<double>(
        0,
        (sum, product) => sum + product.currentStock * product.purchasePrice,
      ),
      lowStockAlerts: products.where((product) => product.isLowStock).length,
      recentOrders: orders.take(6).toList(),
      userActivity: groupedActivity.values.toList()
        ..sort((a, b) => b.totalActions.compareTo(a.totalActions)),
    );
  }

  Future<List<EmployeeReport>> _buildReports() async {
    final users = await _fetchUsers();
    final orders = await _fetchOrders();

    return users.map((user) {
      final createdOrders = orders.where((order) => order.createdBy == user.id).toList();
      final reviewedOrderIds = <String>{};
      final shippedOrderIds = <String>{};
      final returnedOrderIds = <String>{};

      for (final order in orders) {
        for (final history in order.history) {
          if (history.changedBy != user.id) {
            continue;
          }
          if (history.status == OrderStatus.checked ||
              history.status == OrderStatus.approved) {
            reviewedOrderIds.add(order.id);
          }
          if (history.status == OrderStatus.shipped ||
              history.status == OrderStatus.completed) {
            shippedOrderIds.add(order.id);
          }
          if (history.status == OrderStatus.returned) {
            returnedOrderIds.add(order.id);
          }
        }
      }

      return EmployeeReport(
        userId: user.id,
        userName: user.name,
        role: user.role,
        ordersEntered: createdOrders.length,
        ordersReviewed: reviewedOrderIds.length,
        ordersShipped: shippedOrderIds.length,
        ordersReturned: returnedOrderIds.length,
      );
    }).toList()
      ..sort((a, b) => a.userName.compareTo(b.userName));
  }

  Future<T> _safeFetch<T>(Future<T> Function() fetch, T fallback) async {
    try {
      return await fetch();
    } catch (_) {
      return fallback;
    }
  }
}
