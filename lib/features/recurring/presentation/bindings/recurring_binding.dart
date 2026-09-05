import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/recurring_repository.dart';
import '../../../../domain/services/recurring_service.dart';
import '../controllers/recurring_controller.dart';
import '../controllers/recurring_form_controller.dart';

class RecurringBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => RecurringController(
        Get.find<RecurringRepository>(),
        Get.find<RecurringService>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class RecurringFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => RecurringFormController(
        Get.find<RecurringRepository>(),
        Get.find<AccountRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}
