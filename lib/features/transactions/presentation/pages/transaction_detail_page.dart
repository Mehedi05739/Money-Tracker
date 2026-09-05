import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../domain/entities/money_transaction.dart';
import '../../../../routes/app_routes.dart';

/// Read-only view of one transaction.
///
/// The edit form shows the fields you can change; this shows everything the
/// record holds, including what was derived rather than entered — when it was
/// created, when it was last edited, and whether a schedule posted it.
class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({super.key, this.transaction});

  final MoneyTransaction? transaction;

  /// Opens the detail view. Returns true when the row was edited or deleted,
  /// so the caller can refresh.
  static Future<bool> open(MoneyTransaction transaction) async {
    final changed = await Get.toNamed(
      AppRoutes.transactionDetail,
      arguments: transaction,
    );
    return changed == true;
  }

  @override
  Widget build(BuildContext context) {
    final record = transaction ?? Get.arguments as MoneyTransaction;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () async {
              final saved = await Get.toNamed(
                AppRoutes.transactionForm,
                arguments: record,
              );
              if (saved == true) Get.back(result: true);
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.xxl,
          ),
          children: [
            _AmountHeader(transaction: record),
            AppSpacing.gapBase,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: 'Category',
                    value: record.displayCategory,
                    leading: record.isTransfer
                        ? null
                        : CategoryAvatar(
                            icon: record.categoryIcon,
                            color: record.categoryColor,
                            seed: record.categoryId ?? 0,
                            size: 32,
                          ),
                  ),
                  const Divider(height: 1, indent: AppSpacing.base),
                  _DetailRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: record.isTransfer ? 'From' : 'Account',
                    value: record.accountName ?? '—',
                  ),
                  if (record.isTransfer) ...[
                    const Divider(height: 1, indent: AppSpacing.base),
                    _DetailRow(
                      icon: Icons.arrow_forward_rounded,
                      label: 'To',
                      value: record.toAccountName ?? '—',
                    ),
                  ],
                  const Divider(height: 1, indent: AppSpacing.base),
                  _DetailRow(
                    icon: Icons.event_rounded,
                    label: 'Date',
                    value: AppDate.formatDateTime(record.transactionDate),
                  ),
                  if (record.paymentMethod != null) ...[
                    const Divider(height: 1, indent: AppSpacing.base),
                    _DetailRow(
                      icon: Icons.payments_outlined,
                      label: 'Payment method',
                      value: record.paymentMethod!.label,
                    ),
                  ],
                ],
              ),
            ),
            if (record.note?.isNotEmpty ?? false) ...[
              AppSpacing.gapBase,
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.gapXs,
                    Text(record.note!, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
            AppSpacing.gapBase,
            _RecordFooter(transaction: record),
            AppSpacing.gapXl,
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, record),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete transaction'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MoneyTransaction record,
  ) async {
    final confirmed = await ConfirmDialog.show(
      title: 'Delete transaction?',
      message:
          'This removes "${record.title}" and adjusts your account balance. '
          'This cannot be undone.',
    );
    // The list owns deletion so the balance, budgets and plans all refresh
    // through the same path; this screen only asks and reports back.
    if (confirmed) Get.back(result: _DetailResult.deleted);
  }
}

/// What the detail screen returns to its caller.
enum _DetailResult { deleted }

/// Signals that the user asked to delete from the detail screen.
bool wasDeleteRequested(Object? result) => result == _DetailResult.deleted;

class _AmountHeader extends StatelessWidget {
  const _AmountHeader({required this.transaction});

  final MoneyTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (transaction.type) {
      TransactionType.income => context.incomeColor,
      TransactionType.expense => context.expenseColor,
      TransactionType.transfer => context.transferColor,
    };
    final prefix = switch (transaction.type) {
      TransactionType.income => '+',
      TransactionType.expense => '−',
      TransactionType.transfer => '',
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: AppRadius.pillAll,
            ),
            child: Text(
              transaction.type.label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
          AppSpacing.gapMd,
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$prefix${Money.format(transaction.amount)}',
              style: theme.textTheme.displaySmall?.copyWith(color: color),
            ),
          ),
          AppSpacing.gapXs,
          Text(
            transaction.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.leading,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          leading ??
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Provenance: when the record was created, last changed, and whether a
/// recurring schedule produced it.
class _RecordFooter extends StatelessWidget {
  const _RecordFooter({required this.transaction});

  final MoneyTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edited = transaction.updatedAt.difference(transaction.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (transaction.isRecurringInstance) ...[
          Row(
            children: [
              Icon(
                Icons.autorenew_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              AppSpacing.hGapSm,
              Text(
                'Added by a recurring schedule',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.gapXs,
        ],
        Text(
          'Recorded ${AppDate.formatDateTime(transaction.createdAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // Only worth showing once it differs from creation.
        if (edited.inMinutes >= 1) ...[
          AppSpacing.gapXxs,
          Text(
            'Edited ${AppDate.formatDateTime(transaction.updatedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
