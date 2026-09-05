import 'package:flutter/material.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// One action.
class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// The four things people open this app to do.
///
/// The floating button only covers expenses; income, transfers and goals were
/// otherwise several taps away through the More tab.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.onAddExpense,
    required this.onAddIncome,
    required this.onTransfer,
    required this.onAddGoal,
  });

  final VoidCallback onAddExpense;
  final VoidCallback onAddIncome;
  final VoidCallback onTransfer;
  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final actions = [
      QuickAction(
        label: 'Expense',
        icon: Icons.north_east_rounded,
        color: context.expenseColor,
        onTap: onAddExpense,
      ),
      QuickAction(
        label: 'Income',
        icon: Icons.south_west_rounded,
        color: context.incomeColor,
        onTap: onAddIncome,
      ),
      QuickAction(
        label: 'Transfer',
        icon: Icons.swap_horiz_rounded,
        color: context.transferColor,
        onTap: onTransfer,
      ),
      QuickAction(
        label: 'Goal',
        icon: Icons.flag_rounded,
        color: theme.colorScheme.primary,
        onTap: onAddGoal,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) AppSpacing.hGapMd,
          Expanded(child: _ActionButton(action: actions[i])),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Add ${action.label.toLowerCase()}',
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: theme.dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, size: 18, color: action.color),
                ),
                AppSpacing.gapSm,
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The transaction types the quick actions open the entry sheet with.
const Map<String, TransactionType> kQuickActionTypes = {
  'expense': TransactionType.expense,
  'income': TransactionType.income,
  'transfer': TransactionType.transfer,
};
