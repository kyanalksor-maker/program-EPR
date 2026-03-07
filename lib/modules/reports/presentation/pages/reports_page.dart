import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';
import 'package:warehouse_manager_app/presentation/widgets/common_widgets.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsValue = ref.watch(employeeReportsProvider);

    return reportsValue.when(
      data: (reports) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionPanel(
            title: 'Employee Reports',
            trailing: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _showExport(context, 'CSV Preview', _csv(reports)),
                  child: const Text('CSV'),
                ),
                OutlinedButton(
                  onPressed: () => _showExport(context, 'Excel-ready Preview', _tsv(reports)),
                  child: const Text('Excel'),
                ),
                OutlinedButton(
                  onPressed: () => _showExport(context, 'PDF Narrative Preview', _pdf(reports)),
                  child: const Text('PDF'),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Entered')),
                  DataColumn(label: Text('Reviewed')),
                  DataColumn(label: Text('Shipped')),
                  DataColumn(label: Text('Returned')),
                ],
                rows: reports
                    .map(
                      (report) => DataRow(
                        cells: [
                          DataCell(Text(report.userName)),
                          DataCell(Text(report.role.label)),
                          DataCell(Text('${report.ordersEntered}')),
                          DataCell(Text('${report.ordersReviewed}')),
                          DataCell(Text('${report.ordersShipped}')),
                          DataCell(Text('${report.ordersReturned}')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }

  static String _csv(List<dynamic> reports) {
    final rows = <String>[
      'employee,role,entered,reviewed,shipped,returned',
      ...reports.map(
        (report) =>
            '${report.userName},${report.role.label},${report.ordersEntered},${report.ordersReviewed},${report.ordersShipped},${report.ordersReturned}',
      ),
    ];
    return rows.join('\n');
  }

  static String _tsv(List<dynamic> reports) {
    final rows = <String>[
      'Employee\tRole\tEntered\tReviewed\tShipped\tReturned',
      ...reports.map(
        (report) =>
            '${report.userName}\t${report.role.label}\t${report.ordersEntered}\t${report.ordersReviewed}\t${report.ordersShipped}\t${report.ordersReturned}',
      ),
    ];
    return rows.join('\n');
  }

  static String _pdf(List<dynamic> reports) {
    final lines = reports
        .map(
          (report) =>
              '${report.userName} (${report.role.label}) handled entered=${report.ordersEntered}, reviewed=${report.ordersReviewed}, shipped=${report.ordersShipped}, returned=${report.ordersReturned}.',
        )
        .join('\n');
    return 'Operational report summary\n\n$lines';
  }

  static Future<void> _showExport(
    BuildContext context,
    String title,
    String content,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(child: SelectableText(content)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
