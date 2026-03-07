import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';
import 'package:warehouse_manager_app/core/utils/formatters.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';
import 'package:warehouse_manager_app/presentation/widgets/common_widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({
    super.key,
    required this.onOpenOrder,
  });

  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardValue = ref.watch(dashboardProvider);

    return dashboardValue.when(
      data: (snapshot) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                      ? 2
                      : 1;
              final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    height: 180,
                    child: StatCard(
                      title: 'Total Orders',
                      value: '${snapshot.totalOrders}',
                      subtitle: 'Across all workflow stages',
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFF0C6B58),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    height: 180,
                    child: StatCard(
                      title: 'Revenue',
                      value: AppFormatters.currency(snapshot.revenue),
                      subtitle: 'Realized from shipped/completed orders',
                      icon: Icons.payments_outlined,
                      color: const Color(0xFFD97A29),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    height: 180,
                    child: StatCard(
                      title: 'Profit',
                      value: AppFormatters.currency(snapshot.profit),
                      subtitle: 'Calculated automatically per order',
                      icon: Icons.trending_up_outlined,
                      color: const Color(0xFF1E64B7),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    height: 180,
                    child: StatCard(
                      title: 'Low Stock Alerts',
                      value: '${snapshot.lowStockAlerts}',
                      subtitle: 'Products below minimum stock',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFB63D3D),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 980;
              if (vertical) {
                return Column(
                  children: [
                    SectionPanel(
                      title: 'Orders by Status',
                      child: SizedBox(height: 260, child: _StatusChart(snapshot.ordersByStatus)),
                    ),
                    const SizedBox(height: 16),
                    SectionPanel(
                      title: 'Recent Orders',
                      child: Column(
                        children: snapshot.recentOrders.take(5).map((order) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(order.customerName),
                            subtitle: Text(order.id),
                            trailing: StatusBadge(order.status),
                            onTap: () => onOpenOrder(order.id),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SectionPanel(
                      title: 'Orders by Status',
                      child: SizedBox(height: 260, child: _StatusChart(snapshot.ordersByStatus)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SectionPanel(
                      title: 'Recent Orders',
                      child: Column(
                        children: snapshot.recentOrders.take(5).map((order) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(order.customerName),
                            subtitle: Text(order.id),
                            trailing: StatusBadge(order.status),
                            onTap: () => onOpenOrder(order.id),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }
}

class _StatusChart extends StatelessWidget {
  const _StatusChart(this.data);

  final Map<OrderStatus, int> data;

  @override
  Widget build(BuildContext context) {
    final statuses = OrderStatus.values;
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final status = statuses[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(status.name.substring(0, 3).toUpperCase()),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(statuses.length, (index) {
          final status = statuses[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (data[status] ?? 0).toDouble(),
                width: 24,
                color: const Color(0xFF0C6B58),
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }),
      ),
    );
  }
}
