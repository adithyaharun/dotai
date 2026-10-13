---
name: "Git: Release"
description: "Cut a semver release: bump manifest versions, changelog from commits since the last tag, annotated tag, GitHub/GitLab release. Asks for the version if not given."
argument-hint: "[X.Y.Z | major | minor | patch]"
allowed-tools: Read, Grep, Bash, Edit, AskUserQuestion, Skill
---

Release: $ARGUMENTS

Run only when the user explicitly asked for a release in this conversation.

1. Load `dev-conventions`. Run `~/.ai/bin/git-forge`.
2. Preconditions: clean tree, on the default branch (or a `release/*` branch), up to date with the remote, CI green on HEAD (`gh run list -b <branch> -L 1` / `glab ci status`). Fail any: report and stop.
3. Version:
   - Given `X.Y.Z`: validate it is greater than `LATEST_TAG`.
   - Given `major|minor|patch`: compute from `LATEST_TAG`.
   - Not given: compute the suggestion with `~/.ai/bin/git-changelog --bump`, then `AskUserQuestion` with the suggested version first "(Recommended)", the other two bumps, and Other.
4. Notes: `~/.ai/bin/git-changelog --from <LATEST_TAG>`. Write a one-paragraph highlight on top. Show it.
5. Bump manifests listed in the conventions. Use the ecosystem tool when it exists (`npm version --no-git-tag-version X.Y.Z`, `poetry version X.Y.Z`, `cargo set-version`); else edit the field. Verify with `git diff`.
6. Delivery: `AskUserQuestion` — Commit and tag on `<default>` (Recommended when not protected) / Release PR (`release/vX.Y.Z`, tag after merge) / Stop.
   Release PR: branch, commit `chore(release): vX.Y.Z`, `/git:pr`, then stop and tell the user to re-run `/git:release X.Y.Z` after merge to tag.
7. Direct: commit `chore(release): vX.Y.Z`, `git tag -a vX.Y.Z -m "vX.Y.Z"`, confirm once more, then `git push origin <default> vX.Y.Z`.
8. Release object with notes from a file:
   - GitHub: `gh release create vX.Y.Z --title "vX.Y.Z" --notes-file <tmp> --verify-tag`
   - GitLab: `glab release create vX.Y.Z --name "vX.Y.Z" --notes-file <tmp>`
9. Print the release URL.
