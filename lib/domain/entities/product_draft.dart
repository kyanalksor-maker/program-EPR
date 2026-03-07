class ProductDraft {
  const ProductDraft({
    this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.purchasePrice,
    required this.salePrice,
    required this.stock,
    required this.minStockLevel,
  });

  final String? id;
  final String name;
  final String sku;
  final String category;
  final double purchasePrice;
  final double salePrice;
  final int stock;
  final int minStockLevel;
}
