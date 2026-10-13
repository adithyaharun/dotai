---
name: telegram-notify
description: >-
  Send the user a Telegram push notification when their task finishes. Use
  whenever the user asks to be pinged, notified, messaged, texted, or alerted on
  Telegram (or "tg") about completion of work you're doing — e.g. "tell me on
  Telegram when you're done", "ping me on tg when the build passes", "notify me
  after the migration", "i'm grabbing lunch, message me when the tests are
  green". Also fire it when the user asked earlier in the session to be notified
  on completion and a long-running task then wraps up (success OR failure). The
  message auto-includes which project and tmux session the work ran in. Do NOT
  use this for building a Telegram feature into an app, notifying merchants/third
  parties, debugging the notify.sh script itself, or notifying via a different
  channel (Slack, email, desktop, PR comment) — it only sends Telegram pings to
  the user about Claude's own task completion.
---

# Telegram notify

Send the user a Telegram message so they don't have to babysit a long task. The
point is timing and signal: fire the notification **after** the work is actually
finished (or has clearly failed), and make the message say what happened in one
glance — not "task done" but *which* task and whether it succeeded.

## How to send

Run the bundled script. It handles auth and the API call:

```bash
bash ~/.claude/skills/telegram-notify/scripts/notify.sh "your message"
```

Flags (any order, after the message): `--silent` for no-sound delivery (routine
FYIs; keep sound for things the user is actively waiting on), `--no-context` to
suppress the auto footer.

The script reads `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` from the environment
if set, otherwise from the macOS keychain (`ai-secret set TELEGRAM_BOT_TOKEN`,
`ai-secret set TELEGRAM_CHAT_ID`). Never pass the token or chat id yourself.

## Project + tmux context is automatic

The script appends a footer to every message on its own — you do **not** write
it into the text. It detects:

- **project**: the git repo root basename, else the working-dir basename. In
  this workspace that's the specific project you were in (`minerapay-api`,
  `minerapay-dashboard`, etc.), which is exactly what the user wants to see since
  the repo is a multi-project monorepo.
- **tmux session**: included only when running inside tmux (`$TMUX` set), shown
  as the session name.

So a sent message looks like:

```
✅ Migration applied cleanly. All 142 tests green.

📁 minerapay-api  ·  🖥 tmux: work
```

Don't duplicate the project or tmux name in your own text — let the footer carry
it. Pass `--no-context` only if the user explicitly doesn't want it.

## What to put in the message

Write a **short 1–3 paragraph summary** of what you did — the way a colleague
would text you a status update, enough that the user knows whether to come back
to the terminal without re-reading scrollback. A bulleted list inside the
summary is fine when you changed several distinct things.

- Lead with an emoji status: ✅ success, ❌ failure, ⚠️ partial / needs attention.
- Name the actual task ("deploy to staging", "Prisma migration", "jest suite"),
  not a generic "your task".
- Give concrete result facts: tests passed count, files changed, the error class
  that broke it. Keep paragraphs tight — it's a phone notification, not a report.
- The script sends with Markdown parse mode, so use `*bold*` and `` `code` `` to
  make it skimmable.

**Example — success (multi-line summary, lead emoji, footer added by script):**
```bash
bash ~/.claude/skills/telegram-notify/scripts/notify.sh "✅ *Deposit webhook refactor done.*

Reworked the Giga callback handler to verify signatures before parsing, and moved the ledger write inside the same transaction so a failed credit can't leave a dangling deposit.

Touched: \`giga.service.ts\`, \`giga.controller.ts\`, plus 3 new spec cases. Full suite green (142)."
```

**Example — failure:**
```bash
bash ~/.claude/skills/telegram-notify/scripts/notify.sh "❌ *Build failed.* \`tsc\` errored in \`app/routes/deposit\` — a missing type on the new \`WhitelistIp\` query. Stopped before deploy; needs a look."
```

## When to fire

Send exactly one notification when the task reaches a terminal state — done, or
failed in a way that needs the user. Don't ping on intermediate steps (that's
noise that trains the user to ignore it), and don't ping before you've confirmed
the result, or the message will lie. If a task fails partway, still notify — the
user asked to be told when it's *over*, and "it broke" is the most useful ping
of all.

## Security note

No secret lives in this skill. If the script errors with "missing", tell the user
to run `~/.ai/bin/ai-secret set TELEGRAM_BOT_TOKEN` and `... set TELEGRAM_CHAT_ID`.
Never read, print, or echo the token.
