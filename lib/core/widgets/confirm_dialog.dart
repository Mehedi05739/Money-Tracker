import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Confirmation for destructive actions. Returns true only on explicit confirm.
class ConfirmDialog {
  const ConfirmDialog._();

  static Future<bool> show({
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool destructive = true,
  }) async {
    final context = Get.context;
    if (context == null) return false;

    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    minimumSize: const Size(88, 44),
                  )
                : FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
