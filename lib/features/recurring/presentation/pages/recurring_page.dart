import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../domain/entities/recurring_transaction.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/recurring_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class RecurringPage extends GetView<RecurringController> {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Post everything due',
              onPressed: controller.isPosting.value
                  ? null
                  : controller.postDueNow,
              icon: controller.isPosting.value
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_outline_rounded),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Schedule'),
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
              title: 'No recurring transactions',
              message:
                  'Schedule rent, salary or subscriptions once and they '
                  'are recorded automatically each period.',
              icon: Icons.autorenew_rounded,
              action: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a schedule'),
              ),
            ),
            LoadedState() => _RecurringList(controller: controller),
          };
        }),
      ),
    );
  }

  Future<void> _openForm([Object? argument]) async {
    final saved = await Get.toNamed(
      AppRoutes.recurringForm,
      arguments: argument,
    );
    if (saved == true) await controller.load(showLoader: false);
  }
}

class _RecurringList extends StatelessWidget {
  const _RecurringList({required this.controller});

  final RecurringController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Obx(
          () => AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly commitments', style: theme.textTheme.titleMedium),
                AppSpacing.gapXs,
                Text(
                  'Each schedule normalised to a per-month figure',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapMd,
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Income',
                        value: Money.format(controller.monthlyInflow),
                        color: context.incomeColor,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Expense',
                        value: Money.format(controller.monthlyOutflow),
                        color: context.expenseColor,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Due now',
                        value: '${controller.dueRules.length}',
                        color: controller.dueRules.isEmpty
                            ? null
                            : context.warningColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapBase,
        Obx(
          () => Column(
            children: [
              for (final rule in controller.rules) ...[
                _RuleCard(rule: rule, controller: controller),
                AppSpacing.gapMd,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.controller});

  final RecurringTransaction rule;
  final RecurringController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () async {
        final saved = await Get.toNamed(
          AppRoutes.recurringForm,
          arguments: rule,
        );
        if (saved == true) await controller.load(showLoader: false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(
                icon: rule.categoryIcon,
                color: rule.categoryColor,
                seed: rule.categoryId ?? 0,
                size: 38,
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      '${rule.frequency.label}'
                      '${rule.intervalCount > 1 ? ' ×${rule.intervalCount}' : ''}'
                      ' · ${rule.accountName ?? 'Account'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AmountText(
                amount: rule.amount,
                type: rule.type,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            children: [
              Icon(
                rule.isDue ? Icons.schedule_rounded : Icons.event_rounded,
                size: 14,
                color: rule.isDue && rule.isActive
                    ? context.warningColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  _scheduleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: rule.isDue && rule.isActive
                        ? context.warningColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Switch.adaptive(
                value: rule.isActive,
                onChanged: (value) => controller.setActive(rule, value),
              ),
              IconButton(
                tooltip: 'Delete schedule',
                onPressed: _confirmDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _scheduleLabel {
    if (!rule.isActive) return 'Paused';
    if (rule.isDue) return 'Due now';
    final days = rule.daysUntilNextRun;
    if (days == 0) return 'Runs today';
    if (days == 1) return 'Runs tomorrow';
    return 'Next on ${AppDate.formatDate(rule.nextRunDate)}';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await ConfirmDialog.show(
      title: 'Delete this schedule?',
      message:
          'Transactions already recorded from it are kept. '
          'Only future occurrences stop.',
    );
    if (confirmed) await controller.delete(rule);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

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
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
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
