import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/goal_repository.dart';
import '../controllers/goal_detail_controller.dart';
import '../controllers/goal_form_controller.dart';
import '../controllers/goals_controller.dart';

class GoalsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => GoalsController(Get.find<GoalRepository>(), Get.find<AppEvents>()),
    );
  }
}

class GoalFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () =>
          GoalFormController(Get.find<GoalRepository>(), Get.find<AppEvents>()),
    );
  }
}

class GoalDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => GoalDetailController(
        Get.find<GoalRepository>(),
        Get.find<AccountRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}
