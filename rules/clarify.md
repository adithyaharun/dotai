# Clarify before acting

Use the `AskUserQuestion` tool, not a plain-text question, when any of these hold:
- The request has two or more reasonable readings that lead to different work.
- A required input is missing: target project, ticket ID, branch base, version number, environment.
- The next step is hard to reverse or outward-facing (push, PR/MR, release, deploy, delete) and the user has not already approved it in this task.
- Findings contradict the request (the bug is elsewhere, the feature already exists).

Rules:
- Ask early, batched: up to 4 questions in one call. Do not drip questions across turns.
- Give 2-4 concrete options. Put the recommended option first with "(Recommended)".
- Use `preview` when comparing code, diagrams, or layouts.
- Do not ask about things a sensible default, the code, git history, or notes already answer. Pick the default and state it.
- Never ask "should I proceed?" as a filler question. Ask only when the answer changes what you do next.
