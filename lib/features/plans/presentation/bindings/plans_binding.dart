import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/spending_plan_repository.dart';
import '../controllers/plan_detail_controller.dart';
import '../controllers/plan_form_controller.dart';

class PlanFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => PlanFormController(
        Get.find<SpendingPlanRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class PlanDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => PlanDetailController(
        Get.find<SpendingPlanRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}
