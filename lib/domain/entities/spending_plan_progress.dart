import '../../core/enums/spending_warning.dart';
import 'spending_plan.dart';

/// Actual-versus-planned for one line of a spending plan.
class SpendingPlanItemProgress {
  const SpendingPlanItemProgress({required this.item, required this.spent});

  final SpendingPlanItem item;
  final double spent;

  double get planned => item.plannedAmount;
  double get remaining => planned - spent;
  double get usagePercent => planned <= 0 ? 0 : (spent / planned) * 100;
  double get usageFraction => (usagePercent / 100).clamp(0.0, 1.0);

  bool get isExceeded => spent > planned;

  /// Which threshold this category has crossed.
  SpendingWarning get warning => SpendingWarning.fromPercent(usagePercent);

  bool get isAtRisk => warning.shouldWarn && !isExceeded;

  /// Amount spent beyond the plan, or zero.
  double get overspend => spent > planned ? spent - planned : 0;
}

/// Roll-up for a whole plan, including spending that fell outside any
/// allocated category.
class SpendingPlanProgress {
  const SpendingPlanProgress({
    required this.plan,
    required this.items,
    required this.totalSpent,
  });

  SpendingPlanProgress.empty(this.plan) : items = const [], totalSpent = 0;

  final SpendingPlan plan;
  final List<SpendingPlanItemProgress> items;

  /// All expense spending in the plan window, allocated or not.
  final double totalSpent;

  /// The income the plan is built against.
  double get expectedIncome => plan.expectedIncome;

  double get totalPlanned => items.fold(0, (sum, item) => sum + item.planned);

  /// Income not yet assigned to any category — what is still free to plan.
  double get unallocated => expectedIncome - totalPlanned;

  /// Income left after what has actually been spent.
  double get remaining => expectedIncome - totalSpent;

  double get usagePercent =>
      expectedIncome <= 0 ? 0 : (totalSpent / expectedIncome) * 100;

  double get usageFraction => (usagePercent / 100).clamp(0.0, 1.0);

  bool get isExceeded => totalSpent > expectedIncome;

  SpendingWarning get warning => SpendingWarning.fromPercent(usagePercent);

  bool get isAtRisk => warning.shouldWarn && !isExceeded;

  /// The categories add up to more than the user expects to receive.
  bool get isOverAllocated => totalPlanned > expectedIncome;

  /// Categories that have crossed a threshold, closest to the edge first.
  List<SpendingPlanItemProgress> get warningItems {
    final flagged = items.where((item) => item.warning.shouldWarn).toList()
      ..sort((a, b) => b.usagePercent.compareTo(a.usagePercent));
    return flagged;
  }

  List<SpendingPlanItemProgress> get breachedItems =>
      items.where((item) => item.isExceeded).toList();

  double get safeDailyAllowance {
    final daysLeft = plan.range.dayCount - plan.range.elapsedDays + 1;
    if (daysLeft <= 0 || remaining <= 0) return 0;
    return remaining / daysLeft;
  }

  String get headline {
    if (isExceeded) return 'Over plan';
    if (isAtRisk) return warning.label;
    return 'Within plan';
  }
}
