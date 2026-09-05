import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../domain/entities/budget_status.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/budgets_controller.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

class BudgetsPage extends GetView<BudgetsController> {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          Obx(
            () => TextButton(
              onPressed: controller.toggleScope,
              child: Text(controller.currentOnly.value ? 'Active' : 'All'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Budget'),
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
            EmptyState(:final message) => AppEmptyView(
              title: 'No budgets',
              message:
                  '$message. Set a limit for a category and track it '
                  'as you spend.',
              icon: Icons.pie_chart_outline_rounded,
              action: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create budget'),
              ),
            ),
            LoadedState() => _BudgetList(controller: controller),
          };
        }),
      ),
    );
  }

  Future<void> _openForm([Object? argument]) async {
    final saved = await Get.toNamed(AppRoutes.budgetForm, arguments: argument);
    if (saved == true) await controller.load(showLoader: false);
  }
}

class _BudgetList extends StatelessWidget {
  const _BudgetList({required this.controller});

  final BudgetsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Obx(() {
          final budgeted = controller.totalBudgeted;
          final spent = controller.totalSpent;
          final exceeded = controller.exceededCount;

          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('All budgets', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    if (exceeded > 0)
                      Text(
                        '$exceeded over limit',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.expenseColor,
                        ),
                      ),
                  ],
                ),
                AppSpacing.gapMd,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Money.format(spent),
                      style: theme.textTheme.headlineMedium,
                    ),
                    AppSpacing.hGapSm,
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'of ${Money.format(budgeted)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapMd,
                AppProgressBar(
                  value: budgeted <= 0 ? 0 : spent / budgeted,
                  exceeded: spent > budgeted,
                ),
              ],
            ),
          );
        }),
        AppSpacing.gapBase,
        Obx(
          () => Column(
            children: [
              for (final status in controller.statuses) ...[
                _BudgetCard(status: status, controller: controller),
                AppSpacing.gapMd,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.status, required this.controller});

  final BudgetStatus status;
  final BudgetsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = status.budget;
    final statusColor = status.isExceeded
        ? context.expenseColor
        : status.isAtRisk || status.isOverPace
        ? context.warningColor
        : theme.colorScheme.primary;

    return AppCard(
      onTap: () async {
        final saved = await Get.toNamed(
          AppRoutes.budgetForm,
          arguments: budget,
        );
        if (saved == true) await controller.load(showLoader: false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(
                icon: budget.categoryIcon,
                color: budget.categoryColor,
                seed: budget.categoryId ?? 0,
                size: 38,
                overrideIcon: budget.isOverall
                    ? Icons.all_inclusive_rounded
                    : null,
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      '${budget.period.label} · '
                      '${AppDate.formatDate(budget.startDate)} – '
                      '${AppDate.formatDate(budget.endDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
            children: [
              Text(
                Money.format(status.spent),
                style: theme.textTheme.titleLarge?.copyWith(color: statusColor),
              ),
              AppSpacing.hGapSm,
              Text(
                'of ${Money.format(status.limit)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.13),
                  borderRadius: AppRadius.xsAll,
                ),
                child: Text(
                  status.headline,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          AppProgressBar(
            value: status.usageFraction,
            exceeded: status.isExceeded,
            warningThreshold: budget.alertPercentage / 100,
          ),
          AppSpacing.gapSm,
          Text(
            status.isExceeded
                ? '${Money.format(status.spent - status.limit)} over the limit'
                : '${Money.format(status.remaining)} left · '
                      '${Money.format(status.safeDailyAllowance)} a day to stay on track',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await ConfirmDialog.show(
      title: 'Delete budget?',
      message: 'Your transactions stay — only the budget is removed.',
    );
    if (confirmed) await controller.delete(status);
  }
}
