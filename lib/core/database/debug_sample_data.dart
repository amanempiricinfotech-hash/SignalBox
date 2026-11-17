import 'package:sqflite/sqflite.dart';

import '../../shared/models/notification_priority.dart';

/// Developer fixtures. **Never** inserted automatically.
///
/// SignalBox shows the user's own notifications and the applications actually
/// installed on their device. Nothing in this file runs unless a developer
/// explicitly triggers it from Settings in a debug build.
///
/// It exists for one reason: the issues catalogued in `docs/SEEDED_BUGS.md`
/// need a fixed dataset so that their reproduction steps give the same result
/// on every machine. Reproducing a bug against whatever happens to be in your
/// own notification shade is not repeatable.
///
/// The data is deliberately fictional and obviously so. It is never shipped to
/// a user: [generate] is only reachable behind `kDebugMode`.
class DebugSampleData {
  const DebugSampleData._();

  /// Fictional applications used only by the fixtures.
  static const List<(String packageName, String label)> fixtureApps = [
    ('com.example.chat', 'Fixture Chat'),
    ('com.example.mail', 'Fixture Mail'),
    ('com.example.team', 'Fixture Team'),
    ('com.example.social', 'Fixture Social'),
    ('com.example.bank', 'Fixture Bank'),
    ('com.example.food', 'Fixture Food'),
    ('com.example.system', 'Fixture System'),
  ];

  /// True when no fixture data is present.
  static Future<bool> isAbsent(Database db) async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM notification_items "
      "WHERE package_name LIKE 'com.example.%'",
    );
    return ((rows.first['c'] as int?) ?? 0) == 0;
  }

  /// Removes every fixture row, leaving real captured notifications alone.
  static Future<int> clear(Database db) async {
    await db.delete('app_sources', where: "package_name LIKE 'com.example.%'");
    await db.delete('rules', where: "match_value LIKE 'com.example.%'");
    return db.delete(
      'notification_items',
      where: "package_name LIKE 'com.example.%'",
    );
  }

  /// Inserts the fixture dataset. Returns the number of notifications added.
  ///
  /// Calling it twice is a no-op, so the dataset stays deterministic.
  static Future<int> generate(Database db) async {
    if (!await isAbsent(db)) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final appBatch = db.batch();
    for (final app in fixtureApps) {
      appBatch.insert('app_sources', {
        'package_name': app.$1,
        'app_label': app.$2,
        'is_muted': app.$1 == 'com.example.system' ? 1 : 0,
        'first_seen_at': today
            .subtract(const Duration(days: 45))
            .millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await appBatch.commit(noResult: true);

    final categories = await db.query('categories');
    int categoryId(String name) =>
        categories.firstWhere(
              (c) => c['name'] == name,
              orElse: () => categories.first,
            )['id']
            as int;

    var inserted = 0;
    final batch = db.batch();

    void add({
      required String package,
      required String title,
      required String body,
      required DateTime postedAt,
      NotificationPriority priority = NotificationPriority.normal,
      String? category,
      bool isRead = false,
      bool isArchived = false,
      DateTime? snoozeUntil,
    }) {
      inserted++;
      batch.insert('notification_items', {
        'package_name': package,
        'title': title,
        'body': body,
        'posted_at': postedAt.millisecondsSinceEpoch,
        'priority': priority.index,
        'category_id': category == null ? null : categoryId(category),
        'is_read': isRead ? 1 : 0,
        'is_archived': isArchived ? 1 : 0,
        'snooze_until': snoozeUntil?.millisecondsSinceEpoch,
        'native_key': 'fixture|$package|${postedAt.millisecondsSinceEpoch}',
      });
    }

    // --- Today --------------------------------------------------------------
    add(
      package: 'com.example.chat',
      title: 'Priya Sharma',
      body: 'Are we still meeting at 6? Let me know.',
      postedAt: today.add(const Duration(hours: 9, minutes: 12)),
      category: 'Messages',
      priority: NotificationPriority.high,
    );
    add(
      package: 'com.example.chat',
      title: 'Design Team (4 messages)',
      body: 'Rohan: pushed the updated inbox mockups to the shared folder',
      postedAt: today.add(const Duration(hours: 9, minutes: 40)),
      category: 'Messages',
    );
    add(
      package: 'com.example.bank',
      title: 'Payment received',
      body: 'Your UPI transaction of INR 2,400 was credited successfully.',
      postedAt: today.add(const Duration(hours: 10, minutes: 5)),
      category: 'Finance',
      priority: NotificationPriority.high,
    );
    add(
      package: 'com.example.mail',
      title: 'Invoice for November',
      body: 'Your subscription receipt is attached. Amount: INR 499.',
      postedAt: today.add(const Duration(hours: 10, minutes: 30)),
      category: 'Finance',
      isRead: true,
    );
    add(
      package: 'com.example.team',
      title: 'mentioned you in #release',
      body: 'Aman: can you review the changelog before the cut?',
      postedAt: today.add(const Duration(hours: 11, minutes: 15)),
      category: 'Messages',
      priority: NotificationPriority.high,
    );
    add(
      package: 'com.example.food',
      title: 'Flat 60% off on your next order',
      body: 'Use code SIGNAL60. Valid until midnight.',
      postedAt: today.add(const Duration(hours: 12)),
      category: 'Promotions',
      priority: NotificationPriority.low,
    );
    add(
      package: 'com.example.social',
      title: 'nikhil started following you',
      body: 'Tap to see their profile.',
      postedAt: today.add(const Duration(hours: 13, minutes: 20)),
      category: 'Social',
      priority: NotificationPriority.low,
      isRead: true,
    );

    // Identical timestamps: used to reproduce the unstable-sort issue.
    final tie = today.add(const Duration(hours: 14));
    add(
      package: 'com.example.team',
      title: 'Build passed',
      body: 'signalbox/main finished in 2m 14s.',
      postedAt: tie,
      category: 'System',
    );
    add(
      package: 'com.example.mail',
      title: 'Weekly report is ready',
      body: 'Your notification digest for this week is available.',
      postedAt: tie,
      category: 'System',
    );

    // Snoozed into the future: used to reproduce the snooze boundary issue.
    add(
      package: 'com.example.food',
      title: 'Rate your last order',
      body: 'How was your meal?',
      postedAt: today.add(const Duration(hours: 15)),
      category: 'Promotions',
      priority: NotificationPriority.low,
      snoozeUntil: now.add(const Duration(hours: 3)),
    );

    // --- The past month -----------------------------------------------------
    const bodies = <String>[
      'Tap to open the conversation.',
      'You have a new update waiting.',
      'Your order is out for delivery.',
      'Someone commented on your post.',
      'A debit of INR 320 was made from your account.',
      'Storage is almost full.',
      'Two new messages in this chat.',
    ];
    const titles = <String>[
      'New message',
      'Update available',
      'Order on the way',
      'New comment',
      'Transaction alert',
      'Low storage',
      'Unread messages',
    ];
    const categoryNames = <String>[
      'Messages',
      'System',
      'Promotions',
      'Social',
      'Finance',
      'System',
      'Messages',
    ];

    for (var day = 1; day <= 29; day++) {
      final perDay = 1 + (day % 3);
      for (var n = 0; n < perDay; n++) {
        final idx = (day + n) % fixtureApps.length;
        add(
          package: fixtureApps[idx].$1,
          title: titles[idx],
          body: bodies[idx],
          postedAt: today
              .subtract(Duration(days: day))
              .add(Duration(hours: 8 + n * 4, minutes: 10 * n + day % 50)),
          priority: NotificationPriority.fromIndex((day + n) % 3),
          category: categoryNames[idx],
          isRead: day > 3,
          isArchived: day > 20 && n == 0,
        );
      }
    }

    await batch.commit(noResult: true);

    // Two enabled rules target the same package on purpose: that is what makes
    // the application-totals issue reproducible.
    final ruleBatch = db.batch();
    void addRule({
      required String name,
      required int field,
      required String value,
      required int action,
      required String actionValue,
      bool enabled = true,
      int order = 0,
    }) {
      ruleBatch.insert('rules', {
        'name': name,
        'match_field': field,
        'match_value': value,
        'action_type': action,
        'action_value': actionValue,
        'is_enabled': enabled ? 1 : 0,
        'sort_order': order,
      });
    }

    addRule(
      name: 'Bank alerts are high priority',
      field: 0,
      value: 'com.example.bank',
      action: 0,
      actionValue: '${NotificationPriority.high.index}',
      order: 0,
    );
    addRule(
      name: 'Offers are low priority',
      field: 1,
      value: 'off on your next order',
      action: 0,
      actionValue: '${NotificationPriority.low.index}',
      order: 1,
    );
    addRule(
      name: 'Chat goes to Messages',
      field: 0,
      value: 'com.example.chat',
      action: 1,
      actionValue: 'Messages',
      order: 2,
    );
    addRule(
      name: 'Chat is high priority',
      field: 0,
      value: 'com.example.chat',
      action: 0,
      actionValue: '${NotificationPriority.high.index}',
      order: 3,
    );
    addRule(
      name: 'Mute fixture system app',
      field: 0,
      value: 'com.example.system',
      action: 2,
      actionValue: '',
      enabled: false,
      order: 4,
    );
    await ruleBatch.commit(noResult: true);

    return inserted;
  }
}
