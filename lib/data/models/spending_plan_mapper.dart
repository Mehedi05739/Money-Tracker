import '../../core/database/db_tables.dart';
import '../../core/enums/plan_status.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/spending_plan.dart';
import 'row_reader.dart';

class SpendingPlanMapper {
  const SpendingPlanMapper._();

  static SpendingPlan fromRow(Map<String, Object?> row) => SpendingPlan(
    id: row.readInt(SpendingPlanColumns.id),
    name: row.readString(SpendingPlanColumns.name),
    totalLimit: row.readDouble(SpendingPlanColumns.totalLimit),
    startDate: row.readDate(SpendingPlanColumns.startDate),
    endDate: row.readDate(SpendingPlanColumns.endDate),
    status: PlanStatus.fromName(row[SpendingPlanColumns.status] as String?),
    note: row.readStringOrNull(SpendingPlanColumns.note),
    createdAt: row.readDate(SpendingPlanColumns.createdAt),
    updatedAt: row.readDate(SpendingPlanColumns.updatedAt),
  );

  static Map<String, Object?> toRow(
    SpendingPlan plan, {
    bool includeId = false,
  }) {
    return {
      if (includeId) SpendingPlanColumns.id: plan.id,
      SpendingPlanColumns.name: plan.name.trim(),
      SpendingPlanColumns.totalLimit: plan.totalLimit,
      SpendingPlanColumns.startDate: AppDate.toDb(plan.startDate),
      SpendingPlanColumns.endDate: AppDate.toDb(plan.endDate),
      SpendingPlanColumns.status: plan.status.name,
      SpendingPlanColumns.note: plan.note,
      SpendingPlanColumns.createdAt: AppDate.toDb(plan.createdAt),
      SpendingPlanColumns.updatedAt: AppDate.toDb(plan.updatedAt),
    };
  }
}

class SpendingPlanItemMapper {
  const SpendingPlanItemMapper._();

  static const String aliasCategoryName = 'category_name';
  static const String aliasCategoryIcon = 'category_icon';
  static const String aliasCategoryColor = 'category_color';

  static SpendingPlanItem fromRow(Map<String, Object?> row) => SpendingPlanItem(
    id: row.readInt(SpendingPlanItemColumns.id),
    planId: row.readInt(SpendingPlanItemColumns.planId),
    categoryId: row.readIntOrNull(SpendingPlanItemColumns.categoryId),
    plannedAmount: row.readDouble(SpendingPlanItemColumns.plannedAmount),
    note: row.readStringOrNull(SpendingPlanItemColumns.note),
    createdAt: row.readDate(SpendingPlanItemColumns.createdAt),
    updatedAt: row.readDate(SpendingPlanItemColumns.updatedAt),
    categoryName: row.readStringOrNull(aliasCategoryName),
    categoryIcon: row.readStringOrNull(aliasCategoryIcon),
    categoryColor: row.readIntOrNull(aliasCategoryColor),
  );

  static Map<String, Object?> toRow(
    SpendingPlanItem item, {
    bool includeId = false,
  }) {
    return {
      if (includeId) SpendingPlanItemColumns.id: item.id,
      SpendingPlanItemColumns.planId: item.planId,
      SpendingPlanItemColumns.categoryId: item.categoryId,
      SpendingPlanItemColumns.plannedAmount: item.plannedAmount,
      SpendingPlanItemColumns.note: item.note,
      SpendingPlanItemColumns.createdAt: AppDate.toDb(item.createdAt),
      SpendingPlanItemColumns.updatedAt: AppDate.toDb(item.updatedAt),
    };
  }
}
