import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../domain/entities/budget_status.dart';

/// Budget status at a glance: one bar for the whole month, then only the
/// budgets that need attention.
///
/// Showing every budget here would repeat the Budgets screen; showing none
/// until something breaks hides the fact that budgets exist at all.
class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    super.key,
    required this.overview,
    this.onTap,
    this.maxAlerts = 2,
  });

  /// Precomputed by the controller — this widget only draws it.
  final BudgetOverview overview;
  final VoidCallback? onTap;
  final int maxAlerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = overview.isExceeded
        ? context.expenseColor
        : overview.isAtRisk
        ? context.warningColor
        : theme.colorScheme.primary;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Budgets', style: theme.textTheme.titleMedium),
              const Spacer(),
              _StatusPill(label: overview.headline, color: statusColor),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Money.format(overview.spent),
                style: theme.textTheme.titleLarge?.copyWith(color: statusColor),
              ),
              AppSpacing.hGapXs,
              Text(
                'of ${Money.format(overview.limit)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          AppProgressBar(
            value: overview.usageFraction,
            exceeded: overview.isExceeded,
            height: 6,
          ),
          if (overview.alerts.isNotEmpty) ...[
            AppSpacing.gapMd,
            for (final status in overview.alerts.take(maxAlerts)) ...[
              _AlertRow(status: status),
              AppSpacing.gapSm,
            ],
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

    return Row(
      children: [
        Icon(
          status.isExceeded
              ? Icons.error_outline_rounded
              : Icons.warning_amber_rounded,
          size: 15,
          color: color,
        ),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(
            status.budget.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          status.isExceeded
              ? '${Money.compact(status.spent - status.limit)} over'
              : '${Money.compact(status.remaining)} left',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: AppRadius.xsAll,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
