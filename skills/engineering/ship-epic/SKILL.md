---
name: ship-epic
description: Land the current slice on its parent epic integration branch (`feat/epic-NN-<slug>`) instead of staging — commit, push, open a PR with the epic branch as base, request a GitHub Copilot code review, fix and resolve every review thread, then squash-merge and delete the branch. Use when the user says "ship to the epic branch", "PR against the epic branch", "land this on feat/epic-NN", or when the branch being shipped is an `issue-*` slice of an epic.
argument-hint: "[optional PR title]"
disable-model-invocation: true
---

# Ship to the epic branch

Take a slice of an epic to a squash-merged PR on its **epic integration branch**
(`feat/epic-NN-<slug>`) — not on `staging`, not on `main`. Deliberately
user-invoked: the last step is a merge.

## Guardrails

- Base is the epic branch, never `main` or `staging`, unless the user explicitly
  says so.
- Stop and report if `mergeStateStatus` is `BLOCKED`; never bypass a gate
  (`--admin`, `--no-verify`, force-push).
- Never push, merge, or delete a branch you did not author without asking.

## 1. Detect the base

1. **Epic number** — from the issue this branch closes:
   `gh issue view <N> --json title --jq .title` → `epic-NN: <slice>`.
   If the branch already encodes it (`feat/epic-NN-*`), take `NN` from there.
2. **Find the integration branch** — `git fetch origin --quiet`, then
   `git branch -r --list "*epic-NN*"`.
3. **Decide** — never guess:
   - **exactly one match** → that is the base; no need to ask.
   - **zero matches** → the epic branch does not exist yet. Ask whether to create
     `feat/epic-NN-<slug>` from `origin/staging` (the repo's rule), then **stop
     until the user answers**. Do not create it unasked.
   - **multiple matches** → list them and ask which one.

Set it once and use it throughout: `EPIC_BRANCH="feat/epic-NN-<slug>"`.

**Before `gh pr create`:** say the base out loud. If it resolved to `main`, STOP —
detection failed.

## 2. Recon

```bash
git status --short && git branch --show-current
git fetch origin "$EPIC_BRANCH" --quiet
git rev-list --left-right --count "HEAD...origin/$EPIC_BRANCH"
gh auth status
```

Read the repo's own rules first (`AGENTS.md`, `.agents/rules/`, `CONTRIBUTING.md`) —
branch naming, PR body shape, and the check commands live there, not here.

## 3. Branch and commit

- Uncommitted change sitting on the epic branch → branch first:
  `git checkout -b <type>/<slug>` (`docs/`, `feat/`, `fix/`, `chore/`).
- Conventional Commits subject, ending with the trailer
  `Co-authored-by: CommandCodeBot <noreply@commandcode.ai>`; commit with
  `git commit -F -` and a heredoc so the trailer survives.

## 4. Check before pushing

- **Docs-only diff** (all paths `*.md`/`*.mdx`/`*.txt`, or under `docs/` / `.agents/`) → skip the gate.
- Otherwise run the repo's checks (monorepos: the root runner, e.g. `yarn lint && yarn typecheck && yarn test`). Never push red.

## 5. Push and open the PR

```bash
git push -u origin "$(git branch --show-current)"
gh pr create --base "$EPIC_BRANCH" --title "<type>(<scope>): <subject>" --body "Closes #NN

Part of [epic-NN](docs/prd/todo/epic-NN-<slug>.md)

<one or two sentences on what changed and why>"
```

Body ≤6 lines. An epic slice always links its parent epic PRD. No file lists or diff recap.

## 6. Review loop — request, wait, resolve, repeat

1. **Report the depth** — `scripts/review-effort.sh "origin/$EPIC_BRANCH"`
   scores the diff and prints the level it warrants (Lite/Balanced). Say it out loud,
   but **do not try to set it**: no API, CLI flag, or comment can. The review runs at
   the repo/org default, or a level someone picks in the PR UI.
   See [REFERENCE.md](REFERENCE.md#effort-level-lite-vs-balanced).
2. **Request** — `scripts/request-copilot-review.sh <PR>`
3. **Wait** — `scripts/watch-copilot-review.sh <PR> <baseline-count>`
4. **List findings** — `scripts/review-threads.sh <PR>`
5. **Judge every finding.** Fix what is real. When one is wrong, reply with the
   reason — never resolve it silently to make the panel go green.
6. **Reply, then resolve** the thread — reply first, resolve second. Exact
   commands: [REFERENCE.md](REFERENCE.md#reading-and-resolving-threads).

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

## 7. Merge, then sync

```bash
gh pr view <PR> --json mergeable,mergeStateStatus,reviewDecision
gh api "repos/{owner}/{repo}/branches/$EPIC_BRANCH/protection"   # approval required?
gh pr merge <PR> --squash --delete-branch
git checkout "$EPIC_BRANCH" && git pull --ff-only && git log --oneline -5
```

`--squash` lands the slice as a single commit on the epic branch; a pending preview deploy is not a gate unless the branch requires status checks.

Report: PR number, the detected base, merge commit, review passes run vs. the
cap (`n/3`), findings fixed vs. pushed back, and any threads still open.
