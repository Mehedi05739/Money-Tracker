import '../../core/database/db_tables.dart';
import '../../core/enums/account_type.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/account.dart';
import 'row_reader.dart';

class AccountMapper {
  const AccountMapper._();

  static Account fromRow(Map<String, Object?> row) => Account(
        id: row.readInt(AccountColumns.id),
        name: row.readString(AccountColumns.name),
        type: AccountType.fromName(row[AccountColumns.type] as String?),
        openingBalance: row.readDouble(AccountColumns.openingBalance),
        currentBalance: row.readDouble(AccountColumns.currentBalance),
        currency: row.readString(AccountColumns.currency),
        icon: row.readStringOrNull(AccountColumns.icon),
        color: row.readIntOrNull(AccountColumns.color),
        isArchived: row.readBool(AccountColumns.isArchived),
        sortOrder: row.readIntOrNull(AccountColumns.sortOrder) ?? 0,
        createdAt: row.readDate(AccountColumns.createdAt),
        updatedAt: row.readDate(AccountColumns.updatedAt),
      );

  /// [includeId] stays false on insert so SQLite assigns the autoincrement id.
  static Map<String, Object?> toRow(Account account, {bool includeId = false}) {
    return {
      if (includeId) AccountColumns.id: account.id,
      AccountColumns.name: account.name.trim(),
      AccountColumns.type: account.type.name,
      AccountColumns.openingBalance: account.openingBalance,
      AccountColumns.currentBalance: account.currentBalance,
      AccountColumns.currency: account.currency,
      AccountColumns.icon: account.icon,
      AccountColumns.color: account.color,
      AccountColumns.isArchived: asDbBool(account.isArchived),
      AccountColumns.sortOrder: account.sortOrder,
      AccountColumns.createdAt: AppDate.toDb(account.createdAt),
      AccountColumns.updatedAt: AppDate.toDb(account.updatedAt),
    };
  }
}
