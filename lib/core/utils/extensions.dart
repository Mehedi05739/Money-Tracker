import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Only additions GetX does not already provide — `context.theme`,
/// `context.textTheme` and `context.isDarkMode` come from `package:get`.
extension BuildContextX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  bool get isKeyboardOpen => MediaQuery.viewInsetsOf(this).bottom > 0;
}

extension NumX on num {
  /// `1234.5` → `$1,234.50`
  String toCurrency({String symbol = AppConstants.defaultCurrencySymbol}) {
    final negative = this < 0;
    final parts = abs().toStringAsFixed(2).split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return '${negative ? '-' : ''}$symbol$grouped.${parts.last}';
  }
}

extension DateTimeX on DateTime {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `2026-09-05` → `05 Sep 2026`
  String get formatted =>
      '${day.toString().padLeft(2, '0')} ${_months[month - 1]} $year';

  bool get isToday {
    final now = DateTime.now();
    return now.year == year && now.month == month && now.day == day;
  }

  DateTime get startOfDay => DateTime(year, month, day);
}

extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(trim());

  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
