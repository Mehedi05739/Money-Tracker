import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Hero card: total balance across accounts, with income and expense for the
/// selected period beneath it.
class BalanceHeader extends StatelessWidget {
  const BalanceHeader({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xxlAll,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total balance',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          AppSpacing.gapSm,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(summary.totalBalance),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          AppSpacing.gapLg,
          Row(
            children: [
              Expanded(
                child: _Flow(
                  label: 'Income',
                  amount: summary.totals.income,
                  icon: Icons.south_west_rounded,
                  changePercent: summary.incomeChangePercent,
                  higherIsBetter: true,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              Expanded(
                child: _Flow(
                  label: 'Expense',
                  amount: summary.totals.expense,
                  icon: Icons.north_east_rounded,
                  changePercent: summary.expenseChangePercent,
                  higherIsBetter: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.changePercent,
    required this.higherIsBetter,
  });

  final String label;
  final double amount;
  final IconData icon;
  final double? changePercent;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            AppSpacing.hGapSm,
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        AppSpacing.gapXs,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Money.format(amount),
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
        ),
        if (changePercent != null) ...[
          const SizedBox(height: 3),
          _ChangeBadge(percent: changePercent!, higherIsBetter: higherIsBetter),
        ],
      ],
    );
  }
}

/// Period-over-period delta. Green means "good for the user", which is a rise
/// for income and a fall for spending.
class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.percent, required this.higherIsBetter});

  final double percent;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = percent >= 0;
    final isGood = higherIsBetter ? isUp : !isUp;

    return Row(
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 11,
          color: isGood ? AppColors.incomeDark : AppColors.expenseDark,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            '${percent.abs().toStringAsFixed(0)}% vs last period',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
