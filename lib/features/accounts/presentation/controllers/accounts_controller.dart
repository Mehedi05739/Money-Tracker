import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/repositories/account_repository.dart';

class AccountsController extends BaseController {
  AccountsController(this._repository, this._events);

  final AccountRepository _repository;
  final AppEvents _events;

  final RxList<Account> accounts = <Account>[].obs;
  final RxBool showArchived = false.obs;
  final RxDouble totalBalance = 0.0.obs;

  Worker? _changeWorker;

  @override
  void onInit() {
    super.onInit();
    load();

    // The shell keeps this tab alive, so refresh when data changes elsewhere.
    _changeWorker =
        _events.listen(const [DataChange.accounts, DataChange.transactions], () => load(showLoader: false));
  }

  @override
  void onClose() {
    _changeWorker?.dispose();
    super.onClose();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final accountFuture =
        _repository.getAccounts(includeArchived: showArchived.value);
    final totalFuture = _repository.getTotalBalance();

    final accountResult = await accountFuture;
    totalBalance.value = (await totalFuture).dataOrNull ?? 0;

    accountResult.fold(
      onSuccess: (data) {
        accounts.assignAll(data);
        data.isEmpty ? setEmpty('No accounts yet') : setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  void toggleArchived() {
    showArchived.toggle();
    load(showLoader: false);
  }

  Future<void> setArchived(Account account, bool archived) async {
    final result = await _repository.setArchived(account.id, archived);
    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.accounts);
        AppSnackbar.success(archived ? 'Account archived' : 'Account restored');
        load(showLoader: false);
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }

  Future<void> delete(Account account) async {
    final result = await _repository.delete(account.id);
    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.accounts);
        AppSnackbar.success('Account deleted');
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
