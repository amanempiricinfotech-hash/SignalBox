#!/usr/bin/env bash
#
# Creates the SignalBox labels, milestones and issues on GitHub.
#
# Idempotent: existing labels and milestones are updated rather than
# duplicated, and an issue whose exact title already exists is skipped.
#
# Requirements: gh (authenticated), jq.
#
# Usage:
#   ./tools/github/setup_github.sh <owner/repo>
#   DRY_RUN=1 ./tools/github/setup_github.sh <owner/repo>

set -euo pipefail

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  echo "usage: $0 <owner/repo>" >&2
  exit 1
fi

DRY_RUN="${DRY_RUN:-0}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUES_JSON="$HERE/issues.json"

for binary in gh jq; do
  command -v "$binary" >/dev/null || { echo "$binary is required" >&2; exit 1; }
done
[[ -f "$ISSUES_JSON" ]] || { echo "missing $ISSUES_JSON" >&2; exit 1; }

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY RUN: $*"
  else
    "$@"
  fi
}

echo "==> Labels"
# name|colour|description
LABELS=(
  "bug|d73a4a|Something behaves incorrectly"
  "feature|0e8a16|New functionality"
  "enhancement|a2eeef|Improvement to something that already exists"
  "documentation|0075ca|Documentation only"
  "testing|c2e0c6|Tests only"
  "performance|fbca04|Speed, memory or battery"
  "good first issue|7057ff|Good for a first contribution"
  "help wanted|008672|Maintainers would welcome help here"
  "beginner|c5def5|One or two files, no need to know the whole codebase"
  "intermediate|bfd4f2|Repository logic, SQL, state management"
  "advanced|5319e7|Kotlin, migrations, background work, performance"
  "priority: high|b60205|Fix or build this first"
  "priority: medium|fbca04|Normal priority"
  "priority: low|0e8a16|Nice to have"
  "in progress|ededed|Someone is actively working on this"
  "blocked|000000|Waiting on another issue"
)

# --force creates the label, or updates it when it already exists, so this
# step is safe to re-run after a partial failure.
for entry in "${LABELS[@]}"; do
  IFS='|' read -r name colour description <<< "$entry"
  run gh label create "$name" --repo "$REPO" --color "$colour" \
    --description "$description" --force
  echo "    ok: $name"
done

echo "==> Milestones"
MILESTONES=(
  "Milestone 1: Application Foundation|Architecture, navigation, theme, database, core screens and CI. Complete."
  "Milestone 2: Bug Fixes|The 12 seeded bugs, each with a regression test."
  "Milestone 3: Missing Features|The 10 intentionally unfinished features."
  "Milestone 4: Performance and Quality|Indexes, rebuild reduction, accessibility, responsive layout, docs."
  "Milestone 5: Stable Release|No known seeded bugs, no unfinished features in the UI, 1.0.0."
)

existing_milestones="$(gh api "repos/$REPO/milestones?state=all&per_page=100" --jq '.[].title' 2>/dev/null || true)"
for entry in "${MILESTONES[@]}"; do
  IFS='|' read -r title description <<< "$entry"
  if grep -Fxq "$title" <<< "$existing_milestones"; then
    echo "    exists: $title"
  else
    run gh api "repos/$REPO/milestones" -f title="$title" -f description="$description" --silent
    echo "    created: $title"
  fi
done

echo "==> Issues"
existing_issues="$(gh issue list --repo "$REPO" --state all --limit 500 --json title --jq '.[].title' 2>/dev/null || true)"

count="$(jq 'length' "$ISSUES_JSON")"
for ((i = 0; i < count; i++)); do
  title="$(jq -r ".[$i].title" "$ISSUES_JSON")"
  milestone="$(jq -r ".[$i].milestone" "$ISSUES_JSON")"
  key="$(jq -r ".[$i].key" "$ISSUES_JSON")"

  if grep -Fxq "$title" <<< "$existing_issues"; then
    echo "    skip (exists): [$key] $title"
    continue
  fi

  body_file="$(mktemp)"
  jq -r ".[$i].body" "$ISSUES_JSON" > "$body_file"

  label_args=()
  while IFS= read -r label; do
    label_args+=(--label "$label")
  done < <(jq -r ".[$i].labels[]" "$ISSUES_JSON")

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY RUN: gh issue create [$key] $title (${#label_args[@]} labels, milestone: $milestone)"
  else
    gh issue create \
      --repo "$REPO" \
      --title "$title" \
      --body-file "$body_file" \
      --milestone "$milestone" \
      "${label_args[@]}" >/dev/null
    echo "    created: [$key] $title"
  fi
  rm -f "$body_file"
done

echo
echo "Done. Remaining manual steps (they need settings the API cannot fully drive):"
echo "  1. Settings > Branches: protect 'main' (1 approval, required checks, no bypass)."
echo "  2. Projects: create the board and add the seven columns, then add the issues."
echo "     See docs/PROJECT_BOARD.md."
