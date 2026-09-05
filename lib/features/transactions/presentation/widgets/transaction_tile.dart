import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../domain/entities/money_transaction.dart';
import '../../../../core/theme/app_spacing.dart';

/// One ledger row. Used by the dashboard's recent list and the full ledger.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDate = false,
    this.dense = false,
  });

  final MoneyTransaction transaction;
  final VoidCallback? onTap;
  final bool showDate;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 8 : 11),
        child: Row(
          children: [
            CategoryAvatar(
              icon: transaction.categoryIcon,
              color: transaction.categoryColor,
              seed: transaction.categoryId ?? 0,
              size: dense ? 38 : 42,
              overrideIcon: transaction.isTransfer
                  ? Icons.swap_horiz_rounded
                  : null,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          transaction.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (transaction.isRecurringInstance) ...[
                        AppSpacing.hGapSm,
                        Icon(
                          Icons.autorenew_rounded,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
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
            AppSpacing.hGapSm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(
                  amount: transaction.amount,
                  type: transaction.type,
                  style: theme.textTheme.titleSmall,
                ),
                if (showDate) ...[
                  AppSpacing.gapXxs,
                  Text(
                    AppDate.formatTime(transaction.transactionDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    if (transaction.isTransfer) {
      return '${transaction.accountName ?? 'Account'} → '
          '${transaction.toAccountName ?? 'Account'}';
    }
    final account = transaction.accountName;
    return account == null
        ? transaction.displayCategory
        : '${transaction.displayCategory} · $account';
  }
}

/// Sticky-style date header for grouped ledger sections.
class TransactionDateHeader extends StatelessWidget {
  const TransactionDateHeader({
    super.key,
    required this.date,
    required this.net,
  });

  final DateTime date;
  final double net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            AppDate.formatRelativeDay(date),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '${net >= 0 ? '+' : '−'}${Money.format(net.abs())}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: net >= 0 ? context.incomeColor : context.expenseColor,
            ),
          ),
        ],
      ),
    );
  }
}
