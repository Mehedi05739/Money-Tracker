import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

/// Budget/goal progress bar that turns amber near the limit and red past it.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.warningThreshold = 0.8,
    this.height = AppSpacing.sm,
    this.exceeded = false,
    this.animate = true,
  });

  /// 0–1, already clamped by the caller.
  final double value;
  final Color? color;
  final double warningThreshold;
  final double height;
  final bool exceeded;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = color ?? _statusColor(context);

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: theme.progressIndicatorTheme.linearTrackColor,
        valueColor: AlwaysStoppedAnimation<Color>(resolved),
      ),
    );

    if (!animate) return bar;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (context, animated, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: theme.progressIndicatorTheme.linearTrackColor,
          valueColor: AlwaysStoppedAnimation<Color>(resolved),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    if (exceeded || value > 1) return context.expenseColor;
    if (value >= warningThreshold) return context.warningColor;
    return Theme.of(context).colorScheme.primary;
  }
}
