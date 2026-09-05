import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../controllers/account_form_controller.dart';
import '../controllers/accounts_controller.dart';

class AccountsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AccountsController(
        Get.find<AccountRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class AccountFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AccountFormController(
        Get.find<AccountRepository>(),
        Get.find<SettingsController>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}
