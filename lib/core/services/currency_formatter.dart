import 'package:get/get.dart';

/// Formats money in the user's chosen currency.
///
/// Registered in the DI graph rather than kept in a mutable static: the
/// currency is application state, and a global would be a second source of
/// truth alongside `app_settings`, invisible to `Get.reset()` and shared
/// between tests running in the same isolate.
class CurrencyFormatter extends GetxService {
  CurrencyFormatter({this.symbol = r'$'});

  String symbol;

  /// Called by the settings layer when the user picks another currency.
  void useSymbol(String value) => symbol = value;

  /// `1234.5` → `$1,234.50`
  String format(num value, {bool showSign = false}) {
    final sign = value < 0 ? '-' : (showSign && value > 0 ? '+' : '');
    return '$sign$symbol${_grouped(value.abs().toStringAsFixed(2))}';
  }

  /// Drops decimals for dense summary cards, and abbreviates large values.
  String compact(num value) {
    final absolute = value.abs();
    final sign = value < 0 ? '-' : '';

    if (absolute >= 1000000) {
      return '$sign$symbol${(absolute / 1000000).toStringAsFixed(1)}M';
    }
    if (absolute >= 10000) {
      return '$sign$symbol${(absolute / 1000).toStringAsFixed(1)}K';
    }
    return format(value);
  }

  static String _grouped(String fixed) {
    final parts = fixed.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return '$whole.${parts.last}';
  }
}
