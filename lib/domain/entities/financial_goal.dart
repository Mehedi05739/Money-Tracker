import '../../core/enums/goal_status.dart';
import '../../core/utils/date_utils.dart';
import '../../core/base/value_equality.dart';

class FinancialGoal with ValueEquality {
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

  /// What must be set aside each month to finish on time.
  ///
  /// `null` when there is no target date, the date has passed, or the goal is
  /// already met — in those cases there is no rate to recommend, and showing
  /// one would imply the goal is still open.
  double? get requiredMonthlyContribution => _requiredPerPeriod(30);

  /// What must be set aside each week to finish on time.
  double? get requiredWeeklyContribution => _requiredPerPeriod(7);

  double? _requiredPerPeriod(int daysPerPeriod) {
    final days = daysRemaining;
    if (days == null || days <= 0 || isAchieved) return null;
    // Round the period count up: three-and-a-bit months to save in is three
    // full months of saving plus a part month, and recommending against the
    // fractional figure would leave the user short.
    final periods = (days / daysPerPeriod).ceil();
    return remainingAmount / periods;
  }

  /// Whole months left before the target date, rounded up.
  int? get monthsRemaining {
    final days = daysRemaining;
    if (days == null || days <= 0) return null;
    return (days / 30).ceil();
  }

  int? get weeksRemaining {
    final days = daysRemaining;
    if (days == null || days <= 0) return null;
    return (days / 7).ceil();
  }

  /// How long is left, in the largest unit that still reads naturally.
  ///
  /// "4 months" is easier to act on than "118 days", but under a fortnight the
  /// day count is what matters.
  String? get timeToTarget {
    final days = daysRemaining;
    if (days == null) return null;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Due today';
    if (days <= 14) return '$days ${days == 1 ? 'day' : 'days'}';

    final weeks = (days / 7).round();
    if (days < 60) return '$weeks ${weeks == 1 ? 'week' : 'weeks'}';

    final months = (days / 30).round();
    return '$months ${months == 1 ? 'month' : 'months'}';
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
  }) => FinancialGoal(
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
  List<Object?> get props => [
    id,
    name,
    targetAmount,
    currentAmount,
    targetDate,
    icon,
    color,
    status,
    note,
    createdAt,
    updatedAt,
  ];
}

class GoalContribution with ValueEquality {
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

  GoalContribution copyWith({
    double? amount,
    DateTime? contributedAt,
    int? accountId,
    bool clearAccount = false,
    String? note,
    bool clearNote = false,
  }) => GoalContribution(
    id: id,
    goalId: goalId,
    accountId: clearAccount ? null : (accountId ?? this.accountId),
    amount: amount ?? this.amount,
    contributedAt: contributedAt ?? this.contributedAt,
    note: clearNote ? null : (note ?? this.note),
    createdAt: createdAt,
    accountName: accountName,
  );

  @override
  List<Object?> get props => [
    id,
    goalId,
    accountId,
    amount,
    contributedAt,
    note,
    createdAt,
    accountName,
  ];
}
