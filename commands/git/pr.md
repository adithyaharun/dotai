---
name: "Git: PR"
description: "Open a GitHub PR or GitLab MR for the current branch with a short, useful title and body (summary, changes, Mermaid diagram, testing, risks)."
argument-hint: "[--draft] [--base <branch>] [--reviewer <user>]"
allowed-tools: Read, Grep, Bash, AskUserQuestion, Skill
---

Open a PR/MR for the current branch. $ARGUMENTS

1. Load `dev-conventions`. Run `~/.ai/bin/git-forge`. `CLI_INSTALLED=no`: tell the user to install `gh` or `glab` and stop.
2. Branch not pushed or behind local: run `/git:push` first.
3. Existing open PR/MR for the branch (`gh pr view --json url` / `glab mr view`): offer to update its body instead of opening a new one.
4. Gather: `git log origin/<base>..HEAD --format='%s%n%b'`, `git diff origin/<base>...HEAD --stat`, the OpenSpec `proposal.md`/`design.md` if any, ticket, the last `/verify` result.
5. Repo template exists (`.github/pull_request_template.md`, `.gitlab/merge_request_templates/Default.md`): fill it. Else use the conventions template.
6. Diagram: include the Mermaid flow from `design.md` or `call-graph --mermaid` only when the change alters a flow across 3+ nodes. Mark changed nodes.
7. Testing section lists only commands that actually ran, with results.
8. Show title + body. `AskUserQuestion`: Create / Create as draft / Edit / Skip. Verify not green: default to draft.
9. Create with a body file (avoids shell quoting issues):
   - GitHub: `gh pr create --base <base> --head <branch> --title "<title>" --body-file <tmp> [--draft]`
   - GitLab: `glab mr create --target-branch <base> --source-branch <branch> --title "<title>" --description "$(cat <tmp>)" [--draft] --remove-source-branch`
10. Print the URL.
