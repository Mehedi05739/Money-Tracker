import 'package:flutter/material.dart';

import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/charts/donut_chart.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../core/theme/app_spacing.dart';

/// Spending-by-category donut with a ranked legend.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({super.key, required this.breakdown});

  final CategoryBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = breakdown.entries;
    // The period's real total, not the sum of the slices on screen — the list
    // is capped, and labelling a partial sum "spent" would be wrong.
    final total = breakdown.total;

    if (categories.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                'No spending recorded for this period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final slices = [
      for (var i = 0; i < categories.length; i++)
        DonutSlice(
          label: categories[i].categoryName,
          value: categories[i].amount,
          color: CategoryIcons.resolveColor(
            categories[i].categoryColor,
            seed: i,
          ),
        ),
    ];

    return AppCard(
      child: Column(
        children: [
          Center(
            child: DonutChart(
              slices: slices,
              centerTitle: Money.compact(total),
              centerSubtitle: 'spent',
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < categories.length; i++) ...[
            _LegendRow(
              category: categories[i],
              color: CategoryIcons.resolveColor(
                categories[i].categoryColor,
                seed: i,
              ),
            ),
            if (i < categories.length - 1 || breakdown.hasOther)
              AppSpacing.gapMd,
          ],
          if (breakdown.hasOther)
            _LegendRow.other(
              amount: breakdown.otherAmount,
              share: breakdown.otherShare,
              count: breakdown.categoryCount - categories.length,
              color: theme.colorScheme.outlineVariant,
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.category, required this.color})
    : otherAmount = null,
      otherShare = 0,
      otherCount = 0;

  const _LegendRow.other({
    required double amount,
    required double share,
    required int count,
    required this.color,
  }) : category = null,
       otherAmount = amount,
       otherShare = share,
       otherCount = count;

  final CategorySpending? category;
  final double? otherAmount;
  final double otherShare;
  final int otherCount;
  final Color color;

  String get _name =>
      category?.categoryName ??
      (otherCount > 0 ? 'Other ($otherCount)' : 'Other');
  double get _amount => category?.amount ?? otherAmount ?? 0;
  double get _share => category?.share ?? otherShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label:
          '$_name, ${Money.format(_amount)}, '
          '${_share.toStringAsFixed(0)} percent',
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              _name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          AppSpacing.hGapSm,
          SizedBox(
            width: 42,
            child: Text(
              '${_share.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          AppSpacing.hGapSm,
          Text(Money.format(_amount), style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
