---
name: note-write
description: Write efficient notes for future references. ALWAYS use when the user wants to write notes.
model: haiku
allowed-tools: Read, Write, Grep
---

Write efficient notes for future references.

## Input
The context of current conversation OR as the user instructs.

## Output
A markdown file in a designated location.

## Note Format

The note markdown file should have a frontmatter as follow:
```yaml
---
tags: [go, http] # topics, ticket numbers
projects: [user-management-svc, sso-frontend] # related projects
created: 2026-04-30 # when written
updated: 2026-05-02 # last edited
related: # linked notes/files
  - go-context.md
  - blabla.json 
description: What this is about in short.
---
```

### Location
As defined on CLAUDE.md OR to `notes/` relative to the workspace by default.

### Writing
- Write note filename in format `{YYYY}-{MM}-{DD}-descriptive-slug.md` OR if ticket number is supplied `{YYYY}-{MM}-{DD}-{TICKET-NUMBER}-descriptive-slug.md`
- Note filenames should be all lowercase
- Note can have supporting files and should be referred on frontmatter's `related`