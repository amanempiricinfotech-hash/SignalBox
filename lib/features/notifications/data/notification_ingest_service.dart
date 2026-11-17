import 'dart:async';

import '../../../core/services/notification_access_service.dart';
import '../../../shared/models/notification_item.dart';
import '../../../shared/models/notification_priority.dart';
import '../../applications/data/application_repository.dart';
import 'notification_repository.dart';

/// Persists notifications as the Android listener delivers them.
///
/// This is the only writer in the capture path: the platform side normalises a
/// notification, and this service registers the application and stores the row.
///
/// Rules are not applied here yet. The rule engine is a separate open task, and
/// pretending otherwise would hide that.
class NotificationIngestService {
  NotificationIngestService({
    required NotificationAccessService access,
    required NotificationRepository notifications,
    required ApplicationRepository applications,
    this.onBatchStored,
    Duration notifyAfter = const Duration(milliseconds: 600),
  }) : _access = access,
       _notifications = notifications,
       _applications = applications,
       _notifyAfter = notifyAfter;

  final NotificationAccessService _access;
  final NotificationRepository _notifications;
  final ApplicationRepository _applications;

  /// Called after a burst of notifications has been stored, so that the UI can
  /// refresh once rather than once per notification.
  final void Function()? onBatchStored;

  final Duration _notifyAfter;

  StreamSubscription<IncomingNotification>? _subscription;
  Timer? _notifyTimer;

  bool get isRunning => _subscription != null;

  /// Begins listening. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    _subscription = _access.stream().listen(
      store,
      onError: (_) {
        // A dropped platform event must never take the app down. The listener
        // reconnects on its own when the service is rebound.
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Stores a single incoming notification.
  ///
  /// Exposed so that it can be tested without a platform channel.
  Future<void> store(IncomingNotification incoming) async {
    if (incoming.packageName.isEmpty) return;
    if (incoming.title.isEmpty && incoming.body.isEmpty) return;

    await _applications.upsert(
      packageName: incoming.packageName,
      appLabel: incoming.appLabel.isEmpty
          ? incoming.packageName
          : incoming.appLabel,
    );

    if (await _notifications.existsByNativeKey(
      incoming.nativeKey,
      incoming.postedAt,
    )) {
      return;
    }

    await _notifications.insert(
      NotificationItem(
        id: 0,
        packageName: incoming.packageName,
        title: incoming.title,
        body: incoming.body,
        postedAt: incoming.postedAt,
        priority: priorityFor(incoming.androidImportance),
        nativeKey: incoming.nativeKey,
      ),
    );

    _scheduleNotify();
  }

  /// Maps an Android notification priority onto a SignalBox bucket.
  ///
  /// Android's legacy scale runs from -2 (MIN) to 2 (MAX), with 0 as DEFAULT.
  static NotificationPriority priorityFor(int androidImportance) {
    if (androidImportance > 0) return NotificationPriority.high;
    if (androidImportance < 0) return NotificationPriority.low;
    return NotificationPriority.normal;
  }

  /// Coalesces refreshes so that a burst of notifications triggers one rebuild.
  void _scheduleNotify() {
    if (onBatchStored == null) return;
    _notifyTimer?.cancel();
    _notifyTimer = Timer(_notifyAfter, () => onBatchStored?.call());
  }
}
