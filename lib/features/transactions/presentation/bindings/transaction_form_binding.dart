import 'package:get/get.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/events/app_events.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/transaction_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../controllers/transaction_form_controller.dart';

/// Dependencies for the full-page transaction form.
class TransactionFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => buildTransactionFormController());
  }
}

/// Builds the form controller from the global graph.
///
/// Shared with the quick-add sheet, which has no route of its own to attach a
/// binding to — without this the sheet would have to resolve five
/// dependencies inline, putting DI wiring inside a widget.
TransactionFormController buildTransactionFormController({
  TransactionFormArgs? seed,
}) => TransactionFormController(
  Get.find<TransactionRepository>(),
  Get.find<AccountRepository>(),
  Get.find<CategoryRepository>(),
  Get.find<SettingsController>(),
  Get.find<AppEvents>(),
  seed: seed,
);

/// Registers a controller for the quick-add sheet under [tag].
///
/// Tagged so a sheet opened while the full edit page is alive cannot replace
/// that page's controller.
TransactionFormController putQuickAddController({
  required String tag,
  required TransactionType type,
}) => Get.put(
  buildTransactionFormController(seed: TransactionFormArgs(type: type)),
  tag: tag,
);
