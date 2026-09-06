import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

class BarGroup {
  const BarGroup({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;
}

/// Income-versus-expense bars, scrollable when there are more groups than fit.
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.groups,
    this.height = 190,
    this.barWidth = 9,
    this.groupSpacing = 22,
  });

  final List<BarGroup> groups;
  final double height;
  final double barWidth;
  final double groupSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (groups.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data for this period',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final maxValue = groups.fold<double>(
      0,
      (max, group) =>
          [max, group.income, group.expense].reduce((a, b) => a > b ? a : b),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: context.incomeColor, label: 'Income'),
            const SizedBox(width: 16),
            _LegendDot(color: context.expenseColor, label: 'Expense'),
            const Spacer(),
            Text(
              'Peak ${Money.compact(maxValue)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final group in groups)
                  Padding(
                    padding: EdgeInsets.only(
                      right: groupSpacing / 2,
                      left: groupSpacing / 2,
                    ),
                    child: _BarPair(
                      group: group,
                      maxValue: maxValue,
                      barWidth: barWidth,
                      height: height,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BarPair extends StatelessWidget {
  const _BarPair({
    required this.group,
    required this.maxValue,
    required this.barWidth,
    required this.height,
  });

  final BarGroup group;
  final double maxValue;
  final double barWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Reserve room for the axis label beneath the bars.
    final plotHeight = height - 26;

    return Semantics(
      label:
          '${group.label}: income ${Money.format(group.income)}, '
          'expense ${Money.format(group.expense)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Bar(
                value: group.income,
                maxValue: maxValue,
                plotHeight: plotHeight,
                width: barWidth,
                color: context.incomeColor,
              ),
              const SizedBox(width: 4),
              _Bar(
                value: group.expense,
                maxValue: maxValue,
                plotHeight: plotHeight,
                width: barWidth,
                color: context.expenseColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            group.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.maxValue,
    required this.plotHeight,
    required this.width,
    required this.color,
  });

  final double value;
  final double maxValue;
  final double plotHeight;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // A non-zero value always shows at least a sliver, so small amounts read
    // as present rather than missing.
    final fraction = maxValue <= 0 ? 0.0 : value / maxValue;
    final target = value <= 0
        ? 2.0
        : (fraction * plotHeight).clamp(3.0, plotHeight);

    // Drawn at its final height rather than grown into place: the chart is
    // read, not watched, and a bar that animates on every filter change makes
    // comparing two periods slower, not nicer.
    return Container(
      width: width,
      height: target,
      decoration: BoxDecoration(
        color: value <= 0 ? color.withValues(alpha: 0.25) : color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
