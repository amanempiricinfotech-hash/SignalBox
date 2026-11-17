#!/usr/bin/env bash
#
# Rewrites the body of every issue in issues.json that already exists on the
# repository, matching on the exact title. Use it after regenerating
# issues.json so that the published issues and the docs stay in step.
#
# Issues that do not exist yet are left to setup_github.sh.
#
# Usage:
#   ./tools/github/sync_issue_bodies.sh <owner/repo>
#   DRY_RUN=1 ./tools/github/sync_issue_bodies.sh <owner/repo>

set -euo pipefail

REPO="${1:-}"
[[ -n "$REPO" ]] || { echo "usage: $0 <owner/repo>" >&2; exit 1; }

DRY_RUN="${DRY_RUN:-0}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUES_JSON="$HERE/issues.json"

for binary in gh jq; do
  command -v "$binary" >/dev/null || { echo "$binary is required" >&2; exit 1; }
done

mapping="$(gh issue list --repo "$REPO" --state all --limit 500 \
  --json number,title)"

count="$(jq 'length' "$ISSUES_JSON")"
updated=0
missing=0

for ((i = 0; i < count; i++)); do
  title="$(jq -r ".[$i].title" "$ISSUES_JSON")"
  key="$(jq -r ".[$i].key" "$ISSUES_JSON")"

  number="$(jq -r --arg t "$title" \
    '.[] | select(.title == $t) | .number' <<< "$mapping" | head -1)"

  if [[ -z "$number" ]]; then
    echo "    not on GitHub yet: [$key] $title"
    missing=$((missing + 1))
    continue
  fi

  body_file="$(mktemp)"
  jq -r ".[$i].body" "$ISSUES_JSON" > "$body_file"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY RUN: would update #$number [$key]"
  else
    gh issue edit "$number" --repo "$REPO" --body-file "$body_file" >/dev/null
    echo "    updated #$number [$key]"
    updated=$((updated + 1))
  fi
  rm -f "$body_file"
done

echo
echo "updated: $updated, not yet created: $missing"
