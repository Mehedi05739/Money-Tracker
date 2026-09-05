import '../../core/enums/payment_method.dart';
import '../../core/enums/transaction_type.dart';

/// A single ledger entry.
///
/// Named `MoneyTransaction` to avoid colliding with sqflite's `Transaction`.
/// [categoryName], [accountName] and their display fields are denormalised by
/// the DAO's join so lists render without an N+1 lookup per row.
class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.title,
    required this.transactionDate,
    this.toAccountId,
    this.categoryId,
    this.description,
    this.paymentMethod,
    this.note,
    this.recurringId,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.accountName,
    this.toAccountName,
  });

  factory MoneyTransaction.draft({
    required TransactionType type,
    int accountId = 0,
  }) =>
      MoneyTransaction(
        id: 0,
        accountId: accountId,
        type: type,
        amount: 0,
        title: '',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  final int id;
  final int accountId;
  final int? toAccountId;
  final TransactionType type;
  final double amount;
  final int? categoryId;
  final String title;
  final String? description;
  final DateTime transactionDate;
  final PaymentMethod? paymentMethod;
  final String? note;
  final int? recurringId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined display fields — never written back to the database.
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final String? accountName;
  final String? toAccountName;

  bool get isPersisted => id > 0;
  bool get isIncome => type.isIncome;
  bool get isExpense => type.isExpense;
  bool get isTransfer => type.isTransfer;
  bool get isRecurringInstance => recurringId != null;

  /// Amount signed for net-worth math. Transfers net to zero across accounts.
  double get signedAmount => type.isTransfer ? 0 : amount * type.balanceSign;

  String get displayCategory =>
      isTransfer ? 'Transfer' : (categoryName ?? 'Uncategorized');

  MoneyTransaction copyWith({
    int? id,
    int? accountId,
    int? toAccountId,
    bool clearToAccount = false,
    TransactionType? type,
    double? amount,
    int? categoryId,
    bool clearCategory = false,
    String? title,
    String? description,
    DateTime? transactionDate,
    PaymentMethod? paymentMethod,
    String? note,
    DateTime? updatedAt,
  }) =>
      MoneyTransaction(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        toAccountId: clearToAccount ? null : (toAccountId ?? this.toAccountId),
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        title: title ?? this.title,
        description: description ?? this.description,
        transactionDate: transactionDate ?? this.transactionDate,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        note: note ?? this.note,
        recurringId: recurringId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        categoryName: categoryName,
        categoryIcon: categoryIcon,
        categoryColor: categoryColor,
        accountName: accountName,
        toAccountName: toAccountName,
      );

  @override
  bool operator ==(Object other) => other is MoneyTransaction && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
