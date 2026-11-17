# Seeded bugs

SignalBox is a learning repository. The bugs listed here were introduced **on
purpose** so that contributors have realistic, reproducible defects to fix.

Every entry is a real defect in committed code, not a stub or a `TODO`. Each one
is reproducible from the seeded demo data with the steps given below, and each
has a corresponding GitHub issue.

Ground rules for this catalogue:

- The app still compiles, launches and passes `flutter analyze` and `flutter test`.
- No bug corrupts the database, weakens security or disables the test suite.
- No bug is undocumented. If you find a defect that is not listed here, it is a
  genuine bug: please open an issue for it.
- Existing tests assert correct behaviour only. None of them encode a seeded
  bug, so you will not have to delete a passing test to fix one. When you fix a
  bug, **add** the regression test named in its issue.

## Index

| ID | Bug | Area | Difficulty |
| --- | --- | --- | --- |
| `B1` | inbox search ignores notification body text | notifications / search | Beginner |
| `B2` | date range filter excludes the final selected day | notifications / filtering, statistics | Intermediate |
| `B3` | application totals double when two rules target the same app | applications / grouping | Intermediate |
| `B4` | unread counter does not refresh after deleting a notification | notifications / state management | Beginner |
| `B5` | snoozed notifications reappear before their snooze time | notifications / snooze | Intermediate |
| `B6` | no empty state when a search returns no results | notifications / UI | Beginner |
| `B7` | inbox pagination skips one notification per page | notifications / pagination | Intermediate |
| `B8` | statistics total ignores the active filters | statistics | Intermediate |
| `B9` | notifications with identical timestamps sort inconsistently | notifications / sorting | Intermediate |
| `B10` | retention setting is not restored after restart | settings / persistence | Beginner |
| `B11` | muting an application does not remove it from the inbox | applications / notifications | Intermediate |
| `B12` | "mark all as read" ignores the active filter | notifications | Intermediate |

---

## `B1` inbox search ignores notification body text

**Area:** notifications / search  
**Difficulty:** Beginner  
**Labels:** `bug`, `good first issue`, `beginner`, `priority: high`

**Likely files**

- `lib/features/notifications/domain/notification_query.dart`

### Problem

The inbox search box only matches the notification title. Any query that appears in the message body returns no results, so users cannot find a notification by what it said.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Launch the app and open the **Inbox** tab.
3. Confirm that the fixture notification titled `Payment received` is visible and that its body reads `Your UPI transaction of INR 2,400 was credited successfully.`
4. Type `UPI` into the search field.

### Expected behaviour

The `Payment received` notification is listed, because `UPI` appears in its body.

### Actual behaviour

No results are shown. The list is blank and the counter reads `0 notifications`.

### Acceptance criteria

- [ ] Searching matches text in the notification title **or** the body.
- [ ] Matching stays case insensitive.
- [ ] A query containing a SQL wildcard (`%` or `_`) is treated as literal text, not as a wildcard.
- [ ] An empty or whitespace-only query still returns every notification.

### Suggested regression tests

- `test/features/notifications/notification_repository_test.dart`: add a case asserting a body-only match is returned.
- Add a case asserting a query matching neither field returns nothing.
- Add a case asserting `%` in a query does not match everything.

### Where to look

`NotificationQuery.where` builds the clause `title LIKE ?`.

---

## `B2` date range filter excludes the final selected day

**Area:** notifications / filtering, statistics  
**Difficulty:** Intermediate  
**Labels:** `bug`, `help wanted`, `intermediate`, `priority: high`

**Likely files**

- `lib/features/notifications/domain/notification_query.dart`

### Problem

The upper bound of a date range is compared against midnight at the *start* of the chosen end date, so every notification posted on that final day is filtered out. The same builder powers the Statistics screen, so `Last 7 days` silently drops today as well.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Inbox** tab and tap the filter icon.
3. Under **Date range**, select a range that starts yesterday and ends today, then tap **Show results**.
4. Observe which notifications are listed.
5. Open the **Stats** tab with `Last 7 days` selected and look at the `Volume per day` chart.

### Expected behaviour

Notifications posted today are included in the filtered inbox, and today appears as a bar in the statistics chart.

### Actual behaviour

Everything posted today is missing from both screens. Only notifications up to midnight of the end date are counted.

### Acceptance criteria

- [ ] A range whose end date is today includes everything posted today.
- [ ] A single-day range (start == end) returns that whole day.
- [ ] The lower bound still includes everything from the start date's 00:00.
- [ ] The Statistics screen counts today when the selected range includes it.

### Suggested regression tests

- Add a repository test inserting a notification at 23:59 on the end date and assert it is returned.
- Add a test for a same-day range.
- Add a statistics test asserting today's notifications are counted by `Last 7 days`.

### Where to look

Compare the end bound against `endOfDay`, not `startOfDay`. `DateTimeX` already provides both.

---

## `B3` application totals double when two rules target the same app

**Area:** applications / grouping  
**Difficulty:** Intermediate  
**Labels:** `bug`, `help wanted`, `intermediate`, `priority: high`

**Likely files**

- `lib/features/applications/data/application_repository.dart`

### Problem

`ApplicationRepository.summaries()` joins `rules` in order to show how many rules target an app. The join multiplies notification rows, so every notification is counted once per matching rule. An app with two enabled package rules reports twice its real total.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Apps** tab.
3. Note the count shown for **Fixture Chat** (the fixtures ship two enabled rules that both target `com.example.chat`).
4. Tap Fixture Chat to open its detail screen and count the notifications actually listed.

### Expected behaviour

The total on the Applications row equals the number of notifications listed on the app's detail screen.

### Actual behaviour

The Applications row reports double the real total (and double the unread count). Apps with one rule or none are correct, which is why the problem looks intermittent.

### Acceptance criteria

- [ ] `total` and `unread` are independent of how many rules match the application.
- [ ] `matchingRules` still reports the number of enabled package rules.
- [ ] `lastPostedAt` stays correct.
- [ ] The query still returns applications that have no notifications at all, with a total of 0.

### Suggested regression tests

- Extend `test/features/applications/application_repository_test.dart` with a case that inserts two enabled rules for one package and asserts the total is unchanged.
- Assert `matchingRules` equals 2 in that same case.

### Where to look

Either count distinct notification ids, or compute the rule count in a separate subquery instead of a join.

---

## `B4` unread counter does not refresh after deleting a notification

**Area:** notifications / state management  
**Difficulty:** Beginner  
**Labels:** `bug`, `good first issue`, `beginner`, `priority: medium`

**Likely files**

- `lib/features/notifications/presentation/providers/notification_providers.dart`

### Problem

`InboxNotifier.delete` removes the row and updates the list, but never invalidates `unreadCountProvider`. The Dashboard and the inbox app bar keep showing the old unread total until something else happens to refresh it.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Dashboard** tab and note the number on the **Unread** card.
3. Switch to the **Inbox** tab, long-press an unread notification and choose **Delete**.
4. Go back to the **Dashboard** tab without pulling to refresh.

### Expected behaviour

The Unread card drops by one immediately after the deletion.

### Actual behaviour

The Unread card still shows the old value. Pulling to refresh corrects it.

### Acceptance criteria

- [ ] Deleting an unread notification updates the unread count everywhere it is shown.
- [ ] Deleting a notification that was already read leaves the count unchanged.
- [ ] `deleteMany` behaves the same way as `delete`.
- [ ] No extra database query is issued when nothing was deleted.

### Suggested regression tests

- Add a provider test that reads `unreadCountProvider`, deletes an unread notification through `inboxProvider`, and asserts the count decreases.
- Add the equivalent test for `deleteMany`.

### Where to look

Compare `delete` with `archive` in the same file; `archive` already does the right thing.

---

## `B5` snoozed notifications reappear before their snooze time

**Area:** notifications / snooze  
**Difficulty:** Intermediate  
**Labels:** `bug`, `help wanted`, `intermediate`, `priority: high`

**Likely files**

- `lib/features/notifications/domain/notification_query.dart`

### Problem

The snooze clause compares `snooze_until` against the *end of today* instead of the current time. Any snooze that expires later the same day is treated as already elapsed, so the notification is never actually hidden.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Inbox** tab.
3. Long-press any notification, choose **Snooze**, then choose **15 minutes**.
4. The row disappears from the list because the notifier removes it locally.
5. Pull down to refresh the inbox, or switch tabs and come back.

### Expected behaviour

The notification stays out of the inbox for 15 minutes and appears under **Snoozed** (the clock icon in the app bar) in the meantime.

### Actual behaviour

The notification is back in the inbox immediately after the refresh, while the Snoozed screen correctly still lists it as snoozed.

### Acceptance criteria

- [ ] A notification snoozed for any duration stays out of the inbox until its snooze time has passed.
- [ ] A notification whose snooze time has passed appears in the inbox again.
- [ ] Notifications that were never snoozed are unaffected.
- [ ] The Snoozed screen and the inbox agree on what is snoozed.

### Suggested regression tests

- Add a repository test that snoozes a notification by one hour and asserts `page()` does not return it.
- Add a test that snoozes by a negative duration (already expired) and asserts it *is* returned.
- Add a test asserting a snoozed notification appears in `snoozed()` and not in `all()` at the same time.

### Where to look

The clause is appended at the end of `NotificationQuery.where`. The bound should be `DateTime.now()`.

---

## `B6` no empty state when a search returns no results

**Area:** notifications / UI  
**Difficulty:** Beginner  
**Labels:** `bug`, `good first issue`, `beginner`, `priority: medium`

**Likely files**

- `lib/features/notifications/presentation/inbox_page.dart`

### Problem

The inbox only renders its empty state when the search query is empty. A search with no matches therefore shows a blank area with no explanation and no way to recover.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Inbox** tab.
3. Type `zzzzz` into the search field.

### Expected behaviour

A clear empty state explains that no notifications match the search, and offers a way to clear it.

### Actual behaviour

The list area is blank. Only the `0 notifications match your filters` line hints at what happened.

### Acceptance criteria

- [ ] An empty result set always shows an empty state.
- [ ] The wording distinguishes "nothing captured yet" from "nothing matches your search or filters".
- [ ] When filters or a search caused the empty result, the empty state offers an action that clears them.
- [ ] The empty state is reachable by a screen reader.

### Suggested regression tests

- Extend `test/widgets/inbox_page_test.dart` with a case that types a non-matching query and asserts `EmptyState` is present.
- Add a case asserting the clear action restores the full list.

### Where to look

See the `items.isEmpty && searchQuery.isEmpty` condition in `_InboxList.build`.

---

## `B7` inbox pagination skips one notification per page

**Area:** notifications / pagination  
**Difficulty:** Intermediate  
**Labels:** `bug`, `help wanted`, `intermediate`, `priority: high`

**Likely files**

- `lib/features/notifications/presentation/providers/notification_providers.dart`

### Problem

`InboxNotifier.loadMore` passes `current.items.length + 1` as the SQL offset. The `+ 1` skips exactly one notification at every page boundary, so records silently disappear from the inbox as the user scrolls.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Inbox** tab (the fixtures contain more than 60 notifications, and the page size is 20).
3. Note the 20th and 21st notifications by scrolling slowly.
4. Keep scrolling so the next page loads.
5. Compare the list against `SELECT title, posted_at FROM notification_items ORDER BY posted_at DESC` or against the per-app lists on the Apps tab.

### Expected behaviour

Scrolling through the whole inbox shows every notification exactly once; the number of rows matches the counter above the list.

### Actual behaviour

One notification is skipped at each page boundary, so the inbox shows fewer rows than the counter claims.

### Acceptance criteria

- [ ] Paging through the entire list yields every notification exactly once, in order.
- [ ] No notification is returned twice.
- [ ] `hasMore` becomes false exactly once, after the last page.
- [ ] Paging still works when the total is an exact multiple of the page size.

### Suggested regression tests

- Add a repository or notifier test that inserts 25 notifications, loads two pages and asserts the collected ids equal the ids from an unpaged query.
- Add a case where the total is exactly 20 and assert `hasMore` ends up false with no duplicate fetch.

### Where to look

A SQL `OFFSET` is the number of rows to skip, which is exactly the number of rows already loaded.

---

## `B8` statistics total ignores the active filters

**Area:** statistics  
**Difficulty:** Intermediate  
**Labels:** `bug`, `help wanted`, `intermediate`, `priority: medium`

**Likely files**

- `lib/features/statistics/data/statistics_repository.dart`

### Problem

`StatisticsRepository.load` computes `total` with a query that hard-codes `WHERE is_archived = 0` and drops the filter entirely, while every breakdown below it respects the filter. The headline number therefore contradicts the chart underneath it.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Stats** tab.
3. Select `Last 7 days`, then pick a single application such as **Fixture Team** from the second chip row.
4. Compare the **Total notifications** card with the sum of the bars in **Volume per day** and with the per-application breakdown.

### Expected behaviour

The Total notifications card equals the sum of the filtered breakdowns.

### Actual behaviour

The total stays at the all-time, all-apps count and does not change when the range or the application filter changes.

### Acceptance criteria

- [ ] `total` respects the range, the application filter and every other field of `NotificationFilter`.
- [ ] `total` equals the sum of `perDay` counts for the same filter.
- [ ] `total` equals the sum of `perPriority` counts for the same filter.
- [ ] An empty result set reports a total of 0 rather than the table size.

### Suggested regression tests

- Add a statistics test asserting `total` changes when a package filter is applied.
- Add a test asserting `total` equals the summed `perDay` counts.

### Where to look

The filtered clause is already built in `load()` as `where`/`args`; the total query just does not use it.

---

## `B9` notifications with identical timestamps sort inconsistently

**Area:** notifications / sorting  
**Difficulty:** Intermediate  
**Labels:** `bug`, `help wanted`, `intermediate`, `priority: medium`

**Likely files**

- `lib/features/notifications/data/notification_repository.dart`

### Problem

`page()` orders only by `posted_at DESC`, with no tiebreaker, while `all()` and `forPackage()` order by `posted_at DESC, id DESC`. Notifications that share a timestamp therefore appear in a different order in the inbox than in the per-app list, and SQLite is free to return them in a different order between two paged queries, which can also duplicate or drop rows at a page boundary.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. The fixtures contain two notifications posted at exactly 14:00 today: `Build passed` (Fixture Team) and `Weekly report is ready` (Fixture Mail).
3. Open the **Inbox** tab and note which of the two is listed first.
4. Open the **Apps** tab, open **Fixture Team**, then open **Fixture Mail**, and compare their relative order against the inbox.
5. Pull to refresh the inbox a few times and watch the two rows.

### Expected behaviour

Two notifications with the same timestamp keep one stable, documented order in every list and across refreshes.

### Actual behaviour

The inbox order of the tied pair is not guaranteed and can differ from the per-app lists.

### Acceptance criteria

- [ ] Every notification query uses the same deterministic sort, including a tiebreaker.
- [ ] Repeating the same query returns the same order.
- [ ] The inbox and the per-app list agree on the order of tied notifications.
- [ ] The sort order is stated in a doc comment on the repository.

### Suggested regression tests

- Add a repository test that inserts two notifications with identical `postedAt` and asserts `page()` returns them in the same order as `all()`.
- Add a test that runs the same paged query twice and asserts identical id order.

### Where to look

Put the ordering in one constant used by every query in the repository.

---

## `B10` retention setting is not restored after restart

**Area:** settings / persistence  
**Difficulty:** Beginner  
**Labels:** `bug`, `good first issue`, `beginner`, `priority: medium`

**Likely files**

- `lib/features/settings/data/settings_repository.dart`

### Problem

`SettingsRepository.saveRetentionDays` writes to `PrefKeys.retentionDays` (`settings.retention_days`), but `load()` reads a hard-coded `'settings.retentionDays'`. The two keys never match, so the stored value is unreachable and the setting falls back to its default on every launch.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Settings** tab.
3. Under **Data**, tap **Keep history for** and choose `90 days`. The subtitle updates to `90 days`.
4. Fully restart the app (stop and relaunch, not hot reload).
5. Open **Settings** again.

### Expected behaviour

`Keep history for` still reads `90 days`.

### Actual behaviour

It has reverted to `30 days`. Every other setting on the screen is restored correctly.

### Acceptance criteria

- [ ] A saved retention value is read back after a restart.
- [ ] Every preference is read and written through a key defined in `PrefKeys`, with no string literals.
- [ ] An absent value still falls back to `AppConstants.defaultRetentionDays`.
- [ ] `Forever` (0) round-trips and is not confused with "not set".

### Suggested regression tests

- Extend `test/features/settings/settings_repository_test.dart` with a save-then-load round trip for retention.
- Add a case asserting `0` round-trips as `Forever`.

### Where to look

`PrefKeys` carries a comment saying every key must go through it. One call site does not.

---

## `B11` muting an application does not remove it from the inbox

**Area:** applications / notifications  
**Difficulty:** Intermediate  
**Labels:** `bug`, `help wanted`, `intermediate`, `priority: medium`

**Likely files**

- `lib/features/notifications/domain/notification_query.dart`
- `lib/features/applications/data/application_repository.dart`

### Problem

`app_sources.is_muted` is persisted and shown in the UI, but no notification query consults it. Muting an app changes the switch and nothing else, even though the documented behaviour is that a muted app keeps collecting history while staying out of the inbox.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Apps** tab and turn the switch **off** for **Fixture Chat** (off means muted).
3. Go to the **Inbox** tab and pull to refresh.

### Expected behaviour

Fixture Chat notifications are no longer listed in the inbox, while remaining visible on the Fixture Chat detail screen and counted in Statistics.

### Actual behaviour

Fixture Chat notifications are still in the inbox. Only the mute icon on the Apps row changed.

### Acceptance criteria

- [ ] The inbox excludes notifications from muted applications.
- [ ] The per-application detail screen still shows them.
- [ ] Unmuting restores them in the inbox without data loss.
- [ ] The behaviour is documented on the mute switch (a subtitle or tooltip).
- [ ] Decide and document whether the unread badge counts muted apps.

### Suggested regression tests

- Add a repository test that mutes an app and asserts `page()` excludes its notifications while `forPackage()` includes them.
- Add a test that unmutes and asserts they return.

### Where to look

The inbox query will need to consider `app_sources`. Keep one source of truth for the clause so the inbox and the counter cannot disagree.

---

## `B12` "mark all as read" ignores the active filter

**Area:** notifications  
**Difficulty:** Intermediate  
**Labels:** `bug`, `help wanted`, `intermediate`, `priority: medium`

**Likely files**

- `lib/features/notifications/data/notification_repository.dart`

### Problem

`markAllAsRead` accepts a `NotificationFilter` and then ignores it, running `UPDATE notification_items SET is_read = 1 WHERE is_read = 0` across the whole table. A user who filters to one app and taps the button marks their entire history as read, with no undo.

### Steps to reproduce

1. In a **debug build**, open **Settings > Developer > Load issue fixtures**. SignalBox ships no sample data - it shows your own captured notifications - so the fixtures give every contributor the same starting point.
2. Open the **Inbox** tab and confirm several apps have unread notifications.
3. Tap the filter icon, select only **Fixture Team** under **Application**, and tap **Show results**.
4. Tap the double-tick **Mark all as read** button in the app bar.
5. Clear the filter.

### Expected behaviour

Only the Fixture Team notifications that matched the filter are marked read; everything else stays unread.

### Actual behaviour

Every notification in the database is marked read, including archived ones and ones from other apps.

### Acceptance criteria

- [ ] Only notifications matching the active filter are marked as read.
- [ ] With no filter active, the behaviour is unchanged (everything unread becomes read).
- [ ] Archived notifications are only affected when `includeArchived` is set.
- [ ] The unread counter and the list both refresh afterwards.

### Suggested regression tests

- Add a repository test that marks all read under a package filter and asserts other packages stay unread.
- Add a test asserting archived rows are untouched by default.

### Where to look

`NotificationQuery.where` already produces the clause; `markAllAsRead` just needs to use it.
