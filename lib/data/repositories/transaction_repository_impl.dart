import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/money_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../local/daos/transaction_dao.dart';
import 'repository_guard.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl(this._dao);

  final TransactionDao _dao;

  @override
  Future<Result<List<MoneyTransaction>>> getTransactions({
    TransactionFilter filter = const TransactionFilter(),
    int limit = 30,
    int offset = 0,
  }) =>
      guard(
        () => _dao.find(filter: filter, limit: limit, offset: offset),
        context: 'getTransactions',
      );

  @override
  Future<Result<int>> count(TransactionFilter filter) =>
      guard(() => _dao.count(filter), context: 'countTransactions');

  @override
  Future<Result<MoneyTransaction>> getById(int id) => guardFound(
        () => _dao.findById(id),
        notFoundMessage: 'Transaction not found',
      );

  @override
  Future<Result<List<MoneyTransaction>>> getRecent({int limit = 5}) =>
      guard(() => _dao.findRecent(limit: limit), context: 'recentTransactions');

  @override
  Future<Result<MoneyTransaction>> create(MoneyTransaction transaction) async {
    final invalid = _validate(transaction);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      final id = await _dao.insert(_normalize(transaction));
      final created = await _dao.findById(id);
      if (created == null) {
        throw StateError('Transaction $id missing after insert');
      }
      return created;
    }, context: 'createTransaction');
  }

  @override
  Future<Result<MoneyTransaction>> update(MoneyTransaction transaction) async {
    final invalid = _validate(transaction);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      await _dao.update(_normalize(transaction));
      final updated = await _dao.findById(transaction.id);
      if (updated == null) {
        throw StateError('Transaction ${transaction.id} missing');
      }
      return updated;
    }, context: 'updateTransaction');
  }

  @override
  Future<Result<void>> delete(int id) =>
      guard(() => _dao.delete(id), context: 'deleteTransaction');

  /// Rounds the amount to cents and drops fields that do not apply to the
  /// chosen type, so a type switch in the form cannot leave stale data behind.
  MoneyTransaction _normalize(MoneyTransaction transaction) {
    final amount = Validators.normalizeAmount(transaction.amount);

    if (transaction.type.isTransfer) {
      return transaction.copyWith(amount: amount, clearCategory: true);
    }
    return transaction.copyWith(amount: amount, clearToAccount: true);
  }

  Failure? _validate(MoneyTransaction transaction) {
    final errors = <String, String>{};

    if (transaction.amount <= 0) {
      errors['amount'] = 'Amount must be greater than zero';
    } else if (transaction.amount > Validators.maxAmount) {
      errors['amount'] = 'Amount is too large';
    } else if (transaction.amount.isNaN || transaction.amount.isInfinite) {
      errors['amount'] = 'Enter a valid number';
    }

    if (transaction.title.trim().isEmpty) {
      errors['title'] = 'Add a short title';
    }

    if (transaction.accountId <= 0) {
      errors['account'] = 'Choose an account';
    }

    if (transaction.type.isTransfer) {
      if (transaction.toAccountId == null) {
        errors['toAccount'] = 'Choose a destination account';
      } else if (transaction.toAccountId == transaction.accountId) {
        errors['toAccount'] = 'Pick a different destination account';
      }
    } else if (transaction.categoryId == null) {
      errors['category'] = 'Choose a category';
    }

    // A far-future date is almost always a typo in the year field.
    if (transaction.transactionDate
        .isAfter(DateTime.now().add(const Duration(days: 365 * 5)))) {
      errors['date'] = 'That date is too far in the future';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure(
      'Please fix the highlighted fields',
      fieldErrors: errors,
    );
  }
}
