import 'package:intl/intl.dart';
import 'package:warehouse_manager_app/core/constants/app_constants.dart';

class AppFormatters {
  const AppFormatters._();

  static final _currency = NumberFormat.currency(
    locale: 'en',
    symbol: '${AppConstants.currencyCode} ',
    decimalDigits: 2,
  );

  static final _compact = NumberFormat.compact(locale: 'en');

  static String currency(double value) => _currency.format(value);

  static String shortDate(DateTime value) =>
      DateFormat('dd MMM yyyy', 'en').format(value);

  static String shortDateTime(DateTime value) =>
      DateFormat('dd MMM yyyy, hh:mm a', 'en').format(value);

  static String compact(num value) => _compact.format(value);
}
