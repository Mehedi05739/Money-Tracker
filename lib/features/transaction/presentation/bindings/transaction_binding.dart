import 'package:get/get.dart';

import '../../../../core/services/storage_service.dart';
import '../../data/datasources/fake_transaction_remote_datasource.dart';
import '../../data/datasources/transaction_local_datasource.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/add_transaction.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/get_transactions.dart';
import '../controllers/transaction_controller.dart';

/// Wires one feature's dependency graph, created when its route opens and
/// disposed when it closes. `lazyPut` means nothing is built until used.
class TransactionBinding extends Bindings {
  @override
  void dependencies() {
    // Data sources.
    // Swap for `TransactionRemoteDataSourceImpl(Get.find<ApiClient>())`
    // once the backend is available.
    Get.lazyPut<TransactionRemoteDataSource>(
      () => FakeTransactionRemoteDataSource(),
    );
    Get.lazyPut<TransactionLocalDataSource>(
      () => TransactionLocalDataSourceImpl(Get.find<StorageService>()),
    );

    // Repository.
    Get.lazyPut<TransactionRepository>(
      () => TransactionRepositoryImpl(
        remote: Get.find<TransactionRemoteDataSource>(),
        local: Get.find<TransactionLocalDataSource>(),
      ),
    );

    // Use cases.
    Get.lazyPut(() => GetTransactions(Get.find<TransactionRepository>()));
    Get.lazyPut(() => AddTransaction(Get.find<TransactionRepository>()));
    Get.lazyPut(() => DeleteTransaction(Get.find<TransactionRepository>()));

    // Controller.
    Get.lazyPut(
      () => TransactionController(
        Get.find<GetTransactions>(),
        Get.find<AddTransaction>(),
        Get.find<DeleteTransaction>(),
      ),
    );
  }
}
