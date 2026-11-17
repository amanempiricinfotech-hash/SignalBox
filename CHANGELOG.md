# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **SignalBox no longer ships sample data.** The demo inbox that was inserted on
  first launch is gone, along with the hard-coded list of applications
  (WhatsApp, Gmail, Slack and the rest). A fresh install is empty and fills up
  with the user's own notifications.

### Added

- **Installed applications are read from the device.** `InstalledAppsService`
  and the Kotlin `InstalledAppsReader` enumerate launchable packages through the
  package manager, with labels and launcher icons. The manifest declares a
  `<queries>` launcher intent rather than requesting the restricted
  `QUERY_ALL_PACKAGES` permission.
- **Real launcher icons** in `AppAvatar`, falling back to the monogram while
  loading or when an app is no longer installed.
- **Applications screen has two views:** *With notifications* and *All apps*,
  the latter listing everything installed so an app can be muted before it ever
  notifies, with a system-app filter and a rescan action.
- **Notifications are now actually captured.** `NotificationIngestService`
  subscribes to the platform stream, registers the originating app, maps
  Android's priority hint and stores the row, de-duplicating on
  `(native_key, posted_at)`.
- `DefaultCategories`, replacing the category half of the old seeder.
- `DebugSampleData`: the fictional fixture dataset, reachable only from
  **Settings > Developer** in a debug build, so the catalogued issues stay
  reproducible on every machine.
- `ApplicationRepository.syncInstalled`, which refreshes labels while preserving
  the user's mute flags.
- 23 further tests (147 total).

### Removed

- `SeedData` and its seven hard-coded applications, ~60 fictional notifications
  and five rules that were inserted automatically on first launch.

## [0.1.0] - 2026-11-17

First public release of the foundation. The `main` branch builds, launches,
analyzes clean and passes its test suite.

### Added

- Feature-first project structure with `data` / `domain` / `presentation` layers
- SQLite persistence through `sqflite` with a hand-written schema
  (`app_sources`, `categories`, `notification_items`, `rules`) at schema version 1
- Riverpod 2 state management using `Notifier` / `AsyncNotifier`, with the
  database and preferences injected through `ProviderScope` overrides
- go_router navigation with a five-destination bottom-navigation shell
- Light and dark Material 3 themes, following the system by default
- Android notification capture: a Kotlin `NotificationListenerService`, a
  buffering stream handler, and `MethodChannel` / `EventChannel` bridges
- Notification inbox with date grouping, search, filtering, pagination,
  swipe-to-archive, snooze, archive and delete
- Snoozed notifications screen with unsnooze
- Notification detail screen with priority and category editing
- Application-wise grouping with per-app totals, unread counts, last activity,
  rule counts and a mute switch
- Per-application notification history screen
- Categories screen listing the five seeded system categories with live counts
- Notification rules: create, edit, enable, disable, delete and reorder by sort order
- Statistics screen: volume per day, breakdowns by application, category and
  priority, daily average, busiest day, with range and application filters
- Dashboard with unread, captured, snoozed and daily-average cards, a seven-day
  chart, the most active applications, and a notification-access banner
- Settings: theme, inbox grouping preference, privacy masking, retention window,
  delete-all, and an honest about section
- Deterministic seed data: 7 applications, ~60 notifications across 30 days,
  5 system categories, 5 rules
- 124 tests covering extensions, filters, all five repositories, settings
  persistence and five widgets
- GitHub Actions CI: format check, analyzer, tests, and a debug APK build
- Documentation: README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, architecture,
  testing, seeded bugs, missing features, improvements and collaboration guides

### Known issues

This release deliberately contains **12 seeded bugs**, **10 unfinished
features** and **5 code-quality tasks**, all catalogued and all tracked as
issues. See [`docs/SEEDED_BUGS.md`](docs/SEEDED_BUGS.md),
[`docs/MISSING_FEATURES.md`](docs/MISSING_FEATURES.md) and
[`docs/IMPROVEMENTS.md`](docs/IMPROVEMENTS.md).

[Unreleased]: ../../compare/v0.1.0...HEAD
[0.1.0]: ../../releases/tag/v0.1.0
