import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../local/daos/account_dao.dart';
import 'repository_guard.dart';

class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl(this._dao);

  final AccountDao _dao;

  @override
  Future<Result<List<Account>>> getAccounts({bool includeArchived = false}) =>
      guard(
        () => _dao.findAll(includeArchived: includeArchived),
        context: 'getAccounts',
      );

  @override
  Future<Result<Account>> getById(int id) => guardFound(
        () => _dao.findById(id),
        notFoundMessage: 'Account not found',
      );

  @override
  Future<Result<Account>> create(Account account) async {
    final invalid = _validate(account);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      final id = await _dao.insert(account);
      final created = await _dao.findById(id);
      if (created == null) throw StateError('Account $id vanished after insert');
      return created;
    }, context: 'createAccount');
  }

  @override
  Future<Result<Account>> update(Account account) async {
    final invalid = _validate(account);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      await _dao.update(account);
      final updated = await _dao.findById(account.id);
      if (updated == null) throw StateError('Account ${account.id} missing');
      return updated;
    }, context: 'updateAccount');
  }

  @override
  Future<Result<void>> delete(int id) async {
    // Refuse to remove the last account: every transaction needs one.
    final remaining = await guard(_dao.count, context: 'countAccounts');
    if (remaining case Success(:final data) when data <= 1) {
      return const Result.error(
        ValidationFailure('You need at least one account'),
      );
    }
    return guard(() => _dao.delete(id), context: 'deleteAccount');
  }

  @override
  Future<Result<void>> setArchived(int id, bool archived) =>
      guard(() => _dao.setArchived(id, archived), context: 'archiveAccount');

  @override
  Future<Result<double>> getTotalBalance() =>
      guard(_dao.totalBalance, context: 'totalBalance');

  @override
  Future<Result<void>> recalculateBalances() =>
      guard(_dao.recalculateAll, context: 'recalculateBalances');

  Failure? _validate(Account account) {
    final nameError = Validators.name(account.name, field: 'Account name');
    if (nameError != null) {
      return ValidationFailure(nameError, fieldErrors: {'name': nameError});
    }
    if (account.openingBalance.abs() > Validators.maxAmount) {
      return const ValidationFailure(
        'Opening balance is too large',
        fieldErrors: {'openingBalance': 'Amount is too large'},
      );
    }
    return null;
  }
}
