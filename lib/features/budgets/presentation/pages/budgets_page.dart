import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
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

/// One budget: amount, spend, remaining, days left and what can safely be
/// spent per day.
///
/// All five are shown together because a budget is only actionable when the
/// user can see the number *and* the time left to spend it in.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.status, required this.controller});

  final BudgetStatus status;
  final BudgetsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = status.budget;
    final paused = status.isPaused;

    final statusColor = paused
        ? theme.colorScheme.onSurfaceVariant
        : status.isExceeded
        ? context.expenseColor
        : status.isAtRisk || status.isOverPace
        ? context.warningColor
        : theme.colorScheme.primary;

    return Opacity(
      // A paused budget is still readable, just visibly out of play.
      opacity: paused ? 0.6 : 1,
      child: AppCard(
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
                        '${Money.format(status.limit)} · ${budget.period.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: status.headline, color: statusColor),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (action) => switch (action) {
                    'pause' => controller.setActive(status, false),
                    'resume' => controller.setActive(status, true),
                    _ => _confirmDelete(),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: paused ? 'resume' : 'pause',
                      child: Text(paused ? 'Resume' : 'Pause'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            AppSpacing.gapMd,
            AppProgressBar(
              value: status.usageFraction,
              exceeded: status.isExceeded,
              warningThreshold: budget.alertPercentage / 100,
              color: paused ? theme.colorScheme.outlineVariant : null,
            ),
            AppSpacing.gapMd,
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: 'Spent',
                    value: Money.format(status.spent),
                    color: statusColor,
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: status.isExceeded ? 'Over by' : 'Remaining',
                    value: Money.format(
                      status.isExceeded ? status.overspend : status.remaining,
                    ),
                    color: status.isExceeded ? context.expenseColor : null,
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Days left',
                    value: '${status.daysRemaining}',
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Per day',
                    value: status.recommendedDailySpend > 0
                        ? Money.compact(status.recommendedDailySpend)
                        : '—',
                  ),
                ),
              ],
            ),
            if (status.isExceeded && !paused) ...[
              AppSpacing.gapMd,
              _OverspendBanner(status: status),
            ],
          ],
        ),
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

/// One figure in the row beneath the progress bar.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapXxs,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// States the overspend plainly, rather than leaving it to be inferred from a
/// full progress bar.
class _OverspendBanner extends StatelessWidget {
  const _OverspendBanner({required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: AppSpacing.cardCompact,
      decoration: BoxDecoration(
        color: context.expenseColor.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 17,
            color: context.expenseColor,
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              'Over budget by ${Money.format(status.overspend)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.expenseColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
        vertical: 3,
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
