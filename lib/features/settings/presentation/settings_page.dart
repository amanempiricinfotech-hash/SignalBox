import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/debug_sample_data.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/section_header.dart';
import '../../applications/presentation/providers/application_providers.dart';
import '../../notifications/presentation/providers/notification_providers.dart';
import '../../statistics/presentation/providers/statistics_providers.dart';
import 'providers/settings_providers.dart';

/// Appearance, privacy and data-management preferences.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const List<int> _retentionOptions = [7, 30, 90, 180, 0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionHeader(title: 'Appearance'),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (value) =>
                  controller.setThemeMode(value ?? ThemeMode.system),
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(switch (mode) {
                        ThemeMode.system => 'Follow system',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Inbox'),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Group inbox by application'),
                  subtitle: const Text(
                    'Not implemented yet - the inbox still groups by day.',
                  ),
                  value: settings.groupByApp,
                  onChanged: controller.setGroupByApp,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.rule_rounded),
                  title: const Text('Notification rules'),
                  subtitle: const Text('Automate priority and categories'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.rules),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_rounded),
                  title: const Text('Rescan installed applications'),
                  subtitle: const Text(
                    'Refreshes the app list from this device',
                  ),
                  onTap: () => _rescanApps(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.label_outline_rounded),
                  title: const Text('Categories'),
                  subtitle: const Text('Buckets used to group notifications'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.categories),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Privacy'),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Hide notification previews'),
                  subtitle: const Text(
                    'Masks message bodies in lists so they cannot be read '
                    'over your shoulder.',
                  ),
                  value: settings.hidePreviewContent,
                  onChanged: controller.setHidePreviewContent,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Daily summary notification'),
                  subtitle: const Text(
                    'Not implemented yet - scheduling is not wired up.',
                  ),
                  value: settings.dailySummaryEnabled,
                  onChanged: controller.setDailySummaryEnabled,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_delete_outlined),
                  title: const Text('Keep history for'),
                  subtitle: Text(_retentionLabel(settings.retentionDays)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickRetention(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Export history to CSV'),
                  subtitle: const Text('Not implemented yet'),
                  onTap: () => _notImplemented(context, 'CSV export'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup and restore'),
                  subtitle: const Text('Not implemented yet'),
                  onTap: () => _notImplemented(context, 'Backup and restore'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Delete all notifications',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text('Clears the local history immediately'),
                  onTap: () => _confirmDeleteAll(context, ref),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SectionHeader(title: 'Developer'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: const Text('Load issue fixtures'),
                    subtitle: const Text(
                      'Inserts the fictional dataset the catalogued issues are '
                      'reproduced against. Debug builds only.',
                    ),
                    onTap: () => _loadFixtures(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('Remove issue fixtures'),
                    subtitle: const Text(
                      'Deletes only the fixture rows. Captured notifications '
                      'are left alone.',
                    ),
                    onTap: () => _clearFixtures(context, ref),
                  ),
                ],
              ),
            ),
          ],
          const SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('${AppConstants.appName} 0.1.0'),
                  subtitle: Text(
                    'An open-source learning project. It ships with known '
                    'bugs and unfinished features on purpose - see the '
                    'repository issues.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_rounded),
                  title: const Text('Local-first storage'),
                  subtitle: Text(
                    'Everything lives in ${AppConstants.databaseFileName} on '
                    'this device. SignalBox has no backend and no account.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _retentionLabel(int days) =>
      days == 0 ? 'Forever' : '$days days';

  Future<void> _pickRetention(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).retentionDays;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final days in _retentionOptions)
              ListTile(
                title: Text(_retentionLabel(days)),
                trailing: days == current
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(days),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(settingsProvider.notifier).setRetentionDays(selected);
    }
  }

  Future<void> _rescanApps(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await ref.read(appSyncControllerProvider).syncFromDevice();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Application list is up to date'
                : 'Found $added new application${added == 1 ? '' : 's'}',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not read apps: $error')),
      );
    }
  }

  Future<void> _loadFixtures(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final inserted = await DebugSampleData.generate(ref.read(databaseProvider));
    _refreshEverything(ref);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          inserted == 0
              ? 'Fixtures are already loaded'
              : 'Inserted $inserted fixture notifications',
        ),
      ),
    );
  }

  Future<void> _clearFixtures(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final removed = await DebugSampleData.clear(ref.read(databaseProvider));
    _refreshEverything(ref);
    messenger.showSnackBar(
      SnackBar(content: Text('Removed $removed fixture notifications')),
    );
  }

  void _refreshEverything(WidgetRef ref) {
    ref.invalidate(inboxProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(appSummariesProvider);
    ref.invalidate(appLabelsProvider);
    ref.invalidate(statisticsProvider);
    ref.invalidate(snoozedNotificationsProvider);
  }

  void _notImplemented(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is not implemented yet.'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all notifications?'),
        content: const Text(
          'This permanently removes every captured notification from this '
          'device. Applications, categories and rules are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(notificationRepositoryProvider).deleteAll();
    ref.invalidate(inboxProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(appSummariesProvider);
    ref.invalidate(statisticsProvider);
    ref.invalidate(snoozedNotificationsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications deleted')),
      );
    }
  }
}
