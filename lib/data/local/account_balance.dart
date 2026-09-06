import '../../core/database/db_tables.dart';
import '../../core/enums/transaction_type.dart';
import '../../domain/entities/money_transaction.dart';

/// The single definition of how a transaction moves account balances.
///
/// Balances are maintained two ways, and both are necessary: incrementally as
/// each transaction is written (cheap, keeps the stored balance live) and in
/// bulk by recalculating from the ledger (the repair path, and what an import
/// uses instead of thousands of per-row updates).
///
/// Those two used to encode the rule separately — Dart arithmetic on one side,
/// a hand-written SQL `CASE` on the other — with nothing keeping them in step.
/// A new transaction type, or a changed [TransactionType.balanceSign], would
/// have updated one and not the other, and the disagreement would only surface
/// as a wrong balance *after* a repair: the operation meant to fix the ledger
/// would be the one that corrupted it.
///
/// Both renderings now come from [TransactionType.balanceSign], so they cannot
/// drift. `test/data/account_balance_test.dart` asserts they agree.
class AccountBalance {
  const AccountBalance._();

  /// How [transaction] moves the account it is recorded against.
  ///
  /// A transfer debits its source exactly like an expense; what makes it not an
  /// expense is [destinationDelta] putting the money back somewhere else, and
  /// the reporting queries excluding it.
  static double sourceDelta(MoneyTransaction transaction) =>
      transaction.amount * transaction.type.balanceSign;

  /// How [transaction] moves the account it points at, if any.
  ///
  /// Only transfers have a destination, and they credit it by the full amount —
  /// so a transfer nets to zero across the two accounts and changes no net
  /// worth.
  static double destinationDelta(MoneyTransaction transaction) =>
      transaction.type.isTransfer && transaction.toAccountId != null
      ? transaction.amount
      : 0;

  /// The `CASE` that gives [sourceDelta] for a ledger row, generated from the
  /// same signs rather than written out a second time.
  ///
  /// [alias] is the transactions table's alias in the surrounding query.
  static String sourceDeltaSql({String alias = 't'}) {
    final arms = [
      for (final type in TransactionType.values)
        "WHEN '${type.name}' THEN ${type.balanceSign < 0 ? '-' : ''}"
            '$alias.${TransactionColumns.amount}',
    ].join('\n            ');

    return '''
        CASE $alias.${TransactionColumns.type}
            $arms
          END''';
  }
}
