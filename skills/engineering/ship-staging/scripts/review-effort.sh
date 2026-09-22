#!/usr/bin/env bash
# Recommend a Copilot code review effort level (Lite or Balanced) for the current diff.
#
# The level itself CANNOT be set by any API, CLI flag, or comment — it is chosen in
# the pull request's Reviewers section, or inherited from the repository/org default
# for automatic reviews. This script only decides which level the change *warrants*,
# so the agent can report it (and so a human knows when the default under-serves a
# risky diff).
#
# Rule (from GitHub's docs): Balanced for complex logic, security-sensitive code,
# and cross-service changes; Lite for routine changes.
#
# Usage: review-effort.sh [base-ref]      # default: merge-base with origin/HEAD
set -uo pipefail

BASE="${1:-}"
if [ -z "$BASE" ]; then
  BASE="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"
fi

if ! git rev-parse --verify --quiet "$BASE" >/dev/null; then
  echo "cannot resolve base ref '$BASE' — pass one explicitly, e.g. review-effort.sh origin/staging" >&2
  exit 2
fi

MERGE_BASE="$(git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")"
PATHS="$(git diff --name-only "$MERGE_BASE" HEAD)"

if [ -z "$PATHS" ]; then
  echo "LITE"
  echo "reason: empty diff"
  exit 0
fi

FILES="$(printf '%s\n' "$PATHS" | grep -c .)"
LINES="$(git diff --numstat "$MERGE_BASE" HEAD | awk '{a+=$1; d+=$2} END {print a+d+0}')"

# Docs-only diffs never need the deeper model.
if ! printf '%s\n' "$PATHS" | grep -qvE '(^docs/|^\.agents/|\.md$|\.mdx$|\.txt$)'; then
  echo "LITE"
  echo "reason: docs-only diff ($FILES files, $LINES lines)"
  exit 0
fi

REASONS=""

if [ "$FILES" -gt 10 ]; then
  REASONS="${REASONS}size: $FILES files changed (threshold 10)
"
fi
if [ "$LINES" -gt 300 ]; then
  REASONS="${REASONS}size: $LINES changed lines (threshold 300)
"
fi

RISK="$(printf '%s\n' "$PATHS" | grep -iE 'auth|payment|stripe|billing|migration|drizzle|schema|rls|supabase|session|token|crypto|secret' | head -3)"
if [ -n "$RISK" ]; then
  REASONS="${REASONS}risk path: $(printf '%s' "$RISK" | tr '\n' ' ')
"
fi

WORKSPACES="$(printf '%s\n' "$PATHS" | awk -F/ '{print $1"/"$2}' | sort -u | grep -cE '^(apps|packages)/')"
if [ "$WORKSPACES" -gt 1 ]; then
  REASONS="${REASONS}cross-service: $WORKSPACES workspaces touched
"
fi

if [ -n "$REASONS" ]; then
  echo "BALANCED"
  printf '%s' "$REASONS" | sed -e '/^$/d' -e 's/^/reason: /'
else
  echo "LITE"
  echo "reason: routine change — $FILES files, $LINES lines, single workspace"
fi
