import '../../core/database/db_tables.dart';
import '../../core/enums/payment_method.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/money_transaction.dart';
import 'row_reader.dart';

class TransactionMapper {
  const TransactionMapper._();

  /// Column aliases produced by the DAO's join, kept here so the mapper and
  /// the query cannot drift apart.
  static const String aliasCategoryName = 'category_name';
  static const String aliasCategoryIcon = 'category_icon';
  static const String aliasCategoryColor = 'category_color';
  static const String aliasAccountName = 'account_name';
  static const String aliasToAccountName = 'to_account_name';

  static MoneyTransaction fromRow(Map<String, Object?> row) => MoneyTransaction(
    id: row.readInt(TransactionColumns.id),
    accountId: row.readInt(TransactionColumns.accountId),
    toAccountId: row.readIntOrNull(TransactionColumns.toAccountId),
    type: TransactionType.fromName(row[TransactionColumns.type] as String?),
    amount: row.readDouble(TransactionColumns.amount),
    categoryId: row.readIntOrNull(TransactionColumns.categoryId),
    title: row.readString(TransactionColumns.title),
    description: row.readStringOrNull(TransactionColumns.description),
    transactionDate: row.readDate(TransactionColumns.transactionDate),
    paymentMethod: PaymentMethod.fromName(
      row[TransactionColumns.paymentMethod] as String?,
    ),
    note: row.readStringOrNull(TransactionColumns.note),
    recurringId: row.readIntOrNull(TransactionColumns.recurringId),
    createdAt: row.readDate(TransactionColumns.createdAt),
    updatedAt: row.readDate(TransactionColumns.updatedAt),
    categoryName: row.readStringOrNull(aliasCategoryName),
    categoryIcon: row.readStringOrNull(aliasCategoryIcon),
    categoryColor: row.readIntOrNull(aliasCategoryColor),
    accountName: row.readStringOrNull(aliasAccountName),
    toAccountName: row.readStringOrNull(aliasToAccountName),
  );

  static Map<String, Object?> toRow(
    MoneyTransaction transaction, {
    bool includeId = false,
  }) {
    return {
      if (includeId) TransactionColumns.id: transaction.id,
      TransactionColumns.accountId: transaction.accountId,
      TransactionColumns.toAccountId: transaction.toAccountId,
      TransactionColumns.type: transaction.type.name,
      TransactionColumns.amount: transaction.amount,
      TransactionColumns.categoryId: transaction.categoryId,
      TransactionColumns.title: transaction.title.trim(),
      TransactionColumns.description: transaction.description,
      TransactionColumns.transactionDate: AppDate.toDb(
        transaction.transactionDate,
      ),
      TransactionColumns.paymentMethod: transaction.paymentMethod?.name,
      TransactionColumns.note: transaction.note,
      TransactionColumns.recurringId: transaction.recurringId,
      TransactionColumns.createdAt: AppDate.toDb(transaction.createdAt),
      TransactionColumns.updatedAt: AppDate.toDb(transaction.updatedAt),
    };
  }
}
