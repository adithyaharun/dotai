#!/usr/bin/env bash
# Read the user's replies sent to the bot.
#
# Usage:
#   read.sh                 # print new messages since the last read, then mark them read
#   read.sh --wait 1800     # block up to N seconds until at least one new message arrives
#   read.sh --peek          # print new messages without marking them read
#   read.sh --follow        # watch forever; one line per message: TG <ts> #<id> [re: ...] <text>
#                           # button taps: TG <ts> #<question id> [button q<qid>:<index>] <label>
#
# Prints only text and button taps from the private chat TELEGRAM_CHAT_ID; taps are acknowledged and their
# buttons removed (not in --peek). Never prints the token. TELEGRAM_API_BASE overrides the API host.
# Exit codes: 0 messages printed, 3 none (or --wait timed out), 1 error.
set -euo pipefail

kc() { security find-generic-password -a "$USER" -s "ai.$1" -w 2>/dev/null || true; }
TOKEN="${TELEGRAM_BOT_TOKEN:-$(kc TELEGRAM_BOT_TOKEN)}"
CHAT_ID="${TELEGRAM_CHAT_ID:-$(kc TELEGRAM_CHAT_ID)}"
API_BASE="${TELEGRAM_API_BASE:-https://api.telegram.org}"
if [[ "$API_BASE" != "https://api.telegram.org" && ! "$API_BASE" =~ ^http://(127\.0\.0\.1|localhost)(:[0-9]{1,5})?$ ]]; then
  echo "error: TELEGRAM_API_BASE must be https://api.telegram.org or a loopback test server" >&2
  exit 1
fi
if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then
  echo "error: TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID missing; run: ai-secret set TELEGRAM_BOT_TOKEN" >&2
  exit 1
fi

usage() { echo "usage: read.sh [--wait SECONDS] [--peek] | read.sh --follow" >&2; exit 1; }
WAIT=0
WAIT_SET="false"
PEEK="false"
FOLLOW="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait) [[ "${2:-}" =~ ^[0-9]+$ ]] || usage; WAIT="$2"; WAIT_SET="true"; shift 2 ;;
    --peek) PEEK="true"; shift ;;
    --follow) FOLLOW="true"; shift ;;
    *) usage ;;
  esac
done
if [[ "$FOLLOW" == "true" && ( "$WAIT_SET" == "true" || "$PEEK" == "true" ) ]]; then
  usage
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/telegram-notify"
OFFSET_FILE="$STATE_DIR/offset"
LOCK="$STATE_DIR/follow.lock"
mkdir -p "$STATE_DIR"
OFFSET="$(cat "$OFFSET_FILE" 2>/dev/null || true)"
[[ "$OFFSET" =~ ^[0-9]+$ ]] || OFFSET=0

# URL goes via stdin config to stay out of argv; curl's stderr is dropped because it can echo the URL.
fetch() {
  printf 'url = "%s/bot%s/getUpdates?offset=%s&timeout=%s&allowed_updates=%%5B%%22message%%22%%2C%%22callback_query%%22%%5D"\n' \
    "$API_BASE" "$TOKEN" "$OFFSET" "$1" | curl -s --max-time "$(( $1 + 15 ))" -K - 2>/dev/null
}

# FORMAT line|block: first output line is "<next_offset|-> <shown> <callbacks>"; messages follow.
# FORMAT actions: a curl config that answers each callback and strips its buttons. Exit 2 means 409 conflict.
parse() {
  CHAT_ID="$CHAT_ID" FORMAT="$1" TOKEN="$TOKEN" API_BASE="$API_BASE" python3 -I -c '
import json, os, sys, datetime
try:
    data = json.load(sys.stdin)
except ValueError:
    print("error: Telegram returned an unreadable response", file=sys.stderr)
    sys.exit(1)
if not data.get("ok"):
    desc = data.get("description", "unknown")
    if data.get("error_code") == 409:
        print("error: Telegram 409 conflict (%s); a webhook is set on the bot or another read.sh is already polling" % desc, file=sys.stderr)
        sys.exit(2)
    print("error: Telegram getUpdates failed: %s" % desc, file=sys.stderr)
    sys.exit(1)
chat = os.environ["CHAT_ID"]
fmt = os.environ["FORMAT"]
one_line = fmt == "line"

def first_line(text, fallback="(non-text message)"):
    return ((text or "").splitlines() or [fallback])[0]

def label_for(cq):
    for row in (cq.get("message") or {}).get("reply_markup", {}).get("inline_keyboard", []):
        for b in row:
            if b.get("callback_data") == cq.get("data"):
                return b.get("text", "")
    return "(unknown option)"

def q(s):
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

def call(method, body):
    url = "%s/bot%s/%s" % (os.environ["API_BASE"], os.environ["TOKEN"], method)
    return "\n".join([
        "url = " + q(url),
        "header = \"Content-Type: application/json\"",
        "data-binary = " + q(json.dumps(body)),
        "max-time = 10",
    ])

last = None
out = []
calls = []
callbacks = 0
for u in data.get("result", []):
    last = u["update_id"]
    cq = u.get("callback_query")
    if cq:
        cm = cq.get("message") or {}
        if not (cm.get("chat", {}).get("type") == "private" and str(cm.get("chat", {}).get("id")) == chat and str(cq.get("from", {}).get("id")) == chat):
            continue
        callbacks += 1
        label = label_for(cq)
        cb_data = cq.get("data", "")
        if fmt == "actions":
            calls.append(call("answerCallbackQuery", {"callback_query_id": cq.get("id"), "text": ("Chose: " + label)[:200]}))
            if cm.get("message_id") is not None and cm.get("chat", {}).get("id") is not None:
                calls.append(call("editMessageReplyMarkup", {"chat_id": cm["chat"]["id"], "message_id": cm["message_id"], "reply_markup": {"inline_keyboard": []}}))
            continue
        ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        mid = cm.get("message_id", "?")
        if one_line:
            out.append("TG %s #%s [button %s] %s" % (ts, mid, cb_data, " / ".join(label.splitlines())))
        else:
            lines = ["--- %s (message %s)" % (ts, mid)]
            if cm.get("text"):
                lines.append("in reply to: %s" % first_line(cm["text"])[:80])
            lines.append("button: %s %s" % (cb_data, label))
            out.append("\n".join(lines))
        continue
    m = u.get("message") or {}
    if m.get("chat", {}).get("type") != "private" or str(m.get("chat", {}).get("id")) != chat or str(m.get("from", {}).get("id")) != chat or "text" not in m:
        continue
    ts = datetime.datetime.fromtimestamp(m["date"]).strftime("%Y-%m-%d %H:%M:%S")
    reply = m.get("reply_to_message")
    quoted = first_line(reply.get("text")) if reply else ""
    if one_line:
        re_part = "[re: %s] " % quoted[:60] if reply else ""
        out.append("TG %s #%s %s%s" % (ts, m["message_id"], re_part, " / ".join(m["text"].splitlines())))
    else:
        lines = ["--- %s (message %s)" % (ts, m["message_id"])]
        if reply:
            lines.append("in reply to: %s" % quoted[:80])
        lines.append(m["text"])
        out.append("\n".join(lines))
if fmt == "actions":
    print("\nnext\n".join(calls))
    sys.exit(0)
print("%s %d %d" % ("-" if last is None else last + 1, len(out), callbacks))
for o in out:
    print(o)
'
}

# Answer taps so the spinner stops and remove their buttons; failures are ignored.
ack_callbacks() {
  printf '%s' "$1" | parse actions 2>/dev/null | curl -s -K - >/dev/null 2>&1 || true
}

lock_pid() { cat "$LOCK/pid" 2>/dev/null || true; }
follower_running() { local p; p="$(lock_pid)"; [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null; }

take_lock() {
  if ! mkdir "$LOCK" 2>/dev/null; then
    if follower_running; then
      echo "error: another read.sh --follow is already running (pid $(lock_pid))" >&2
      exit 1
    fi
    rm -rf "$LOCK"
    mkdir "$LOCK" 2>/dev/null || { echo "error: could not take the follow lock" >&2; exit 1; }
  fi
  echo $$ >"$LOCK/pid"
  trap 'rm -rf "$LOCK"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

follow() {
  take_lock
  local resp out rc next shown cbs
  while :; do
    if ! resp="$(fetch 50)"; then
      echo "warn: could not reach Telegram; retrying in 10s" >&2
      sleep 10
      continue
    fi
    rc=0
    out="$(printf '%s' "$resp" | parse line)" || rc=$?
    if (( rc == 2 )); then
      echo "TG-ERROR 409 another poller is running"
      sleep 60
      continue
    elif (( rc != 0 )); then
      echo "warn: Telegram API error; retrying in 10s" >&2
      sleep 10
      continue
    fi
    read -r next shown cbs <<<"${out%%$'\n'*}"
    if (( shown > 0 )); then
      printf '%s\n' "${out#*$'\n'}"
    fi
    if [[ "$next" != "-" ]]; then
      OFFSET="$next"
      echo "$next" >"$OFFSET_FILE"
    fi
    if (( cbs > 0 )); then
      ack_callbacks "$resp"
    fi
  done
}

if [[ "$FOLLOW" == "true" ]]; then
  follow
fi

if follower_running; then
  echo "error: a read.sh --follow watcher is running (pid $(lock_pid)); its output already has new messages" >&2
  exit 1
fi

deadline=$(( $(date +%s) + WAIT ))
while :; do
  remaining=$(( deadline - $(date +%s) ))
  poll=0
  (( remaining > 0 )) && poll=$(( remaining < 50 ? remaining : 50 ))
  if ! resp="$(fetch "$poll")"; then
    if (( deadline - $(date +%s) > 5 )); then
      sleep 5
      continue
    fi
    echo "error: could not reach Telegram (network failure or timeout)" >&2
    exit 1
  fi
  out="$(printf '%s' "$resp" | parse block)" || exit 1
  read -r next shown cbs <<<"${out%%$'\n'*}"
  if [[ "$next" != "-" ]]; then
    # Peek advances in memory only, past skipped updates; it exits before any shown ones get confirmed.
    OFFSET="$next"
    [[ "$PEEK" == "true" ]] || echo "$next" >"$OFFSET_FILE"
  fi
  if (( cbs > 0 )) && [[ "$PEEK" != "true" ]]; then
    ack_callbacks "$resp"
  fi
  if (( shown > 0 )); then
    printf '%s\n' "${out#*$'\n'}"
    exit 0
  fi
  if (( $(date +%s) >= deadline )); then
    echo "no new messages"
    exit 3
  fi
done
