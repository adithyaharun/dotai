#!/usr/bin/env bash
# Symlink this repo into Claude config (profile) dirs. Safe to re-run.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: link.sh [--source DIR] [--profile DIR]... [--yes]

  --source DIR    repo to link from (default: this script's directory)
  --profile DIR   Claude config dir to link into; repeatable (default: ask, or all detected)
  --yes           accept defaults without prompting
  ADOPT=1         back up and replace real files/dirs that differ
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE=""; PROFILES=(); YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --profile) PROFILES+=("$2"); shift 2 ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

INTERACTIVE=0
[ $YES = 0 ] && [ -t 0 ] && INTERACTIVE=1

ask() {
  local prompt=$1 default=$2 reply
  if [ $INTERACTIVE = 1 ]; then
    read -r -p "$prompt [$default]: " reply || true
    printf '%s' "${reply:-$default}"
  else
    printf '%s' "$default"
  fi
}

expand() { case "$1" in "~") printf '%s' "$HOME" ;; "~/"*) printf '%s' "$HOME/${1#\~/}" ;; *) printf '%s' "$1" ;; esac; }

# 1. Source directory
if [ -z "$SOURCE" ]; then
  SOURCE="$(ask "Source directory (this repo)" "${SCRIPT_DIR/#$HOME/~}")"
fi
SOURCE="$(expand "$SOURCE")"
[ -d "$SOURCE/skills" ] && [ -d "$SOURCE/commands" ] || { echo "error: $SOURCE is not an ai repo (no skills/ or commands/)" >&2; exit 1; }
AI="$(cd "$SOURCE" && pwd -P)"

# 2. Profile directories
if [ ${#PROFILES[@]} -eq 0 ]; then
  CANDIDATES=()
  for d in "${CLAUDE_CONFIG_DIR:-}" "$HOME/.claude" "$HOME"/.claude.* "$HOME"/.claude-*; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    [ -e "$d/settings.json" ] || [ -d "$d/projects" ] || continue
    d="$(cd "$d" && pwd -P)"
    case " ${CANDIDATES[*]:-} " in *" $d "*) continue ;; esac
    CANDIDATES+=("$d")
  done

  if [ ${#CANDIDATES[@]} -eq 0 ]; then
    PROFILES+=("$(expand "$(ask "No profile found. Profile directory" "~/.claude")")")
  elif [ $INTERACTIVE = 1 ]; then
    echo "Detected Claude profile directories:"
    i=1
    for d in "${CANDIDATES[@]}"; do echo "  $i) ${d/#$HOME/~}"; i=$((i + 1)); done
    echo "  Enter numbers (e.g. \"1 3\"), \"a\" for all, or paths separated by spaces."
    sel="$(ask "Profiles" "a")"
    for tok in $sel; do
      case "$tok" in
        a|all) PROFILES+=("${CANDIDATES[@]}") ;;
        *[!0-9]*) PROFILES+=("$(expand "$tok")") ;;
        *) [ "$tok" -ge 1 ] && [ "$tok" -le ${#CANDIDATES[@]} ] \
             && PROFILES+=("${CANDIDATES[$((tok - 1))]}") \
             || echo "  ! ignoring invalid choice: $tok" ;;
      esac
    done
  else
    PROFILES=("${CANDIDATES[@]}")
  fi
fi
[ ${#PROFILES[@]} -gt 0 ] || { echo "error: no profile selected" >&2; exit 1; }

echo
echo "source:   ${AI/#$HOME/~}"
for p in "${PROFILES[@]}"; do echo "profile:  ${p/#$HOME/~}"; done
echo

STAMP="$(date +%Y%m%d%H%M%S)"

link() {
  local src=$1 dst=$2 label=$3
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
      mv "$dst" "$dst.bak-$STAMP"
      ln -s "$src" "$dst"
      echo "  + adopted  $label (identical file backed up)"
    elif [ "${ADOPT:-0}" = "1" ]; then
      mv "$dst" "$dst.bak-$STAMP"
      ln -s "$src" "$dst"
      echo "  + adopted  $label (old copy at $(basename "$dst").bak-$STAMP)"
    else
      echo "  ! skip     $label (real path differs; re-run with ADOPT=1 to back up and replace)"
    fi
  elif [ "$(readlink "$dst" 2>/dev/null)" = "$src" ]; then
    echo "  = ok       $label"
  elif [ -L "$dst" ]; then
    ln -sfn "$src" "$dst"
    echo "  ~ relinked $label"
  else
    ln -sfn "$src" "$dst"
    echo "  + linked   $label"
  fi
}

# Skills, commands, and docs reference ~/.ai/...; keep that path valid for clones elsewhere.
STABLE="$HOME/.ai"
if [ "$AI" != "$(cd "$STABLE" 2>/dev/null && pwd -P || true)" ]; then
  if [ -e "$STABLE" ] && [ ! -L "$STABLE" ]; then
    echo "~/.ai exists and is not this repo; paths like ~/.ai/bin/ai-env will not point here."
  else
    ans="$(ask "Point ~/.ai at ${AI/#$HOME/~} so ~/.ai/... paths resolve? (y/n)" "y")"
    case "$ans" in y|Y|yes) link "$AI" "$STABLE" "~/.ai" ;; esac
  fi
  echo
fi

for cfg in "${PROFILES[@]}"; do
  mkdir -p "$cfg"
  echo "${cfg/#$HOME/~}"
  for f in CLAUDE.md RTK.md; do
    [ -f "$AI/$f" ] && link "$AI/$f" "$cfg/$f" "$f"
  done
  for d in agents commands rules; do
    [ -d "$AI/$d" ] || continue
    n=$(find "$AI/$d" -name '*.md' | wc -l | tr -d ' ')
    link "$AI/$d" "$cfg/$d" "$d/ ($n files)"
  done
  mkdir -p "$cfg/skills"
  for s in "$AI"/skills/*/; do
    name=$(basename "$s")
    link "$AI/skills/$name" "$cfg/skills/$name" "skills/$name"
  done
  for l in "$cfg"/skills/*; do
    if [ -L "$l" ] && [ ! -e "$l" ]; then
      rm "$l"
      echo "  - pruned   skills/$(basename "$l") (broken link)"
    fi
  done
done

case ":$PATH:" in
  *":$HOME/.ai/bin:"*|*":$AI/bin:"*) ;;
  *) echo
     echo "Add ~/.ai/bin to PATH:"
     echo "  fish: fish_add_path ~/.ai/bin"
     echo "  zsh/bash: export PATH=\"\$HOME/.ai/bin:\$PATH\"" ;;
esac
