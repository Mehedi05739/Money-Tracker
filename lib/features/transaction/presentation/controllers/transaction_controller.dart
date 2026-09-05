import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/add_transaction.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/get_transactions.dart';

/// Holds screen state and calls use cases. It never touches repositories,
/// data sources or HTTP directly.
class TransactionController extends BaseController {
  TransactionController(
    this._getTransactions,
    this._addTransaction,
    this._deleteTransaction,
  );

  final GetTransactions _getTransactions;
  final AddTransaction _addTransaction;
  final DeleteTransaction _deleteTransaction;

  final RxList<TransactionEntity> transactions = <TransactionEntity>[].obs;
  final RxBool isSubmitting = false.obs;
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  double get balance =>
      transactions.fold(0, (sum, item) => sum + item.signedAmount);

  double get totalIncome => transactions
      .where((e) => e.isIncome)
      .fold(0, (sum, item) => sum + item.amount);

  double get totalExpense => transactions
      .where((e) => !e.isIncome)
      .fold(0, (sum, item) => sum + item.amount);

  @override
  void onInit() {
    super.onInit();
    loadTransactions();
  }

  Future<void> loadTransactions({bool showLoader = true}) async {
    await execute(
      () => _getTransactions(
        const GetTransactionsParams(limit: AppConstants.pageSize),
      ),
      showLoader: showLoader,
      onSuccess: (data) {
        transactions.assignAll(data);
        if (data.isEmpty) setEmpty('No transactions yet');
      },
    );
  }

  /// Pull-to-refresh: keep the current list visible while reloading.
  Future<void> refreshTransactions() => loadTransactions(showLoader: false);

  Future<bool> addTransaction(TransactionEntity transaction) async {
    isSubmitting.value = true;
    fieldErrors.clear();

    final result = await _addTransaction(transaction);
    isSubmitting.value = false;

    return result.fold(
      onSuccess: (created) {
        transactions.insert(0, created);
        setLoaded();
        Get.snackbar('Saved', '${created.title} was added');
        return true;
      },
      onError: (failure) {
        if (failure case ValidationFailure(fieldErrors: final errors)) {
          fieldErrors.assignAll(errors);
        }
        Get.snackbar('Could not save', failure.message);
        return false;
      },
    );
  }

  Future<void> deleteTransaction(String id) async {
    final removed = transactions.firstWhereOrNull((e) => e.id == id);
    if (removed == null) return;

    // Optimistic removal, restored if the server rejects it.
    transactions.removeWhere((e) => e.id == id);
    if (transactions.isEmpty) setEmpty('No transactions yet');

    final result = await _deleteTransaction(id);
    result.fold(
      onSuccess: (_) => null,
      onError: (failure) {
        transactions.add(removed);
        transactions.sort((a, b) => b.date.compareTo(a.date));
        setLoaded();
        Get.snackbar('Could not delete', failure.message);
        return null;
      },
    );
  }
}
