import 'package:flutter/material.dart';

import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../domain/entities/financial_goal.dart';

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
        separatorBuilder: (_, _) => const SizedBox(width: 12),
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.seed, required this.onTap});

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
              const SizedBox(width: 8),
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
          const SizedBox(height: 10),
          AppProgressBar(
            value: goal.progressPercent / 100,
            color: color,
            height: 6,
          ),
          const SizedBox(height: 6),
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
        ],
      ),
    );
  }
}
