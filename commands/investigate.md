---
name: "Investigate"
description: "Investigate a bug or issue. Traces the root cause, diagrams the faulty flow, then hands off to /dev for proposal, branch, fix, verify, and PR."
argument-hint: "<symptom | error | ticket>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion, Skill, WebFetch
model: sonnet
---

Investigate this bug or issue: $ARGUMENTS

## Steps

### 1. Extract any related ticket from Jira/GitHub Issue/Trello/Linear/Front/Strix if present

Scan `$ARGUMENTS` for:
- An issue URL: `linear.app/*/issue/*/` or `github.com/org/repo/-/issues/*/`
- A bare ticket ID matching patterns like `QR-123`, `GEN-456` (project prefix + number)

If ticket ticket reference is found:
- Use ToolSearch to find available MCP tools
- Authenticate if needed and fetch the full ticket: title, description, labels, comments, linked issues
- Use the ticket content as additional context for the investigation — it may contain reproduction steps, stack traces, or prior attempts

If no reference is found, proceed directly to investigation.

Symptom, expected behavior, or environment unclear (which endpoint, which tenant, prod vs staging, since when): ask with `AskUserQuestion` before tracing.

### 2. Check prior notes

Search `./notes/` for any notes relevant to the affected area. Run:
```
/note-search <keywords from the bug description>
```
Prior notes may explain why something was built a specific way, which would affect where to look.

### 3. Identify the affected project

Determine which project is affected. If the bug spans multiple projects, note both but focus investigation on the primary failure point first.

### 4. Investigate the codebase

Trace the bug systematically:
- Start from the error message, failing endpoint, or symptom described
- Follow the call chain: URL → view/handler → service → model/query
- Check for edge cases in data flow, middleware interference, or async timing issues
- Look for recent changes in relevant files via `git log -p -- <file>` if git is available
- Suspect a library behavior or version change: query Context7 for that library and version before concluding
- Run the `call-graph` skill on the failing path. Terminal: tree. Report and proposal: Mermaid with the faulty node marked `bug`

### 5. Report findings

Structure your output as:

**Root Cause**: One clear sentence identifying what is wrong and where.

**Evidence**: Relevant file paths and line numbers supporting the diagnosis.

**Flow**: The call-graph tree with the faulty node marked.

**Proposed Fix**: Specific code change(s) needed. Show the diff or describe exactly what to change.

**Caveats**: Any side-effects, related issues, or follow-up work the fix might require.

### 6. Propose and implement the fix

Run `/opsx:propose` with the root cause and proposed fix as the description. This generates a reviewable proposal and task breakdown before any code is written.

**IMPORTANT**: Never write any specs or notes in the `projects/` folder. Write it relative to the workspace root folder.

**NOTE**: If the issue scope is too small (one-line fix, one-character fix, typo, missing semi-colon, etc.), skip the proposal creation and begin implementation. If you are confused, ask the user back.

Once the user approves, continue with `/dev` from Phase 3 (branch, fix + regression test that fails before the fix, `/verify`, push, PR). Branch type is `fix` (or `hotfix` for production incidents).

**IMPORTANT**: ALWAYS delegate the tasks to dedicated sub-agents, NEVER run the solution by yourself. You ONLY instruct, you SHOULD NOT work on it.

### 7. Save a note if the investigation uncovered non-obvious context

If the root cause involved a non-obvious constraint (e.g., tenant schema isolation behaviour, a middleware interaction, a BullMQ retry quirk), save it using `/note-write` command so it could be retrievable by other agents in future sessions using `/note-search`.
