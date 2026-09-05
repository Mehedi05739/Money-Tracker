import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:money_tracker/core/events/app_events.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/domain/entities/account.dart';
import 'package:money_tracker/domain/entities/analytics.dart';
import 'package:money_tracker/domain/entities/budget_status.dart';
import 'package:money_tracker/domain/entities/financial_goal.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/entities/spending_plan_progress.dart';
import 'package:money_tracker/core/services/currency_formatter.dart';
import 'package:money_tracker/domain/repositories/account_repository.dart';
import 'package:money_tracker/domain/repositories/dashboard_repository.dart';
import 'package:money_tracker/domain/repositories/settings_repository.dart';
import 'package:money_tracker/features/settings/presentation/controllers/settings_controller.dart';
import 'package:money_tracker/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// Counts which dashboard sections were re-queried.
class _CountingDashboardRepository implements DashboardRepository {
  int summary = 0;
  int recent = 0;
  int budgets = 0;
  int plan = 0;
  int goals = 0;
  int accountList = 0;
  int full = 0;

  void reset() =>
      summary = recent = budgets = plan = goals = accountList = full = 0;

  List<int> get counts => [summary, recent, budgets, plan, goals];

  @override
  Future<Result<DashboardData>> load(DateRange range, {int? accountId}) async {
    full++;
    return Result.success(
      DashboardData(
        summary: DashboardSummary.empty(range),
        recent: const [],
        budgets: const [],
        currentPlan: null,
        goals: const [],
        accounts: const [],
      ),
    );
  }

  @override
  Future<Result<DashboardSummary>> getSummary(
    DateRange range, {
    int? accountId,
  }) async {
    summary++;
    return Result.success(DashboardSummary.empty(range));
  }

  @override
  Future<Result<List<MoneyTransaction>>> getRecent({
    int limit = 5,
    int? accountId,
  }) async {
    recent++;
    return const Result.success([]);
  }

  @override
  Future<Result<List<Account>>> getAccounts() async {
    accountList++;
    return const Result.success([]);
  }

  @override
  Future<Result<List<BudgetStatus>>> getBudgetStatuses() async {
    budgets++;
    return const Result.success([]);
  }

  @override
  Future<Result<SpendingPlanProgress?>> getCurrentPlan() async {
    plan++;
    return const Result.success(null);
  }

  @override
  Future<Result<List<FinancialGoal>>> getActiveGoals() async {
    goals++;
    return const Result.success([]);
  }
}

/// Settings backed by nothing — the dashboard only reads the hidden-balance
/// flag from it.
class _StubSettingsRepository implements SettingsRepository {
  final Map<String, String> _values = {};

  @override
  Future<Result<Map<String, String>>> getAll() async =>
      Result.success(Map.of(_values));

  @override
  Future<Result<String?>> get(String key) async => Result.success(_values[key]);

  @override
  Future<Result<void>> set(String key, String value) async {
    _values[key] = value;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> remove(String key) async {
    _values.remove(key);
    return const Result.success(null);
  }
}

class _StubAccountRepository implements AccountRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _CountingDashboardRepository repository;
  late AppEvents events;
  late SettingsController settings;
  late DashboardController controller;

  setUp(() async {
    repository = _CountingDashboardRepository();
    events = AppEvents();
    settings = SettingsController(
      _StubSettingsRepository(),
      _StubAccountRepository(),
      CurrencyFormatter(),
    );
    controller = DashboardController(repository, events, settings);
    controller.onInit();
    // Let the initial load settle, then measure only what events cause.
    await Future<void>.delayed(Duration.zero);
    repository.reset();
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  Future<void> emit(DataChange change) async {
    events.emit(change);
    await Future<void>.delayed(Duration.zero);
  }

  test('the first load fetches every section in one call', () {
    // setUp already ran onInit.
    expect(repository.counts, [0, 0, 0, 0, 0]);
  });

  test(
    'a transaction change refreshes only what transactions affect',
    () async {
      await emit(DataChange.transactions);

      expect(repository.summary, 1);
      expect(repository.recent, 1);
      expect(
        repository.budgets,
        1,
        reason: 'budget spend comes from the ledger',
      );
      expect(repository.plan, 1, reason: 'plan progress comes from the ledger');
      expect(
        repository.goals,
        0,
        reason: 'goals do not depend on transactions',
      );
    },
  );

  test('a goal change refreshes goals and nothing else', () async {
    await emit(DataChange.goals);

    expect(repository.goals, 1);
    expect(repository.summary, 0);
    expect(repository.recent, 0);
    expect(repository.budgets, 0);
    expect(repository.plan, 0);
  });

  test('a budget change refreshes budgets and nothing else', () async {
    await emit(DataChange.budgets);

    expect(repository.budgets, 1);
    expect(
      [
        repository.summary,
        repository.recent,
        repository.plan,
        repository.goals,
      ],
      [0, 0, 0, 0],
    );
  });

  test('a plan change refreshes the plan and nothing else', () async {
    await emit(DataChange.plans);

    expect(repository.plan, 1);
    expect(
      [
        repository.summary,
        repository.recent,
        repository.budgets,
        repository.goals,
      ],
      [0, 0, 0, 0],
    );
  });

  test('an account change refreshes balances and the joined rows', () async {
    await emit(DataChange.accounts);

    expect(repository.summary, 1, reason: 'total balance changed');
    expect(repository.recent, 1, reason: 'account names are joined into rows');
    expect(repository.accountList, 1, reason: 'the selector list changed');
    expect([repository.budgets, repository.plan, repository.goals], [0, 0, 0]);
  });

  test('a recurring-schedule change refreshes nothing on its own', () async {
    await emit(DataChange.recurring);

    expect(repository.counts, [
      0,
      0,
      0,
      0,
      0,
    ], reason: 'posting a schedule emits transactions instead');
  });

  test('no section is ever re-queried through the full load path', () async {
    await emit(DataChange.transactions);
    await emit(DataChange.goals);

    expect(repository.full, 0, reason: 'events use targeted reloads');
  });

  test('the worker is disposed with the controller', () async {
    controller.onClose();
    await emit(DataChange.transactions);

    expect(repository.counts, [0, 0, 0, 0, 0]);

    // tearDown calls onClose again; disposing twice must not throw.
  });
}
