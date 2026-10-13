---
name: dev-conventions
description: >
  The user's git conventions: branch naming (feat/*, fix/*, REP-123-*, gh-123-*, gl-123-*),
  Conventional Commit messages, PR/MR title and body template, semver release and changelog
  rules. Load before creating a branch, writing a commit message, opening a PR/MR, tagging,
  or drafting release notes, in any repo. Repo-local conventions (CONTRIBUTING.md, CLAUDE.md,
  commitlint config, existing history) override these defaults.
user-invocable: false
---

# Dev conventions

Repo-local rules win. Before applying a default below, check in this order:
`CLAUDE.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md` / `.gitlab/merge_request_templates/`,
commitlint / semantic-release config, then history:

```bash
git branch -r --sort=-committerdate | head -20
git log --no-merges --format=%s -20
git tag --sort=-creatordate | head -5
```

If history shows a clear pattern (3+ of the last 20 follow it), follow the pattern.

Forge facts (GitHub vs GitLab, default branch, CLI, latest tag): run `~/.ai/bin/git-forge`.

## Branch names

Pick the first rule that matches:

| Source of work | Pattern | Example |
|---|---|---|
| Tracker key (Jira, Linear, YouTrack: `ABC-123`) | `<KEY>-<slug>` (key keeps its case) | `REP-482-fix-ledger-rounding` |
| GitHub issue | `gh-<n>-<slug>` | `gh-91-retry-webhook` |
| GitLab issue | `gl-<n>-<slug>` | `gl-17-export-csv` |
| No ticket | `<type>/<slug>` | `feat/bulk-invite`, `fix/null-avatar` |

- `type`: feat, fix, hotfix, chore, refactor, perf, docs, test, ci.
- `slug`: lowercase kebab-case, 2-5 words, whole branch name 50 chars max. No dates, no usernames.
- Base: the default branch from `git-forge`. Use `develop` only when the repo uses git-flow (branch exists and recent feature branches merge into it). `hotfix/*` branches from the default/production branch.
- Ticket key and type both known: ticket pattern wins (trackers auto-link on the key).

## Commits

Conventional Commits: `type(scope): subject`.
- Subject: imperative, lowercase start, no trailing period, 72 chars max.
- Scope: package, module, or app name. Omit when the change spans the repo.
- Body (optional): why, not what. Wrap at 72.
- Breaking change: `type!:` plus a `BREAKING CHANGE: <what to migrate>` footer.
- Ticket footer: `Refs: REP-482`. GitHub/GitLab issue closed by this change: `Closes #91`.
- One logical change per commit. Tests go in the same commit as the code they cover.

## PR / MR

Title: same shape as a commit subject, 72 chars max. Prefix the ticket key when the repo does (`REP-482: fix ledger rounding`).

Body: short. Reviewer reads it in under a minute. Delete empty sections.

```markdown
## Summary
<1-3 bullets: what changed and why. Link the ticket.>

## Changes
- <grouped by area, one line each, only what a reviewer must know>

## Diagram
<Mermaid from call-graph. Only for non-trivial flow changes; mark changed/faulty nodes.>

## Testing
- <command run> — <result>
- <manual check, if any>

## Risks
<migrations, flags, rollout order, breaking changes. Omit if none.>

Closes #91 | Refs: REP-482
```

Rules: no file-by-file narration, no restating the diff, no marketing words. Draft PR when tests or review are not green yet.

## Releases

- Version: semver. Tag format follows existing tags (`v1.2.3` if any tag has the `v`, else `1.2.3`; `v` when there are no tags).
- Suggested bump: `~/.ai/bin/git-changelog --bump` (breaking = major, feat = minor, fix/perf = patch). Before 1.0.0, breaking = minor.
- Release notes: `~/.ai/bin/git-changelog --from <last-tag>`; add a one-paragraph highlight on top.
- Version bump commit: `chore(release): vX.Y.Z`. Annotated tag: `git tag -a vX.Y.Z -m "vX.Y.Z"`.
- Manifests to bump, if present: `package.json` (+ lockfile via the package manager, not by hand), `pyproject.toml`, `Cargo.toml`, `composer.json`, `pubspec.yaml`, `*.csproj`, `VERSION`, `version.go`/`__version__` constants found by `git grep -n "<old version>"`.
