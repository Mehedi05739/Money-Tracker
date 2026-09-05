import '../../core/utils/date_utils.dart';
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

  /// Amount spent beyond the limit, or zero.
  double get overspend => spent > limit ? spent - limit : 0;

  /// Whole days left in the period, counting today.
  ///
  /// Today counts because the user can still act on it — a budget with one day
  /// left is one they can still keep. Derived from the dates rather than from
  /// elapsed days: `dayCount - elapsed + 1` reports 1 for a period that has
  /// already ended, which would recommend spending the whole remaining balance
  /// on a day outside the budget.
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(budget.endDate)) return 0;
    if (now.isBefore(budget.startDate)) return budget.range.dayCount;
    return AppDate.daysBetween(now, budget.endDate) + 1;
  }

  int get daysElapsed =>
      budget.range.elapsedDays.clamp(0, budget.range.dayCount);

  /// What can still be spent each remaining day without breaching the limit.
  ///
  /// Zero once the budget is spent: there is no safe daily amount left to
  /// recommend, and showing a small positive number would imply otherwise.
  double get recommendedDailySpend {
    if (daysRemaining <= 0 || remaining <= 0) return 0;
    return remaining / daysRemaining;
  }

  /// Kept for callers that predate the rename.
  double get safeDailyAllowance => recommendedDailySpend;

  /// True once the period has finished.
  bool get isFinished => DateTime.now().isAfter(budget.endDate);

  /// True while the period has not started.
  bool get isUpcoming => DateTime.now().isBefore(budget.startDate);

  bool get isPaused => !budget.isActive;

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
    if (isPaused) return 'Paused';
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
