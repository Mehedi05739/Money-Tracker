import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../domain/entities/financial_goal.dart';
import '../../../../core/theme/app_spacing.dart';

/// Horizontally scrolling goal cards.
class GoalProgressStrip extends StatelessWidget {
  const GoalProgressStrip({
    super.key,
    required this.goals,
    required this.onTapGoal,
  });

  final List<FinancialGoal> goals;
  final void Function(FinancialGoal goal) onTapGoal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: goals.length,
        separatorBuilder: (_, _) => AppSpacing.hGapMd,
        itemBuilder: (context, index) => SizedBox(
          width: 220,
          child: _GoalCard(
            goal: goals[index],
            seed: index,
            onTap: () => onTapGoal(goals[index]),
          ),
        ),
      ),
    );
  }
}

/// `by 12 Mar 2027`, or how overdue the goal is.
String _targetLabel(FinancialGoal goal) {
  final target = goal.targetDate!;
  if (goal.isAchieved) return AppDate.formatDate(target);
  if (goal.isOverdue) return 'Overdue · ${AppDate.formatDate(target)}';

  final days = goal.daysRemaining ?? 0;
  if (days <= 31) return '$days days left';
  return 'by ${AppDate.formatDate(target)}';
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.seed,
    required this.onTap,
  });

  final FinancialGoal goal;
  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryIcons.resolveColor(goal.color, seed: seed);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CategoryIcons.resolve(goal.icon), size: 17, color: color),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            Money.compact(goal.currentAmount),
            style: theme.textTheme.titleLarge,
          ),
          Text(
            'of ${Money.compact(goal.targetAmount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapSm,
          AppProgressBar(
            value: goal.progressPercent / 100,
            color: color,
            height: 6,
          ),
          AppSpacing.gapSm,
          Text(
            goal.isAchieved
                ? 'Goal reached'
                : '${goal.progressPercent.toStringAsFixed(0)}% · '
                      '${Money.compact(goal.remainingAmount)} to go',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // The deadline is what makes a goal actionable rather than a wish.
          if (goal.targetDate != null) ...[
            AppSpacing.gapXxs,
            Row(
              children: [
                Icon(
                  goal.isOverdue
                      ? Icons.event_busy_rounded
                      : Icons.event_rounded,
                  size: 11,
                  color: goal.isOverdue
                      ? context.expenseColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _targetLabel(goal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      color: goal.isOverdue
                          ? context.expenseColor
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
