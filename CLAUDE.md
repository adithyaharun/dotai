@RTK.md

# Code comments

Default to **no comments**. Write one only when the *why* is non-obvious — a hidden constraint, a subtle invariant, a workaround for a specific bug, behaviour that would surprise a reader.

Never write:
- Multi-paragraph or multi-line comment blocks, or verbose docstrings.
- Comments that narrate what the code does (well-named identifiers already do that).
- Restatements of spec/design/task text inside the source file.
- References to the current task, fix, or callers ("used by X", "added for the Y flow", "handles issue #123") — those belong in the PR description and rot as the code changes.

One short line is the maximum for the comments that do earn their place. If removing a comment would not confuse a future reader, do not write it.

Applies to every language and every project, and must be passed into every sub-agent brief that writes code.

# Cloudflare

When interacting with Cloudflare, use the cf CLI unless the project has a Wrangler configuration file.

# Workflow

- Discovery before work: `/analyze`. Bugs: `/investigate`. Free-form thinking: `/opsx:explore`. Test a feature or app with scenarios: `/test`.
- Build a feature or fix end to end: `/dev` (proposal, `/git:branch`, implement + tests, `/verify`, `/git:push`, `/git:pr`, `/opsx:archive` in the same PR before merge, `/git:release` only when asked).
- Git naming, commit, PR/MR, and release rules live in the `dev-conventions` skill.
- Secrets: never inline in `.mcp.json`. Use `${VAR}` (resolved by `~/.ai/bin/ai-env`) or `headersHelper` with `~/.ai/bin/ai-secret`.
