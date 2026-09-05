import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/money_transaction.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/transaction_repository.dart';

/// A day's transactions plus its net, precomputed so the list builder does no
/// arithmetic while scrolling.
class TransactionDayGroup {
  const TransactionDayGroup({
    required this.date,
    required this.transactions,
    required this.net,
  });

  final DateTime date;
  final List<MoneyTransaction> transactions;
  final double net;
}

/// Paginated, filterable ledger.
///
/// Pages are appended rather than reloaded, so recording a transaction or
/// scrolling never re-reads rows already in memory.
class TransactionsController extends BaseController {
  TransactionsController(
    this._transactions,
    this._categories,
    this._accounts,
    this._events,
  );

  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final AccountRepository _accounts;
  final AppEvents _events;

  final RxList<MoneyTransaction> transactions = <MoneyTransaction>[].obs;
  final RxList<TransactionDayGroup> groups = <TransactionDayGroup>[].obs;
  final Rx<TransactionFilter> filter = const TransactionFilter().obs;
  final Rx<DateRange> range =
      DateRange.fromPreset(DateRangePreset.thisMonth).obs;

  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxInt totalCount = 0.obs;

  final RxList<Category> categories = <Category>[].obs;
  final RxList<Account> accounts = <Account>[].obs;

  Timer? _searchDebounce;
  Worker? _changeWorker;
  int _offset = 0;

  /// Combines the date range with the user's other filter choices.
  TransactionFilter get effectiveFilter =>
      filter.value.copyWith(range: range.value);

  int get activeFilterCount => filter.value.activeCount;

  @override
  void onInit() {
    super.onInit();
    _loadReferenceData();
    load();

    _changeWorker = _events.listen(
      const [DataChange.transactions, DataChange.accounts, DataChange.categories],
      () {
        _loadReferenceData();
        load(showLoader: false);
      },
    );
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _changeWorker?.dispose();
    super.onClose();
  }

  Future<void> _loadReferenceData() async {
    final categoryFuture = _categories.getCategories();
    final accountFuture = _accounts.getAccounts();
    categories.assignAll((await categoryFuture).dataOrNull ?? const []);
    accounts.assignAll((await accountFuture).dataOrNull ?? const []);
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();
    _offset = 0;
    hasMore.value = true;

    final countFuture = _transactions.count(effectiveFilter);
    final pageFuture = _transactions.getTransactions(
      filter: effectiveFilter,
      limit: AppConstants.pageSize,
    );

    final countResult = await countFuture;
    final pageResult = await pageFuture;

    pageResult.fold(
      onSuccess: (page) {
        totalCount.value = countResult.dataOrNull ?? page.length;
        transactions.assignAll(page);
        _offset = page.length;
        hasMore.value = page.length >= AppConstants.pageSize;
        _rebuildGroups();

        if (page.isEmpty) {
          setEmpty(
            effectiveFilter.activeCount > 0
                ? 'No transactions match these filters'
                : 'No transactions in this period',
          );
        } else {
          setLoaded();
        }
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  /// Appends the next page. Guarded so scroll callbacks cannot stack requests.
  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || isLoading) return;

    isLoadingMore.value = true;
    final result = await _transactions.getTransactions(
      filter: effectiveFilter,
      limit: AppConstants.pageSize,
      offset: _offset,
    );
    isLoadingMore.value = false;

    result.fold(
      onSuccess: (page) {
        if (page.isEmpty) {
          hasMore.value = false;
          return null;
        }
        transactions.addAll(page);
        _offset += page.length;
        hasMore.value = page.length >= AppConstants.pageSize;
        _rebuildGroups();
        return null;
      },
      onError: (failure) {
        hasMore.value = false;
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  void changeRange(DateRange value) {
    if (value == range.value) return;
    range.value = value;
    load(showLoader: false);
  }

  void search(String term) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppConstants.searchDebounce, () {
      filter.value = filter.value.copyWith(search: term.trim());
      load(showLoader: false);
    });
  }

  void applyFilter(TransactionFilter value) {
    filter.value = value;
    load(showLoader: false);
  }

  void clearFilters() {
    filter.value = const TransactionFilter();
    load(showLoader: false);
  }

  void toggleType(TransactionType type) {
    final types = Set<TransactionType>.from(filter.value.types);
    if (!types.add(type)) types.remove(type);
    applyFilter(filter.value.copyWith(types: types));
  }

  Future<void> deleteTransaction(MoneyTransaction transaction) async {
    final result = await _transactions.delete(transaction.id);

    result.fold(
      onSuccess: (_) {
        // Remove locally instead of refetching: the balance headline is
        // recomputed by the dashboard on its own next read.
        transactions.removeWhere((item) => item.id == transaction.id);
        totalCount.value = (totalCount.value - 1).clamp(0, 1 << 30);
        _rebuildGroups();
        if (transactions.isEmpty) setEmpty('No transactions in this period');
        _events.emit(DataChange.transactions);
        AppSnackbar.success('Transaction deleted');
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }

  /// Groups the loaded page into day sections. Runs once per page rather than
  /// on every frame of the list.
  void _rebuildGroups() {
    final byDay = <String, List<MoneyTransaction>>{};

    for (final transaction in transactions) {
      final key = AppDate.toDayKey(transaction.transactionDate);
      byDay.putIfAbsent(key, () => []).add(transaction);
    }

    groups.assignAll([
      for (final entry in byDay.entries)
        TransactionDayGroup(
          date: DateTime.parse(entry.key),
          transactions: entry.value,
          net: entry.value.fold<double>(
            0,
            (sum, transaction) => sum + transaction.signedAmount,
          ),
        ),
    ]);
  }
}
