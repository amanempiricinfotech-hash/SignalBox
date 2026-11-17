import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../shared/models/installed_app.dart';
import '../errors/failures.dart';

/// Reads the applications installed on this device over the platform channel.
///
/// Only Android exposes the package manager, so on every other platform the
/// list is empty and the UI says so rather than inventing entries.
class InstalledAppsService {
  InstalledAppsService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.signalbox/notification_access';

  final MethodChannel _channel;

  bool get isSupported => Platform.isAndroid;

  /// Every launchable application on the device, sorted by label.
  Future<List<InstalledApp>> installedApps() async {
    if (!isSupported) return const <InstalledApp>[];
    try {
      final raw = await _channel.invokeListMethod<Object?>('getInstalledApps');
      if (raw == null) return const <InstalledApp>[];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(InstalledApp.fromMap)
          .where((app) => app.packageName.isNotEmpty)
          .toList();
    } on PlatformException catch (e) {
      throw PlatformFailure(
        'Could not read the installed applications.',
        cause: e,
      );
    }
  }

  /// The user visible label for one package, or null when it cannot be
  /// resolved (for example because the app has been uninstalled).
  Future<String?> appLabel(String packageName) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('getAppLabel', {
        'packageName': packageName,
      });
    } on PlatformException {
      return null;
    }
  }

  /// The application's launcher icon as PNG bytes, or null when unavailable.
  Future<Uint8List?> appIcon(String packageName) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
    } on PlatformException {
      return null;
    }
  }
}
