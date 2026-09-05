import 'package:flutter/material.dart';

import 'date_utils.dart';
import 'formatters.dart';

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
  String get asMoney => Money.format(this);

  /// Same, but prefixes `+` for positive values.
  String get asSignedMoney => Money.format(this, showSign: true);

  /// Share of [total] as a 0–100 value, safe when [total] is zero.
  double percentOf(num total) => total == 0 ? 0 : (this / total) * 100;
}

extension DateTimeX on DateTime {
  String get formatted => AppDate.formatDate(this);
  String get formattedWithTime => AppDate.formatDateTime(this);
  String get relativeDay => AppDate.formatRelativeDay(this);
  bool get isToday => AppDate.isToday(this);
  DateTime get startOfDay => AppDate.startOfDay(this);
  DateTime get endOfDay => AppDate.endOfDay(this);
}

extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(trim());

  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
