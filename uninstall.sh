#!/usr/bin/env sh
set -eu

target=all
dry_run=0
hub=0
hub_root="$HOME/.omne/installation"

usage() {
  cat <<'EOF'
Usage: sh uninstall.sh [--target all|codex|claude] [--dry-run]
                       [--hub] [--hub-root PATH]

Removes the installed ponytail skill folders.
Codex:  $CODEX_HOME/skills or ~/.codex/skills
Claude: $CLAUDE_CONFIG_DIR/skills or ~/.claude/skills

--hub also removes the staged copies under PATH/<agent>
(default ~/.omne/installation/<agent>).
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      target="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --hub)
      hub=1
      shift
      ;;
    --hub-root)
      hub_root="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$target" in
  all|codex|claude) ;;
  *)
    echo "--target must be all, codex, or claude" >&2
    exit 2
    ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
skill_root="$script_dir/skills"
has_skills=0

for skill in "$skill_root"/ponytail*; do
  if [ -d "$skill" ]; then
    has_skills=1
    break
  fi
done

[ "$has_skills" -eq 1 ] || {
  echo "No ponytail skills found in $skill_root" >&2
  exit 1
}

codex_skill_dir() {
  if [ -n "${CODEX_HOME:-}" ]; then
    printf '%s/skills\n' "$CODEX_HOME"
  else
    printf '%s/.codex/skills\n' "$HOME"
  fi
}

claude_skill_dir() {
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    printf '%s/skills\n' "$CLAUDE_CONFIG_DIR"
  else
    printf '%s/.claude/skills\n' "$HOME"
  fi
}

assert_child_path() {
  parent=$1
  child=$2
  case "$child" in
    "$parent"/*) ;;
    *)
      echo "Refusing to delete outside target directory: $child" >&2
      exit 1
      ;;
  esac
}

# rm on a symlink (even to a dir) removes only the link, never the target's
# contents, as long as there is no trailing slash.
remove_at() {
  path=$1
  label=$2
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    printf 'Not present: %s\n' "$path"
    return
  fi
  if [ "$dry_run" -eq 1 ]; then
    printf 'Would remove %s %s\n' "$label" "$path"
    return
  fi
  rm -rf "$path"
  printf 'Removed %s %s\n' "$label" "$path"
}

uninstall_skills() {
  name="$1"
  agent_key="$2"
  dest_root="$3"

  for skill in "$skill_root"/ponytail*; do
    [ -d "$skill" ] || continue
    dest="$dest_root/$(basename "$skill")"
    assert_child_path "$dest_root" "$dest"
    remove_at "$dest" skill
  done

  if [ "$hub" -eq 1 ]; then
    hub_agent="$hub_root/$agent_key"
    for skill in "$skill_root"/ponytail*; do
      [ -d "$skill" ] || continue
      hub_dest="$hub_agent/$(basename "$skill")"
      assert_child_path "$hub_agent" "$hub_dest"
      remove_at "$hub_dest" "hub copy"
    done
  fi
}

case "$target" in
  all)
    uninstall_skills Codex codex "$(codex_skill_dir)"
    uninstall_skills Claude claude "$(claude_skill_dir)"
    ;;
  codex)
    uninstall_skills Codex codex "$(codex_skill_dir)"
    ;;
  claude)
    uninstall_skills Claude claude "$(claude_skill_dir)"
    ;;
esac

echo "Restart Codex or Claude to drop the skills."
