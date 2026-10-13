---
name: "Analyze"
description: "Structured discovery before any task or proposal: clarify, map code, fetch docs, weigh options, write a findings note, then decide whether to propose."
argument-hint: "<idea | feature | question | ticket>"
allowed-tools: Read, Grep, Glob, Bash, Agent, AskUserQuestion, Skill, WebFetch, Write
---

Analyze before committing to work: $ARGUMENTS

Read-only on code. The only file this command writes is the findings note. No proposal, branch, or code until the gate in step 8.

Use `/investigate` instead when the input is a defect with a symptom. Use `/opsx:explore` for open-ended thinking with no deliverable.

## 1. Clarify the question

Restate the goal in one sentence. If the goal, scope, target project, or success criteria are unclear, ask with `AskUserQuestion` (batch up to 4). Do not continue on a guess.

## 2. Pull existing context (in parallel)

- Ticket key or issue URL in the input: fetch it via the tracker MCP (ToolSearch for the tool). Read description, comments, linked issues.
- `/note-search` with keywords from the request.
- `openspec list --json` from the workspace root: an active change may already cover this.

## 3. Locate the code

Workspace layout `openspec/`, `notes/`, `projects/`: decide which project(s) are in scope. Ask if ambiguous.

Delegate broad sweeps to `Agent(Explore)` (or `caveman:cavecrew-investigator`) with a precise brief. Keep only conclusions in this context.

## 4. Map the affected flow

Run the `call-graph` skill on each entry point the change touches. Terminal: tree. Findings note: Mermaid, with nodes the change would add or modify marked `changed`.

## 5. Fetch current docs

For every library, framework, SDK, or external API the change relies on, query Context7 (`resolve-library-id`, then `query-docs` one concept per call). Record version-specific facts that affect the design (deprecations, new APIs, limits).

## 6. Weigh options

For each viable approach (2-3, not more):
- How it works, in two lines.
- Files/modules touched, rough size (S/M/L).
- Risks: data migration, breaking API, performance, security, rollout.
- Fit with existing patterns in the codebase.

Recommend one. Say what would change the recommendation.

## 7. Write the findings note

`/note-write` to `notes/YYYY-MM-DD-[TICKET-]analysis-<slug>.md` with tags `[analysis, ...]`:

```markdown
## Goal
## Context        (ticket, prior notes, active changes)
## Current flow   (Mermaid)
## Docs findings  (library@version: fact, link)
## Options        (table: approach | size | risks)
## Recommendation
## Open questions
```

## 8. Gate

Print a 5-line summary: goal, recommendation, size, top risk, open questions. Then `AskUserQuestion`:
- "Create proposal" (Recommended when no blocking open questions): run `/opsx:propose` seeded with the note path, recommendation, and Mermaid diagram.
- "Go straight to /dev": only for S-size changes with no open questions.
- "Explore further": name what to dig into next.
- "Stop here": keep the note.
