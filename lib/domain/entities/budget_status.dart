import 'budget.dart';

/// How a budget is tracking. [spent] comes from an indexed SQL aggregate over
/// the budget's own date range and category.
class BudgetStatus {
  const BudgetStatus({required this.budget, required this.spent});

  final Budget budget;
  final double spent;

  double get limit => budget.amount;

  double get remaining => limit - spent;

  /// Consumption as 0–unbounded; values above 100 mean the budget is blown.
  double get usagePercent => limit <= 0 ? 0 : (spent / limit) * 100;

  /// Clamped for progress bars, which must not overflow their track.
  double get usageFraction => (usagePercent / 100).clamp(0.0, 1.0);

  bool get isExceeded => spent > limit;
  bool get isAtRisk => !isExceeded && usagePercent >= budget.alertPercentage;
  bool get isHealthy => !isExceeded && !isAtRisk;

  /// What can still be spent per remaining day without breaching the limit.
  double get safeDailyAllowance {
    final daysLeft = budget.range.dayCount - budget.range.elapsedDays + 1;
    if (daysLeft <= 0 || remaining <= 0) return 0;
    return remaining / daysLeft;
  }

  /// Spending pace against time elapsed. Above 1 means the user is burning the
  /// budget faster than the period is passing.
  double get paceRatio {
    final elapsedShare = budget.range.dayCount <= 0
        ? 0.0
        : budget.range.elapsedDays / budget.range.dayCount;
    if (elapsedShare <= 0 || limit <= 0) return 0;
    return (spent / limit) / elapsedShare;
  }

  bool get isOverPace => paceRatio > 1.1 && !isExceeded;

  String get headline {
    if (isExceeded) return 'Over budget';
    if (isAtRisk) return 'Approaching limit';
    if (isOverPace) return 'Spending fast';
    return 'On track';
  }
}
