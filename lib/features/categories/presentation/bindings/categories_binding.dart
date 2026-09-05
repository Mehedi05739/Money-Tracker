import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../controllers/categories_controller.dart';
import '../controllers/category_form_controller.dart';

class CategoriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CategoriesController(
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class CategoryFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CategoryFormController(
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}
