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
suppress the auto footer, `--buttons "A|B|C"` to attach tap answers (see
*Asking the user a question*).

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

## Reading replies

The user can answer from their phone. `read.sh` prints the text messages and
button taps they sent to the bot. Only the private chat `TELEGRAM_CHAT_ID` counts,
and only messages its own user sent; groups and other chats are skipped:

```bash
bash ~/.claude/skills/telegram-notify/scripts/read.sh             # new messages, then mark read
bash ~/.claude/skills/telegram-notify/scripts/read.sh --wait 1800 # block up to N secs for one
bash ~/.claude/skills/telegram-notify/scripts/read.sh --peek      # show without marking read
```

Each message prints as a block; `in reply to:` appears only when the user used
Telegram's reply on a message, and quotes its first line:

```
--- 2026-10-26 14:02:11 (message 812)
in reply to: ❓ Which migration strategy?
2
```

Exit codes: `0` messages printed, `3` none (or `--wait` timed out, prints
`no new messages`), `1` error (missing credentials, network, Telegram 409 when a
webhook is set or another `read.sh` is already polling). The read offset lives
in `${XDG_STATE_HOME:-~/.local/state}/telegram-notify/offset`.

**Asking the user a question:** prefer tap buttons. Pass the options with
`--buttons` (`|`-separated, recommended option first and marked), and lead the
text with ❓ and the question on its first line:

```bash
bash ~/.claude/skills/telegram-notify/scripts/notify.sh "❓ *Which migration strategy?*
Online backfill keeps writes live; offline is faster but needs a 10 min window." \
  --buttons "Online backfill (Recommended)|Offline with window|Hold off"
# sent: Telegram notification delivered (message 812, qid 3fa9c1)
```

Remember the `message` and `qid` from the output; they map the tap back to the
question. Each button's callback data is `q<qid>:<index>` (index from 0, in
`--buttons` order). `--qid ID` sets the id yourself (1-40 chars of
`[A-Za-z0-9_-]`); `--buttons-rows N` sets buttons per row (default: 3 per row,
1 per row when any label is over 16 chars). Labels can't contain `|`.

When the user taps, `read.sh` answers the tap (the phone shows `Chose: <label>`),
removes the buttons from the question so it can't be tapped twice, and prints:

```
--- 2026-10-26 14:02:11 (message 812)
in reply to: ❓ Which migration strategy?
button: q3fa9c1:0 Online backfill (Recommended)
```

or in `--follow`: `TG 2026-10-26 14:02:11 #812 [button q3fa9c1:0] Online backfill (Recommended)`.
`#812` is the question's message id; the timestamp is when the tap was read.
Free-text replies still work alongside buttons (the user may type instead of
tapping), so handle both. Without buttons, number the options in the text.
Run `read.sh --wait <secs>` as a background Bash command, or rely on a running
`--follow`, and act on the answer when it arrives. With several open questions
the qid (buttons) or Telegram's reply (`in reply to:`) maps each answer to its
question. Run only one `read.sh` at a time. `--peek` shows taps without
acknowledging them.

**Watching continuously:** Claude runs `read.sh --follow` under the Monitor tool;
re-arm on expiry. It long-polls forever, marks each batch read, and prints every
message as one line (each line becomes a notification):

```
TG 2026-10-26 14:02:11 #812 [re: ❓ Which migration strategy?] 2
```

`[re: …]` appears only for Telegram replies (first 60 chars of the quoted
message); newlines in the text become ` / `. Network and API errors are retried
every 10s (stderr only). `TG-ERROR 409 another poller is running` means another
poller holds the bot; it retries every 60s. A lock in the state dir allows one
`--follow` at a time (a second exits `1`), and one-shot `read.sh` refuses to run
while a watcher is active. `--follow` cannot be combined with `--wait`/`--peek`.

## Security note

No secret lives in this skill. If the script errors with "missing", tell the user
to run `~/.ai/bin/ai-secret set TELEGRAM_BOT_TOKEN` and `... set TELEGRAM_CHAT_ID`.
Never read, print, or echo the token. Neither script prints it, and both keep it
and the chat id out of the process list (curl gets its config on stdin).
`TELEGRAM_API_BASE` overrides the API host for offline tests only: `https://api.telegram.org` or a loopback `http://127.0.0.1[:port]` / `http://localhost[:port]`; anything else exits 1.
