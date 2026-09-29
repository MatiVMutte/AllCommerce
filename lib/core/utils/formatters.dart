import 'package:intl/intl.dart';

abstract final class Formatters {
  /// '$1.234' for whole amounts, '$1.234,56' with cents (es_AR style).
  static String price(num value) {
    final bool hasCents = value % 1 != 0;
    final int digits = hasCents ? 2 : 0;
    final NumberFormat format = NumberFormat.decimalPattern('es_AR')
      ..minimumFractionDigits = digits
      ..maximumFractionDigits = digits;
    return '\$${format.format(value)}';
  }

  /// 'dd/MM HH:mm' — short timestamp for order lists.
  static String dateTime(DateTime value) {
    return DateFormat('dd/MM HH:mm').format(value);
  }
}
