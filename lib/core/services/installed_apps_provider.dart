import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/installed_app.dart';
import 'installed_apps_service.dart';

final installedAppsServiceProvider = Provider<InstalledAppsService>(
  (ref) => InstalledAppsService(),
);

/// The applications installed on this device, read from the package manager.
///
/// Empty on platforms without a package manager, which the Applications screen
/// reports honestly instead of showing placeholder entries.
final installedAppsProvider = FutureProvider<List<InstalledApp>>(
  (ref) => ref.watch(installedAppsServiceProvider).installedApps(),
);

/// A single application's launcher icon.
///
/// Kept alive once loaded so that scrolling a long list does not re-decode the
/// same icon repeatedly.
final appIconProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  packageName,
) async {
  final icon = await ref
      .watch(installedAppsServiceProvider)
      .appIcon(packageName);
  if (icon != null) ref.keepAlive();
  return icon;
});
