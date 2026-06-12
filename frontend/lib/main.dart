import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  // Ensure that Flutter engine context is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize high-performance offline cachers
  await Hive.initFlutter();

  // Pre-open required key-value and telemetry sync boxes
  await Hive.openBox('auth_box');
  await Hive.openBox('gps_box');
  await Hive.openBox('sos_box');

  runApp(
    const ProviderScope(
      child: FishermanSafetyApp(),
    ),
  );
}

class FishermanSafetyApp extends StatelessWidget {
  const FishermanSafetyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart Fisherman Safety',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
