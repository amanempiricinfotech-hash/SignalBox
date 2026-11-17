import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:signalbox/shared/models/notification_category.dart';
import 'package:signalbox/shared/models/notification_item.dart';
import 'package:signalbox/shared/models/notification_priority.dart';

void main() {
  NotificationItem build({
    String title = 'Payment received',
    String body = 'INR 2,400 was credited to your account.',
    bool isRead = false,
    NotificationPriority priority = NotificationPriority.high,
    DateTime? snoozeUntil,
    bool isArchived = false,
  }) {
    return NotificationItem(
      id: 1,
      packageName: 'com.hdfcbank.payzapp',
      title: title,
      body: body,
      postedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      priority: priority,
      isRead: isRead,
      isArchived: isArchived,
      snoozeUntil: snoozeUntil,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    NotificationItem item, {
    bool hidePreview = false,
    NotificationCategory? category,
    VoidCallback? onTap,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: NotificationTile(
              item: item,
              appLabel: 'HDFC Bank',
              category: category,
              hidePreview: hidePreview,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the app label, title and body', (tester) async {
    await pump(tester, build());

    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('Payment received'), findsOneWidget);
    expect(
      find.text('INR 2,400 was credited to your account.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the priority label', (tester) async {
    await pump(tester, build(priority: NotificationPriority.high));
    expect(find.text('High'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder for an empty title', (tester) async {
    await pump(tester, build(title: ''));
    expect(find.text('(no title)'), findsOneWidget);
  });

  testWidgets('masks the body when previews are hidden', (tester) async {
    await pump(tester, build(), hidePreview: true);

    expect(find.text('INR 2,400 was credited to your account.'), findsNothing);
    expect(find.text('•' * 24), findsOneWidget);
  });

  testWidgets('renders the category chip when a category is set', (
    tester,
  ) async {
    await pump(
      tester,
      build(),
      category: const NotificationCategory(
        id: 3,
        name: 'Finance',
        colorValue: 0xFF2E9E5B,
        isSystem: true,
      ),
    );
    expect(find.text('Finance'), findsOneWidget);
  });

  testWidgets('marks a snoozed notification', (tester) async {
    await pump(
      tester,
      build(snoozeUntil: DateTime.now().add(const Duration(hours: 2))),
    );
    expect(find.text('Snoozed'), findsOneWidget);
  });

  testWidgets('marks an archived notification', (tester) async {
    await pump(tester, build(isArchived: true));
    expect(find.text('Archived'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var taps = 0;
    await pump(tester, build(), onTap: () => taps++);

    await tester.tap(find.text('Payment received'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('exposes an accessible summary', (tester) async {
    await pump(tester, build());

    final semantics = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Payment received from HDFC Bank')),
    );
    expect(semantics, isNotNull);
  });
}
