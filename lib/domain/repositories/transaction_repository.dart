import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
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
}
