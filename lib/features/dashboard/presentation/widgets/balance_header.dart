import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/analytics.dart';

/// The headline card: balance, the scope it covers, and the period's flows.
class BalanceHeader extends StatelessWidget {
  const BalanceHeader({
    super.key,
    required this.summary,
    required this.scopeLabel,
    required this.isHidden,
    required this.onToggleHidden,
    required this.onPickScope,
    this.maskedText = '••••••',
  });

  final DashboardSummary summary;

  /// "All accounts", or the selected account's name.
  final String scopeLabel;
  final bool isHidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onPickScope;
  final String maskedText;

  String _amount(double value) => isHidden ? maskedText : Money.format(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
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
          Row(
            children: [
              Flexible(
                child: _ScopeChip(label: scopeLabel, onTap: onPickScope),
              ),
              const Spacer(),
              IconButton(
                onPressed: onToggleHidden,
                tooltip: isHidden ? 'Show balance' : 'Hide balance',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            'Total balance',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          AppSpacing.gapXs,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _amount(summary.totalBalance),
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
                  value: _amount(summary.totals.income),
                  icon: Icons.south_west_rounded,
                  changePercent: summary.incomeChangePercent,
                  higherIsBetter: true,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              Expanded(
                child: _Flow(
                  label: 'Expense',
                  value: _amount(summary.totals.expense),
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

/// Which accounts the figures cover. Tapping opens the selector.
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Showing $label. Change account',
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: AppRadius.pillAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                AppSpacing.hGapSm,
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow({
    required this.label,
    required this.value,
    required this.icon,
    required this.changePercent,
    required this.higherIsBetter,
  });

  final String label;
  final String value;
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
            value,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
        ),
        if (changePercent != null) ...[
          AppSpacing.gapXxs,
          _ChangeBadge(percent: changePercent!, higherIsBetter: higherIsBetter),
        ],
      ],
    );
  }
}

/// Period-over-period delta. Green means good for the user, which is a rise
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
