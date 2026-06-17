#!/usr/bin/env sh
set -eu

# Update = reinstall the skills over whatever is already there. install.sh --force
# removes the old skill folder and copies the current one, so just delegate and
# pass through any --target/--dry-run flags.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec sh "$dir/install.sh" --force "$@"
