import 'package:flutter/material.dart';

/// Palette for a finance app: a calm green as the brand colour, with income and
/// expense reading clearly in both themes without relying on hue alone.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF16785F);
  static const Color primaryDark = Color(0xFF0E5843);
  static const Color primaryLight = Color(0xFF4CAF8F);

  // Semantic money colours. The dark variants keep contrast on dark surfaces.
  static const Color income = Color(0xFF17864B);
  static const Color incomeDark = Color(0xFF56D397);
  static const Color expense = Color(0xFFC0392B);
  static const Color expenseDark = Color(0xFFFF8A80);
  static const Color transfer = Color(0xFF4A6FA5);
  static const Color transferDark = Color(0xFF8FB3E0);

  static const Color warning = Color(0xFFE58A00);
  static const Color warningDark = Color(0xFFFFC061);
  static const Color danger = Color(0xFFC0392B);

  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEDF1F4);
  static const Color lightBorder = Color(0xFFE1E6EB);

  static const Color darkBackground = Color(0xFF101315);
  static const Color darkSurface = Color(0xFF181C1F);
  static const Color darkSurfaceAlt = Color(0xFF212629);
  static const Color darkBorder = Color(0xFF2C3235);

  /// Palette used for chart series when a category has no colour of its own.
  static const List<Color> chartPalette = [
    Color(0xFF16785F),
    Color(0xFF4A6FA5),
    Color(0xFFE58A00),
    Color(0xFF8E44AD),
    Color(0xFF17A2B8),
    Color(0xFFD35400),
    Color(0xFF2E86AB),
    Color(0xFFAF4C6B),
    Color(0xFF6B8E23),
    Color(0xFF5D6D7E),
  ];

  static Color chartColorAt(int index) =>
      chartPalette[index % chartPalette.length];
}

/// Theme-aware access to the semantic colours.
extension MoneyColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get incomeColor => _isDark ? AppColors.incomeDark : AppColors.income;
  Color get expenseColor => _isDark ? AppColors.expenseDark : AppColors.expense;
  Color get transferColor =>
      _isDark ? AppColors.transferDark : AppColors.transfer;
  Color get warningColor => _isDark ? AppColors.warningDark : AppColors.warning;
  Color get borderColor =>
      _isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get surfaceAltColor =>
      _isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
}
