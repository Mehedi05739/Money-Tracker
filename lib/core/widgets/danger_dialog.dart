import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../theme/app_spacing.dart';

/// Confirmation for actions that destroy data irreversibly.
///
/// Deliberately harder to dismiss than [ConfirmDialog]: the user must type a
/// word before the button enables. A single tap is too easy to give by reflex,
/// and there is no undo behind this — the ledger is the only copy.
///
/// The dialog states plainly what disappears and that it cannot be recovered,
/// rather than asking "are you sure?", which tells the user nothing.
class DangerDialog {
  const DangerDialog._();

  static Future<bool> show({
    required String title,
    required String message,
    required String confirmWord,
    String confirmLabel = 'Delete forever',
  }) async {
    final context = Get.context;
    if (context == null) return false;

    final result = await showDialog<bool>(
      context: context,
      // Not dismissible by tapping away: closing by accident should never be
      // the same gesture as confirming.
      barrierDismissible: false,
      builder: (dialogContext) => _DangerDialogBody(
        title: title,
        message: message,
        confirmWord: confirmWord,
        confirmLabel: confirmLabel,
      ),
    );
    return result ?? false;
  }
}

class _DangerDialogBody extends StatefulWidget {
  const _DangerDialogBody({
    required this.title,
    required this.message,
    required this.confirmWord,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmWord;
  final String confirmLabel;

  @override
  State<_DangerDialogBody> createState() => _DangerDialogBodyState();
}

class _DangerDialogBodyState extends State<_DangerDialogBody> {
  final TextEditingController _field = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _field.addListener(() {
      final matches =
          _field.text.trim().toUpperCase() == widget.confirmWord.toUpperCase();
      if (matches != _matches) setState(() => _matches = matches);
    });
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
      title: Text(widget.title),
      // Scrollable: the keyboard for the confirmation field leaves very little
      // room on a short screen, and this content must never be clipped — the
      // warning is the point of the dialog.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: theme.textTheme.bodyMedium),
            AppSpacing.gapMd,
            Text(
              'This cannot be undone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.gapBase,
            Text(
              'Type ${widget.confirmWord} to confirm',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapSm,
            TextField(
              controller: _field,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              decoration: InputDecoration(hintText: widget.confirmWord),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
