import 'package:flutter/material.dart';

/// Standard surface for grouped content: consistent radius, border and padding.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;

    // Material accepts either `shape` or `borderRadius`, never both, so the
    // theme's shape is the single source of the card's outline.
    final shape = cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return Material(
      color: color ?? cardTheme.color ?? theme.colorScheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
