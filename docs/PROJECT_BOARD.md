# Project board

SignalBox tracks every issue through a GitHub Projects (v2) board.

## Columns

The board has a single-select field named **Status** with these options, in
order:

| Column | Meaning | Who moves it here |
| --- | --- | --- |
| **Backlog** | Accepted, not ready to pick up. Needs scoping, or is blocked by another issue. | Maintainer |
| **Ready to Pick** | Fully specified and unblocked. Anyone may claim it. | Maintainer |
| **In Progress** | Assigned, work has started. | Maintainer, on assigning |
| **In Review** | A pull request is open and waiting for review. | Contributor, on opening the PR |
| **Changes Requested** | Reviewed; the contributor has work to do. | Reviewer |
| **Approved** | Approved and CI is green; waiting to be merged. | Reviewer |
| **Done** | Merged and the issue is closed. | Automatic, on close |

## Rules

- An issue is in exactly one column.
- Nothing enters **In Progress** without an assignee. One assignee per issue,
  unless the issue says it is deliberately a pair task.
- Nothing enters **Ready to Pick** until its acceptance criteria are written and
  its dependencies are unblocked.
- A pull request moves its issue to **In Review**, not to **Done**. `Fixes #N`
  in the PR body closes the issue and moves it to **Done** on merge.
- An issue that has sat in **In Progress** for two weeks with no activity gets a
  nudge, then is unassigned and returned to **Ready to Pick**.

## Creating the board

There is a script for most of it:

```bash
# one-off: the default gh login does not carry the project scope.
# This opens a browser, so it needs an interactive terminal.
gh auth refresh -s project,read:project

./tools/github/create_project_board.sh <owner> <owner>/SignalBox
```

It creates the project, adds a `Workflow` single-select field carrying the seven
columns, and adds every open issue. Two steps are still left to the web UI
afterwards, because the `gh` CLI cannot drive them: grouping the board by
`Workflow`, and enabling the automation workflows. The script prints both when
it finishes.

### Doing it by hand instead

1. Open the repository, choose **Projects > New project > Board**.
2. Name it `SignalBox Development`.
3. Rename the default `Todo` / `In Progress` / `Done` options of the **Status**
   field to the seven columns above, adding the missing ones.
4. **Settings > Workflows**, enable:
   - *Item closed* to **Done**
   - *Pull request merged* to **Done**
   - *Item added to project* to **Backlog**
5. Add the existing issues:

   ```bash
   gh project list --owner <owner>          # find the project number

   for n in $(gh issue list --repo <owner>/SignalBox --state open \
                --limit 100 --json number --jq '.[].number'); do
     gh project item-add <number> --owner <owner> \
       --url https://github.com/<owner>/SignalBox/issues/$n
   done
   ```

6. Move the issues out of **Backlog**: everything that is fully specified and
   unblocked belongs in **Ready to Pick**. For SignalBox at v0.1.0 that is
   every issue except the two with dependencies (`F7` needs `B10`, and `F10`
   needs `B1`), which stay in **Backlog** until their blocker is fixed.

## Suggested grouping

Group the board by **Milestone** for a release view, or by **Difficulty** label
when onboarding new contributors — the second makes it obvious at a glance what
a first-time contributor can pick up.
