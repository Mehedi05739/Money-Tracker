import 'package:get/get.dart';

import '../controllers/add_transaction_controller.dart';
import '../controllers/transaction_controller.dart';

/// The list route is already open when this one pushes, so its controller and
/// dependency graph are reused rather than rebuilt.
class AddTransactionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AddTransactionController(Get.find<TransactionController>()),
    );
  }
}
