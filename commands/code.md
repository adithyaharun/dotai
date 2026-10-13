---
name: "Code"
description: "Generate code for this project. Routes to the right sub-agent based on tech stack."
argument-hint: "<request>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion, Skill
model: sonnet
---

Generate code based on the user's request: $ARGUMENTS

Implementation only. For the full flow with branch, verify, push, PR/MR, and release use `/dev`.

## Steps

### 1. Identify the project

Check the current directory of the project. User is typically structure the workspace as follows:
- /openspec (the Openspec specs/proposals/designs/archive)
- /notes (Notes related to the workspace, check point 2: Check for prior notes)
- /projects (the directory that contains all repos of the workspace)
- .mcp.json (registered MCPs, typically loaded by default)

If the current working directory having the same structure like above, then determine which project the request is for using these signals (in order):
- Current working directory (if inside a `projects/` subfolder)
- Explicit project name in the request
- File paths, framework names, or domain keywords in the request

If the project is ambiguous, ask with `AskUserQuestion` before proceeding.

### 2. Check for prior notes

Run `/note-search` with keywords from the request to surface any prior decisions or caveats stored in `./notes/`. If relevant notes are found, include their context when briefing the sub-agent.

### 3. Always propose before implementing

**Do not write any code yet.** Run `/opsx:propose` with a clear description of what will be built. This generates a proposal, design, and task breakdown for the user to review before any implementation begins.

**🚫 CRITICAL — specs live at the WORKSPACE ROOT, never at project level.** All OpenSpec artifacts (`proposal.md`, `design.md`, `specs/`, `tasks.md`) MUST be created under `$cwd/openspec/changes/<name>/`. NEVER under `projects/<name>/openspec/` even though its CLAUDE.md describes a project-scoped variant — the user's standing preference overrides that.

Before running `openspec new change` or any `openspec`/`/opsx:*` command:
- Change current working directory to the root workspace. Do NOT `cd` into `projects/<name>/`.
- After the proposal completes, verify location: the change dir MUST be `openspec/changes/<name>/` at root. If it landed in a project's `openspec/` by mistake, `mv` the whole change dir to the root `openspec/changes/` and re-verify with `openspec status --change <name>` run from root.

Wait for the user to confirm they want to proceed (e.g. via `/opsx:apply`) before spawning any sub-agent that writes code.

### 4. Spawn the sub-agent (only after proposal is approved)

Once the user approves the proposal, brief the sub-agent with:
- The exact task from `$ARGUMENTS`
- The target project path (`projects/<name>/`)
- Any relevant context from notes or prior exploration
- The approved proposal and task list from `/opsx:propose`
- The CLAUDE.md from the project folder if it exists
- Context7 doc facts for the libraries involved (query before briefing; sub-agents may not have Context7)
- The code-comment rule: no comments unless the why is non-obvious, one short line max
- Tests required: new behavior gets tests, bugfix gets a regression test

Not on a work branch yet: run `/git:branch` before spawning.

Use the Agent tool with the appropriate `subagent_type`. Pass the full working context so the agent does not need to re-discover the stack.

**IMPORTANT**: ALWAYS delegate the tasks to dedicated sub-agents, NEVER run the solution by yourself. You ONLY instruct, you SHOULD NOT work on it.

### 5. Resuming after a stalled or interrupted agent

If a dispatched agent stalls (lost connection, watchdog timeout, token exhaustion) and the user asks you to resume, do NOT restart from scratch and do NOT assume the agent finished:

1. **Find what actually changed on disk** — `git status --short` and `git diff HEAD` in the target project. A stalled agent usually left partial work. Check the index too: `git diff` alone can read empty if changes are staged, so use `git diff HEAD`.
2. **Assess that work against the approved tasks.md** before adding to it. Treat the agent's own claims as unverified — it stopped mid-flight, so nothing it said it did is confirmed until you see it in the diff.
3. **Re-spawn an agent to finish the remaining tasks**, briefing it with what is already done so it does not redo or revert completed work.
4. Never Read the stalled agent's transcript/output file — it will overflow context.

### 6. Save a note if the solution contains non-obvious decisions

If the implementation required a non-obvious architectural decision, workaround, or constraint discovery, save it using `/note-write` so future sessions can retrieve it via `/note-search`.
