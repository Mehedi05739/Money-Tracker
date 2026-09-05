import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// Large read-only amount, driven by [AmountKeypad] rather than the system IME.
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.controller,
    this.errorText,
    this.textAlign = TextAlign.center,
  });

  final TextEditingController controller;
  final String? errorText;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final isEmpty = value.text.isEmpty;
            return Row(
              mainAxisAlignment: textAlign == TextAlign.center
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Money.symbol,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.hGapSm,
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isEmpty ? '0' : value.text,
                      maxLines: 1,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: isEmpty
                            ? theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              )
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (errorText != null) ...[
          AppSpacing.gapXs,
          Text(
            errorText!,
            textAlign: textAlign,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// On-sheet numeric keypad.
///
/// Replaces the system keyboard for amount entry. That is not decoration: the
/// IME claims roughly half the screen and animates in, which leaves no room to
/// show categories beside the amount. Owning the keypad means the whole entry
/// fits on one surface, and the targets are far bigger than an IME's.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    this.onClear,
    this.keyHeight = 52,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final VoidCallback? onClear;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _KeyRow(
            height: keyHeight,
            children: [
              for (final key in row)
                _Key(label: key, height: keyHeight, onTap: () => onDigit(key)),
            ],
          ),
        _KeyRow(
          height: keyHeight,
          children: [
            _Key(label: '.', height: keyHeight, onTap: onDecimal),
            _Key(label: '0', height: keyHeight, onTap: () => onDigit('0')),
            _Key(
              height: keyHeight,
              icon: Icons.backspace_outlined,
              semanticLabel: 'Delete',
              onTap: onBackspace,
              onLongPress: onClear,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children, required this.height});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) AppSpacing.hGapSm,
          Expanded(child: children[i]),
        ],
      ],
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({
    required this.height,
    required this.onTap,
    this.label,
    this.icon,
    this.semanticLabel,
    this.onLongPress,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final double height;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                },
          child: SizedBox(
            height: height,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 22, color: theme.colorScheme.onSurface)
                  : Text(
                      label!,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
