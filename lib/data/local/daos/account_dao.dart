import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../account_balance.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/account.dart';
import '../../models/account_mapper.dart';
import '../../models/row_reader.dart';

class AccountDao {
  const AccountDao(this._db);

  final Database _db;

  Future<List<Account>> findAll({bool includeArchived = false}) async {
    final rows = await _db.query(
      Tables.accounts,
      where: includeArchived ? null : '${AccountColumns.isArchived} = 0',
      orderBy: '${AccountColumns.sortOrder} ASC, ${AccountColumns.name} ASC',
    );
    return rows.map(AccountMapper.fromRow).toList();
  }

  Future<Account?> findById(int id, {DatabaseExecutor? executor}) async {
    final rows = await (executor ?? _db).query(
      Tables.accounts,
      where: '${AccountColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : AccountMapper.fromRow(rows.first);
  }

  /// A new account starts with its current balance equal to the opening
  /// balance; the ledger moves it from there.
  Future<int> insert(Account account) {
    final row = AccountMapper.toRow(
      account.copyWith(currentBalance: account.openingBalance),
    );
    return _db.insert(Tables.accounts, row);
  }

  /// Preserves `current_balance`: it is owned by the ledger, not the edit form.
  /// Changing the opening balance shifts the current balance by the same delta.
  Future<int> update(Account account) async {
    return _db.transaction((txn) async {
      final existing = await findById(account.id, executor: txn);
      if (existing == null) return 0;

      final openingDelta = account.openingBalance - existing.openingBalance;
      final row = AccountMapper.toRow(
        account.copyWith(
          currentBalance: existing.currentBalance + openingDelta,
          updatedAt: DateTime.now(),
        ),
      )..remove(AccountColumns.createdAt);

      return txn.update(
        Tables.accounts,
        row,
        where: '${AccountColumns.id} = ?',
        whereArgs: [account.id],
      );
    });
  }

  /// Removes an account and everything that depended on it, atomically.
  ///
  /// Transactions *in* the account go with it — the schema cascades, and the
  /// confirm dialog says so. Transfers *into* it are the awkward case: the
  /// foreign key would only null their destination, leaving rows that still
  /// claim to be transfers, still debit their source, and now point nowhere.
  /// The source account's balance would stay reduced with nothing on screen to
  /// explain where the money went.
  ///
  /// They are reclassified as expenses instead. The debit is identical — a
  /// transfer and an expense both move the source by `-amount` — so no balance
  /// changes, the row stays visible in the source account's history, and it now
  /// says something true: the money left the accounts being tracked.
  Future<int> delete(int id) {
    return _db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE ${Tables.transactions} '
        "SET ${TransactionColumns.type} = 'expense', "
        '    ${TransactionColumns.toAccountId} = NULL, '
        '    ${TransactionColumns.updatedAt} = ? '
        'WHERE ${TransactionColumns.toAccountId} = ? '
        "  AND ${TransactionColumns.type} = 'transfer'",
        [AppDate.toDb(DateTime.now()), id],
      );

      return txn.delete(
        Tables.accounts,
        where: '${AccountColumns.id} = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> setArchived(int id, bool archived) => _db.update(
    Tables.accounts,
    {
      AccountColumns.isArchived: asDbBool(archived),
      AccountColumns.updatedAt: AppDate.toDb(DateTime.now()),
    },
    where: '${AccountColumns.id} = ?',
    whereArgs: [id],
  );

  Future<double> totalBalance() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(${AccountColumns.currentBalance}), 0) AS total '
      'FROM ${Tables.accounts} WHERE ${AccountColumns.isArchived} = 0',
    );
    return rows.first.readDoubleOr('total');
  }

  /// Current balance of one account, without loading the row.
  Future<double> balanceOf(int accountId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(${AccountColumns.currentBalance}, 0) AS balance '
      'FROM ${Tables.accounts} WHERE ${AccountColumns.id} = ?',
      [accountId],
    );
    return rows.isEmpty ? 0 : rows.first.readDoubleOr('balance');
  }

  Future<int> count() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.accounts}',
    );
    return rows.first.readIntOrNull('c') ?? 0;
  }

  /// Rebuilds every balance from the ledger. Used as a repair action and after
  /// bulk imports, where per-row maintenance would be wasteful.
  Future<void> recalculateAll() async {
    await _db.transaction((txn) async {
      await txn.rawUpdate(
        '''
        UPDATE ${Tables.accounts}
        SET ${AccountColumns.currentBalance} = ${AccountColumns.openingBalance}
          + COALESCE((
              SELECT SUM(${AccountBalance.sourceDeltaSql()})
              FROM ${Tables.transactions} t
              WHERE t.${TransactionColumns.accountId} = ${Tables.accounts}.${AccountColumns.id}
            ), 0)
          + COALESCE((
              SELECT SUM(t.${TransactionColumns.amount})
              FROM ${Tables.transactions} t
              WHERE t.${TransactionColumns.toAccountId} = ${Tables.accounts}.${AccountColumns.id}
            ), 0),
            ${AccountColumns.updatedAt} = ?
      ''',
        [AppDate.toDb(DateTime.now())],
      );
    });
  }
}
