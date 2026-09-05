import '../../core/enums/budget_period.dart';
import '../../core/utils/date_range.dart';
import '../../core/base/value_equality.dart';

class Budget with ValueEquality {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.alertPercentage = 80,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  factory Budget.draft() {
    final range = DateRange.fromPreset(DateRangePreset.thisMonth);
    return Budget(
      id: 0,
      categoryId: null,
      amount: 0,
      period: BudgetPeriod.monthly,
      startDate: range.start,
      endDate: range.end,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  final int id;

  /// `null` means an overall budget across every expense category.
  final int? categoryId;
  final double amount;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final int alertPercentage;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;

  bool get isPersisted => id > 0;
  bool get isOverall => categoryId == null;
  String get displayName => categoryName ?? 'All expenses';

  DateRange get range => DateRange(start: startDate, end: endDate);

  bool get isCurrent {
    final now = DateTime.now();
    return isActive && !now.isBefore(startDate) && !now.isAfter(endDate);
  }

  Budget copyWith({
    int? id,
    int? categoryId,
    bool clearCategory = false,
    double? amount,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    int? alertPercentage,
    bool? isActive,
    DateTime? updatedAt,
  }) => Budget(
    id: id ?? this.id,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    amount: amount ?? this.amount,
    period: period ?? this.period,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    alertPercentage: alertPercentage ?? this.alertPercentage,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    categoryName: categoryName,
    categoryIcon: categoryIcon,
    categoryColor: categoryColor,
  );

  @override
  List<Object?> get props => [
    id,
    categoryId,
    amount,
    period,
    startDate,
    endDate,
    alertPercentage,
    isActive,
    createdAt,
    updatedAt,
    categoryName,
    categoryIcon,
    categoryColor,
  ];
}
