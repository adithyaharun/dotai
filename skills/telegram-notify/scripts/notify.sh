#!/usr/bin/env bash
# Send a Telegram notification to the user.
#
# Usage:
#   notify.sh "message text"
#   notify.sh "message text" --silent       # delivered without sound
#   notify.sh "message text" --no-context    # skip the project/tmux footer
#   notify.sh "❓ question" --buttons "A|B|C" [--buttons-rows N] [--qid ID]
#                                            # inline keyboard; tap answers arrive via read.sh
#   (flags can be combined, in any order, after the message)
#
# The script auto-appends a context footer so every ping says WHERE the work
# happened without Claude having to detect it:
#   - project: the git repo root basename, else the current dir basename
#   - tmux:    the session name if running inside tmux ($TMUX is set)
#
# Button callback_data is q<qid>:<index> (index from 0). --buttons-rows is buttons per row.
# Config: TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID from env, else keychain via `ai-secret`.
# TELEGRAM_API_BASE overrides https://api.telegram.org (for offline tests).
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

usage() {
  echo "usage: notify.sh \"message\" [--silent] [--no-context] [--no-typing] [--buttons \"A|B|C\" [--buttons-rows N] [--qid ID]]" >&2
  exit 1
}

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "error: message text required" >&2
  usage
fi

MESSAGE="$1"; shift
SILENT="false"
WANT_CONTEXT="true"
TYPING="true"
BUTTONS=""
PER_ROW=""
QID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --silent)       SILENT="true"; shift ;;
    --no-context)   WANT_CONTEXT="false"; shift ;;
    --no-typing)    TYPING="false"; shift ;;
    --buttons)      [[ $# -ge 2 && -n "$2" ]] || usage; BUTTONS="$2"; shift 2 ;;
    --buttons-rows) [[ "${2:-}" =~ ^[1-8]$ ]] || usage; PER_ROW="$2"; shift 2 ;;
    --qid)          [[ "${2:-}" =~ ^[A-Za-z0-9_-]{1,40}$ ]] || { echo "error: --qid must be 1-40 chars of [A-Za-z0-9_-]" >&2; exit 1; }
                    QID="$2"; shift 2 ;;
    *)              shift ;;
  esac
done
if [[ -z "$BUTTONS" && ( -n "$PER_ROW" || -n "$QID" ) ]]; then
  echo "error: --buttons-rows/--qid need --buttons" >&2
  exit 1
fi
if [[ -n "$BUTTONS" && -z "$QID" ]]; then
  QID="$(python3 -I -c 'import secrets; print(secrets.token_hex(3))')"
fi

if [[ "$WANT_CONTEXT" == "true" ]]; then
  PROJECT="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
  FOOTER=$'\n\n📁 '"${PROJECT}"
  if [[ -n "${TMUX:-}" ]]; then
    SESSION="$(tmux display-message -p '#S' 2>/dev/null || true)"
    [[ -n "$SESSION" ]] && FOOTER="${FOOTER}  ·  🖥 tmux: ${SESSION}"
  fi
  MESSAGE="${MESSAGE}${FOOTER}"
fi

# Emits a curl config (URL + JSON body) for stdin, keeping the token and chat id out of argv and off disk.
curl_config() {
  TOKEN="$TOKEN" CHAT_ID="$CHAT_ID" API_BASE="$API_BASE" MESSAGE="$MESSAGE" SILENT="$SILENT" \
    BUTTONS="$BUTTONS" PER_ROW="$PER_ROW" QID="$QID" python3 -I -c '
import json, os, sys
e = os.environ
body = {
    "chat_id": e["CHAT_ID"],
    "text": e["MESSAGE"],
    "parse_mode": "Markdown",
    "disable_notification": e["SILENT"] == "true",
}
if e["BUTTONS"]:
    labels = [l.strip() for l in e["BUTTONS"].split("|") if l.strip()]
    if not labels:
        print("error: --buttons has no labels", file=sys.stderr)
        sys.exit(1)
    if len(labels) > 100:
        print("error: at most 100 buttons", file=sys.stderr)
        sys.exit(1)
    per_row = int(e["PER_ROW"]) if e["PER_ROW"] else (1 if max(len(l) for l in labels) > 16 else 3)
    buttons = []
    for i, label in enumerate(labels):
        data = "q%s:%d" % (e["QID"], i)
        if len(data.encode()) > 64:
            print("error: callback_data over 64 bytes; use a shorter --qid", file=sys.stderr)
            sys.exit(1)
        buttons.append({"text": label, "callback_data": data})
    body["reply_markup"] = {"inline_keyboard": [buttons[i:i + per_row] for i in range(0, len(buttons), per_row)]}
def q(s):
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
print("url = " + q("%s/bot%s/sendMessage" % (e["API_BASE"], e["TOKEN"])))
print("header = \"Content-Type: application/json\"")
print("data-binary = " + q(json.dumps(body)))
'
}

# Show "typing…" briefly right before the reply lands; failures are ignored.
if [[ "$TYPING" == "true" ]]; then
  TOKEN="$TOKEN" CHAT_ID="$CHAT_ID" API_BASE="$API_BASE" python3 -I -c '
import json, os
e = os.environ
q = lambda s: "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
print("url = " + q("%s/bot%s/sendChatAction" % (e["API_BASE"], e["TOKEN"])))
print("header = \"Content-Type: application/json\"")
print("data-binary = " + q(json.dumps({"chat_id": e["CHAT_ID"], "action": "typing"})))
' | curl -s -X POST --max-time 10 -K - >/dev/null 2>&1 || true
  sleep 1.5
fi

CONFIG_OUT="$(curl_config)" || exit 1
RESPONSE="$(printf '%s\n' "$CONFIG_OUT" | curl -s -X POST --max-time 30 -K - 2>/dev/null)" || true

# Piped, not a here-string: bash 3.2 backs here-strings with temp files and the response holds the chat id.
MESSAGE_ID="$(printf '%s' "$RESPONSE" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except ValueError:
    sys.exit(1)
if d.get("ok") is not True:
    sys.exit(1)
print(d.get("result", {}).get("message_id", "?"))
' 2>/dev/null)" || MESSAGE_ID=""

if [[ -n "$MESSAGE_ID" ]]; then
  if [[ -n "$BUTTONS" ]]; then
    echo "sent: Telegram notification delivered (message ${MESSAGE_ID}, qid ${QID})"
  else
    echo "sent: Telegram notification delivered"
  fi
else
  echo "error: Telegram send failed" >&2
  [[ -n "$RESPONSE" ]] && echo "$RESPONSE" >&2
  exit 1
fi
