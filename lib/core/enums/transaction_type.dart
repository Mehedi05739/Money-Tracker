/// Kind of money movement. Persisted by [name], so the strings are part of the
/// database contract — never rename a value without a migration.
enum TransactionType {
  income,
  expense,
  transfer;

  static TransactionType fromName(String? value) => values.firstWhere(
        (e) => e.name == value,
        orElse: () => TransactionType.expense,
      );

  String get label => switch (this) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.transfer => 'Transfer',
      };

  /// How this type moves the source account's balance.
  int get balanceSign => switch (this) {
        TransactionType.income => 1,
        TransactionType.expense => -1,
        TransactionType.transfer => -1,
      };

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;
  bool get isTransfer => this == TransactionType.transfer;

  /// Transfers move money between the user's own accounts, so they are excluded
  /// from income/expense totals — counting them would double-count net worth.
  bool get affectsNetWorth => this != TransactionType.transfer;
}
