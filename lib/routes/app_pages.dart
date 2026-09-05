import 'package:get/get.dart';

import '../features/home/presentation/bindings/splash_binding.dart';
import '../features/home/presentation/pages/splash_page.dart';
import '../features/transaction/presentation/bindings/add_transaction_binding.dart';
import '../features/transaction/presentation/bindings/transaction_binding.dart';
import '../features/transaction/presentation/pages/add_transaction_page.dart';
import '../features/transaction/presentation/pages/transaction_list_page.dart';
import 'app_routes.dart';

/// The route table. Each page declares its own binding, so a feature's
/// dependencies are created on navigation and freed when it is popped.
class AppPages {
  const AppPages._();

  static const String initial = AppRoutes.splash;

  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.transactions,
      page: () => const TransactionListPage(),
      binding: TransactionBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.addTransaction,
      page: () => const AddTransactionPage(),
      binding: AddTransactionBinding(),
      transition: Transition.rightToLeft,
    ),
  ];

  /// Shown for unknown deep links.
  static final GetPage<dynamic> unknownRoute = GetPage(
    name: '/not-found',
    page: () => const SplashPage(),
  );
}
