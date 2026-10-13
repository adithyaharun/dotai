# ~/.ai

Single source for Claude Code agents, commands, skills, rules, and memory. `link.sh` symlinks everything into each config dir (`~/.claude`, `~/.claude.sin`), so edits apply live in every profile.

```
CLAUDE.md, RTK.md   user memory (linked)
rules/              always-loaded rules: clarify, diagrams, context7
agents/             specialist sub-agents
commands/           slash commands (subdirs namespace: git/pr.md = /git:pr)
skills/             call-graph, dev-conventions, telegram-notify
bin/                ai-env, ai-secret, git-forge, git-changelog
mcp/                .mcp.json template
.env.example        secret reference template
```

## Setup

```fish
git clone <repo> ~/.ai     # or any directory
~/.ai/link.sh              # asks: source dir, which profiles to link into
fish_add_path ~/.ai/bin
```

`link.sh` asks for the source directory (default: where the script lives) and which Claude profile directories to link into (detected: `$CLAUDE_CONFIG_DIR`, `~/.claude`, `~/.claude.*`, `~/.claude-*`). Cloned somewhere other than `~/.ai`: it offers a `~/.ai` symlink, because skills, commands, and `.mcp.json` reference `~/.ai/...`.

Non-interactive: `link.sh --yes [--source DIR] [--profile DIR]...`. `ADOPT=1` backs up and replaces real files that differ.

## Workflow

| Step | Command |
|---|---|
| Discovery, options, findings note | `/analyze` |
| Bug root cause | `/investigate` |
| Whole lifecycle | `/dev <request\|ticket\|change>` |
| Proposal | `/opsx:propose` |
| Branch | `/git:branch` |
| Implement | `/opsx:apply` or `/code` |
| Tests + review + vuln scan | `/verify` |
| Commit + push | `/git:push` |
| PR / MR | `/git:pr` |
| Release | `/git:release [X.Y.Z]` |
| Flow diagram | `/call-graph <symbol> [--mermaid]` |

Branch, commit, PR, and release rules: `skills/dev-conventions/SKILL.md`.

## Secrets for `.mcp.json`

Never put a secret value in `.mcp.json`, `~/.claude.json`, or a script. Two mechanisms:

1. **`headersHelper`** (HTTP servers, preferred). Claude Code runs the command in a shell on each connect. No launcher needed. For project `.mcp.json` servers Claude Code strips credential-named vars from the helper env, so `ai-secret headers` falls back to the keychain.
   ```json
   "headersHelper": "$HOME/.ai/bin/ai-secret headers 'Authorization=Bearer {CONTEXT7_API_KEY}'"
   ```
2. **`${VAR}` expansion** (stdio `env`/`args`, or HTTP `headers`). Values must be in the environment when Claude starts, so launch through `ai-env`:
   ```fish
   function claude; ~/.ai/bin/ai-env -- command claude $argv; end   # ~/.config/fish/functions/claude.fish
   ```
   `ai-env` loads `~/.ai/.env`, then `<repo root>/.env`. A value of `keychain:NAME` reads keychain service `ai.NAME`; `op://...` uses 1Password CLI when installed. Variables already set in the shell win.

Store a secret:
```fish
ai-secret set CONTEXT7_API_KEY     # hidden prompt
ai-secret ls                       # names only
ai-env --check                     # which keys resolve, never prints values
```

Per workspace: copy `mcp/mcp.example.json` to `<workspace>/.mcp.json` (safe to commit) and keep a gitignored `<workspace>/.env` with `keychain:` refs (also safe, it holds no values).

## Why symlinks, not a plugin

Symlinks: live edits, no namespacing (`/dev`, not `/ai:dev`), works across both config dirs. Switch to a plugin (`.claude-plugin/plugin.json` + a local marketplace) when sharing with a team; plugin `userConfig` with `sensitive: true` then replaces `ai-secret` for shared keys.
