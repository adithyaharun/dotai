#!/usr/bin/env bash
# Symlink ~/.ai into every Claude config dir. Safe to re-run.
set -euo pipefail
AI="$HOME/.ai"
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

for cfg in "$HOME/.claude" "$HOME/.claude.sin"; do
  [ -d "$cfg" ] || continue
  echo "${cfg/#$HOME/~}"
  for f in CLAUDE.md RTK.md; do
    [ -f "$AI/$f" ] && link "$AI/$f" "$cfg/$f" "$f"
  done
  for d in agents commands rules; do
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
  *":$AI/bin:"*) ;;
  *) echo
     echo "Add ~/.ai/bin to PATH:"
     echo "  fish: fish_add_path ~/.ai/bin"
     echo "  zsh/bash: export PATH=\"\$HOME/.ai/bin:\$PATH\"" ;;
esac
