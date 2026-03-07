import 'package:warehouse_manager_app/core/constants/app_enums.dart';

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    required this.salePrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double purchasePrice;
  final double salePrice;

  double get totalCost => purchasePrice * quantity;
  double get totalRevenue => salePrice * quantity;
  double get profit => (salePrice - purchasePrice) * quantity;
}

class OrderHistoryEntry {
  const OrderHistoryEntry({
    required this.status,
    required this.changedBy,
    required this.changedByName,
    required this.changedAt,
    this.note,
  });

  final OrderStatus status;
  final String changedBy;
  final String changedByName;
  final DateTime changedAt;
  final String? note;
}

class OrderEntity {
  const OrderEntity({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.orderDate,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    required this.items,
    required this.history,
    this.notes,
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final DateTime orderDate;
  final String? notes;
  final OrderStatus status;
  final String createdBy;
  final String createdByName;
  final List<OrderItem> items;
  final List<OrderHistoryEntry> history;

  double get totalCost =>
      items.fold<double>(0, (sum, item) => sum + item.totalCost);
  double get totalRevenue =>
      items.fold<double>(0, (sum, item) => sum + item.totalRevenue);
  double get profit => items.fold<double>(0, (sum, item) => sum + item.profit);
  int get totalQuantity => items.fold<int>(0, (sum, item) => sum + item.quantity);

  OrderEntity copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    DateTime? orderDate,
    String? notes,
    OrderStatus? status,
    String? createdBy,
    String? createdByName,
    List<OrderItem>? items,
    List<OrderHistoryEntry>? history,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderDate: orderDate ?? this.orderDate,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      items: items ?? this.items,
      history: history ?? this.history,
    );
  }
}
