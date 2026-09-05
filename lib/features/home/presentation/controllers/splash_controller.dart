import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../routes/app_routes.dart';

/// Entry point for start-up work: session restore, remote config, migrations.
/// Decides the first real route once that finishes.
class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(AppConstants.splashDelay);

    // Replace with a real session check, e.g.
    // final loggedIn = Get.find<StorageService>().getString(StorageKeys.accessToken) != null;
    Get.offAllNamed(AppRoutes.transactions);
  }
}
