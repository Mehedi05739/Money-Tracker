import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/controllers/settings_controller.dart';
import 'routes/app_pages.dart';

class MoneyTrackerApp extends StatelessWidget {
  const MoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Settings are loaded during startup, so the first frame already has the
    // user's theme rather than flashing the default.
    final settings = Get.find<SettingsController>();

    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode.value,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      unknownRoute: AppPages.unknownRoute,
      defaultTransition: Transition.cupertino,
      builder: (context, child) {
        // Clamp text scaling: financial figures must stay readable, but an
        // unbounded scale factor breaks amount columns and chart labels.
        final scale = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.4);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
