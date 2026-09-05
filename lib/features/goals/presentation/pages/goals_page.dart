import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../domain/entities/financial_goal.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/goals_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class GoalsPage extends GetView<GoalsController> {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financial goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Goal'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refreshData,
        child: Obx(() {
          final state = controller.state;

          return switch (state) {
            IdleState() || LoadingState() => const AppLoader(),
            ErrorState(:final message) => AppErrorView(
              message: message,
              onRetry: controller.load,
            ),
            EmptyState() => AppEmptyView(
              title: 'No goals yet',
              message:
                  'Set a target — an emergency fund, a laptop, a trip — '
                  'and track every contribution towards it.',
              icon: Icons.flag_outlined,
              action: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a goal'),
              ),
            ),
            LoadedState() => _GoalList(controller: controller),
          };
        }),
      ),
    );
  }

  Future<void> _openForm([Object? argument]) async {
    final saved = await Get.toNamed(AppRoutes.goalForm, arguments: argument);
    if (saved == true) await controller.load(showLoader: false);
  }
}

class _GoalList extends StatelessWidget {
  const _GoalList({required this.controller});

  final GoalsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Obx(
          () => AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved towards goals',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.gapXs,
                      Text(
                        Money.format(controller.totalSaved),
                        style: theme.textTheme.headlineMedium,
                      ),
                      Text(
                        'of ${Money.format(controller.totalTarget)} targeted',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.flag_rounded,
                  size: 30,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapBase,
        Obx(
          () => Column(
            children: [
              for (var i = 0; i < controller.goals.length; i++) ...[
                _GoalCard(
                  goal: controller.goals[i],
                  seed: i,
                  controller: controller,
                ),
                AppSpacing.gapMd,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.seed,
    required this.controller,
  });

  final FinancialGoal goal;
  final int seed;
  final GoalsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryIcons.resolveColor(goal.color, seed: seed);

    return AppCard(
      onTap: () async {
        await Get.toNamed(AppRoutes.goalDetail, arguments: goal.id);
        await controller.load(showLoader: false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CategoryIcons.resolve(goal.icon),
                  color: color,
                  size: 20,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (goal.isAchieved)
                Icon(Icons.verified_rounded, size: 20, color: color)
              else
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (_) => _confirmDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.format(goal.currentAmount),
                style: theme.textTheme.titleLarge?.copyWith(color: color),
              ),
              AppSpacing.hGapSm,
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'of ${Money.format(goal.targetAmount)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${goal.progressPercent.toStringAsFixed(0)}%',
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
          AppSpacing.gapSm,
          AppProgressBar(
            value: goal.progressPercent / 100,
            color: color,
            warningThreshold: 2,
          ),
          if (!goal.isAchieved && goal.requiredMonthlyContribution != null) ...[
            AppSpacing.gapSm,
            Text(
              'Save ${Money.format(goal.requiredMonthlyContribution!)} a month '
              'to finish on time',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _subtitle {
    if (goal.isAchieved) return 'Achieved';
    final target = goal.targetDate;
    if (target == null) return 'No target date';
    if (goal.isOverdue) return 'Overdue since ${AppDate.formatDate(target)}';
    return '${goal.daysRemaining} days left · ${AppDate.formatDate(target)}';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await ConfirmDialog.show(
      title: 'Delete ${goal.name}?',
      message:
          'The goal and its contribution history will be removed. '
          'Your account balances are not affected.',
    );
    if (confirmed) await controller.delete(goal);
  }
}
