import 'package:flutter/material.dart';

import 'app.dart';
import 'di/dependency_injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DependencyInjection.init();
  runApp(const MoneyTrackerApp());
}
