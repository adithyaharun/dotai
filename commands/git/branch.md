---
name: "Git: Branch"
description: "Create a work branch named by the user's conventions (feat/*, fix/*, REP-123-*, gh-123-*, gl-123-*) from an up-to-date base."
argument-hint: "<ticket | issue URL | description | exact-branch-name>"
allowed-tools: Read, Grep, Bash, AskUserQuestion, Skill
---

Create a branch for: $ARGUMENTS

1. Load `dev-conventions`. Run `~/.ai/bin/git-forge` and the history checks from that skill.
2. Derive the name with the branch table. Input is already a valid branch name: use it as is.
   GitHub/GitLab issue URL or `#123`: use the forge from `git-forge` for the `gh-`/`gl-` prefix and the issue title for the slug.
3. Already on a non-default branch with commits ahead of base: ask whether to reuse it, stack on it, or branch from base.
4. Dirty working tree: ask — carry changes over (default, `git switch -c` keeps them) / stash / stop. Never discard.
5. Update base without touching local work: `git fetch origin <base>`, then `git switch -c <name> origin/<base>`.
6. Name exists locally or on the remote: ask — switch to it / pick a new suffix.
7. Do not push yet. Print: `branch <name> from origin/<base> @ <short-sha>`.
