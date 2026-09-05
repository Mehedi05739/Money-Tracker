import '../../core/enums/payment_method.dart';
import '../../core/enums/recurrence_frequency.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_utils.dart';
import '../../core/base/value_equality.dart';

/// A template that materialises real transactions on a schedule.
class RecurringTransaction with ValueEquality {
  const RecurringTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.title,
    required this.frequency,
    required this.startDate,
    required this.nextRunDate,
    this.categoryId,
    this.note,
    this.paymentMethod,
    this.intervalCount = 1,
    this.endDate,
    this.lastRunDate,
    this.isActive = true,
    this.autoPost = true,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.accountName,
  });

  factory RecurringTransaction.draft({
    TransactionType type = TransactionType.expense,
  }) {
    final today = AppDate.startOfDay(DateTime.now());
    return RecurringTransaction(
      id: 0,
      accountId: 0,
      type: type,
      amount: 0,
      title: '',
      frequency: RecurrenceFrequency.monthly,
      startDate: today,
      nextRunDate: today,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  final int id;
  final int accountId;
  final int? categoryId;
  final TransactionType type;
  final double amount;
  final String title;
  final String? note;
  final PaymentMethod? paymentMethod;
  final RecurrenceFrequency frequency;
  final int intervalCount;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextRunDate;
  final DateTime? lastRunDate;
  final bool isActive;

  /// When false the schedule only reminds; nothing is written automatically.
  final bool autoPost;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final String? accountName;

  bool get isPersisted => id > 0;

  bool get isDue =>
      isActive && !nextRunDate.isAfter(AppDate.endOfDay(DateTime.now()));

  bool get hasEnded =>
      endDate != null && nextRunDate.isAfter(AppDate.endOfDay(endDate!));

  int get daysUntilNextRun => AppDate.daysBetween(DateTime.now(), nextRunDate);

  /// Advances a due date by one interval, clamping month-end overflow.
  DateTime occurrenceAfter(DateTime from) => switch (frequency) {
    RecurrenceFrequency.daily => from.add(Duration(days: intervalCount)),
    RecurrenceFrequency.weekly => from.add(Duration(days: 7 * intervalCount)),
    RecurrenceFrequency.biweekly => from.add(
      Duration(days: 14 * intervalCount),
    ),
    RecurrenceFrequency.monthly => AppDate.addMonths(from, intervalCount),
    RecurrenceFrequency.quarterly => AppDate.addMonths(from, 3 * intervalCount),
    RecurrenceFrequency.yearly => AppDate.addMonths(from, 12 * intervalCount),
  };

  RecurringTransaction copyWith({
    int? id,
    int? accountId,
    int? categoryId,
    bool clearCategory = false,
    TransactionType? type,
    double? amount,
    String? title,
    String? note,
    PaymentMethod? paymentMethod,
    RecurrenceFrequency? frequency,
    int? intervalCount,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    DateTime? nextRunDate,
    DateTime? lastRunDate,
    bool? isActive,
    bool? autoPost,
    DateTime? updatedAt,
  }) => RecurringTransaction(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    type: type ?? this.type,
    amount: amount ?? this.amount,
    title: title ?? this.title,
    note: note ?? this.note,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    frequency: frequency ?? this.frequency,
    intervalCount: intervalCount ?? this.intervalCount,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    nextRunDate: nextRunDate ?? this.nextRunDate,
    lastRunDate: lastRunDate ?? this.lastRunDate,
    isActive: isActive ?? this.isActive,
    autoPost: autoPost ?? this.autoPost,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    categoryName: categoryName,
    categoryIcon: categoryIcon,
    categoryColor: categoryColor,
    accountName: accountName,
  );

  @override
  List<Object?> get props => [
    id,
    accountId,
    categoryId,
    type,
    amount,
    title,
    note,
    paymentMethod,
    frequency,
    intervalCount,
    startDate,
    endDate,
    nextRunDate,
    lastRunDate,
    isActive,
    autoPost,
    createdAt,
    updatedAt,
    categoryName,
    categoryIcon,
    categoryColor,
    accountName,
  ];
}
