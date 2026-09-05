import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../domain/repositories/budget_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../controllers/budget_form_controller.dart';
import '../controllers/budgets_controller.dart';

class BudgetsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => BudgetsController(
        Get.find<BudgetRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class BudgetFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => BudgetFormController(
        Get.find<BudgetRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}
