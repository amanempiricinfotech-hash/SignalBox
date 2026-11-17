import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/features/applications/data/application_repository.dart';
import 'package:signalbox/features/notifications/data/notification_repository.dart';
import 'package:signalbox/shared/models/installed_app.dart';
import 'package:signalbox/shared/models/notification_item.dart';
import 'package:signalbox/shared/models/notification_priority.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabase);

  late Database db;
  late ApplicationRepository applications;
  late NotificationRepository notifications;

  setUp(() async {
    db = await openTestDatabase();
    applications = ApplicationRepository(db);
    notifications = NotificationRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> addNotification(
    String package, {
    bool isRead = false,
    DateTime? postedAt,
  }) {
    return notifications.insert(
      NotificationItem(
        id: 0,
        packageName: package,
        title: 'Title',
        body: 'Body',
        postedAt: postedAt ?? DateTime.now(),
        priority: NotificationPriority.normal,
        isRead: isRead,
      ),
    );
  }

  test('upsert registers an application once', () async {
    await applications.upsert(
      packageName: 'com.whatsapp',
      appLabel: 'WhatsApp',
    );
    await applications.upsert(
      packageName: 'com.whatsapp',
      appLabel: 'WhatsApp',
    );

    expect(await applications.all(), hasLength(1));
  });

  test('byPackage returns null for an unknown package', () async {
    expect(await applications.byPackage('com.nope'), isNull);
  });

  test('setMuted persists the mute flag', () async {
    await applications.upsert(
      packageName: 'com.whatsapp',
      appLabel: 'WhatsApp',
    );

    await applications.setMuted('com.whatsapp', true);
    expect((await applications.byPackage('com.whatsapp'))!.isMuted, isTrue);

    await applications.setMuted('com.whatsapp', false);
    expect((await applications.byPackage('com.whatsapp'))!.isMuted, isFalse);
  });

  test('all() sorts applications by label', () async {
    await applications.upsert(packageName: 'com.slack', appLabel: 'Slack');
    await applications.upsert(packageName: 'com.gm', appLabel: 'Gmail');

    final apps = await applications.all();
    expect(apps.map((a) => a.appLabel).toList(), ['Gmail', 'Slack']);
  });

  group('syncInstalled', () {
    const chat = InstalledApp(
      packageName: 'com.example.chat',
      appLabel: 'Chat',
      isSystemApp: false,
    );
    const mail = InstalledApp(
      packageName: 'com.example.mail',
      appLabel: 'Mail',
      isSystemApp: false,
    );

    test('registers applications read from the device', () async {
      final added = await applications.syncInstalled([chat, mail]);

      expect(added, 2);
      expect(await applications.all(), hasLength(2));
    });

    test('an empty device list changes nothing', () async {
      await applications.syncInstalled([chat]);
      final added = await applications.syncInstalled(const []);

      expect(added, 0);
      expect(await applications.all(), hasLength(1));
    });

    test('syncing twice does not duplicate applications', () async {
      await applications.syncInstalled([chat, mail]);
      final added = await applications.syncInstalled([chat, mail]);

      expect(added, 0);
      expect(await applications.all(), hasLength(2));
    });

    test('a renamed application has its label refreshed', () async {
      await applications.syncInstalled([chat]);
      await applications.syncInstalled([
        const InstalledApp(
          packageName: 'com.example.chat',
          appLabel: 'Chat Pro',
          isSystemApp: false,
        ),
      ]);

      expect(
        (await applications.byPackage('com.example.chat'))!.appLabel,
        'Chat Pro',
      );
    });

    test('syncing preserves the mute flag the user set', () async {
      await applications.syncInstalled([chat]);
      await applications.setMuted('com.example.chat', true);
      await applications.syncInstalled([chat]);

      expect(
        (await applications.byPackage('com.example.chat'))!.isMuted,
        isTrue,
      );
    });

    test('an uninstalled application keeps its captured history', () async {
      await applications.syncInstalled([chat, mail]);
      await addNotification('com.example.mail');

      // The device no longer reports Mail.
      await applications.syncInstalled([chat]);

      expect(await applications.byPackage('com.example.mail'), isNotNull);
      expect(await notifications.count(), 1);
    });
  });

  group('summaries', () {
    test('an application without notifications reports zero', () async {
      await applications.upsert(
        packageName: 'com.whatsapp',
        appLabel: 'WhatsApp',
      );

      final summaries = await applications.summaries();
      expect(summaries, hasLength(1));
      expect(summaries.single.total, 0);
      expect(summaries.single.unread, 0);
      expect(summaries.single.lastPostedAt, isNull);
      expect(summaries.single.hasUnread, isFalse);
    });

    test('totals and unread counts are per application', () async {
      await applications.upsert(
        packageName: 'com.whatsapp',
        appLabel: 'WhatsApp',
      );
      await applications.upsert(packageName: 'com.slack', appLabel: 'Slack');

      await addNotification('com.whatsapp');
      await addNotification('com.whatsapp', isRead: true);
      await addNotification('com.slack');

      final summaries = await applications.summaries();
      final whatsapp = summaries.firstWhere(
        (s) => s.packageName == 'com.whatsapp',
      );
      final slack = summaries.firstWhere((s) => s.packageName == 'com.slack');

      expect(whatsapp.total, 2);
      expect(whatsapp.unread, 1);
      expect(slack.total, 1);
      expect(slack.unread, 1);
    });

    test('lastPostedAt reports the newest notification', () async {
      await applications.upsert(
        packageName: 'com.whatsapp',
        appLabel: 'WhatsApp',
      );

      final older = DateTime(2026, 3, 10, 9);
      final newer = DateTime(2026, 3, 12, 9);
      await addNotification('com.whatsapp', postedAt: older);
      await addNotification('com.whatsapp', postedAt: newer);

      final summaries = await applications.summaries();
      expect(summaries.single.lastPostedAt, newer);
    });

    test('archived notifications are not counted', () async {
      await applications.upsert(
        packageName: 'com.whatsapp',
        appLabel: 'WhatsApp',
      );
      final id = await addNotification('com.whatsapp');
      await addNotification('com.whatsapp');
      await notifications.setArchived(id);

      final summaries = await applications.summaries();
      expect(summaries.single.total, 1);
    });

    test('matchingRules counts enabled package rules', () async {
      await applications.upsert(
        packageName: 'com.whatsapp',
        appLabel: 'WhatsApp',
      );
      await addNotification('com.whatsapp');

      await db.insert('rules', {
        'name': 'WhatsApp is high priority',
        'match_field': 0,
        'match_value': 'com.whatsapp',
        'action_type': 0,
        'action_value': '0',
        'is_enabled': 1,
        'sort_order': 0,
      });

      final summaries = await applications.summaries();
      expect(summaries.single.matchingRules, 1);
    });

    test('disabled rules are not counted', () async {
      await applications.upsert(
        packageName: 'com.whatsapp',
        appLabel: 'WhatsApp',
      );
      await addNotification('com.whatsapp');

      await db.insert('rules', {
        'name': 'Disabled rule',
        'match_field': 0,
        'match_value': 'com.whatsapp',
        'action_type': 0,
        'action_value': '0',
        'is_enabled': 0,
        'sort_order': 0,
      });

      final summaries = await applications.summaries();
      expect(summaries.single.matchingRules, 0);
    });
  });
}
