# Architecture

SignalBox is a local-first Flutter application with a feature-first layout.
There is no backend, no account and no network call in the data path.

## Layout

```
lib/
  main.dart                 start-up: open SQLite, load preferences, inject them
  app.dart                  MaterialApp.router + theme wiring
  core/
    constants/              AppConstants, PrefKeys
    database/               schema, connection, default categories, databaseProvider
    errors/                 Failure hierarchy
    extensions/             DateTimeX, StringX
    router/                 go_router routes and the bottom-navigation shell
    services/               platform channels (notification access, installed apps), preferences
    theme/                  light and dark Material 3 themes
  features/<feature>/
    data/                   repositories: every SQL statement lives here
    domain/                 feature models and pure logic (filters, queries)
    presentation/           screens, widgets and Riverpod providers
  shared/
    models/                 models used by more than one feature
    widgets/                widgets used by more than one feature
```

Features: `dashboard`, `notifications`, `applications`, `categories`, `rules`,
`statistics`, `settings`.

A feature only reaches into another feature's `data` or `presentation/providers`
layer, never into its widgets. `shared/` must not depend on `features/`.

## Layers

**data** owns persistence. Repositories take an open `Database` and expose typed
methods. No widget builds SQL, and no repository knows about Riverpod.

**domain** holds models and pure functions. `NotificationFilter` and
`NotificationQuery` are the interesting pair: the filter is an immutable value
object, and the query builder turns it into a `WHERE` clause. Both the inbox and
the statistics screen use that one builder, so a filter means the same thing
everywhere.

**presentation** holds screens and providers. Providers are the only place that
coordinates repositories, caching and invalidation.

## State management

Riverpod, using the modern `Notifier` / `AsyncNotifier` API.

Two providers are injected at start-up rather than constructed lazily:

```dart
// lib/main.dart
ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    sharedPreferencesProvider.overrideWithValue(preferences),
  ],
  child: const SignalBoxApp(),
)
```

Both throw `UnimplementedError` if they are read without an override. That is
deliberate: it means every repository provider is synchronous, and it gives
tests a single seam. A test overrides `databaseProvider` with an in-memory
database and gets the whole app on throwaway data. See
`test/widgets/inbox_page_test.dart` for the pattern.

### Who owns what

| Provider | Owns |
| --- | --- |
| `inboxFilterProvider` | the active inbox filter |
| `inboxProvider` | the paged inbox list, rebuilt when the filter changes |
| `unreadCountProvider` | the unread badge |
| `filteredCountProvider` | the "N notifications" line above the list |
| `snoozedNotificationsProvider` | the Snoozed screen |
| `appSummariesProvider` | the per-application rollups |
| `categoriesProvider`, `categoriesByIdProvider`, `categoryCountsProvider` | categories and their counts |
| `rulesProvider` | the rule list |
| `statisticsProvider` | the statistics payload for the selected range |
| `settingsProvider` | user preferences, persisted on every write |

A write that changes data another provider derives from must invalidate that
provider. `InboxNotifier.archive` is the example to copy.

## Persistence

SQLite through `sqflite`, with hand-written SQL and no code generation. Four
tables: `app_sources`, `categories`, `notification_items`, `rules`.

Timestamps are stored as integer milliseconds since the Unix epoch and read back
as local `DateTime`. Enum values are stored as their `index`, so the order of
`NotificationPriority`, `RuleMatchField` and `RuleAction` must not change without
a migration.

`AppDatabase.schemaVersion` is 1. Schema changes need a bump and a branch in
`_onUpgrade`; see the index task in `docs/IMPROVEMENTS.md` for a worked example.

### Why not Drift

Drift was the first choice. On this toolchain (Flutter 3.38 / Dart 3.10) its
generator cannot run: `build_runner` 2.15 AOT-compiles its build script, and
`dart compile` refuses to do that when any package in the graph ships native
build hooks, which `sqlite3` does. Older `build_runner` versions will not resolve
against `drift_dev` 2.34. Rather than pin the whole toolchain around a code
generator, the data layer is hand-written SQL: one less build step for
contributors, and no generated files in review.

## Notification capture (Android)

```
other app posts a notification
  -> SignalBoxNotificationListenerService   (Kotlin, system-bound service)
  -> NotificationStreamHandler              (buffers while Dart is detached)
  -> EventChannel  com.signalbox/notification_stream
  -> NotificationAccessService.stream()     (Dart)
  -> IncomingNotification
```

Permission state and the system settings screen go over
`MethodChannel com.signalbox/notification_access`.

The listener and the Flutter engine have independent lifecycles, so
`NotificationStreamHandler` keeps a bounded buffer (100 events) and replays it
when Dart attaches.

Only Android can read other applications' notifications.
`NotificationAccessService.isSupported` is false everywhere else, the stream is
empty, and the dashboard banner says so rather than implying the feature exists.

## No sample data

SignalBox ships with **no** sample notifications and **no** built-in list of
applications. A fresh install is empty and stays empty until the user grants
notification access.

Two things fill it:

- **Captured notifications.** `NotificationIngestService` subscribes to the
  platform stream, registers the originating application and stores the row.
  It de-duplicates on `(native_key, posted_at)`, because Android re-posts a
  notification under the same key when it is updated.
- **Installed applications.** `InstalledAppsService` reads the package manager
  through the same method channel. `ApplicationRepository.syncInstalled`
  registers them, refreshing labels while preserving the user's mute flags.

The only rows written at database creation are the five system categories in
`DefaultCategories`. Those are application defaults, not sample data: a
notification cannot be filed without a bucket to file it in.

### Package visibility

Android 11 filters which packages an app can see. Rather than request the
restricted `QUERY_ALL_PACKAGES` permission, the manifest declares a `<queries>`
entry for the launcher intent. That covers every app a user would recognise and
needs no Play Store justification.

### Developer fixtures

`DebugSampleData` holds a fictional dataset (`com.example.*`, "Fixture Chat"
and friends). It is only reachable from **Settings > Developer** behind
`kDebugMode`, and never runs on its own.

It exists because the issues in `docs/SEEDED_BUGS.md` need reproduction steps
that give the same result on every machine, and "whatever happens to be in your
own notification shade" is not repeatable. `DebugSampleData.clear` removes only
the fixture rows and leaves real captured notifications alone.
