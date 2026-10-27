---
name: "Dev"
description: "End-to-end feature/fix workflow: proposal, branch, implement + tests, verify, push, PR/MR, archive the OpenSpec change before merge, optional release. Gates before every outward-facing step."
argument-hint: "<request | ticket | openspec-change-name> [--release X.Y.Z] [--auto]"
allowed-tools: Read, Grep, Glob, Bash, Agent, AskUserQuestion, Skill, Write, Edit
---

Run the development workflow for: $ARGUMENTS

Load the `dev-conventions` skill first. Track phases with the task list. Report one line per finished phase.

`--auto`: skip the approval gates for branch and push, still stop for PR and release. Without `--auto`, every outward-facing step (push, PR/MR, tag, release) needs an explicit yes in this task.

## Phase 0 — Intake

1. Classify: `feat`, `fix`, `hotfix`, `refactor`, `chore`, `docs`, `perf`.
2. Find the ticket key / issue number in the input or the current branch name.
3. Find the target project (workspace `projects/<name>/`, cwd, or ask).
4. Check `openspec list --json` (workspace root). Input names an active change: resume it, skip to the first incomplete phase.
5. Size: **tiny** (one file, obvious, no behavior risk), **small**, **large**.
6. Anything ambiguous: one `AskUserQuestion` batch now, not later.

## Phase 1 — Understand

- Came from `/analyze` or `/investigate` in this session, or tiny: reuse findings, skip.
- Otherwise: run `/analyze` (feature) or `/investigate` (bug) up to their gate, then continue here.

## Phase 2 — Propose

- Tiny: skip. Write the plan as 2-3 bullets in chat.
- Else: `/opsx:propose` from the workspace root. `design.md` must hold the Mermaid diagram from `call-graph`.
- Gate: `AskUserQuestion` "Approve proposal?" — Approve / Revise (say what) / Stop.

## Phase 3 — Branch

Run `/git:branch` with the type, ticket, and slug. It handles the base branch, dirty tree, and naming.

## Phase 4 — Develop

- Proposal exists: `/opsx:apply <change>`. Else brief one specialist sub-agent directly.
- Every brief includes: target path, task list, project CLAUDE.md, relevant notes, Context7 doc facts, and the user's code-comment rule (no comments unless the why is non-obvious; one short line max).
- Tests are part of the task: new behavior gets tests, a bugfix gets a regression test that fails before the fix.
- Orchestrate, do not implement. Exception: tiny changes, which you may make yourself.

## Phase 5 — Verify

Run `/verify`. Blocking findings: send back to the implementing agent, then re-run `/verify`. Max 3 loops; then stop and report.

## Phase 6 — Commit and push

Run `/git:push`. Gate unless `--auto`.

## Phase 7 — PR / MR

Run `/git:pr`. Always gated: show title and body, ask Create / Create as draft / Edit / Skip.

## Phase 8 — Archive, then merge

The OpenSpec change is archived inside the same PR/MR, never in a follow-up PR. Code and main specs land in one merge.

1. Wait until review is done and CI is green. Archive last: a review fix after archiving must edit `openspec/specs/` directly.
2. Run `/opsx:archive <change>` on the feature branch with spec sync. Replace any `TBD` Purpose placeholder in new `openspec/specs/*/spec.md`. Run `openspec validate --all --strict`.
3. Commit `chore(openspec): archive <change>` and push (gated unless `--auto`). Wait for CI.
4. Merge only when the user asks. Use the repo's merge style (squash by default).

PR/MR not merged in this run: tell the user to run this phase before merging. No proposal (tiny): skip.

## Phase 9 — Release (only when asked)

Only when the user asked for a release (`--release`, or in words). Run `/git:release [version]`. It asks for the version when none was given.

## Finish

- `/note-write` when the work surfaced a non-obvious decision or constraint.
- Change not archived yet: remind that Phase 8 runs before merge.
- User asked for a ping: `telegram-notify`.
- Final summary: branch, commits, PR/MR URL, test result, release URL (if any).

## Resuming

Interrupted run: read `git status --short`, `git log <base>..HEAD --oneline`, `tasks.md` checkboxes, and open PRs for the branch. Continue from the first incomplete phase. Never trust a stalled agent's claims without the diff.
