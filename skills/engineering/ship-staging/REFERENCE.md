# ship-staging — API reference and gotchas

## Requesting a GitHub Copilot review

Copilot cannot be added through the REST reviewer endpoint — it fails with
`422 Reviews may only be requested from collaborators`. It must be requested
through GraphQL `requestReviews` using its **bot node id**.

```bash
PR_ID=$(gh api graphql -f query='
  query { repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: 123) { id } } }' --jq '.data.repository.pullRequest.id')

gh api graphql -f query='
  mutation { requestReviews(input: {pullRequestId: "PR_ID", botIds: ["BOT_kgDOCnlnWA"]}) {
    pullRequest { reviewRequests(first: 10) {
      nodes { requestedReviewer { ... on Bot { login } } } } } } }'
```

The mutation returning `login: copilot-pull-request-reviewer` means the request
took. If `requested_reviewers` comes back empty from a REST call, nothing was
requested — that silent no-op is the trap.

**Node id.** `BOT_kgDOCnlnWA` is Copilot's. Re-resolve it if it ever 422s:

```bash
gh api "users/copilot-pull-request-reviewer%5Bbot%5D" --jq '{login, node_id}'
```

**Polling login.** Reviews are attributed to `copilot-pull-request-reviewer[bot]`.
Matching on the bare `copilot-pull-request-reviewer` finds nothing and the wait
never fires.

## Effort level (Lite vs Balanced)

Copilot reviews at one of two depths. **Neither can be set by any API, CLI flag, or
comment** — do not go looking for one, it does not exist:

| Surface | Reality |
|---|---|
| REST `POST /pulls/{n}/requested_reviewers` | body takes only `reviewers[]` / `team_reviewers[]` |
| GraphQL `RequestReviewsInput` | `pullRequestId`, `userIds`, `botIds`, `teamIds`, `union` |
| GraphQL `CopilotCodeReviewParameters` | only `reviewDraftPullRequests`, `reviewOnPush` — auto-review triggers, not depth |
| `gh pr create` / `gh pr edit` | only `@copilot` as a reviewer handle |
| `GET /repos/{owner}/{repo}/copilot*` | 404 |

The level is a UI selection in the PR's **Reviewers** section before you click
Request, or it is inherited from the repo/org default for *automatic* reviews
(Settings → Copilot → Code review → "Review effort level"). A manually requested
review therefore runs at whatever that default is.

`scripts/review-effort.sh [base-ref]` scores the diff and prints the level the change
*warrants*, per GitHub's own guidance (Balanced for complex logic, security-sensitive
code, cross-service changes). Report it — it is a recommendation, not a control.

| Signal | Verdict |
|---|---|
| docs-only diff | **Lite** (short-circuits everything) |
| files changed > 10 **or** changed lines > 300 | **Balanced** |
| path matches auth / payment / stripe / billing / migration / drizzle / schema / rls / supabase / session / token / crypto / secret | **Balanced** |
| more than one `apps/*` / `packages/*` workspace touched | **Balanced** |
| none of the above | **Lite** |

```bash
scripts/review-effort.sh origin/staging     # or "origin/$EPIC_BRANCH"
# BALANCED
# reason: size: 18 files changed (threshold 10)
# reason: cross-service: 3 workspaces touched
```

Confirm what actually ran — Copilot labels every review:

```bash
gh api repos/OWNER/REPO/pulls/N/reviews \
  --jq '.[] | select(.user.login|startswith("copilot")) | .body' \
  | grep -o "Review effort:\*\* [A-Za-z]*"
```

Balanced costs roughly 5× Lite in AI credits (~$0.05–$1 per Lite review, ~$0.25–$5 per
Balanced), scaling with PR size. If a risky diff ran Lite, that is a repo-default
setting to change in Settings — not a bug in this pipeline.

## Reading and resolving threads

```bash
# inline comments
gh api "repos/OWNER/REPO/pulls/123/comments?per_page=100" \
  --jq '.[] | "ID=\(.id) PATH=\(.path):\(.line // .original_line)\n\(.body)\n---"'

# threads, with the id you need to resolve
gh api graphql -f query='
  query { repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: 123) {
      reviewThreads(first: 50) { nodes {
        id isResolved
        comments(first: 1) { nodes { databaseId path } } } } } } }'

# resolve (requires the thread id, not the comment id)
gh api graphql -f query='
  mutation { resolveReviewThread(input: {threadId: "PRRT_..."}) {
    thread { id isResolved } } }'
```

Reply first, resolve second. A resolved-without-reply thread is indistinguishable
from one that was dismissed.

## Gotchas

- **`COMMENTED`, not `APPROVED`.** Copilot never approves. `reviewDecision` stays
  empty, so gate on unresolved threads plus branch protection, not on approval.
- **Review passes are cumulative.** A re-request produces a *new* review entry;
  count reviews by the bot to detect the fresh one, otherwise you will treat the
  previous pass as the new one.
- **"Previously missed" findings.** A later pass can surface findings in files it
  did not comment on before, listed in the review body rather than as inline
  threads. They have no thread to resolve — just fix them and say so in a PR comment.
- **CodeRabbit skips non-default base branches** unless configured:
  `Review skipped: reviews are disabled for this base branch`. Its config key is
  `reviews.auto_review.base_branches` — a bare `reviews.base_branches` is ignored.
- **Preview deploys** (Vercel, etc.) show as `pending` while building. That is not
  a merge gate unless the branch has required status checks
  (`gh api repos/O/R/branches/<base>/protection/required_status_checks` 404s when none).
- **`required_conversation_resolution` is often false**, so a merge is possible
  with open threads. Resolve them anyway — that is the point of the loop.
