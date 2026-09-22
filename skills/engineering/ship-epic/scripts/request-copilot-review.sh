#!/usr/bin/env bash
# Request a GitHub Copilot code review on a pull request.
#
# Copilot cannot be requested through the REST reviewer endpoint (it 422s with
# "may only be requested from collaborators"). It has to go through GraphQL
# requestReviews with the bot's node id.
#
# Usage: request-copilot-review.sh <pr-number> [owner/repo]
set -euo pipefail

PR="${1:?usage: request-copilot-review.sh <pr-number> [owner/repo]}"
REPO="${2:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
COPILOT_BOT_ID="${COPILOT_BOT_ID:-BOT_kgDOCnlnWA}"

PR_ID="$(gh api graphql -f query="
  query { repository(owner: \"$OWNER\", name: \"$NAME\") {
    pullRequest(number: $PR) { id } } }" \
  --jq '.data.repository.pullRequest.id')"

requested="$(gh api graphql -f query="
  mutation { requestReviews(input: {pullRequestId: \"$PR_ID\", botIds: [\"$COPILOT_BOT_ID\"]}) {
    pullRequest { reviewRequests(first: 10) {
      nodes { requestedReviewer { ... on Bot { login } } } } } } }" \
  --jq '[.data.requestReviews.pullRequest.reviewRequests.nodes[].requestedReviewer.login] | join(",")')"

if [ -z "$requested" ]; then
  echo "no reviewer registered — is Copilot code review enabled for $REPO?" >&2
  exit 1
fi

echo "requested: $requested"
