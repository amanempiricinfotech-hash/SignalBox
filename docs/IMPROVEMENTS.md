# Code-quality improvement tasks

These tasks are neither bugs nor missing features: the app behaves as designed,
but the implementation can be measurably better. Each one asks for a measurement
or an audit first, so that a reviewer can see what the change actually bought.

## Index

| ID | Task | Area | Difficulty |
| --- | --- | --- | --- |
| `Q1` | add database indexes for the inbox and statistics queries | database | Advanced |
| `Q2` | stop rebuilding the whole inbox list on every state change | notifications / performance | Intermediate |
| `Q3` | accessibility pass over the inbox, dashboard and settings | accessibility | Beginner |
| `Q4` | responsive layout for tablets and landscape | UI / layout | Intermediate |
| `Q5` | document the architecture and the data layer contracts | documentation | Beginner |

---

## `Q1` add database indexes for the inbox and statistics queries

**Area:** database  
**Difficulty:** Advanced  
**Labels:** `performance`, `enhancement`, `advanced`, `priority: medium`

### Problem

`notification_items` has no secondary index. Every inbox page sorts the whole table on `posted_at`, every per-app view scans it on `package_name`, and the statistics aggregates scan it repeatedly. This is fine with the 60 fixture rows and poor with months of real capture.

### Requirements

- Measure before changing anything: insert a realistic volume (50,000+ rows) and record the timings of the inbox page query, the per-app query and the statistics aggregates.
- Add the indexes those measurements justify, with a schema migration rather than an edit to the `onCreate` SQL.
- Bump `AppDatabase.schemaVersion` and implement the upgrade branch so existing installs are migrated.
- Re-measure and report the before/after numbers in the pull request.
- Document why each index exists, since every index costs write throughput and disk.

### Acceptance criteria

- [ ] The pull request contains before/after timings from the same machine and dataset.
- [ ] A migration exists and is tested from the current schema version to the new one.
- [ ] A fresh install and an upgraded install end up with identical schemas.
- [ ] `EXPLAIN QUERY PLAN` for the inbox query shows the index being used, and that output is in the PR.
- [ ] No regression in the existing test suite.

### Testing

- A migration test opening a v1 database, upgrading it and asserting the indexes exist.
- A test asserting a fresh install and a migrated install agree on schema.
- A benchmark script or test, excluded from CI, that reproduces the measurement.

---

## `Q2` stop rebuilding the whole inbox list on every state change

**Area:** notifications / performance  
**Difficulty:** Intermediate  
**Labels:** `performance`, `enhancement`, `intermediate`, `priority: medium`

### Problem

`_InboxList` watches `appLabelsProvider`, `categoriesByIdProvider` and `settingsProvider` at the top of its build method, so marking one notification read rebuilds every row. Rows are rebuilt whole rather than rebuilding only what changed, and the date headers are recomputed on each build.

### Requirements

- Profile first: capture the rebuild counts or a DevTools timeline for marking one notification read in a list of 60.
- Narrow the watches so a row depends only on the data it renders, for example with `select` or a per-row provider.
- Avoid recomputing the grouped row list on every build when the inputs have not changed.
- Keep the widget tree readable: do not trade all clarity for a marginal gain, and say in the PR what the measurement showed.

### Acceptance criteria

- [ ] Marking one notification read rebuilds that row and not the rest of the list, demonstrated by a rebuild count or timeline in the PR.
- [ ] Scrolling the fixture inbox holds a steady frame rate in profile mode, with before/after numbers.
- [ ] No behaviour changes: every existing inbox test still passes unmodified.
- [ ] The row widget stays `const`-constructible where its inputs allow it.

### Testing

- A widget test asserting a row is not rebuilt when an unrelated row changes, for instance with a rebuild counter.
- Existing inbox tests must pass without modification.

---

## `Q3` accessibility pass over the inbox, dashboard and settings

**Area:** accessibility  
**Difficulty:** Beginner  
**Labels:** `enhancement`, `documentation`, `good first issue`, `beginner`, `priority: medium`

### Problem

Accessibility is partial. `NotificationTile`, `AppAvatar`, `SimpleBarChart` and `BreakdownBar` carry semantics, but icon-only buttons, chips and switches elsewhere do not, several tap targets are below 48dp, and the charts convey information by colour alone.

### Requirements

- Audit the Dashboard, Inbox, Apps, Stats and Settings screens with TalkBack and with the Flutter semantics debugger.
- Give every interactive element an accessible label, and every icon-only button a tooltip.
- Ensure a minimum 48x48dp tap target for every control.
- Check text contrast against WCAG AA in both light and dark themes, especially the muted `onSurfaceVariant` text.
- Make sure nothing relies on colour alone: priority and category must be readable without seeing the colour.
- Verify the layout at 200% font scale without clipping or overflow.
- Write down the findings and the remaining gaps in `docs/ACCESSIBILITY.md`.

### Acceptance criteria

- [ ] Every interactive element on the audited screens has a meaningful accessible label.
- [ ] No tap target is smaller than 48x48dp.
- [ ] Body and label text meets WCAG AA contrast in both themes, with the measured ratios recorded.
- [ ] At 200% font scale no screen clips or overflows.
- [ ] Priority and category are distinguishable without colour.
- [ ] `docs/ACCESSIBILITY.md` records what was checked, what was fixed and what is still open.

### Testing

- Widget tests using `meetsGuideline(textContrastGuideline)` and `meetsGuideline(androidTapTargetGuideline)` for the audited screens.
- A test pumping a screen at a 2.0 text scale factor and asserting no overflow exception.

---

## `Q4` responsive layout for tablets and landscape

**Area:** UI / layout  
**Difficulty:** Intermediate  
**Labels:** `enhancement`, `help wanted`, `intermediate`, `priority: low`

### Problem

Every screen is built for a single phone column. On a tablet the stat cards stretch to absurd widths, the inbox lines run too long to read comfortably, and the bottom navigation bar wastes a wide window. Nothing adapts to landscape.

### Requirements

- Define the breakpoints the app will support and record them in one place.
- Constrain the readable content width on wide screens instead of stretching it.
- Use a navigation rail instead of a bottom bar above the chosen width.
- Lay the dashboard and statistics cards out in a responsive grid.
- Consider a list/detail split for the inbox on wide screens, or explain in the PR why it is deferred.
- Verify landscape phone, tablet portrait and tablet landscape.

### Acceptance criteria

- [ ] At 1024dp wide the content is constrained and centred rather than stretched edge to edge.
- [ ] A navigation rail replaces the bottom bar above the documented breakpoint, and routing still works.
- [ ] No screen overflows or clips in landscape on a phone.
- [ ] The breakpoints live in one constant, not scattered magic numbers.
- [ ] Screenshots at phone, tablet portrait and tablet landscape are attached to the PR.

### Testing

- Widget tests pumping the shell at several surface sizes and asserting the expected navigation component is present.
- Tests asserting no overflow exceptions at each breakpoint.

---

## `Q5` document the architecture and the data layer contracts

**Area:** documentation  
**Difficulty:** Beginner  
**Labels:** `documentation`, `good first issue`, `beginner`, `priority: low`

### Problem

`docs/ARCHITECTURE.md` describes the layout at a high level, but a new contributor still has to read the source to learn how a notification travels from Android to the screen, what each provider is for, or which invariants the repositories guarantee.

### Requirements

- Document the full ingestion path: `NotificationListenerService` to `NotificationStreamHandler` to the event channel to the repository to SQLite.
- Document every table and column, including the units of each timestamp and the meaning of each enum index.
- List the providers, what each one owns and which ones must be invalidated after which writes.
- Add dartdoc to every public class and method in `features/*/data` that lacks it, stating the ordering and filtering guarantees.
- Include one diagram of the data flow.
- Explain the testing seams: the `databaseProvider` and `sharedPreferencesProvider` overrides.

### Acceptance criteria

- [ ] A contributor can follow a notification from Android to the inbox using only the docs.
- [ ] Every table and column is documented, with units and enum meanings.
- [ ] `dart doc` produces no warnings for the data layer.
- [ ] The provider invalidation rules are written down in one place.
- [ ] The docs match the code at the time of the pull request, with no references to removed APIs.

### Testing

- No automated tests. Verify by having someone unfamiliar with the code follow the document, and note that in the PR.
