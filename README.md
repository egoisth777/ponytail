# Ponytail fork

Opinionated fork of the Ponytail skills.

This fork is skills/instructions-first: use `AGENTS.md`, point an agent at
`skills/`, or use one of the retained thin adapters. It intentionally does not
ship Claude marketplace packaging or a Codex plugin manifest.

## Install

Windows:

```powershell
.\install.ps1 -Target all
```

Linux/macOS:

```sh
sh ./install.sh --target all
```

Use `-Force` / `--force` to replace an existing local install. Restart Codex or
Claude after installing.
