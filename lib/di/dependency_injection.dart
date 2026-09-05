import 'package:get/get.dart';

import '../core/network/api_client.dart';
import '../core/services/storage_service.dart';

/// App-wide singletons, created once before `runApp` and never disposed.
///
/// Feature-scoped dependencies belong in that feature's `Bindings`, not here.
class DependencyInjection {
  const DependencyInjection._();

  static Future<void> init() async {
    final storage = await Get.putAsync<StorageService>(
      () async {
        final service = InMemoryStorageService();
        await service.init();
        return service;
      },
      permanent: true,
    );

    Get.put<ApiClient>(ApiClient(storage), permanent: true);
  }
}
