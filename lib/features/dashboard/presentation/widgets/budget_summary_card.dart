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
    required this.statuses,
    this.onTap,
    this.maxAlerts = 2,
  });

  final List<BudgetStatus> statuses;
  final VoidCallback? onTap;
  final int maxAlerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final limit = statuses.fold<double>(0, (sum, s) => sum + s.limit);
    final spent = statuses.fold<double>(0, (sum, s) => sum + s.spent);
    final alerts =
        statuses
            .where((status) => status.isExceeded || status.isAtRisk)
            .toList()
          ..sort((a, b) => b.usagePercent.compareTo(a.usagePercent));

    final exceeded = statuses.where((s) => s.isExceeded).length;
    final overall = limit <= 0 ? 0.0 : spent / limit;
    final statusColor = spent > limit
        ? context.expenseColor
        : overall >= 0.8
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
              _StatusPill(
                label: exceeded > 0
                    ? '$exceeded over limit'
                    : alerts.isNotEmpty
                    ? '${alerts.length} near limit'
                    : 'On track',
                color: statusColor,
              ),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Money.format(spent),
                style: theme.textTheme.titleLarge?.copyWith(color: statusColor),
              ),
              AppSpacing.hGapXs,
              Text(
                'of ${Money.format(limit)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          AppProgressBar(value: overall, exceeded: spent > limit, height: 6),
          if (alerts.isNotEmpty) ...[
            AppSpacing.gapMd,
            for (final status in alerts.take(maxAlerts)) ...[
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
