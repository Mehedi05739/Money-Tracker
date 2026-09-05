import 'package:flutter/services.dart';

/// Formatting helpers for money and percentages.
///
/// The active currency symbol is injected once at startup from `app_settings`
/// rather than threaded through every widget.
class Money {
  const Money._();

  static String _symbol = r'$';

  static String get symbol => _symbol;

  /// Called by the settings layer when the user picks another currency.
  static void configure(String symbol) => _symbol = symbol;

  /// `1234.5` → `$1,234.50`
  static String format(num value, {bool showSign = false}) {
    final sign = value < 0 ? '-' : (showSign && value > 0 ? '+' : '');
    return '$sign$_symbol${_grouped(value.abs().toStringAsFixed(2))}';
  }

  /// Drops the decimals when they are `.00`, for dense summary cards.
  static String compact(num value) {
    final absolute = value.abs();
    if (absolute >= 1000000) {
      return '${value < 0 ? '-' : ''}$_symbol${(absolute / 1000000).toStringAsFixed(1)}M';
    }
    if (absolute >= 10000) {
      return '${value < 0 ? '-' : ''}$_symbol${(absolute / 1000).toStringAsFixed(1)}K';
    }
    return format(value);
  }

  static String percent(num value, {int decimals = 0}) =>
      '${value.toStringAsFixed(decimals)}%';

  static String _grouped(String fixed) {
    final parts = fixed.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return '$whole.${parts.last}';
  }
}

/// Keeps amount fields to digits with at most two decimals, so invalid input
/// cannot be typed in the first place.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({this.decimals = 2});

  final int decimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final pattern = RegExp(r'^\d*\.?\d{0,' '$decimals' r'}$');
    if (!pattern.hasMatch(text)) return oldValue;
    return newValue;
  }
}
