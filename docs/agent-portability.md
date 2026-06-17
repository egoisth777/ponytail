# Agent Portability

Ponytail keeps the core behavior in `skills/` and `AGENTS.md`. This fork supports
three hosts only — Codex, Claude, and pi — and ships local installers instead of
marketplace or plugin packaging.

## Supported Hosts

| Host | Files | Install | Notes |
|------|-------|---------|-------|
| Claude | `skills/` | `install.ps1` / `install.sh` copy `skills/ponytail*` into `~/.claude/skills` (or `$CLAUDE_CONFIG_DIR/skills`) | Claude Code auto-discovers the skills; `/ponytail*` invoke them. |
| Codex | `skills/`, `AGENTS.md` | same installers copy `skills/ponytail*` into `~/.codex/skills` (or `$CODEX_HOME/skills`) | `@ponytail` invokes the skill; `AGENTS.md` at the repo root supplies always-on rules. |
| pi | `pi-extension/`, `skills/`, `hooks/` | none — loaded in place via the `pi` field in `package.json` | Package extension injects the ruleset each turn through the shared instruction builder and registers the `/ponytail` commands. |

## Installers

- `install.{ps1,sh}` — copy the skill folders into the Codex and/or Claude skill
  dirs (`--target all|codex|claude`, `--force`, `--dry-run`).
- `update.{ps1,sh}` — reinstall over the existing copy (delegates to install with
  force).
- `uninstall.{ps1,sh}` — remove the `ponytail*` skill folders from those dirs.

### Central hub (`--hub`)

`install`/`update`/`uninstall` take `-Hub`/`--hub` to keep one central copy and
symlink the agents at it instead of copying. Real files live under
`~/.omne/installation/<agent>` (override with `-HubRoot`/`--hub-root`); each
agent's skill dir gets per-skill directory symlinks into the hub, so other skills
in that dir are left alone.

```powershell
./install.ps1 -Hub                      # ~/.omne/installation/{codex,claude}
./update.ps1  -Hub                      # refresh hub copies + relink
./uninstall.ps1 -Hub                    # remove links and hub copies
```

Windows needs Developer Mode (or an elevated shell) to create symlinks; on
Linux/macOS `ln -s` is unprivileged. The by-agent layout duplicates a skill once
per agent — point both agents at a shared `-HubRoot` subtree by hand if you want
true dedup.

pi needs no installer: `package.json` points pi at `./pi-extension/index.js` and
`./skills`, so it loads from the repo in place.

## Adapter Rule

Keep adapters thin. When a host supports skills or hooks, point it at the existing
`skills/` and `hooks/` files rather than copying rule text. Do not add Claude
marketplace packaging, a Codex plugin manifest, or other host adapters back to
this fork unless it is explicitly wanted.

## Portable Behavior

- `skills/ponytail/SKILL.md`: lazy senior dev mode
- `skills/ponytail-review/SKILL.md`: over-engineering review
- `skills/ponytail-audit/SKILL.md`: whole-repo over-engineering audit
- `skills/ponytail-debt/SKILL.md`: harvest `ponytail:` shortcuts into a tracked ledger
- `skills/ponytail-help/SKILL.md`: quick reference
- `AGENTS.md`: compact always-on instruction set for agents without skill support
