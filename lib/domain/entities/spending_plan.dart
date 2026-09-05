import '../../core/enums/plan_status.dart';
import '../../core/utils/date_range.dart';

class SpendingPlan {
  const SpendingPlan({
    required this.id,
    required this.name,
    required this.totalLimit,
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
      totalLimit: 0,
      startDate: range.start,
      endDate: range.end,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  final int id;
  final String name;
  final double totalLimit;
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
    double? totalLimit,
    DateTime? startDate,
    DateTime? endDate,
    PlanStatus? status,
    String? note,
    DateTime? updatedAt,
  }) =>
      SpendingPlan(
        id: id ?? this.id,
        name: name ?? this.name,
        totalLimit: totalLimit ?? this.totalLimit,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        status: status ?? this.status,
        note: note ?? this.note,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) => other is SpendingPlan && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class SpendingPlanItem {
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
  }) =>
      SpendingPlanItem(
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
  bool operator ==(Object other) => other is SpendingPlanItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
