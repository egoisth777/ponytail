param(
  [ValidateSet("all", "codex", "claude")]
  [string]$Target = "all",
  [switch]$DryRun,
  [switch]$Hub,
  [string]$HubRoot = (Join-Path $HOME ".omne\installation")
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$SkillRoot = Join-Path $Root "skills"
$Skills = Get-ChildItem -LiteralPath $SkillRoot -Directory -Filter "ponytail*" |
  Sort-Object Name

if (-not $Skills) {
  throw "No ponytail skills found in $SkillRoot"
}

function Get-CodexSkillDir {
  if ($env:CODEX_HOME) { return (Join-Path $env:CODEX_HOME "skills") }
  return (Join-Path $HOME ".codex\skills")
}

function Get-ClaudeSkillDir {
  if ($env:CLAUDE_CONFIG_DIR) { return (Join-Path $env:CLAUDE_CONFIG_DIR "skills") }
  return (Join-Path $HOME ".claude\skills")
}

function Assert-ChildPath([string]$Parent, [string]$Child) {
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  $childFull = [System.IO.Path]::GetFullPath($Child)
  $prefix = $parentFull + [System.IO.Path]::DirectorySeparatorChar
  if (-not $childFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to delete outside target directory: $childFull"
  }
}

# Delete a real dir OR a dir symlink without recursing through a link's target.
function Remove-PathSafe([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.LinkType) { $item.Delete() }
  else { Remove-Item -LiteralPath $Path -Recurse -Force }
}

function Remove-At([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Not present: $Path"
    return
  }
  if ($DryRun) {
    Write-Host "Would remove $Label $Path"
    return
  }
  Remove-PathSafe $Path
  Write-Host "Removed $Label $Path"
}

function Uninstall-Skills([string]$Name, [string]$AgentKey, [string]$DestRoot) {
  foreach ($skill in $Skills) {
    $dest = Join-Path $DestRoot $skill.Name
    Assert-ChildPath $DestRoot $dest
    Remove-At $dest "skill"
  }

  # Hub installs leave the real files in the hub; remove those too.
  if ($Hub) {
    $hubAgent = Join-Path $HubRoot $AgentKey
    foreach ($skill in $Skills) {
      $hubDest = Join-Path $hubAgent $skill.Name
      Assert-ChildPath $hubAgent $hubDest
      Remove-At $hubDest "hub copy"
    }
  }
}

if ($Target -in @("all", "codex")) {
  Uninstall-Skills "Codex" "codex" (Get-CodexSkillDir)
}

if ($Target -in @("all", "claude")) {
  Uninstall-Skills "Claude" "claude" (Get-ClaudeSkillDir)
}

Write-Host "Restart Codex or Claude to drop the skills."
