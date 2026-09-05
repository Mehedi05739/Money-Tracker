import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../domain/entities/spending_plan_progress.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Current spending plan at a glance.
class PlanProgressCard extends StatelessWidget {
  const PlanProgressCard({super.key, required this.progress, this.onTap});

  final SpendingPlanProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = progress.isExceeded
        ? context.expenseColor
        : progress.isAtRisk
        ? context.warningColor
        : theme.colorScheme.primary;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.13),
                  borderRadius: AppRadius.xsAll,
                ),
                child: Text(
                  progress.headline,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.format(progress.totalSpent),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: statusColor,
                ),
              ),
              AppSpacing.hGapSm,
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'of ${Money.format(progress.expectedIncome)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          AppProgressBar(
            value: progress.usageFraction,
            exceeded: progress.isExceeded,
          ),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: progress.isExceeded ? 'Over by' : 'Remaining',
                  value: Money.format(progress.remaining.abs()),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Safe daily',
                  value: Money.format(progress.safeDailyAllowance),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Days left',
                  value:
                      '${(progress.plan.range.dayCount - progress.plan.range.elapsedDays + 1).clamp(0, 9999)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapXxs,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.titleSmall),
        ),
      ],
    );
  }
}
