import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/enums/recurrence_frequency.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/recurring_transaction.dart';
import '../../../../domain/repositories/recurring_repository.dart';
import '../../../../domain/services/recurring_service.dart';

class RecurringController extends BaseController {
  RecurringController(this._repository, this._service, this._events);

  final RecurringRepository _repository;
  final RecurringService _service;
  final AppEvents _events;

  final RxList<RecurringTransaction> rules = <RecurringTransaction>[].obs;
  final RxBool isPosting = false.obs;

  List<RecurringTransaction> get dueRules =>
      rules.where((rule) => rule.isDue && rule.isActive).toList();

  double get monthlyOutflow => rules
      .where((rule) => rule.isActive && rule.type.isExpense)
      .fold(0, (sum, rule) => sum + _monthlyEquivalent(rule));

  double get monthlyInflow => rules
      .where((rule) => rule.isActive && rule.type.isIncome)
      .fold(0, (sum, rule) => sum + _monthlyEquivalent(rule));

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final result = await _repository.getAll();

    result.fold(
      onSuccess: (data) {
        rules.assignAll(data);
        data.isEmpty ? setEmpty('No recurring transactions') : setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  /// Posts every rule that is due now, rather than waiting for the next launch.
  Future<void> postDueNow() async {
    isPosting.value = true;
    final report = await _service.runDue();
    isPosting.value = false;

    if (report.hasChanges) {
      // Posting a schedule writes real transactions.
      _events.emit(DataChange.transactions);
      AppSnackbar.success(report.summary);
      await load(showLoader: false);
    } else {
      AppSnackbar.info('Nothing is due right now');
    }
  }

  Future<void> setActive(RecurringTransaction rule, bool active) async {
    final result = await _repository.setActive(rule.id, active);
    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.recurring);
        AppSnackbar.success(active ? 'Schedule resumed' : 'Schedule paused');
        load(showLoader: false);
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }

  Future<void> delete(RecurringTransaction rule) async {
    final result = await _repository.delete(rule.id);
    result.fold(
      onSuccess: (_) {
        rules.removeWhere((item) => item.id == rule.id);
        if (rules.isEmpty) setEmpty('No recurring transactions');
        _events.emit(DataChange.recurring);
        AppSnackbar.success('Schedule deleted');
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }

  /// Normalises each frequency to a per-month figure so schedules of different
  /// cadences can be summed into one commitment total.
  static double _monthlyEquivalent(RecurringTransaction rule) {
    final perInterval = rule.amount / rule.intervalCount;
    return switch (rule.frequency) {
      RecurrenceFrequency.daily => perInterval * 30,
      RecurrenceFrequency.weekly => perInterval * 4.345,
      RecurrenceFrequency.biweekly => perInterval * 2.172,
      RecurrenceFrequency.monthly => perInterval,
      RecurrenceFrequency.quarterly => perInterval / 3,
      RecurrenceFrequency.yearly => perInterval / 12,
    };
  }
}
