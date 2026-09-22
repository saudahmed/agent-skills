#!/usr/bin/env bash
# Wait for a NEW GitHub Copilot review on a pull request, then print its findings.
#
# Copilot review entries are cumulative: pass the number of Copilot reviews that
# already existed before you re-requested, so this waits for the fresh one rather
# than immediately reporting the previous pass.
#
# Usage: watch-copilot-review.sh <pr-number> <baseline-review-count> [timeout-seconds] [owner/repo]
set -uo pipefail

PR="${1:?usage: watch-copilot-review.sh <pr-number> <baseline-count> [timeout] [owner/repo]}"
BASELINE="${2:?baseline review count required}"
TIMEOUT="${3:-900}"
REPO="${4:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

# Reviews are attributed with the [bot] suffix; matching the bare login never fires.
BOT='copilot-pull-request-reviewer[bot]'

deadline=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  count="$(gh api "repos/$REPO/pulls/$PR/reviews?per_page=100" \
    --jq "[.[] | select(.user.login==\"$BOT\")] | length" 2>/dev/null)"

  if [ -n "${count:-}" ] && [ "$count" -gt "$BASELINE" ]; then
    echo "reviews-by-copilot=$count"
    gh api "repos/$REPO/pulls/$PR/reviews?per_page=100" \
      --jq ".[] | select(.user.login==\"$BOT\") | \"review id=\\(.id) state=\\(.state)\""
    if [ -x "$(dirname "$0")/review-threads.sh" ]; then
      echo "--- open threads ---"
      "$(dirname "$0")/review-threads.sh" "$PR" "$REPO" || true
    fi
    exit 0
  fi

  sleep 15
done

echo "timed out after ${TIMEOUT}s — still $BASELINE copilot review(s)" >&2
exit 1
