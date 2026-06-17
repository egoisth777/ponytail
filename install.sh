#!/usr/bin/env sh
set -eu

target=all
force=0
dry_run=0
hub=0
hub_root="$HOME/.omne/installation"

usage() {
  cat <<'EOF'
Usage: sh install.sh [--target all|codex|claude] [--force] [--dry-run]
                     [--hub] [--hub-root PATH]

Installs the local ponytail skill folders without plugin or marketplace setup.
Codex:  $CODEX_HOME/skills or ~/.codex/skills
Claude: $CLAUDE_CONFIG_DIR/skills or ~/.claude/skills

--hub stages the skills under PATH/<agent> (default ~/.omne/installation/<agent>)
and symlinks them into each agent's skill dir instead of copying.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      target="${2:-}"
      shift 2
      ;;
    --force)
      force=1
      shift
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
      echo "Refusing to write outside target directory: $child" >&2
      exit 1
      ;;
  esac
}

install_copy() {
  name="$1"
  dest_root="$2"

  conflicts=""
  for skill in "$skill_root"/ponytail*; do
    [ -d "$skill" ] || continue
    dest="$dest_root/$(basename "$skill")"
    assert_child_path "$dest_root" "$dest"
    if [ -e "$dest" ] && [ "$force" -ne 1 ]; then
      conflicts="${conflicts}${dest}
"
    fi
  done

  if [ "$dry_run" -eq 1 ]; then
    printf 'Would install %s skills to %s\n' "$name" "$dest_root"
    if [ -n "$conflicts" ]; then
      printf 'Existing skills would block install without --force:\n%s' "$conflicts"
    fi
    return
  fi

  if [ -n "$conflicts" ]; then
    printf '%s already has ponytail skills installed:\n%sRerun with --force to replace them.\n' "$name" "$conflicts" >&2
    exit 1
  fi

  mkdir -p "$dest_root"
  dest_root=$(cd "$dest_root" && pwd)
  for skill in "$skill_root"/ponytail*; do
    [ -d "$skill" ] || continue
    dest="$dest_root/$(basename "$skill")"
    assert_child_path "$dest_root" "$dest"
    rm -rf "$dest"
    cp -R "$skill" "$dest_root/"
    printf 'Installed %s -> %s\n' "$(basename "$skill")" "$dest"
  done
}

install_hub() {
  name="$1"
  agent_key="$2"
  dest_root="$3"
  hub_agent="$hub_root/$agent_key"

  # A real (non-symlink) skill dir at the destination blocks unless --force.
  conflicts=""
  for skill in "$skill_root"/ponytail*; do
    [ -d "$skill" ] || continue
    dest="$dest_root/$(basename "$skill")"
    assert_child_path "$dest_root" "$dest"
    if [ -e "$dest" ] && [ ! -L "$dest" ] && [ "$force" -ne 1 ]; then
      conflicts="${conflicts}${dest}
"
    fi
  done

  if [ "$dry_run" -eq 1 ]; then
    printf 'Would stage %s skills in %s and symlink them into %s\n' "$name" "$hub_agent" "$dest_root"
    if [ -n "$conflicts" ]; then
      printf 'Existing real dirs would block without --force:\n%s' "$conflicts"
    fi
    return
  fi

  if [ -n "$conflicts" ]; then
    printf '%s has real skill dirs that --hub would replace with symlinks:\n%sRerun with --force.\n' "$name" "$conflicts" >&2
    exit 1
  fi

  # 1. Real files live in the hub.
  mkdir -p "$hub_agent"
  hub_agent=$(cd "$hub_agent" && pwd)
  for skill in "$skill_root"/ponytail*; do
    [ -d "$skill" ] || continue
    hub_dest="$hub_agent/$(basename "$skill")"
    assert_child_path "$hub_agent" "$hub_dest"
    rm -rf "$hub_dest"
    cp -R "$skill" "$hub_agent/"
    printf 'Staged %s -> %s\n' "$(basename "$skill")" "$hub_dest"
  done

  # 2. The agent's skill dir holds symlinks into the hub.
  mkdir -p "$dest_root"
  dest_root=$(cd "$dest_root" && pwd)
  for skill in "$skill_root"/ponytail*; do
    [ -d "$skill" ] || continue
    link="$dest_root/$(basename "$skill")"
    target="$hub_agent/$(basename "$skill")"
    assert_child_path "$dest_root" "$link"
    ln -sfn "$target" "$link"
    printf 'Linked %s: %s -> %s\n' "$(basename "$skill")" "$link" "$target"
  done
}

install_target() {
  if [ "$hub" -eq 1 ]; then
    install_hub "$1" "$2" "$3"
  else
    install_copy "$1" "$3"
  fi
}

case "$target" in
  all)
    install_target Codex codex "$(codex_skill_dir)"
    install_target Claude claude "$(claude_skill_dir)"
    ;;
  codex)
    install_target Codex codex "$(codex_skill_dir)"
    ;;
  claude)
    install_target Claude claude "$(claude_skill_dir)"
    ;;
esac

echo "Restart Codex or Claude to pick up new skills."
