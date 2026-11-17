import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_x.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/installed_apps_provider.dart';
import '../../../shared/models/installed_app.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../domain/app_summary.dart';
import 'providers/application_providers.dart';

/// Which applications the screen is listing.
enum _AppsView { withNotifications, allInstalled }

/// Application-wise grouping.
///
/// Two views over the same device: the apps that have actually sent something,
/// and everything installed, so an app can be muted before it ever notifies.
/// Nothing here is hard-coded; the list comes from the package manager.
class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  _AppsView _view = _AppsView.withNotifications;
  bool _includeSystemApps = false;
  bool _isSyncing = false;

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    try {
      final added = await ref.read(appSyncControllerProvider).syncFromDevice();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Application list is up to date'
                : 'Found $added new application${added == 1 ? '' : 's'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not read apps: $error')));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        actions: [
          if (_view == _AppsView.allInstalled)
            IconButton(
              tooltip: _includeSystemApps
                  ? 'Hide system apps'
                  : 'Show system apps',
              onPressed: () =>
                  setState(() => _includeSystemApps = !_includeSystemApps),
              icon: Icon(
                _includeSystemApps
                    ? Icons.filter_alt_off_outlined
                    : Icons.filter_alt_outlined,
              ),
            ),
          IconButton(
            tooltip: 'Rescan installed apps',
            onPressed: _isSyncing ? null : _sync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<_AppsView>(
              segments: const [
                ButtonSegment(
                  value: _AppsView.withNotifications,
                  label: Text('With notifications'),
                ),
                ButtonSegment(
                  value: _AppsView.allInstalled,
                  label: Text('All apps'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) =>
                  setState(() => _view = selection.first),
            ),
          ),
          Expanded(
            child: _view == _AppsView.withNotifications
                ? const _ActiveAppsList()
                : _InstalledAppsList(includeSystemApps: _includeSystemApps),
          ),
        ],
      ),
    );
  }
}

/// Applications that have produced at least one notification.
class _ActiveAppsList extends ConsumerWidget {
  const _ActiveAppsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(appSummariesProvider);

    return summaries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(appSummariesProvider),
      ),
      data: (apps) {
        final active = apps.where((a) => a.total > 0).toList();
        if (active.isEmpty) {
          return const EmptyState(
            icon: Icons.apps_rounded,
            title: 'Nothing captured yet',
            message:
                'Applications appear here as soon as they post their first '
                'notification. Grant notification access on the Dashboard to '
                'start capturing.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(appSummariesProvider),
          child: ListView.separated(
            itemCount: active.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _AppTile(summary: active[index], ref: ref),
          ),
        );
      },
    );
  }
}

/// Everything installed on the device, whether it has notified or not.
class _InstalledAppsList extends ConsumerWidget {
  const _InstalledAppsList({required this.includeSystemApps});

  final bool includeSystemApps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedAppsProvider);
    final service = ref.watch(installedAppsServiceProvider);
    final summaries = ref.watch(appSummariesProvider).valueOrNull ?? const [];

    if (!service.isSupported) {
      return const EmptyState(
        icon: Icons.phonelink_off_rounded,
        title: 'Not available on this platform',
        message:
            'Reading the list of installed applications needs the Android '
            'package manager.',
      );
    }

    return installed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(installedAppsProvider),
      ),
      data: (apps) {
        final visible = includeSystemApps
            ? apps
            : apps.where((a) => !a.isSystemApp).toList();

        if (visible.isEmpty) {
          return EmptyState(
            icon: Icons.apps_outage_rounded,
            title: 'No applications found',
            message: includeSystemApps
                ? 'The package manager returned nothing.'
                : 'Only system apps were found. Use the filter in the app bar '
                      'to show them.',
          );
        }

        final muted = {
          for (final summary in summaries)
            if (summary.isMuted) summary.packageName,
        };
        final counts = {
          for (final summary in summaries) summary.packageName: summary.total,
        };

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(installedAppsProvider),
          child: ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final app = visible[index];
              final count = counts[app.packageName] ?? 0;
              return _InstalledAppTile(
                app: app,
                notificationCount: count,
                isMuted: muted.contains(app.packageName),
              );
            },
          ),
        );
      },
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.summary, required this.ref});

  final AppSummary summary;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AppAvatar(
        packageName: summary.packageName,
        label: summary.appLabel,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              summary.appLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (summary.isMuted) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.volume_off_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${summary.total} total'
        '${summary.hasUnread ? ' · ${summary.unread} unread' : ''}'
        '${summary.lastPostedAt == null ? '' : ' · ${summary.lastPostedAt!.relativeLabel}'}'
        '${summary.matchingRules > 0 ? ' · ${summary.matchingRules} rule${summary.matchingRules == 1 ? '' : 's'}' : ''}',
      ),
      trailing: Switch.adaptive(
        value: !summary.isMuted,
        onChanged: (enabled) => ref
            .read(appMuteControllerProvider)
            .setMuted(summary.packageName, !enabled),
      ),
      onTap: () => context.push(Routes.appDetail(summary.packageName)),
    );
  }
}

class _InstalledAppTile extends ConsumerWidget {
  const _InstalledAppTile({
    required this.app,
    required this.notificationCount,
    required this.isMuted,
  });

  final InstalledApp app;
  final int notificationCount;
  final bool isMuted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      leading: AppAvatar(packageName: app.packageName, label: app.appLabel),
      title: Text(
        app.appLabel,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        notificationCount > 0
            ? '${app.packageName} · $notificationCount captured'
            : app.packageName,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch.adaptive(
        value: !isMuted,
        onChanged: (enabled) async {
          // Register the app first: it may never have posted a notification.
          await ref
              .read(applicationRepositoryProvider)
              .upsert(packageName: app.packageName, appLabel: app.appLabel);
          await ref
              .read(appMuteControllerProvider)
              .setMuted(app.packageName, !enabled);
        },
      ),
      onTap: notificationCount == 0
          ? null
          : () => context.push(Routes.appDetail(app.packageName)),
    );
  }
}
