import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0', 'en_US');

  static String format(double amount) {
    return '৳${_formatter.format(amount)}';
  }

  static String formatWithLabel(double amount, String label) {
    return '${format(amount)} / $label';
  }

  static String displayPrice(double? price, {String? label}) {
    if (price == null) return 'Contact for pricing';
    if (price == 0) return 'Free';
    if (label != null) return formatWithLabel(price, label);
    return format(price);
  }
}
