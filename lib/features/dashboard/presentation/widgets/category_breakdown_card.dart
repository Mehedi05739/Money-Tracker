import 'package:flutter/material.dart';

import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/charts/donut_chart.dart';
import '../../../../domain/entities/analytics.dart';

/// Spending-by-category donut with a ranked legend.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({super.key, required this.categories});

  final List<CategorySpending> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = categories.fold<double>(0, (sum, c) => sum + c.amount);

    if (categories.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
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
          color: CategoryIcons.resolveColor(categories[i].categoryColor, seed: i),
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
            if (i < categories.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.category, required this.color});

  final CategorySpending category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${category.categoryName}, ${Money.format(category.amount)}, '
          '${category.share.toStringAsFixed(0)} percent',
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.categoryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              '${category.share.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            Money.format(category.amount),
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
