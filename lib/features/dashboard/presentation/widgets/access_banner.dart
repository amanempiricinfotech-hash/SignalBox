import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notification_access_provider.dart';

/// Explains the state of Android notification access and offers a way to
/// enable it.
///
/// On platforms without a notification-listener API the banner says so plainly
/// instead of pretending the feature exists.
class AccessBanner extends ConsumerWidget {
  const AccessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final service = ref.watch(notificationAccessServiceProvider);
    final granted = ref.watch(notificationAccessGrantedProvider);

    if (granted.valueOrNull == true) return const SizedBox.shrink();

    final supported = service.isSupported;
    final color = supported
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              supported
                  ? Icons.notifications_active_outlined
                  : Icons.info_outline_rounded,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supported
                        ? 'Notification access is off'
                        : 'Live capture is Android-only',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    supported
                        ? 'SignalBox needs notification access to capture '
                              'notifications from your other apps. Until you '
                              'grant it, your inbox stays empty.'
                        : 'Only Android exposes other applications\' '
                              'notifications, so nothing can be captured on '
                              'this platform.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (supported) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () async {
                        await ref
                            .read(notificationAccessServiceProvider)
                            .openPermissionSettings();
                        ref.invalidate(notificationAccessGrantedProvider);
                      },
                      child: const Text('Open settings'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
