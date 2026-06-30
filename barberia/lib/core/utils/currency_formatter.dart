import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _format =
      NumberFormat.currency(locale: 'es', symbol: r'$');

  static String format(double amount) => _format.format(amount);
}
