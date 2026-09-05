import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/financial_goal.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/goal_repository.dart';

/// One goal with its contribution ledger.
class GoalDetailController extends BaseController {
  GoalDetailController(this._repository, this._accounts, this._events);

  final GoalRepository _repository;
  final AccountRepository _accounts;
  final AppEvents _events;

  final Rxn<FinancialGoal> goal = Rxn<FinancialGoal>();
  final RxList<GoalContribution> contributions = <GoalContribution>[].obs;
  final RxList<Account> accounts = <Account>[].obs;
  final RxBool isSaving = false.obs;

  late final int goalId;

  @override
  void onInit() {
    super.onInit();
    goalId = Get.arguments is int ? Get.arguments as int : 0;
    load();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final goalFuture = _repository.getById(goalId);
    final contributionFuture = _repository.getContributions(goalId);
    final accountFuture = _accounts.getAccounts();

    final goalResult = await goalFuture;
    contributions.assignAll((await contributionFuture).dataOrNull ?? const []);
    accounts.assignAll((await accountFuture).dataOrNull ?? const []);

    goalResult.fold(
      onSuccess: (data) {
        goal.value = data;
        setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  /// [amount] is negative for a withdrawal.
  Future<bool> contribute({
    required double amount,
    Account? account,
    String? note,
  }) async {
    isSaving.value = true;
    final now = DateTime.now();

    final result = await _repository.addContribution(
      GoalContribution(
        id: 0,
        goalId: goalId,
        accountId: account?.id,
        amount: Validators.normalizeAmount(amount),
        contributedAt: now,
        note: note,
        createdAt: now,
      ),
    );
    isSaving.value = false;

    return result.fold(
      onSuccess: (updated) {
        AppSnackbar.success(
          updated.isAchieved && amount > 0
              ? 'Goal reached'
              : amount >= 0
              ? 'Contribution added'
              : 'Withdrawal recorded',
        );
        _events.emit(DataChange.goals);
        load(showLoader: false);
        return true;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return false;
      },
    );
  }

  Future<void> removeContribution(GoalContribution contribution) async {
    final result = await _repository.deleteContribution(contribution.id);
    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.goals);
        AppSnackbar.success('Entry removed');
        load(showLoader: false);
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }
}
