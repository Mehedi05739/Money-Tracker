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

/// Roll-up across several budgets.
///
/// This lives in the domain rather than in the card that draws it: summing
/// limits, summing spend and deciding what counts as "at risk" are money rules,
/// and a widget that recomputes them on every rebuild is both wasteful and a
/// second place for those rules to drift.
class BudgetOverview {
  const BudgetOverview({
    required this.limit,
    required this.spent,
    required this.alerts,
    required this.exceededCount,
    required this.budgetCount,
  });

  const BudgetOverview.empty()
    : limit = 0,
      spent = 0,
      alerts = const [],
      exceededCount = 0,
      budgetCount = 0;

  factory BudgetOverview.from(List<BudgetStatus> statuses) {
    if (statuses.isEmpty) return const BudgetOverview.empty();

    var limit = 0.0;
    var spent = 0.0;
    var exceeded = 0;
    final alerts = <BudgetStatus>[];

    for (final status in statuses) {
      limit += status.limit;
      spent += status.spent;
      if (status.isExceeded) exceeded++;
      if (status.isExceeded || status.isAtRisk) alerts.add(status);
    }

    // Worst first: the budget furthest past its limit is the one to act on.
    alerts.sort((a, b) => b.usagePercent.compareTo(a.usagePercent));

    return BudgetOverview(
      limit: limit,
      spent: spent,
      alerts: alerts,
      exceededCount: exceeded,
      budgetCount: statuses.length,
    );
  }

  final double limit;
  final double spent;

  /// Budgets over or approaching their limit, worst first.
  final List<BudgetStatus> alerts;
  final int exceededCount;
  final int budgetCount;

  bool get isEmpty => budgetCount == 0;
  double get remaining => limit - spent;
  double get usageFraction => limit <= 0 ? 0 : (spent / limit).clamp(0.0, 1.0);
  double get usagePercent => limit <= 0 ? 0 : (spent / limit) * 100;

  bool get isExceeded => spent > limit;
  bool get isAtRisk => !isExceeded && usagePercent >= 80;

  String get headline {
    if (exceededCount > 0) return '$exceededCount over limit';
    if (alerts.isNotEmpty) return '${alerts.length} near limit';
    return 'On track';
  }
}
