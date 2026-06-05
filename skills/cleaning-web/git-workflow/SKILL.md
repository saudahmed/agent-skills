---
name: git-workflow
description: Enforces this project's commit message format (Conventional Commits), branch naming conventions, and PR workflow. Use when making commits, creating branches, opening PRs, writing commit messages, or any git operation in this repository.
---

## Commit Messages (Conventional Commits)

Format: `<type>: <description>`

| Type | Use for |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructuring, no behavior change |
| `test` | Adding or updating tests |
| `chore` | Tooling, dependencies, config |
| `docs` | Documentation |
| `style` | Formatting only |

Examples: `feat: add profile settings screen` · `fix: resolve survey submission crash` · `refactor: simplify auth token refresh logic`

## Branch Naming

| Type | Pattern | Example |
|---|---|---|
| Feature | `feat/description` | `feat/profile-settings` |
| Bug fix | `fix/description` | `fix/survey-crash` |
| Refactor | `refactor/description` | `refactor/auth-flow` |
| Chore | `chore/description` | `chore/rn-upgrade` |

## Workflow

1. Branch from `main`: `git checkout -b feat/feature-name`
2. Implement with tests
3. Run `npm run lint`
4. Commit using conventional commit format
5. Open PR against `main`
6. Get at least one review approval before merging
