import 'package:flutter/material.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// All / Income / Expense / Transfer.
///
/// The filter sheet can already narrow by type, but the split people want most
/// should not be two taps and a sheet away.
class TransactionTypeTabs extends StatelessWidget {
  const TransactionTypeTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showAllWhenMultiple = true,
  });

  /// The single active type, or null for "All".
  final TransactionType? selected;
  final ValueChanged<TransactionType?> onSelected;

  /// When the sheet has selected several types no tab is active, so "All"
  /// should not look selected either.
  final bool showAllWhenMultiple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget chip(String label, TransactionType? type, Color color) {
      final isSelected = type == selected && showAllWhenMultiple;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          selected: isSelected,
          onSelected: (_) => onSelected(type),
          showCheckmark: false,
          label: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          selectedColor: color.withValues(alpha: 0.14),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenH,
        children: [
          chip('All', null, theme.colorScheme.primary),
          chip('Income', TransactionType.income, context.incomeColor),
          chip('Expense', TransactionType.expense, context.expenseColor),
          chip('Transfer', TransactionType.transfer, context.transferColor),
        ],
      ),
    );
  }
}
