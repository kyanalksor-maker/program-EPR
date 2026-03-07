import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/domain/entities/activity_log.dart';
import 'package:warehouse_manager_app/domain/entities/app_notification.dart';
import 'package:warehouse_manager_app/domain/entities/app_user.dart';
import 'package:warehouse_manager_app/domain/entities/order.dart';
import 'package:warehouse_manager_app/domain/entities/product.dart';

class RemoteMapper {
  const RemoteMapper._();

  static AppUser appUser(Map<String, dynamic> json) {
    final permissionsJson = json['permissions'];
    final permissionList = permissionsJson is List
        ? permissionsJson.map((item) => item.toString()).toList()
        : const <String>[];

    return AppUser(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unknown User',
      email: json['email']?.toString() ?? '',
      roleId: json['role_id']?.toString() ?? '',
      role: UserRole.fromRoleName(json['role_name']?.toString() ?? ''),
      permissions: permissionList
          .map(AppPermission.fromCode)
          .whereType<AppPermission>()
          .toSet(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
      lastActive: DateTime.tryParse(json['last_active']?.toString() ?? ''),
    );
  }

  static Product product(Map<String, dynamic> json) {
    final inventory = json['inventory'] is Map<String, dynamic>
        ? json['inventory'] as Map<String, dynamic>
        : null;

    return Product(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unnamed Product',
      sku: json['sku']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0,
      salePrice: (json['sale_price'] as num?)?.toDouble() ?? 0,
      currentStock:
          (inventory?['stock'] as num?)?.toInt() ?? (json['stock'] as num?)?.toInt() ?? 0,
      minStockLevel:
          (inventory?['min_stock'] as num?)?.toInt() ?? (json['min_stock'] as num?)?.toInt() ?? 0,
    );
  }

  static OrderEntity order(Map<String, dynamic> json) {
    final itemsJson = (json['order_items'] as List<dynamic>? ?? const []);
    final historyJson =
        (json['order_status_history'] as List<dynamic>? ?? const []);

    return OrderEntity(
      id: json['id'].toString(),
      customerName: json['customer_name']?.toString() ?? 'Unknown Customer',
      customerPhone: json['customer_phone']?.toString() ?? '',
      orderDate: DateTime.tryParse(json['order_date']?.toString() ?? '') ??
          DateTime.now(),
      notes: json['order_notes']?.toString(),
      status: _statusFromString(json['status']?.toString() ?? 'entered'),
      createdBy: json['created_by']?.toString() ?? '',
      createdByName: json['created_by_name']?.toString() ?? 'System',
      items: itemsJson
          .whereType<Map>()
          .map((item) => orderItem(Map<String, dynamic>.from(item)))
          .toList(),
      history: historyJson
          .whereType<Map>()
          .map((entry) => orderHistory(Map<String, dynamic>.from(entry)))
          .toList()
        ..sort((a, b) => a.changedAt.compareTo(b.changedAt)),
    );
  }

  static OrderItem orderItem(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'].toString(),
      productName: json['product_name']?.toString() ?? 'Product',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0,
      salePrice: (json['sale_price'] as num?)?.toDouble() ?? 0,
    );
  }

  static OrderHistoryEntry orderHistory(Map<String, dynamic> json) {
    return OrderHistoryEntry(
      status: _statusFromString(json['status']?.toString() ?? 'entered'),
      changedBy: json['changed_by']?.toString() ?? '',
      changedByName: json['changed_by_name']?.toString() ?? 'System',
      changedAt: DateTime.tryParse(json['changed_at']?.toString() ?? '') ??
          DateTime.now(),
      note: json['note']?.toString(),
    );
  }

  static AppNotification notification(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: _notificationTypeFromString(json['type']?.toString() ?? 'workflow'),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['read'] as bool? ?? false,
      referenceId: json['reference_id']?.toString(),
    );
  }

  static ActivityLog activityLog(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'].toString(),
      actorId: json['actor_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'Unknown User',
      action: json['action']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  static OrderStatus _statusFromString(String raw) {
    return OrderStatus.values.firstWhere(
      (status) => status.name == raw.toLowerCase(),
      orElse: () => OrderStatus.entered,
    );
  }

  static NotificationType _notificationTypeFromString(String raw) {
    return NotificationType.values.firstWhere(
      (type) => type.name == raw.toLowerCase(),
      orElse: () => NotificationType.workflow,
    );
  }
}
