---
name: "Verify"
description: "Code review gate before push: run tests/lint/typecheck, review the diff for bugs, and scan for vulnerabilities and secrets. Reports blocking vs non-blocking findings."
argument-hint: "[base-ref] [--fix]"
allowed-tools: Read, Grep, Glob, Bash, Agent, AskUserQuestion
---

Verify the current changes. Base: `$ARGUMENTS` or the default branch from `~/.ai/bin/git-forge`.

Scope = `git diff <base>...HEAD` plus uncommitted changes (`git diff HEAD`). Review only this scope.

## 1. Detect the toolchain

Read `package.json` scripts, `Makefile`, `pyproject.toml`, `composer.json`, `Cargo.toml`, `go.mod`, CI config (`.github/workflows/*`, `.gitlab-ci.yml`). Prefer the exact commands CI runs. Ask once if no test command is discoverable.

## 2. Run checks (in parallel where independent)

- Tests: affected scope first, then the full suite if it runs in under ~5 minutes.
- Lint, format check, typecheck.
- Build, if CI builds.

Record command + pass/fail + the shortest decisive error line. Never mark a check as passed without running it.

## 3. Review the diff (parallel agents)

Launch in one message:
- `Agent(code-reviewer)`: correctness, edge cases, error handling, tests that actually assert the behavior, fit with project patterns, the code-comment rule.
- `Agent(code-reviewer)` security brief: injection (SQL/NoSQL/command/template), authn/authz gaps, IDOR, SSRF, path traversal, unsafe deserialization, XSS, CSRF, secrets in code or logs, weak crypto, missing input validation, tenant isolation.

Each returns `path:line — severity (blocker|major|minor) — problem — fix`.

## 4. Supply chain and secrets

- Dependency audit for changed manifests only: `npm audit --omit=dev` / `pnpm audit` / `pip-audit` / `composer audit` / `cargo audit` / `govulncheck ./...`, whichever applies and is installed. Report high/critical only.
- Secrets in the diff: `gitleaks protect --staged` if installed, else grep the diff for key-shaped strings (`AKIA`, `ghp_`, `glpat-`, `sk-`, `xox`, `-----BEGIN`, `password=`). Any hit is a blocker.
- New dependency added: check it is maintained and not typo-squatted.

## 5. Report

```
Checks:   tests ✓ (412) · lint ✓ · types ✗ (src/a.ts:12 TS2345)
Blockers: 2
  src/api/user.ts:88 — authz: missing owner check on PATCH — compare session.userId
  ...
Major:    1   Minor: 3
Verdict:  BLOCKED | PASS | PASS WITH NOTES
```

`--fix` or called from `/dev`: send blockers and majors to the implementing specialist agent, then re-run steps 2-4. Otherwise ask with `AskUserQuestion`: Fix blockers / Fix all / Accept as is.
