import '../../core/utils/result.dart';
import '../entities/financial_goal.dart';

abstract class GoalRepository {
  Future<Result<List<FinancialGoal>>> getGoals({bool activeOnly = false});
  Future<Result<FinancialGoal>> getById(int id);
  Future<Result<FinancialGoal>> create(FinancialGoal goal);
  Future<Result<FinancialGoal>> update(FinancialGoal goal);
  Future<Result<void>> delete(int id);

  Future<Result<List<GoalContribution>>> getContributions(int goalId);

  /// Records a contribution and rolls `current_amount` forward atomically,
  /// marking the goal achieved once the target is met.
  Future<Result<FinancialGoal>> addContribution(GoalContribution contribution);
  Future<Result<FinancialGoal>> deleteContribution(int contributionId);
}
