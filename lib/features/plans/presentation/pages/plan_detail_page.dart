import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/enums/spending_warning.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/spending_plan_progress.dart';
import '../../../../routes/app_routes.dart';
import '../../../dashboard/presentation/widgets/plan_progress_card.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/plan_detail_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class PlanDetailPage extends GetView<PlanDetailController> {
  const PlanDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.progress.value?.plan.name ?? 'Plan')),
        actions: [
          Obx(() {
            final plan = controller.progress.value?.plan;
            if (plan == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Edit plan',
              onPressed: () async {
                final saved = await Get.toNamed(
                  AppRoutes.spendingPlanForm,
                  arguments: plan,
                );
                if (saved != null) await controller.load(showLoader: false);
              },
              icon: const Icon(Icons.edit_outlined),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAllocation(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Allocate'),
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
            _ => _DetailBody(controller: controller),
          };
        }),
      ),
    );
  }

  Future<void> _addAllocation(BuildContext context) async {
    final available = controller.unallocatedCategories;
    if (available.isEmpty) {
      await ConfirmDialog.show(
        title: 'Every category is allocated',
        message:
            'Edit an existing allocation instead, or add a new expense '
            'category first.',
        confirmLabel: 'OK',
        cancelLabel: 'Close',
        destructive: false,
      );
      return;
    }

    final category = await PickerSheets.category(available);
    if (category == null) return;

    final amount = await _AllocationDialog.show(category: category);
    if (amount == null) return;

    await controller.addAllocation(category: category, amount: amount);
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.controller});

  final PlanDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final progress = controller.progress.value;
      if (progress == null) return const AppLoader();

      return ListView(
        padding: const EdgeInsets.only(bottom: 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: PlanProgressCard(progress: progress),
          ),
          // Escalating notice as the plan itself crosses each threshold.
          if (progress.warning.shouldWarn)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.md,
                AppSpacing.base,
                0,
              ),
              child: _Banner(
                icon: progress.isExceeded
                    ? Icons.error_outline_rounded
                    : Icons.warning_amber_rounded,
                color: _colorFor(context, progress.warning),
                message: progress.isExceeded
                    ? 'You have spent '
                          '${Money.format(progress.totalSpent - progress.expectedIncome)} '
                          'more than this plan allows.'
                    : '${progress.usagePercent.toStringAsFixed(0)}% of this '
                          'plan is spent, with '
                          '${Money.format(progress.remaining)} left.',
              ),
            ),
          if (progress.isOverAllocated)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Banner(
                icon: Icons.warning_amber_rounded,
                color: context.warningColor,
                message:
                    'You have planned more than you expect to earn, by '
                    '${Money.format(progress.totalPlanned - progress.expectedIncome)}.',
              ),
            ),
          if (progress.unallocated > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Banner(
                icon: Icons.info_outline_rounded,
                color: theme.colorScheme.primary,
                message:
                    '${Money.format(progress.unallocated)} of your income is not '
                    'assigned to a category yet.',
              ),
            ),
          const SectionHeader(title: 'Category allocations'),
          if (progress.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                child: Text(
                  'Nothing allocated yet. Split your income across categories '
                  'to see planned versus actual spending.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final item in progress.items)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _AllocationCard(progress: item, controller: controller),
              ),
        ],
      );
    });
  }
}

/// One category: planned, spent, remaining and percentage used.
///
/// All four are shown together because each answers a different question —
/// what I meant to spend, what I have spent, what is left, and how close I am.
class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.progress, required this.controller});

  final SpendingPlanItemProgress progress;
  final PlanDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = progress.item;
    final warning = progress.warning;
    final statusColor = _colorFor(context, warning);

    return AppCard(
      padding: AppSpacing.cardCompact,
      onTap: _edit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(
                icon: item.categoryIcon,
                color: item.categoryColor,
                seed: item.categoryId ?? 0,
                size: 34,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (warning.shouldWarn) _WarningChip(warning: warning),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) =>
                    action == 'edit' ? _edit() : _confirmRemove(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit amount')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
            ],
          ),
          AppSpacing.gapSm,
          AppProgressBar(
            value: progress.usageFraction,
            exceeded: progress.isExceeded,
            warningThreshold: SpendingWarning.approachingAt / 100,
            height: 6,
          ),
          AppSpacing.gapMd,
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Planned',
                  value: Money.format(progress.planned),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Spent',
                  value: Money.format(progress.spent),
                  color: statusColor,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: progress.isExceeded ? 'Over by' : 'Remaining',
                  value: Money.format(
                    progress.isExceeded
                        ? progress.overspend
                        : progress.remaining,
                  ),
                  color: progress.isExceeded ? context.expenseColor : null,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Used',
                  value: '${progress.usagePercent.toStringAsFixed(0)}%',
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final amount = await _AllocationDialog.show(
      initialAmount: progress.planned,
      title: 'Edit ${progress.item.displayName}',
    );
    if (amount != null) {
      await controller.updateAllocation(progress.item, amount);
    }
  }

  Future<void> _confirmRemove() async {
    final confirmed = await ConfirmDialog.show(
      title: 'Remove allocation?',
      message:
          '${progress.item.displayName} will no longer be tracked in this '
          'plan. Your transactions are not affected.',
      confirmLabel: 'Remove',
    );
    if (confirmed) await controller.removeAllocation(progress.item);
  }
}

/// One of the four figures under a category.
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

/// Names the threshold a category has crossed.
class _WarningChip extends StatelessWidget {
  const _WarningChip({required this.warning});

  final SpendingWarning warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFor(context, warning);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: AppRadius.xsAll,
      ),
      child: Text(
        warning.shortLabel,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// Escalating colour as the thresholds are crossed.
Color _colorFor(BuildContext context, SpendingWarning warning) =>
    switch (warning) {
      SpendingWarning.none => Theme.of(context).colorScheme.primary,
      SpendingWarning.approaching => context.warningColor,
      SpendingWarning.critical => context.warningColor,
      SpendingWarning.atLimit => context.expenseColor,
      SpendingWarning.exceeded => context.expenseColor,
    };

/// Small amount-entry dialog shared by add and edit.
class _AllocationDialog extends StatefulWidget {
  const _AllocationDialog({this.initialAmount, this.title});

  final double? initialAmount;
  final String? title;

  static Future<double?> show({
    Category? category,
    double? initialAmount,
    String? title,
  }) {
    final context = Get.context;
    if (context == null) return Future.value();

    return showDialog<double>(
      context: context,
      builder: (_) => _AllocationDialog(
        initialAmount: initialAmount,
        title: title ?? 'Allocate to ${category?.name ?? 'category'}',
      ),
    );
  }

  @override
  State<_AllocationDialog> createState() => _AllocationDialogState();
}

class _AllocationDialogState extends State<_AllocationDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialAmount?.toStringAsFixed(2) ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = Validators.nonNegativeAmount(
      _controller.text,
      field: 'Planned amount',
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(Validators.parseAmount(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? 'Planned amount'),
      content: AmountField(
        controller: _controller,
        label: 'Planned amount',
        autofocus: true,
        errorText: _error,
        textStyle: Theme.of(context).textTheme.titleLarge,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          AppSpacing.hGapSm,
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
