import 'package:flutter/material.dart';

import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// The standard content surface: one radius, one border, one interior.
///
/// Cards separate by border and fill rather than heavy shadow — a finance app
/// reads as trustworthy when it is calm.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.color,
    this.borderColor,
    this.elevated = false,
  });

  /// Denser variant for tiles sitting in a grid.
  const AppCard.compact({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderColor,
    this.elevated = false,
  }) : padding = AppSpacing.cardCompact;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  /// Lifts the card above the page. Reserve it for surfaces that overlay
  /// content, not for ordinary rows.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;

    // Material takes either `shape` or `borderRadius`, never both.
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadius.xlAll,
      side: BorderSide(color: borderColor ?? theme.dividerColor),
    );

    final surface = Material(
      color: color ?? cardTheme.color ?? theme.colorScheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (!elevated) return surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        boxShadow: AppElevation.card(context),
      ),
      child: surface,
    );
  }
}
