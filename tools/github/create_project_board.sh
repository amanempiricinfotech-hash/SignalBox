#!/usr/bin/env bash
#
# Creates the "SignalBox Development" Projects v2 board, adds the seven
# Status columns and adds every open issue to it.
#
# This needs a token scope the default gh login does not include. Grant it
# once, interactively:
#
#   gh auth refresh -s project,read:project
#
# Usage:
#   ./tools/github/create_project_board.sh <owner> <owner/repo>

set -euo pipefail

OWNER="${1:-}"
REPO="${2:-}"
if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "usage: $0 <owner> <owner/repo>" >&2
  exit 1
fi

command -v gh >/dev/null || { echo "gh is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

if ! gh project list --owner "$OWNER" >/dev/null 2>&1; then
  cat >&2 <<'MSG'
gh cannot read projects with the current token.

Run this once, then try again:

    gh auth refresh -s project,read:project

It opens a browser, so it needs an interactive terminal.
MSG
  exit 1
fi

TITLE="SignalBox Development"

number="$(gh project list --owner "$OWNER" --format json \
  | jq -r --arg t "$TITLE" '.projects[] | select(.title == $t) | .number' | head -1)"

if [[ -z "$number" ]]; then
  echo "==> Creating project: $TITLE"
  number="$(gh project create --owner "$OWNER" --title "$TITLE" --format json | jq -r '.number')"
else
  echo "==> Reusing existing project #$number"
fi

echo "==> Status columns"
# gh cannot yet edit the options of the built-in Status field, so the columns
# are added as a new single-select field that the board can group by.
if ! gh project field-list "$number" --owner "$OWNER" --format json \
     | jq -e '.fields[] | select(.name == "Workflow")' >/dev/null 2>&1; then
  gh project field-create "$number" --owner "$OWNER" \
    --name "Workflow" \
    --data-type SINGLE_SELECT \
    --single-select-options "Backlog,Ready to Pick,In Progress,In Review,Changes Requested,Approved,Done" \
    >/dev/null
  echo "    created the Workflow field with 7 options"
else
  echo "    Workflow field already exists"
fi

echo "==> Adding open issues"
added=0
for n in $(gh issue list --repo "$REPO" --state open --limit 200 --json number --jq '.[].number'); do
  gh project item-add "$number" --owner "$OWNER" \
    --url "https://github.com/$REPO/issues/$n" >/dev/null 2>&1 && added=$((added + 1))
done
echo "    added $added issues"

cat <<MSG

Board ready: https://github.com/users/$OWNER/projects/$number

Two things still need the web UI:
  1. Group the board by the "Workflow" field (board view > Group by).
  2. Settings > Workflows: enable "Item closed" and "Pull request merged"
     to set Workflow to Done, and "Item added" to set it to Backlog.

Then move everything except the two dependent issues (F7, which needs B10,
and F10, which needs B1) from Backlog into Ready to Pick.
MSG
