import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Single place for transient feedback, so tone and placement stay consistent.
///
/// Messages never include amounts or account names — this is financial data and
/// snackbars can be captured in screenshots or read aloud.
class AppSnackbar {
  const AppSnackbar._();

  static void success(String message, {String? title}) =>
      _show(message, title: title, icon: Icons.check_circle_rounded);

  static void error(String message, {String? title}) => _show(
        message,
        title: title ?? 'Something went wrong',
        icon: Icons.error_outline_rounded,
        isError: true,
      );

  static void info(String message, {String? title}) =>
      _show(message, title: title, icon: Icons.info_outline_rounded);

  static void _show(
    String message, {
    String? title,
    IconData? icon,
    bool isError = false,
  }) {
    final context = Get.context;
    if (context == null) return;

    final theme = Theme.of(context);
    final accent = isError ? theme.colorScheme.error : AppColors.primary;

    // Replace rather than queue: rapid saves should not stack notifications.
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();

    Get.rawSnackbar(
      titleText: title == null
          ? null
          : Text(title, style: theme.textTheme.titleMedium),
      messageText: Text(message, style: theme.textTheme.bodyMedium),
      icon: icon == null ? null : Icon(icon, color: accent),
      backgroundColor: theme.colorScheme.surface,
      borderColor: theme.dividerColor,
      borderWidth: 1,
      borderRadius: AppRadius.lg,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.base,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      animationDuration: AppMotion.base,
      overlayBlur: 0,
    );
  }
}
