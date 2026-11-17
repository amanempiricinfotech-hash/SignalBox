# Testing

```bash
flutter test                                  # everything
flutter test test/features/notifications/     # one area
flutter test --coverage                       # with coverage
dart format --output=none --set-exit-if-changed .
flutter analyze
```

The three commands at the bottom are what CI runs. Run them before you push.

## Layout

```
test/
  helpers/test_database.dart   FFI setup + in-memory database
  core/                        extensions and enums (pure Dart)
  features/<feature>/          repository tests against real SQLite
  widgets/                     widget tests
```

## Database tests

Repository tests run against a real in-memory SQLite database with the
production schema, not a mock. The queries are the thing under test, so mocking
them would test nothing.

```dart
void main() {
  setUpAll(initTestDatabase);

  late Database db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() async => db.close());
}
```

`initTestDatabase` installs `databaseFactoryFfiNoIsolate`. The no-isolate factory
matters: `flutter_test` drives widget tests on a fake async clock, and the
default isolate-backed factory never completes under it, which shows up as
`pumpAndSettle timed out` together with a `database has been locked` warning.

Pass `fixtures: true` to `openTestDatabase` for the developer fixtures. Prefer
inserting exactly the rows a test needs: it is clearer in review and does not
break when the fixtures change.

## Widget tests

A screen needs the two start-up overrides. `test/widgets/inbox_page_test.dart`
is the template:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MaterialApp(home: InboxPage()),
  ),
);
await tester.pumpAndSettle();
```

Use `SharedPreferences.setMockInitialValues({})` in `setUp` before
`SharedPreferences.getInstance()`.

## What the current tests cover

| Area | File | Cases |
| --- | --- | --- |
| Date helpers | `test/core/date_time_x_test.dart` | 7 |
| String helpers | `test/core/string_x_test.dart` | 6 |
| Priority enum | `test/core/notification_priority_test.dart` | 4 |
| Notification filter | `test/features/notifications/notification_filter_test.dart` | 7 |
| Notification repository | `test/features/notifications/notification_repository_test.dart` | 24 |
| Notification ingestion | `test/features/notifications/notification_ingest_service_test.dart` | 17 |
| Application repository (incl. device sync) | `test/features/applications/application_repository_test.dart` | 16 |
| Category repository | `test/features/categories/category_repository_test.dart` | 10 |
| Rule repository | `test/features/rules/rule_repository_test.dart` | 9 |
| Statistics repository | `test/features/statistics/statistics_repository_test.dart` | 10 |
| Settings repository | `test/features/settings/settings_repository_test.dart` | 8 |
| Notification tile | `test/widgets/notification_tile_test.dart` | 9 |
| Inbox screen | `test/widgets/inbox_page_test.dart` | 8 |
| Empty state | `test/widgets/empty_state_test.dart` | 4 |
| Bar chart | `test/widgets/simple_bar_chart_test.dart` | 3 |
| Breakdown bar | `test/widgets/breakdown_bar_test.dart` | 4 |

**147 tests, all passing.**

## A deliberate gap

Every existing test asserts *correct* behaviour. None of them encodes one of the
seeded bugs, so you will never have to delete a passing test in order to fix one.

The flip side is that the seeded bugs are, by construction, in code paths that
are not yet covered. Each issue names the regression test to add. Adding it is
part of the fix, not an optional extra:

- a test that fails before your change and passes after it
- an assertion on the behaviour, not on the implementation

A pull request that fixes a bug without a regression test will be asked for one.
