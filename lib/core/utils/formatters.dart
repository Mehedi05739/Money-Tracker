import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../services/currency_formatter.dart';

/// Formatting helpers for money and percentages.
///
/// The active currency symbol is injected once at startup from `app_settings`
/// rather than threaded through every widget.
/// Formatting entry point for money.
///
/// A thin façade over the injected [CurrencyFormatter] so call sites stay
/// readable. It resolves the service rather than holding the symbol itself —
/// the currency is application state and belongs in the DI graph.
class Money {
  const Money._();

  /// Falls back to a default formatter when DI has not run, which is the case
  /// in pure unit tests that only format a number.
  static CurrencyFormatter get _formatter =>
      Get.isRegistered<CurrencyFormatter>()
      ? Get.find<CurrencyFormatter>()
      : _fallback;

  static final CurrencyFormatter _fallback = CurrencyFormatter();

  static String get symbol => _formatter.symbol;

  /// `1234.5` → `$1,234.50`
  static String format(num value, {bool showSign = false}) =>
      _formatter.format(value, showSign: showSign);

  /// Abbreviates large values for dense cards.
  static String compact(num value) => _formatter.compact(value);

  static String percent(num value, {int decimals = 0}) =>
      '${value.toStringAsFixed(decimals)}%';
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

    final pattern = RegExp(
      r'^\d*\.?\d{0,'
      '$decimals'
      r'}$',
    );
    if (!pattern.hasMatch(text)) return oldValue;
    return newValue;
  }
}
