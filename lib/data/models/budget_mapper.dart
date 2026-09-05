import '../../core/database/db_tables.dart';
import '../../core/enums/budget_period.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/budget.dart';
import 'row_reader.dart';

class BudgetMapper {
  const BudgetMapper._();

  static const String aliasCategoryName = 'category_name';
  static const String aliasCategoryIcon = 'category_icon';
  static const String aliasCategoryColor = 'category_color';

  static Budget fromRow(Map<String, Object?> row) => Budget(
    id: row.readInt(BudgetColumns.id),
    categoryId: row.readIntOrNull(BudgetColumns.categoryId),
    amount: row.readDouble(BudgetColumns.amount),
    period: BudgetPeriod.fromName(row[BudgetColumns.period] as String?),
    startDate: row.readDate(BudgetColumns.startDate),
    endDate: row.readDate(BudgetColumns.endDate),
    alertPercentage: row.readIntOrNull(BudgetColumns.alertPercentage) ?? 80,
    isActive: row.readBool(BudgetColumns.isActive),
    createdAt: row.readDate(BudgetColumns.createdAt),
    updatedAt: row.readDate(BudgetColumns.updatedAt),
    categoryName: row.readStringOrNull(aliasCategoryName),
    categoryIcon: row.readStringOrNull(aliasCategoryIcon),
    categoryColor: row.readIntOrNull(aliasCategoryColor),
  );

  static Map<String, Object?> toRow(Budget budget, {bool includeId = false}) {
    return {
      if (includeId) BudgetColumns.id: budget.id,
      BudgetColumns.categoryId: budget.categoryId,
      BudgetColumns.amount: budget.amount,
      BudgetColumns.period: budget.period.name,
      BudgetColumns.startDate: AppDate.toDb(budget.startDate),
      BudgetColumns.endDate: AppDate.toDb(budget.endDate),
      BudgetColumns.alertPercentage: budget.alertPercentage,
      BudgetColumns.isActive: asDbBool(budget.isActive),
      BudgetColumns.createdAt: AppDate.toDb(budget.createdAt),
      BudgetColumns.updatedAt: AppDate.toDb(budget.updatedAt),
    };
  }
}
