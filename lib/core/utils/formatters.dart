import 'package:all_commerce/core/constants/product_units.dart';
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

  /// '2' / '1,25' — quantity, trims trailing zeros (es_AR decimals).
  static String qty(num value) {
    final NumberFormat format = NumberFormat.decimalPattern('es_AR')
      ..maximumFractionDigits = 3;
    return format.format(value);
  }

  /// '2 un.' / '1,25 kg' — quantity with its unit label.
  static String qtyLabel(num value, String unit) =>
      '${qty(value)} ${ProductUnit.labelOf(unit)}';

  /// 'dd/MM HH:mm' — short timestamp for order lists (local timezone).
  static String dateTime(DateTime value) {
    return DateFormat('dd/MM HH:mm').format(value.toLocal());
  }
}
