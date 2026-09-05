import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../domain/entities/budget_status.dart';
import '../../../../core/theme/app_spacing.dart';

/// Surfaces budgets that are over or near their limit, worst first.
class BudgetAlertCard extends StatelessWidget {
  const BudgetAlertCard({
    super.key,
    required this.alerts,
    this.onTap,
    this.maxVisible = 3,
  });

  final List<BudgetStatus> alerts;
  final VoidCallback? onTap;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = alerts.take(maxVisible).toList();
    final overflow = alerts.length - visible.length;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: context.warningColor,
              ),
              AppSpacing.hGapSm,
              Text('Budget alerts', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (overflow > 0)
                Text(
                  '+$overflow more',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          AppSpacing.gapMd,
          for (var i = 0; i < visible.length; i++) ...[
            _AlertRow(status: visible[i]),
            if (i < visible.length - 1) AppSpacing.gapMd,
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status.isExceeded
        ? context.expenseColor
        : context.warningColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.budget.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '${Money.compact(status.spent)} / ${Money.compact(status.limit)}',
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        AppSpacing.gapSm,
        AppProgressBar(
          value: status.usageFraction,
          exceeded: status.isExceeded,
          height: 6,
        ),
        const SizedBox(height: 5),
        Text(
          status.isExceeded
              ? '${Money.format(status.spent - status.limit)} over budget'
              : '${Money.format(status.remaining)} left · '
                    '${Money.format(status.safeDailyAllowance)}/day',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
