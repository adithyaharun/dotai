# Diagrams

For every non-trivial feature or bugfix, use the `call-graph` skill to map the affected flow before proposing changes.
- Terminal output: ASCII tree (terminals do not render Mermaid).
- Persisted artifacts (OpenSpec `design.md`, PR/MR body, notes): Mermaid, because GitHub and GitLab render it.
- For a bugfix, mark the faulty node. For a feature, mark new or changed nodes.
- Skip the diagram for one-file, one-function changes (typo, config value, copy change).
