import '../../core/database/db_tables.dart';
import '../../core/enums/goal_status.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/financial_goal.dart';
import 'row_reader.dart';

class GoalMapper {
  const GoalMapper._();

  static FinancialGoal fromRow(Map<String, Object?> row) => FinancialGoal(
        id: row.readInt(GoalColumns.id),
        name: row.readString(GoalColumns.name),
        targetAmount: row.readDouble(GoalColumns.targetAmount),
        currentAmount: row.readDouble(GoalColumns.currentAmount),
        targetDate: row.readDateOrNull(GoalColumns.targetDate),
        icon: row.readStringOrNull(GoalColumns.icon),
        color: row.readIntOrNull(GoalColumns.color),
        status: GoalStatus.fromName(row[GoalColumns.status] as String?),
        note: row.readStringOrNull(GoalColumns.note),
        createdAt: row.readDate(GoalColumns.createdAt),
        updatedAt: row.readDate(GoalColumns.updatedAt),
      );

  static Map<String, Object?> toRow(FinancialGoal goal,
      {bool includeId = false}) {
    return {
      if (includeId) GoalColumns.id: goal.id,
      GoalColumns.name: goal.name.trim(),
      GoalColumns.targetAmount: goal.targetAmount,
      GoalColumns.currentAmount: goal.currentAmount,
      GoalColumns.targetDate:
          goal.targetDate == null ? null : AppDate.toDb(goal.targetDate!),
      GoalColumns.icon: goal.icon,
      GoalColumns.color: goal.color,
      GoalColumns.status: goal.status.name,
      GoalColumns.note: goal.note,
      GoalColumns.createdAt: AppDate.toDb(goal.createdAt),
      GoalColumns.updatedAt: AppDate.toDb(goal.updatedAt),
    };
  }
}

class GoalContributionMapper {
  const GoalContributionMapper._();

  static const String aliasAccountName = 'account_name';

  static GoalContribution fromRow(Map<String, Object?> row) => GoalContribution(
        id: row.readInt(GoalContributionColumns.id),
        goalId: row.readInt(GoalContributionColumns.goalId),
        accountId: row.readIntOrNull(GoalContributionColumns.accountId),
        amount: row.readDouble(GoalContributionColumns.amount),
        contributedAt: row.readDate(GoalContributionColumns.contributedAt),
        note: row.readStringOrNull(GoalContributionColumns.note),
        createdAt: row.readDate(GoalContributionColumns.createdAt),
        accountName: row.readStringOrNull(aliasAccountName),
      );

  static Map<String, Object?> toRow(GoalContribution contribution,
      {bool includeId = false}) {
    return {
      if (includeId) GoalContributionColumns.id: contribution.id,
      GoalContributionColumns.goalId: contribution.goalId,
      GoalContributionColumns.accountId: contribution.accountId,
      GoalContributionColumns.amount: contribution.amount,
      GoalContributionColumns.contributedAt:
          AppDate.toDb(contribution.contributedAt),
      GoalContributionColumns.note: contribution.note,
      GoalContributionColumns.createdAt: AppDate.toDb(contribution.createdAt),
    };
  }
}
