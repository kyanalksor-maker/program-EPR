import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/core/utils/formatters.dart';
import 'package:warehouse_manager_app/domain/entities/product.dart';
import 'package:warehouse_manager_app/domain/entities/product_draft.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsValue = ref.watch(productsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final canCreate = currentUser?.hasPermission(AppPermission.productsCreate) ?? false;
    final canEdit = currentUser?.hasPermission(AppPermission.productsEdit) ?? false;
    final canDelete = currentUser?.hasPermission(AppPermission.productsDelete) ?? false;
    final canAdjust = currentUser?.hasPermission(AppPermission.inventoryEdit) ?? false;

    return productsValue.when(
      data: (products) {
        final filtered = products.where((product) {
          final query = _searchController.text.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query) ||
              product.category.toLowerCase().contains(query);
        }).toList();

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
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by name, SKU, or category',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () => _showProductDialog(context),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Add Product'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...filtered.map(
              (product) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(product.name),
                  subtitle: Text('${product.sku} • ${product.category}'),
                  trailing: Wrap(
                    spacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MetricText(label: 'Stock', value: '${product.currentStock}'),
                      _MetricText(
                        label: 'Price',
                        value: AppFormatters.currency(product.salePrice),
                      ),
                      _MetricText(
                        label: 'Profit',
                        value: AppFormatters.currency(product.unitProfit),
                      ),
                      _MetricText(
                        label: 'Status',
                        value: product.isLowStock ? 'Low Stock' : 'Healthy',
                        color: product.isLowStock
                            ? const Color(0xFFB63D3D)
                            : const Color(0xFF0C6B58),
                      ),
                      if (canAdjust)
                        IconButton(
                          onPressed: () => _showInventoryDialog(context, product),
                          icon: const Icon(Icons.tune),
                          tooltip: 'Adjust Inventory',
                        ),
                      if (canEdit)
                        IconButton(
                          onPressed: () => _showProductDialog(context, product: product),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Product',
                        ),
                      if (canDelete)
                        IconButton(
                          onPressed: () => _deleteProduct(product.id),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Archive Product',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }

  Future<void> _showProductDialog(
    BuildContext context, {
    Product? product,
  }) async {
    final nameController = TextEditingController(text: product?.name ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');
    final categoryController = TextEditingController(text: product?.category ?? '');
    final purchaseController =
        TextEditingController(text: product?.purchasePrice.toString() ?? '');
    final saleController =
        TextEditingController(text: product?.salePrice.toString() ?? '');
    final stockController =
        TextEditingController(text: product?.currentStock.toString() ?? '0');
    final minStockController =
        TextEditingController(text: product?.minStockLevel.toString() ?? '0');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'Add Product' : 'Edit Product'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(controller: skuController, decoration: const InputDecoration(labelText: 'SKU')),
                const SizedBox(height: 12),
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 12),
                TextField(controller: purchaseController, decoration: const InputDecoration(labelText: 'Purchase Price (EGP)')),
                const SizedBox(height: 12),
                TextField(controller: saleController, decoration: const InputDecoration(labelText: 'Sale Price (EGP)')),
                const SizedBox(height: 12),
                TextField(controller: stockController, decoration: const InputDecoration(labelText: 'Current Stock')),
                const SizedBox(height: 12),
                TextField(controller: minStockController, decoration: const InputDecoration(labelText: 'Minimum Stock')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) {
      return;
    }

    await ref.read(operationsControllerProvider.notifier).upsertProduct(
          ProductDraft(
            id: product?.id,
            name: nameController.text.trim(),
            sku: skuController.text.trim(),
            category: categoryController.text.trim(),
            purchasePrice: double.parse(purchaseController.text.trim()),
            salePrice: double.parse(saleController.text.trim()),
            stock: int.parse(stockController.text.trim()),
            minStockLevel: int.parse(minStockController.text.trim()),
          ),
        );

    if (!context.mounted) {
      return;
    }
    _showOperationResult(context);
  }

  Future<void> _showInventoryDialog(BuildContext context, Product product) async {
    final qtyController = TextEditingController(text: '0');
    final reasonController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Inventory • ${product.name}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(
                  labelText: 'Quantity Delta (+/-)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (saved != true) {
      return;
    }

    await ref.read(operationsControllerProvider.notifier).adjustInventory(
          productId: product.id,
          quantityDelta: int.parse(qtyController.text.trim()),
          reason: reasonController.text.trim(),
        );

    if (!context.mounted) {
      return;
    }
    _showOperationResult(context);
  }

  Future<void> _deleteProduct(String productId) async {
    await ref.read(operationsControllerProvider.notifier).deleteProduct(productId);
    if (!mounted) {
      return;
    }
    _showOperationResult(context);
  }

  void _showOperationResult(BuildContext context) {
    final state = ref.read(operationsControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString())),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Operation completed.')),
    );
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
