---
name: call-graph
description: >
  Render how code flows through a system as a simple indented call graph — one node per call,
  grouped by entry point, each node carrying its file:line. Produces a scannable ASCII arrow tree
  in the terminal and a Mermaid flowchart for persisted artifacts, never a dense prose paragraph. Trigger in two cases only. (1) Explicit
  invoke: the user names this skill or runs /call-graph — e.g. "use call-graph", "/call-graph
  CheckUniqueProjectName", "call-graph the login flow". (2) Asked to analyze or explain how
  something works — e.g. "explain how the login endpoint works", "how does the export job run",
  "walk me through what happens when a project is created", "how does X reach the DB", "analyze
  how Y flows end to end", "what's the request flow for Z". Not for executing code, writing tests,
  writing the code itself, or doing a feature-impact / root-cause analysis — when "analyze" means
  scope-the-change or find-the-bug, use analyze / investigate instead (they end in a note, this
  ends in a tree). Also invoked by /analyze, /investigate, /dev and /git:pr to diagram the flow a
  feature or fix touches; there it emits Mermaid for the persisted artifact. Flags: --mermaid,
  --tree, --both.
argument-hint: "<symbol | endpoint | flow> [--mermaid|--tree|--both]"
allowed-tools: Read, Grep, Glob, Bash
---

# Call graph

Produce a simple indented call graph showing how a symbol flows through the codebase. The goal: a
reader skims the tree and grasps the whole path in seconds — counting hops by eye, jumping to any
node via its `file:line`.

## The pain this fixes

The format this skill replaces is the one-liner that crams everything into a single stream:

> `endpoint (endpoints/) → transport (handler.go:36-83) → route (server.go:184) → usecase → service → repo`

To read that, the eye has to tokenize arrows, parentheses, paths, and line ranges all at once, with
no visual hierarchy. Indentation carries the structure instead, and each node gets its own line. The
arrows no longer have to do the work of grammar.

## When invoked

1. **Identify the target.** A function, method, endpoint/handler, CLI command, cron job, message
   consumer, or struct/type the user named. If none is named, ask once rather than guessing.
2. **Read the real code.** Grep/Glob/Read the definition and follow each call. Do not infer a path
   from names alone — names suggest, code decides. When a call-hierarchy tool is connected, use it
   to avoid manual trace errors (e.g. the GoLand `analyze_calls` for Go, or an IDE/LSP call
   hierarchy / outgoing-calls). Treat the tool as a shortcut to the same evidence, not as a
   substitute for reading the call sites.
3. **Walk the path from the entry point downward.** For each node record: the symbol name, its
   layer/component, and `file:line`.
4. **Stop the trace at real boundaries** — standard library, framework/external packages, the
   data-access call itself (the SQL query, RPC, external HTTP API), or a mock/interface seam. Tag
   the stop rather than silently truncating: `[DB]`, `[RPC]`, `[external]`, `[stdlib]`, `[mock]`.
   A silent truncation looks like an exhaustive trace; a tagged stop reads honestly.
5. **Pick the format by destination** (flag wins):
   - Terminal reply only: ASCII tree (below). Terminals do not render Mermaid.
   - Going into a file or PR/MR (OpenSpec `design.md`, notes, PR/MR body): Mermaid (see
     "Mermaid format"). GitHub and GitLab render it.
   - Both destinations, or `--both`: tree in the reply, Mermaid in the artifact.
6. **Emit** in the chosen format.

## Output format

An indented arrow tree. One node per line. A grouping label opens each tree; the location sits
inline, right of the symbol.

```
<entry-point group label>
  → <symbol>                    <file>:<line>
    → <symbol>                  <file>:<line>-<end>   (note)
      → <symbol>                <file>:<line>         [boundary tag]
```

Worked example — tracing `CheckUniqueProjectName` from its HTTP entry to the database:

```
HTTP handlers
  → CheckProjectName              endpoints/check_project_name.go
    → handleCheckProjectName      transport/handler.go:36-83
      → POST /projects/:id/name   server.go:184-187  (privateMiddlewares)
        → CheckUniqueProjectName  usecases/project/check.go
          → Project.ExistsByName  services/project.go:58
            → projects.Exists     repos/project.go:112  [DB boundary]
```

Node-by-node rules:

- **Indent one level per call hop.** Two spaces per level, `→` as the node marker. The indentation
  *is* the graph — it must reflect real caller→callee depth. A misaligned tree is a wrong tree.
- **Group label** (first line, no arrow): the entry-point category — "HTTP handlers",
  "CLI command: reconcile", "Cron: nightly-rollup", "gRPC: UserService.Create",
  "Message consumer: order.created", "Event: user.signed_up". One tree per entry point; tracing
  several entry points means several trees, not one merged blob.
- **Symbol** = the actual function/method name as written in the code. Keep it short; do not
  restate the path here — the path lives in the location field.
- **Location** = `path/to/file.ext:line` (or `:start-end` for a span). Project-relative; trim a long
  shared prefix only if what remains is still unambiguous. This is how the reader jumps to the code,
  so it has to be a real location. If you could not confirm one, write `(location unconfirmed)`
  rather than inventing a plausible-looking line number — a fabricated `file:line` is the worst
  failure mode of this skill.
- **Note** (optional, in parens after the location): only when it adds something a name cannot —
  middleware wrapping (`privateMiddlewares`), a branch condition (`on 404`), a fan-out hint
  (`calls both`), a queue/topic, a feature flag. Leave it off in the common case; note noise defeats
  the format.
- **Boundary tag** (optional, bracketed): `[DB]`, `[RPC]`, `[external]`, `[stdlib]`, `[mock]`,
  `[interface]` — marks where the trace deliberately stops. See step 4.

Alignment of the location column is nice-to-have when widths are similar; drop it the moment it
would wrap a narrow terminal. Scannability comes from indentation and one-node-per-line, not from
perfect padding.

## Mermaid format

Same trace, same evidence rules. Use `flowchart TD` for a call path, `sequenceDiagram` when the
point is ordering across services (request/response, queues, retries).

- One node per symbol. Label: `Symbol<br/>file:line`. Same location rules as the tree.
- Boundaries: cylinder for DB `[(DB)]`, stadium for external `([external API])`.
- One `subgraph` per entry point, mirroring the tree group labels.
- Change marking: `classDef changed fill:#fde68a,stroke:#b45309` for new/changed nodes (feature),
  `classDef bug fill:#fecaca,stroke:#b91c1c` for the faulty node (bugfix). Add a short edge label
  on the faulty edge (`-- "nil when 404" -->`).
- Node IDs: short and stable (`h1`, `uc1`), never raw symbols with dots or colons.
- Keep under ~25 nodes. Collapse an out-of-scope fan-out into one `...` node.

```mermaid
flowchart TD
  subgraph HTTP["HTTP: POST /projects/:id/name"]
    h1["handleCheckProjectName<br/>transport/handler.go:36"]
    uc1["CheckUniqueProjectName<br/>usecases/project/check.go:22"]
    s1["Project.ExistsByName<br/>services/project.go:58"]
    r1[("projects.Exists<br/>repos/project.go:112")]
  end
  h1 --> uc1 --> s1 -- "case-sensitive compare" --> r1
  class s1 bug
  classDef bug fill:#fecaca,stroke:#b91c1c
```

## Fan-out

When a node calls two or more things that matter, show each as a sibling child at the same indent —
do not linearize a fan-out into a fake sequential chain, because the reader will infer a call order
that does not exist:

```
  → Create
    → validate             service.go:58
    → repo.Create          repo.go:77
    → emit                 events.go:44
```

If only one branch of a fan-out is in scope for what the user asked, trace that branch and leave a
one-line note for the others (`+ also calls audit.Log, out of scope here`) so the fan-out is visible
without expanding it.

## Two shapes

**Entry-point trace (default).** One symbol followed down through layers to a boundary. This is the
shape of the worked example and the majority of requests.

**Type / struct map.** When the target is a struct/class/interface rather than a single call, make
the type the root, its methods the first level, and what each method calls beneath:

```
ProjectService                  services/project.go:18
  → Create                      services/project.go:40
    → validate                  services/project.go:58
    → repo.Create               repos/project.go:77     [DB]
  → ExistsByName                services/project.go:90
    → repo.ExistsByName         repos/project.go:112    [DB]
```

Pick by what the user pointed at: a callable → entry-point trace; a type → type map. If unsure, the
entry-point trace is the safer default.

## What "easy to digest" means here

A cold reader should be able to: see the whole path at a glance, count the hops by eye, and jump to
any node via its `file:line`. Three signs the draft is wrong — rewrite, don't ship:

- it reads like a paragraph (→ break it into the tree);
- a node has no real location (→ go read the code, or mark it unconfirmed);
- two arrows sit on the same line, or indentation does not match call depth (→ fix the structure,
  the indentation *is* the information).

## Before you print

Reread as a cold reader: can the path be followed from indentation alone? Is every location real?
Did the trace stop at a real boundary or just where patience ran out? For Mermaid: are node IDs
safe, labels quoted, and does it parse (no unescaped `()`, `:` or `"` inside labels)? Then output
the tree in a fenced block (or Mermaid in a ```mermaid block) and stop — do not add a prose retelling of what the tree already shows. If the user
asked for prose commentary, give it after the tree, separately, so the tree stays copy-pasteable.
