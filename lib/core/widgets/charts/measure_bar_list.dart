import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../app_card.dart';
import '../app_progress_bar.dart';

/// One labelled measure: an amount shown against the whole it belongs to.
class MeasureBar {
  const MeasureBar({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    this.caption,
    this.trailingNote,
    this.leading,
    this.isOver = false,
  });

  final String label;

  /// The measured amount, already formatted for display.
  final String value;

  /// Optional line under the bar — share, counts, days left.
  final String? caption;

  /// Optional short note beside [value], such as a percentage.
  final String? trailingNote;

  /// How full the bar is, 0–1. Values above 1 are clamped by the bar itself.
  final double fraction;

  final Color color;
  final Widget? leading;

  /// Draws the bar in the theme's warning colour — over budget, over plan.
  final bool isOver;
}

/// A ranked list of [MeasureBar] rows.
///
/// The shared shape behind every "which of these is biggest" report — spending
/// by category, by account, budget usage, plan usage. Each row is a label, an
/// amount and a bar, so the four reports stay visually consistent instead of
/// each inventing its own layout.
class MeasureBarList extends StatelessWidget {
  const MeasureBarList({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.base),
  });

  final List<MeasureBar> items;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: padding.add(const EdgeInsets.only(bottom: AppSpacing.sm)),
            child: _MeasureRow(item: item),
          ),
      ],
    );
  }
}

class _MeasureRow extends StatelessWidget {
  const _MeasureRow({required this.item});

  final MeasureBar item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = item.isOver ? theme.colorScheme.error : item.color;

    return AppCard(
      padding: AppSpacing.cardCompact,
      child: Row(
        children: [
          if (item.leading != null) ...[item.leading!, AppSpacing.hGapMd],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(item.value, style: theme.textTheme.titleSmall),
                    if (item.trailingNote != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.trailingNote!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: barColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                AppSpacing.gapSm,
                AppProgressBar(
                  value: item.fraction,
                  color: barColor,
                  height: 5,
                  // These bars measure a share, not a budget, so the built-in
                  // "approaching the limit" tint would be meaningless noise.
                  warningThreshold: 2,
                ),
                if (item.caption != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
