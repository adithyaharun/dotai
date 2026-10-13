---
name: "Git: Push"
description: "Group changes into Conventional Commits, show them, and push the current branch after confirmation."
argument-hint: "[--yes]"
allowed-tools: Read, Grep, Bash, AskUserQuestion, Skill
---

Commit and push the current work. $ARGUMENTS

1. Load `dev-conventions`. Refuse to commit on the default branch: offer `/git:branch` first.
2. `git status --short` and `git diff HEAD --stat`. Exclude anything that looks generated, local-only, or secret (`.env*`, `*.pem`, credentials, large binaries). Ask if unsure.
3. Split into logical commits (code + its tests together). Stage paths explicitly; never `git add -A` blindly.
4. Write messages per the conventions, ticket footer from the branch name (`REP-482-*` gives `Refs: REP-482`; `gh-91-*` gives `Closes #91` only when the change resolves the issue).
5. Pre-commit hook fails: fix the cause, re-stage, create a new commit. Never `--no-verify`, never amend a commit that is already pushed.
6. Show the plan: `git log origin/<base>..HEAD --oneline` plus the branch and remote. Without `--yes`, confirm with `AskUserQuestion` (Push / Edit messages / Stop).
7. `git push -u origin <branch>`. Rejected because the remote moved: `git pull --rebase`, re-run tests, ask again. Never force-push a shared branch; `--force-with-lease` only on the user's own branch and only after asking.
