import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/providers/notification_providers.dart';
import 'features/settings/presentation/providers/settings_providers.dart';

/// Root widget: wires the router and the user's theme preference together.
class SignalBoxApp extends ConsumerWidget {
  const SignalBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider).themeMode;

    // Starts the Android capture pipeline and keeps it alive for the lifetime
    // of the app. On platforms without a notification listener this is inert.
    ref.watch(notificationIngestProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
