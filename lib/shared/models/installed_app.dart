/// An application that is actually installed on this device.
///
/// This is read from the Android package manager at runtime. SignalBox has no
/// built-in list of applications.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.appLabel,
    required this.isSystemApp,
  });

  final String packageName;
  final String appLabel;

  /// True for apps shipped with the system image rather than installed by the
  /// user. Useful for filtering a long list down to what the user recognises.
  final bool isSystemApp;

  factory InstalledApp.fromMap(Map<Object?, Object?> map) => InstalledApp(
    packageName: (map['packageName'] as String?) ?? '',
    appLabel: (map['appLabel'] as String?) ?? '',
    isSystemApp: (map['isSystemApp'] as bool?) ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is InstalledApp && other.packageName == packageName;

  @override
  int get hashCode => packageName.hashCode;
}
