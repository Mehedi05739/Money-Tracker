import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// The single theme definition. Every component theme reads its geometry from
/// the token files, so a change to the scale reaches the whole app.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    );

    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceAlt = isDark
        ? AppColors.darkSurfaceAlt
        : AppColors.lightSurfaceAlt;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      textTheme: AppTextStyles.textTheme(scheme.onSurface),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlAll,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(space: 1, thickness: 1, color: border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        border: _inputBorder(border),
        enabledBorder: _inputBorder(border),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          textStyle: AppTextStyles.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppTextStyles.titleMedium,
          // 48dp keeps text buttons at the minimum accessible tap target.
          minimumSize: const Size(48, 44),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: AppTextStyles.caption.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: AppTextStyles.caption.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
        side: BorderSide(color: border),
        labelStyle: AppTextStyles.bodyMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: border,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xxlAll),
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearMinHeight: AppSpacing.sm,
        linearTrackColor: surfaceAlt,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: AppMotion.slow,
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.xsAll,
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: color, width: width),
      );
}
