import '../../core/enums/plan_status.dart';
import '../../core/utils/date_range.dart';
import '../../core/base/value_equality.dart';

class SpendingPlan with ValueEquality {
  const SpendingPlan({
    required this.id,
    required this.name,
    required this.expectedIncome,
    required this.startDate,
    required this.endDate,
    this.status = PlanStatus.active,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SpendingPlan.draft() {
    final range = DateRange.fromPreset(DateRangePreset.thisMonth);
    return SpendingPlan(
      id: 0,
      name: '',
      expectedIncome: 0,
      startDate: range.start,
      endDate: range.end,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  final int id;
  final String name;

  /// What the user expects to receive this period, and therefore the most
  /// their categories can add up to.
  ///
  /// Stored in the `total_limit` column, which shipped before the concept had
  /// a name; the mapper keeps that mapping in one place.
  final double expectedIncome;
  final DateTime startDate;
  final DateTime endDate;
  final PlanStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPersisted => id > 0;
  DateRange get range => DateRange(start: startDate, end: endDate);

  bool get isCurrent {
    final now = DateTime.now();
    return status == PlanStatus.active &&
        !now.isBefore(startDate) &&
        !now.isAfter(endDate);
  }

  SpendingPlan copyWith({
    int? id,
    String? name,
    double? expectedIncome,
    DateTime? startDate,
    DateTime? endDate,
    PlanStatus? status,
    String? note,
    DateTime? updatedAt,
  }) => SpendingPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    expectedIncome: expectedIncome ?? this.expectedIncome,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    status: status ?? this.status,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    expectedIncome,
    startDate,
    endDate,
    status,
    note,
    createdAt,
    updatedAt,
  ];
}

class SpendingPlanItem with ValueEquality {
  const SpendingPlanItem({
    required this.id,
    required this.planId,
    required this.categoryId,
    required this.plannedAmount,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  final int id;
  final int planId;
  final int? categoryId;
  final double plannedAmount;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;

  bool get isPersisted => id > 0;
  String get displayName => categoryName ?? 'Unassigned';

  SpendingPlanItem copyWith({
    int? id,
    int? planId,
    int? categoryId,
    double? plannedAmount,
    String? note,
    DateTime? updatedAt,
  }) => SpendingPlanItem(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    categoryId: categoryId ?? this.categoryId,
    plannedAmount: plannedAmount ?? this.plannedAmount,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    categoryName: categoryName,
    categoryIcon: categoryIcon,
    categoryColor: categoryColor,
  );

  @override
  List<Object?> get props => [
    id,
    planId,
    categoryId,
    plannedAmount,
    note,
    createdAt,
    updatedAt,
    categoryName,
    categoryIcon,
    categoryColor,
  ];
}
