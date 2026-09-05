import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
import '../entities/analytics.dart';
import '../entities/money_transaction.dart';

/// Filter set for the transaction list. All fields are optional and combine
/// with AND.
class TransactionFilter {
  const TransactionFilter({
    this.range,
    this.types = const {},
    this.categoryIds = const {},
    this.accountIds = const {},
    this.search,
    this.minAmount,
    this.maxAmount,
  });

  final DateRange? range;
  final Set<TransactionType> types;
  final Set<int> categoryIds;
  final Set<int> accountIds;
  final String? search;
  final double? minAmount;
  final double? maxAmount;

  bool get isEmpty =>
      range == null &&
      types.isEmpty &&
      categoryIds.isEmpty &&
      accountIds.isEmpty &&
      (search == null || search!.isEmpty) &&
      minAmount == null &&
      maxAmount == null;

  /// Filters other than the date range, which is presented separately in the UI.
  int get activeCount =>
      types.length +
      categoryIds.length +
      accountIds.length +
      ((search != null && search!.isNotEmpty) ? 1 : 0) +
      (minAmount != null ? 1 : 0) +
      (maxAmount != null ? 1 : 0);

  TransactionFilter copyWith({
    DateRange? range,
    bool clearRange = false,
    Set<TransactionType>? types,
    Set<int>? categoryIds,
    Set<int>? accountIds,
    String? search,
    double? minAmount,
    double? maxAmount,
    bool clearAmounts = false,
  }) => TransactionFilter(
    range: clearRange ? null : (range ?? this.range),
    types: types ?? this.types,
    categoryIds: categoryIds ?? this.categoryIds,
    accountIds: accountIds ?? this.accountIds,
    search: search ?? this.search,
    minAmount: clearAmounts ? null : (minAmount ?? this.minAmount),
    maxAmount: clearAmounts ? null : (maxAmount ?? this.maxAmount),
  );
}

abstract class TransactionRepository {
  /// One page of transactions, newest first. Paged in SQL — the full table is
  /// never materialised.
  Future<Result<List<MoneyTransaction>>> getTransactions({
    TransactionFilter filter = const TransactionFilter(),
    int limit = 30,
    int offset = 0,
  });

  Future<Result<int>> count(TransactionFilter filter);
  Future<Result<MoneyTransaction>> getById(int id);

  /// Inserts the row and adjusts affected account balances in one SQL
  /// transaction.
  Future<Result<MoneyTransaction>> create(MoneyTransaction transaction);

  /// Reverses the old row's balance effect and applies the new one atomically.
  Future<Result<MoneyTransaction>> update(MoneyTransaction transaction);

  Future<Result<void>> delete(int id);

  Future<Result<List<MoneyTransaction>>> getRecent({int limit = 5});

  // ---- Named queries ------------------------------------------------------
  // Each composes onto [base] so a period query can still be narrowed by
  // account, category or search without building a filter by hand.

  Future<Result<List<MoneyTransaction>>> getToday({
    TransactionFilter base = const TransactionFilter(),
    int limit = 100,
  });

  Future<Result<List<MoneyTransaction>>> getThisWeek({
    TransactionFilter base = const TransactionFilter(),
    int limit = 100,
  });

  Future<Result<List<MoneyTransaction>>> getThisMonth({
    TransactionFilter base = const TransactionFilter(),
    int limit = 100,
  });

  Future<Result<List<MoneyTransaction>>> getByDateRange(
    DateRange range, {
    TransactionFilter base = const TransactionFilter(),
    int limit = 100,
    int offset = 0,
  });

  Future<Result<List<MoneyTransaction>>> getByCategory(
    int categoryId, {
    DateRange? range,
    int limit = 100,
    int offset = 0,
  });

  Future<Result<List<MoneyTransaction>>> getByAccount(
    int accountId, {
    DateRange? range,
    int limit = 100,
    int offset = 0,
  });

  Future<Result<List<MoneyTransaction>>> getIncome({
    DateRange? range,
    int limit = 100,
    int offset = 0,
  });

  Future<Result<List<MoneyTransaction>>> getExpenses({
    DateRange? range,
    int limit = 100,
    int offset = 0,
  });

  Future<Result<List<MoneyTransaction>>> getTransfers({
    DateRange? range,
    int limit = 100,
    int offset = 0,
  });

  // ---- Aggregates ---------------------------------------------------------
  // Computed by SQL. None of these return rows.

  /// Income, expense, transfer and count for [filter] in a single query.
  Future<Result<TransactionTotals>> getTotals([
    TransactionFilter filter = const TransactionFilter(),
  ]);

  Future<Result<double>> getTotalIncome({
    DateRange? range,
    TransactionFilter base = const TransactionFilter(),
  });

  Future<Result<double>> getTotalExpenses({
    DateRange? range,
    TransactionFilter base = const TransactionFilter(),
  });

  /// Per-category totals with each category's share of the filtered set.
  Future<Result<List<CategorySpending>>> getCategorySpending({
    DateRange? range,
    TransactionType type = TransactionType.expense,
    TransactionFilter base = const TransactionFilter(),
    int limit = 50,
  });

  /// One point per day with activity, oldest first.
  Future<Result<List<TrendPoint>>> getDailySpending({
    DateRange? range,
    TransactionFilter base = const TransactionFilter(),
  });
}
