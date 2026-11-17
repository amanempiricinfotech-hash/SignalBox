import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/core/services/notification_access_service.dart';
import 'package:signalbox/features/applications/data/application_repository.dart';
import 'package:signalbox/features/notifications/data/notification_ingest_service.dart';
import 'package:signalbox/features/notifications/data/notification_repository.dart';
import 'package:signalbox/shared/models/notification_priority.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabase);

  late Database db;
  late NotificationRepository notifications;
  late ApplicationRepository applications;
  late NotificationIngestService service;

  setUp(() async {
    db = await openTestDatabase();
    notifications = NotificationRepository(db);
    applications = ApplicationRepository(db);
    service = NotificationIngestService(
      access: NotificationAccessService(),
      notifications: notifications,
      applications: applications,
    );
  });

  tearDown(() async {
    await service.stop();
    await db.close();
  });

  IncomingNotification incoming({
    String packageName = 'com.example.chat',
    String appLabel = 'Chat',
    String title = 'Priya Sharma',
    String body = 'Are we still meeting at 6?',
    DateTime? postedAt,
    String? key = 'key-1',
    int importance = 0,
  }) => IncomingNotification(
    packageName: packageName,
    appLabel: appLabel,
    title: title,
    body: body,
    postedAt: postedAt ?? DateTime(2026, 3, 12, 9, 30),
    nativeKey: key,
    androidImportance: importance,
  );

  group('storing', () {
    test('a captured notification is persisted', () async {
      await service.store(incoming());

      final stored = await notifications.all();
      expect(stored, hasLength(1));
      expect(stored.single.title, 'Priya Sharma');
      expect(stored.single.packageName, 'com.example.chat');
      expect(stored.single.isRead, isFalse);
    });

    test('the originating application is registered', () async {
      await service.store(incoming());

      final app = await applications.byPackage('com.example.chat');
      expect(app, isNotNull);
      expect(app!.appLabel, 'Chat');
      expect(app.isMuted, isFalse);
    });

    test('an app that notifies twice is registered once', () async {
      await service.store(incoming(key: 'a'));
      await service.store(
        incoming(key: 'b', postedAt: DateTime(2026, 3, 12, 10)),
      );

      expect(await applications.all(), hasLength(1));
      expect(await notifications.count(), 2);
    });

    test('a missing label falls back to the package name', () async {
      await service.store(incoming(appLabel: ''));

      final app = await applications.byPackage('com.example.chat');
      expect(app!.appLabel, 'com.example.chat');
    });

    test('the native key is kept for de-duplication', () async {
      await service.store(incoming(key: 'abc'));
      expect((await notifications.all()).single.nativeKey, 'abc');
    });
  });

  group('rejecting', () {
    test('a notification with neither title nor body is dropped', () async {
      await service.store(incoming(title: '', body: ''));
      expect(await notifications.count(), 0);
    });

    test('a notification with no package is dropped', () async {
      await service.store(incoming(packageName: ''));
      expect(await notifications.count(), 0);
    });

    test('a title with no body is still captured', () async {
      await service.store(incoming(body: ''));
      expect(await notifications.count(), 1);
    });
  });

  group('de-duplication', () {
    test('the same key at the same time is stored once', () async {
      await service.store(incoming(key: 'dup'));
      await service.store(incoming(key: 'dup'));

      expect(await notifications.count(), 1);
    });

    test('the same key at a later time is a new notification', () async {
      await service.store(incoming(key: 'dup'));
      await service.store(
        incoming(key: 'dup', postedAt: DateTime(2026, 3, 12, 11)),
      );

      expect(await notifications.count(), 2);
    });

    test('a null key never de-duplicates', () async {
      await service.store(incoming(key: null));
      await service.store(incoming(key: null));

      expect(await notifications.count(), 2);
    });
  });

  group('priority mapping', () {
    test('Android MAX and HIGH become high priority', () {
      expect(
        NotificationIngestService.priorityFor(2),
        NotificationPriority.high,
      );
      expect(
        NotificationIngestService.priorityFor(1),
        NotificationPriority.high,
      );
    });

    test('Android DEFAULT becomes normal priority', () {
      expect(
        NotificationIngestService.priorityFor(0),
        NotificationPriority.normal,
      );
    });

    test('Android LOW and MIN become low priority', () {
      expect(
        NotificationIngestService.priorityFor(-1),
        NotificationPriority.low,
      );
      expect(
        NotificationIngestService.priorityFor(-2),
        NotificationPriority.low,
      );
    });

    test('the mapped priority is persisted', () async {
      await service.store(incoming(importance: 2));
      expect(
        (await notifications.all()).single.priority,
        NotificationPriority.high,
      );
    });
  });

  group('lifecycle', () {
    test('the service is not running until it is started', () {
      expect(service.isRunning, isFalse);
    });

    test('stopping an unstarted service is safe', () async {
      await service.stop();
      expect(service.isRunning, isFalse);
    });
  });
}
