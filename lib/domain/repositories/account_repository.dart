import '../../core/utils/result.dart';
import '../entities/account.dart';

abstract class AccountRepository {
  Future<Result<List<Account>>> getAccounts({bool includeArchived = false});
  Future<Result<Account>> getById(int id);
  Future<Result<Account>> create(Account account);
  Future<Result<Account>> update(Account account);

  /// Deleting an account cascades to its transactions — callers must confirm
  /// with the user first.
  Future<Result<void>> delete(int id);
  Future<Result<void>> setArchived(int id, bool archived);

  /// Sum of every non-archived account balance.
  Future<Result<double>> getTotalBalance();

  /// Recomputes `current_balance` from `opening_balance` plus the ledger.
  /// A repair path for data written outside the normal flow.
  Future<Result<void>> recalculateBalances();
}
