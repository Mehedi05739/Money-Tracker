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
  bool get isAtRisk => !isExceeded && usagePercent >= 80;
}

/// Roll-up for a whole plan, including spending that fell outside any
/// allocated category.
class SpendingPlanProgress {
  const SpendingPlanProgress({
    required this.plan,
    required this.items,
    required this.totalSpent,
  });

  SpendingPlanProgress.empty(this.plan)
      : items = const [],
        totalSpent = 0;

  final SpendingPlan plan;
  final List<SpendingPlanItemProgress> items;

  /// All expense spending in the plan window, allocated or not.
  final double totalSpent;

  double get totalLimit => plan.totalLimit;

  double get totalPlanned =>
      items.fold(0, (sum, item) => sum + item.planned);

  /// Limit not yet assigned to any category.
  double get unallocated => totalLimit - totalPlanned;

  double get remaining => totalLimit - totalSpent;

  double get usagePercent =>
      totalLimit <= 0 ? 0 : (totalSpent / totalLimit) * 100;

  double get usageFraction => (usagePercent / 100).clamp(0.0, 1.0);

  bool get isExceeded => totalSpent > totalLimit;
  bool get isAtRisk => !isExceeded && usagePercent >= 80;
  bool get isOverAllocated => totalPlanned > totalLimit;

  List<SpendingPlanItemProgress> get breachedItems =>
      items.where((item) => item.isExceeded).toList();

  double get safeDailyAllowance {
    final daysLeft = plan.range.dayCount - plan.range.elapsedDays + 1;
    if (daysLeft <= 0 || remaining <= 0) return 0;
    return remaining / daysLeft;
  }

  String get headline {
    if (isExceeded) return 'Limit exceeded';
    if (isAtRisk) return 'Close to limit';
    return 'Within plan';
  }
}
