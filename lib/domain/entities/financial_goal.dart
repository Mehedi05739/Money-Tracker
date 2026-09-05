import '../../core/enums/goal_status.dart';
import '../../core/utils/date_utils.dart';

class FinancialGoal {
  const FinancialGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.icon,
    this.color,
    this.status = GoalStatus.active,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinancialGoal.draft() => FinancialGoal(
        id: 0,
        name: '',
        targetAmount: 0,
        currentAmount: 0,
        targetDate: DateTime.now().add(const Duration(days: 180)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  final int id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String? icon;
  final int? color;
  final GoalStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPersisted => id > 0;

  double get remainingAmount =>
      (targetAmount - currentAmount).clamp(0, double.infinity);

  /// 0–100, capped so an over-funded goal does not overflow progress bars.
  double get progressPercent => targetAmount <= 0
      ? 0
      : ((currentAmount / targetAmount) * 100).clamp(0, 100);

  bool get isAchieved =>
      status == GoalStatus.achieved || currentAmount >= targetAmount;

  int? get daysRemaining => targetDate == null
      ? null
      : AppDate.daysBetween(DateTime.now(), targetDate!);

  bool get isOverdue =>
      !isAchieved && (daysRemaining != null && daysRemaining! < 0);

  /// What the user must set aside per month to finish on time.
  /// `null` when there is no target date or the date has passed.
  double? get requiredMonthlyContribution {
    final days = daysRemaining;
    if (days == null || days <= 0 || isAchieved) return null;
    final months = (days / 30).ceil();
    return remainingAmount / months;
  }

  FinancialGoal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? icon,
    int? color,
    GoalStatus? status,
    String? note,
    DateTime? updatedAt,
  }) =>
      FinancialGoal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
        icon: icon ?? this.icon,
        color: color ?? this.color,
        status: status ?? this.status,
        note: note ?? this.note,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) => other is FinancialGoal && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class GoalContribution {
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.contributedAt,
    this.accountId,
    this.note,
    required this.createdAt,
    this.accountName,
  });

  final int id;
  final int goalId;
  final int? accountId;

  /// Negative values represent a withdrawal from the goal.
  final double amount;
  final DateTime contributedAt;
  final String? note;
  final DateTime createdAt;
  final String? accountName;

  bool get isWithdrawal => amount < 0;

  @override
  bool operator ==(Object other) => other is GoalContribution && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
