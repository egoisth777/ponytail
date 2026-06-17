param(
  [ValidateSet("all", "codex", "claude")]
  [string]$Target = "all",
  [switch]$DryRun,
  [switch]$Hub,
  [string]$HubRoot = (Join-Path $HOME ".omne\installation")
)

$ErrorActionPreference = "Stop"

# Update = reinstall the skills over whatever is already there. install.ps1 -Force
# replaces the old skill folder (or refreshes the hub copy and relinks), so there
# is nothing to do here but delegate and pass the hub options through.
& (Join-Path $PSScriptRoot "install.ps1") -Target $Target -Force -DryRun:$DryRun -Hub:$Hub -HubRoot $HubRoot
