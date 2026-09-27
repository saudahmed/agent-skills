---
name: ship-staging
description: Land the current branch on `staging` end to end — commit, push, open a PR with base=staging, request a GitHub Copilot code review, fix and resolve every review thread, then rebase-merge and delete the branch. Use when the user says "ship to staging", "ship this to staging", "PR against staging", or "get this merged into staging".
argument-hint: "[optional PR title]"
disable-model-invocation: true
---

# Ship to staging

Take a local change to a rebase-merged PR on `staging`. Deliberately user-invoked: the last step is a merge.

## Guardrails

- Destination is `staging`, never `main`. An `issue-*` slice of an epic lands on
  its epic branch — use `ship-epic` instead.
- Stop and report if `mergeStateStatus` is `BLOCKED`; never bypass a gate
  (`--admin`, `--no-verify`, force-push).
- Never push, merge, or delete a branch you did not author without asking.

## 1. Recon

```bash
git status --short && git branch --show-current
git fetch origin staging --quiet && git rev-list --left-right --count HEAD...origin/staging
git ls-remote --exit-code --heads origin staging || echo "NO staging branch"
gh auth status
```

Read the repo's own rules first (`AGENTS.md`, `.agents/rules/`, `CONTRIBUTING.md`) —
branch naming, PR body shape, and the check commands live there, not here.

## 2. Branch and commit

- Uncommitted change sitting on `staging` → branch first:
  `git checkout -b <type>/<slug>` (`docs/`, `feat/`, `fix/`, `chore/`).
- Conventional Commits subject, ending with the trailer
  `Co-authored-by: CommandCodeBot <noreply@commandcode.ai>`.
  Commit with `git commit -F -` and a heredoc so the trailer survives.

## 3. Check before pushing

- **Docs-only diff** (every changed path is `*.md`/`*.mdx`/`*.txt`, or under
  `docs/` / `.agents/`) → skip the gate and say so.
- Otherwise run the repo's checks (monorepos: the root runner, e.g.
  `yarn lint && yarn typecheck && yarn test`). Never push red — fix failures.

## 4. Push and open the PR

```bash
git push -u origin "$(git branch --show-current)"
gh pr create --base staging --title "<type>(<scope>): <subject>" --body "Closes #NN

<one or two sentences on what changed and why>"
```

Body ≤6 lines: `Closes #NN`, epic PRD link if any, one sentence. No file lists or diff recap.

## 5. Review loop — request, wait, resolve, repeat

1. **Report the depth** — `scripts/review-effort.sh origin/staging`
   scores the diff and prints the level it warrants (Lite/Balanced). Say it out loud,
   but **do not try to set it**: no API, CLI flag, or comment can. The review runs at
   the repo/org default, or a level someone picks in the PR UI.
   See [REFERENCE.md](REFERENCE.md#effort-level-lite-vs-balanced).
2. **Request** — `scripts/request-copilot-review.sh <PR>`
3. **Wait** — `scripts/watch-copilot-review.sh <PR> <baseline-count>`
4. **List findings** — `scripts/review-threads.sh <PR>`
5. **Judge every finding.** Fix what is real. When one is wrong, reply with the
   reason — never resolve it silently to make the panel go green.
6. **Reply, then resolve** the thread:

   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR>/comments/<comment_id>/replies \
     -f body="Fixed in <sha> — what changed."
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<threadId>"}) { thread { isResolved } } }'
   ```

7. Push the fixes, re-request (back to 2), repeat — **bounded by the round cap
   below.**

**Round cap — 3 passes by default (`MAX_REVIEW_ROUNDS`), never more than 5.**
One pass = one re-request followed by a wait. Stop requesting when either:

- a pass reports **no new findings** (the good case), or
- you have run **3 passes** (default) — the user may raise `MAX_REVIEW_ROUNDS`
  for this ship, but treat 5 as the hard ceiling unless a human explicitly says
  otherwise.

At the cap, **do not re-request and do not keep looping.** Instead: list the
still-unresolved threads (`scripts/review-threads.sh <PR>`), report how many
were fixed vs. deferred, and ask the user whether to spend one more pass or
merge with the remainder triaged. Copilot never approves and a later pass can
always surface "previously missed" findings, so an unbounded loop does not
terminate on its own — that is how a ship turns into 12 passes over two hours.

Copilot only posts `COMMENTED`, never `APPROVED` — gate on *zero unresolved threads*. Details: [REFERENCE.md](REFERENCE.md).

## 6. Merge

```bash
gh pr view <PR> --json mergeable,mergeStateStatus,reviewDecision
gh api repos/{owner}/{repo}/branches/staging/protection   # approval required?
gh pr merge <PR> --rebase --delete-branch
```

`--rebase` keeps history linear; a pending preview deploy is not a gate unless the branch requires status checks.

## 7. Sync and report

```bash
git checkout staging && git pull --ff-only && git log --oneline -5
```

Report: PR number, merge commit, review passes run vs. the cap (`n/3`), findings
fixed vs. pushed back, and any threads still open.
