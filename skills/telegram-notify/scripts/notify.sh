#!/usr/bin/env bash
# Send a Telegram notification to the user.
#
# Usage:
#   notify.sh "message text"
#   notify.sh "message text" --silent       # delivered without sound
#   notify.sh "message text" --no-context    # skip the project/tmux footer
#   (flags can be combined, in any order, after the message)
#
# The script auto-appends a context footer so every ping says WHERE the work
# happened without Claude having to detect it:
#   - project: the git repo root basename, else the current dir basename
#   - tmux:    the session name if running inside tmux ($TMUX is set)
#
# Config: TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID from env, else keychain via `ai-secret`.
set -euo pipefail

kc() { security find-generic-password -a "$USER" -s "ai.$1" -w 2>/dev/null || true; }
TOKEN="${TELEGRAM_BOT_TOKEN:-$(kc TELEGRAM_BOT_TOKEN)}"
CHAT_ID="${TELEGRAM_CHAT_ID:-$(kc TELEGRAM_CHAT_ID)}"
if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then
  echo "error: TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID missing; run: ai-secret set TELEGRAM_BOT_TOKEN" >&2
  exit 1
fi

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "error: message text required" >&2
  echo "usage: notify.sh \"message\" [--silent] [--no-context]" >&2
  exit 1
fi

MESSAGE="$1"; shift
SILENT="false"
WANT_CONTEXT="true"
for arg in "$@"; do
  case "$arg" in
    --silent)     SILENT="true" ;;
    --no-context) WANT_CONTEXT="false" ;;
  esac
done

if [[ "$WANT_CONTEXT" == "true" ]]; then
  PROJECT="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
  FOOTER=$'\n\n📁 '"${PROJECT}"
  if [[ -n "${TMUX:-}" ]]; then
    SESSION="$(tmux display-message -p '#S' 2>/dev/null || true)"
    [[ -n "$SESSION" ]] && FOOTER="${FOOTER}  ·  🖥 tmux: ${SESSION}"
  fi
  MESSAGE="${MESSAGE}${FOOTER}"
fi

RESPONSE="$(curl -sS -X POST \
  "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${MESSAGE}" \
  --data-urlencode "parse_mode=Markdown" \
  --data-urlencode "disable_notification=${SILENT}")"

if echo "$RESPONSE" | grep -q '"ok":true'; then
  echo "sent: Telegram notification delivered"
else
  echo "error: Telegram send failed" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
