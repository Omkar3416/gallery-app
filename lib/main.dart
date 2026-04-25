import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gallery_app/services/isar/isar_service.dart';
import 'package:gallery_app/services/media_indexer/media_indexer.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_settings.dart';
import 'services/aws/guardrails/budget_guard.dart';
import 'features/ai/tagging/tagging_service.dart';
import 'package:gallery_app/core/routing/app_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await IsarService().init();
  await AppSettings().init();
  await BudgetGuard().init();

  Future.microtask(() => MediaIndexer().startFast());
  Future.microtask(() async {
    final n = await IsarService().purgeTrashedOlderThanDays(30);
    if (n > 0) {}
  });
  Future.microtask(() => TaggingService().tagUntagged(batchSize: 300));

  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppSettings().changes,
      builder: (_, __, ___) {
        final s = AppSettings();
        return MaterialApp.router(
          title: 'Gallery App',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: AppTheme.light(s.seedColor),
          darkTheme: AppTheme.dark(s.seedColor),
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}