import '../../core/database/db_tables.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/category.dart';
import 'row_reader.dart';

class CategoryMapper {
  const CategoryMapper._();

  static Category fromRow(Map<String, Object?> row) => Category(
    id: row.readInt(CategoryColumns.id),
    name: row.readString(CategoryColumns.name),
    type: TransactionType.fromName(row[CategoryColumns.type] as String?),
    icon: row.readStringOrNull(CategoryColumns.icon),
    color: row.readIntOrNull(CategoryColumns.color),
    isDefault: row.readBool(CategoryColumns.isDefault),
    isArchived: row.readBool(CategoryColumns.isArchived),
    createdAt: row.readDate(CategoryColumns.createdAt),
  );

  static Map<String, Object?> toRow(
    Category category, {
    bool includeId = false,
  }) {
    return {
      if (includeId) CategoryColumns.id: category.id,
      CategoryColumns.name: category.name.trim(),
      CategoryColumns.type: category.type.name,
      CategoryColumns.icon: category.icon,
      CategoryColumns.color: category.color,
      CategoryColumns.isDefault: asDbBool(category.isDefault),
      CategoryColumns.isArchived: asDbBool(category.isArchived),
      CategoryColumns.createdAt: AppDate.toDb(category.createdAt),
    };
  }
}
