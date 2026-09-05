import '../../core/database/db_tables.dart';
import '../../core/enums/payment_method.dart';
import '../../core/enums/recurrence_frequency.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/recurring_transaction.dart';
import 'row_reader.dart';

class RecurringMapper {
  const RecurringMapper._();

  static const String aliasCategoryName = 'category_name';
  static const String aliasCategoryIcon = 'category_icon';
  static const String aliasCategoryColor = 'category_color';
  static const String aliasAccountName = 'account_name';

  static RecurringTransaction fromRow(Map<String, Object?> row) =>
      RecurringTransaction(
        id: row.readInt(RecurringColumns.id),
        accountId: row.readInt(RecurringColumns.accountId),
        categoryId: row.readIntOrNull(RecurringColumns.categoryId),
        type: TransactionType.fromName(row[RecurringColumns.type] as String?),
        amount: row.readDouble(RecurringColumns.amount),
        title: row.readString(RecurringColumns.title),
        note: row.readStringOrNull(RecurringColumns.note),
        paymentMethod: PaymentMethod.fromName(
          row[RecurringColumns.paymentMethod] as String?,
        ),
        frequency: RecurrenceFrequency.fromName(
          row[RecurringColumns.frequency] as String?,
        ),
        intervalCount: row.readIntOrNull(RecurringColumns.intervalCount) ?? 1,
        startDate: row.readDate(RecurringColumns.startDate),
        endDate: row.readDateOrNull(RecurringColumns.endDate),
        nextRunDate: row.readDate(RecurringColumns.nextRunDate),
        lastRunDate: row.readDateOrNull(RecurringColumns.lastRunDate),
        isActive: row.readBool(RecurringColumns.isActive),
        autoPost: row.readBool(RecurringColumns.autoPost),
        createdAt: row.readDate(RecurringColumns.createdAt),
        updatedAt: row.readDate(RecurringColumns.updatedAt),
        categoryName: row.readStringOrNull(aliasCategoryName),
        categoryIcon: row.readStringOrNull(aliasCategoryIcon),
        categoryColor: row.readIntOrNull(aliasCategoryColor),
        accountName: row.readStringOrNull(aliasAccountName),
      );

  static Map<String, Object?> toRow(RecurringTransaction rule,
      {bool includeId = false}) {
    return {
      if (includeId) RecurringColumns.id: rule.id,
      RecurringColumns.accountId: rule.accountId,
      RecurringColumns.categoryId: rule.categoryId,
      RecurringColumns.type: rule.type.name,
      RecurringColumns.amount: rule.amount,
      RecurringColumns.title: rule.title.trim(),
      RecurringColumns.note: rule.note,
      RecurringColumns.paymentMethod: rule.paymentMethod?.name,
      RecurringColumns.frequency: rule.frequency.name,
      RecurringColumns.intervalCount: rule.intervalCount,
      RecurringColumns.startDate: AppDate.toDb(rule.startDate),
      RecurringColumns.endDate:
          rule.endDate == null ? null : AppDate.toDb(rule.endDate!),
      RecurringColumns.nextRunDate: AppDate.toDb(rule.nextRunDate),
      RecurringColumns.lastRunDate:
          rule.lastRunDate == null ? null : AppDate.toDb(rule.lastRunDate!),
      RecurringColumns.isActive: asDbBool(rule.isActive),
      RecurringColumns.autoPost: asDbBool(rule.autoPost),
      RecurringColumns.createdAt: AppDate.toDb(rule.createdAt),
      RecurringColumns.updatedAt: AppDate.toDb(rule.updatedAt),
    };
  }
}
