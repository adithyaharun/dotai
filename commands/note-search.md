---
name: note-search
description: Retrieve relevant notes. ALWAYS use when the user needs to retrieve persisted knowledge from notes.
model: haiku
allowed-tools: Read, Grep, Bash
---

Retrieve relevant notes.

## Input
As the user instructs OR can be by filtered projects, topics, ticket numbers.

## Output
List of relevant note files based on the keywords.

## Note Format

Each notes have following frontmatter that can be used to filter:
```yaml
---
tags: [antd, ui] # topics, ticket numbers
projects: [minerapay-dashboard] # related projects
created: 2026-04-30 # when written
updated: 2026-05-02 # last edited
related: # linked notes/files
  - projects/minerapay-dashboard/src/router.ts
description: Simplify router configuration by extracting route definitions from `router.ts`.
---
```

### Location
As defined on CLAUDE.md OR to `notes/` relative to the workspace by default.

### Searching for note files with `grep`

**IMPORTANT**: Respect the frontmatter fields.

Search by topics, ticket number with `tags`:
```
grep -l "tags: .*keywords" notes/*.md
```

Search with `projects` field:
```
grep -l "tags: .*genium-investment-portal" notes/*.md
```

Search by date:
```
grep -l "created: 2025-04-30" notes/*.md
grep -l "updated: 2025-04-30" notes/*.md
```
**IMPORTANT**: Refrain from reading the whole file without checking the frontmatter:
```
awk '/^---$/{c++; if(c==2){exit;} next} c==1' .memory/not-sure-the-correct-note.md
```
