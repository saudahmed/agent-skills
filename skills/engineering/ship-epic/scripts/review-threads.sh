#!/usr/bin/env bash
# List the unresolved review threads on a pull request, one line per thread.
#
# Prints the ids needed to reply and resolve:
#   thread=PRRT_...  comment=<id>  path=<file>:<line>
#
# Usage: review-threads.sh <pr-number> [owner/repo]
set -euo pipefail

PR="${1:?usage: review-threads.sh <pr-number> [owner/repo]}"
REPO="${2:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"

gh api graphql -f query="
  query { repository(owner: \"$OWNER\", name: \"$NAME\") {
    pullRequest(number: $PR) {
      reviewThreads(first: 100) { nodes {
        id isResolved isOutdated
        comments(first: 1) { nodes { databaseId path line body } } } } } } }" \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | select(.isResolved == false)
        | .comments.nodes[0] as $c
        | "thread=\(.id)  comment=\($c.databaseId)  path=\($c.path):\($c.line // "?")"
          + (if .isOutdated then "  (outdated)" else "" end)
          + "\n" + ($c.body | split("\n")[0]) + "\n"'
