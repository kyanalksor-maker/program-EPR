class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.purchasePrice,
    required this.salePrice,
    required this.currentStock,
    required this.minStockLevel,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final double purchasePrice;
  final double salePrice;
  final int currentStock;
  final int minStockLevel;

  double get unitProfit => salePrice - purchasePrice;
  bool get isLowStock => currentStock <= minStockLevel;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    double? purchasePrice,
    double? salePrice,
    int? currentStock,
    int? minStockLevel,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      currentStock: currentStock ?? this.currentStock,
      minStockLevel: minStockLevel ?? this.minStockLevel,
    );
  }
}
