import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/events/app_events.dart';
import '../core/services/currency_formatter.dart';
import '../data/local/daos/account_dao.dart';
import '../data/local/daos/analytics_dao.dart';
import '../data/local/daos/budget_dao.dart';
import '../data/local/daos/category_dao.dart';
import '../data/local/daos/goal_dao.dart';
import '../data/local/daos/recurring_dao.dart';
import '../data/local/daos/settings_dao.dart';
import '../data/local/daos/spending_plan_dao.dart';
import '../data/local/daos/transaction_dao.dart';
import '../data/repositories/account_repository_impl.dart';
import '../data/repositories/analytics_repository_impl.dart';
import '../data/repositories/budget_repository_impl.dart';
import '../data/repositories/category_repository_impl.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../data/repositories/goal_repository_impl.dart';
import '../data/repositories/recurring_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../data/repositories/spending_plan_repository_impl.dart';
import '../data/repositories/transaction_repository_impl.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/analytics_repository.dart';
import '../domain/repositories/budget_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/repositories/goal_repository.dart';
import '../domain/repositories/recurring_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/spending_plan_repository.dart';
import '../domain/repositories/transaction_repository.dart';
import '../domain/services/recurring_service.dart';
import '../features/settings/presentation/controllers/settings_controller.dart';

/// Application-wide graph, built once before `runApp`.
///
/// Repositories are permanent singletons rather than per-route: the dashboard,
/// reports and budgets all read the same data, and rebuilding a DAO per
/// navigation would be pure overhead. Controllers stay feature-scoped in their
/// own `Bindings`.
class DependencyInjection {
  const DependencyInjection._();

  static Future<void> init() async {
    final database = AppDatabase(fileName: AppConstants.databaseFile);
    await database.open();
    Get.put<AppDatabase>(database, permanent: true);

    _registerDaos(database);
    _registerRepositories();
    await _registerServices();
  }

  static void _registerDaos(AppDatabase database) {
    final db = database.db;
    Get
      ..put(AccountDao(db), permanent: true)
      ..put(CategoryDao(db), permanent: true)
      ..put(TransactionDao(db), permanent: true)
      ..put(BudgetDao(db), permanent: true)
      ..put(SpendingPlanDao(db), permanent: true)
      ..put(GoalDao(db), permanent: true)
      ..put(RecurringDao(db), permanent: true)
      ..put(AnalyticsDao(db), permanent: true)
      ..put(SettingsDao(db), permanent: true);
  }

  static void _registerRepositories() {
    Get
      ..put<AccountRepository>(
        AccountRepositoryImpl(Get.find<AccountDao>()),
        permanent: true,
      )
      ..put<CategoryRepository>(
        CategoryRepositoryImpl(Get.find<CategoryDao>()),
        permanent: true,
      )
      ..put<TransactionRepository>(
        TransactionRepositoryImpl(Get.find<TransactionDao>()),
        permanent: true,
      )
      ..put<BudgetRepository>(
        BudgetRepositoryImpl(Get.find<BudgetDao>()),
        permanent: true,
      )
      ..put<SpendingPlanRepository>(
        SpendingPlanRepositoryImpl(Get.find<SpendingPlanDao>()),
        permanent: true,
      )
      ..put<GoalRepository>(
        GoalRepositoryImpl(Get.find<GoalDao>()),
        permanent: true,
      )
      ..put<RecurringRepository>(
        RecurringRepositoryImpl(Get.find<RecurringDao>()),
        permanent: true,
      )
      ..put<AnalyticsRepository>(
        AnalyticsRepositoryImpl(
          Get.find<AnalyticsDao>(),
          Get.find<AccountDao>(),
        ),
        permanent: true,
      )
      ..put<SettingsRepository>(
        SettingsRepositoryImpl(Get.find<SettingsDao>()),
        permanent: true,
      )
      // Composes the feature repositories the dashboard reads from, so its
      // controller depends on one thing instead of five.
      ..put<DashboardRepository>(
        DashboardRepositoryImpl(
          analytics: Get.find<AnalyticsRepository>(),
          transactions: Get.find<TransactionRepository>(),
          budgets: Get.find<BudgetRepository>(),
          plans: Get.find<SpendingPlanRepository>(),
          goals: Get.find<GoalRepository>(),
          accountsRepository: Get.find<AccountRepository>(),
        ),
        permanent: true,
      );
  }

  static Future<void> _registerServices() async {
    Get
      ..put(AppEvents(), permanent: true)
      ..put(CurrencyFormatter(), permanent: true);

    Get.put(RecurringService(Get.find<RecurringRepository>()), permanent: true);

    // Loaded before the first frame so the theme and currency symbol are
    // correct on the very first paint.
    final settings = Get.put(
      SettingsController(
        Get.find<SettingsRepository>(),
        Get.find<AccountRepository>(),
        Get.find<CurrencyFormatter>(),
      ),
      permanent: true,
    );
    await settings.load();
  }
}
