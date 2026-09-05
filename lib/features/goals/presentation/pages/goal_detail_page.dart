import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/financial_goal.dart';
import '../../../../routes/app_routes.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/goal_detail_controller.dart';

class GoalDetailPage extends GetView<GoalDetailController> {
  const GoalDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.goal.value?.name ?? 'Goal')),
        actions: [
          Obx(() {
            final goal = controller.goal.value;
            if (goal == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Edit goal',
              onPressed: () async {
                final saved =
                    await Get.toNamed(AppRoutes.goalForm, arguments: goal);
                if (saved == true) await controller.load(showLoader: false);
              },
              icon: const Icon(Icons.edit_outlined),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _contribute(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Contribute'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refreshData,
        child: Obx(() {
          final state = controller.state;

          return switch (state) {
            IdleState() || LoadingState() => const AppLoader(),
            ErrorState(:final message) =>
              AppErrorView(message: message, onRetry: controller.load),
            _ => _DetailBody(controller: controller),
          };
        }),
      ),
    );
  }

  Future<void> _contribute(BuildContext context) async {
    final result = await _ContributionSheet.show(accounts: controller.accounts);
    if (result == null) return;

    await controller.contribute(
      amount: result.amount,
      account: result.account,
      note: result.note,
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.controller});

  final GoalDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final goal = controller.goal.value;
      if (goal == null) return const AppLoader();

      final color = CategoryIcons.resolveColor(goal.color, seed: goal.id);

      return ListView(
        padding: const EdgeInsets.only(bottom: 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CategoryIcons.resolve(goal.icon),
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    Money.format(goal.currentAmount),
                    style: theme.textTheme.displaySmall?.copyWith(color: color),
                  ),
                  Text(
                    'of ${Money.format(goal.targetAmount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppProgressBar(
                    value: goal.progressPercent / 100,
                    color: color,
                    warningThreshold: 2,
                    height: 10,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Remaining',
                          value: Money.format(goal.remainingAmount),
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: 'Progress',
                          value: '${goal.progressPercent.toStringAsFixed(0)}%',
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: 'Target date',
                          value: goal.targetDate == null
                              ? '—'
                              : AppDate.formatDate(goal.targetDate!),
                        ),
                      ),
                    ],
                  ),
                  if (goal.requiredMonthlyContribution != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Set aside '
                        '${Money.format(goal.requiredMonthlyContribution!)} '
                        'each month to reach this goal on time.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                  if (goal.isOverdue) ...[
                    const SizedBox(height: 16),
                    Text(
                      'This goal is past its target date.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.warningColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (goal.note != null && goal.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppCard(
                child: Text(goal.note!, style: theme.textTheme.bodyMedium),
              ),
            ),
          SectionHeader(
            title: 'Contribution history',
            subtitle: '${controller.contributions.length} entries',
          ),
          Obx(() {
            if (controller.contributions.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppCard(
                  child: Text(
                    'No contributions yet. Add one to start tracking progress.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final contribution in controller.contributions)
                  _ContributionTile(
                    contribution: contribution,
                    controller: controller,
                  ),
              ],
            );
          }),
        ],
      );
    });
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({
    required this.contribution,
    required this.controller,
  });

  final GoalContribution contribution;
  final GoalDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWithdrawal = contribution.isWithdrawal;
    final color = isWithdrawal ? context.expenseColor : context.incomeColor;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.13),
        child: Icon(
          isWithdrawal
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        AppDate.formatDate(contribution.contributedAt),
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        contribution.note?.isNotEmpty == true
            ? contribution.note!
            : contribution.accountName ?? 'Manual entry',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isWithdrawal ? '−' : '+'}${Money.format(contribution.amount.abs())}',
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          IconButton(
            tooltip: 'Remove entry',
            onPressed: _confirmRemove,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove() async {
    final confirmed = await ConfirmDialog.show(
      title: 'Remove this entry?',
      message: 'The goal total will be recalculated without it.',
      confirmLabel: 'Remove',
    );
    if (confirmed) await controller.removeContribution(contribution);
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
          child: Text(value, style: theme.textTheme.titleSmall),
        ),
      ],
    );
  }
}

/// Contribution entry sheet. Supports withdrawals so a goal can be corrected
/// without deleting history.
class _ContributionSheet extends StatefulWidget {
  const _ContributionSheet({required this.accounts});

  final List<Account> accounts;

  static Future<({double amount, Account? account, String? note})?> show({
    required List<Account> accounts,
  }) {
    final context = Get.context;
    if (context == null) return Future.value();

    return showModalBottomSheet<({double amount, Account? account, String? note})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContributionSheet(accounts: accounts),
    );
  }

  @override
  State<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<_ContributionSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  Account? _account;
  bool _isWithdrawal = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final error = Validators.amount(_amount.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final value = Validators.parseAmount(_amount.text)!;
    Navigator.of(context).pop((
      amount: _isWithdrawal ? -value : value,
      account: _account,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isWithdrawal ? 'Withdraw from goal' : 'Add contribution',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AmountField(
                controller: _amount,
                label: 'Amount',
                autofocus: true,
                errorText: _error,
              ),
              const SizedBox(height: 12),
              AppPickerField(
                label: 'From account',
                value: _account?.name,
                placeholder: 'Optional',
                onTap: () async {
                  final picked = await PickerSheets.account(
                    widget.accounts,
                    selected: _account,
                  );
                  if (picked != null) setState(() => _account = picked);
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _note,
                label: 'Note',
                hint: 'Optional',
                maxLength: 120,
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isWithdrawal,
                onChanged: (value) => setState(() => _isWithdrawal = value),
                title: const Text('This is a withdrawal'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _submit,
                child: Text(_isWithdrawal ? 'Withdraw' : 'Add contribution'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
