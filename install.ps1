param(
  [ValidateSet("all", "codex", "claude")]
  [string]$Target = "all",
  [switch]$Force,
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
    throw "Refusing to write outside target directory: $childFull"
  }
}

# Remove a real directory OR a directory symlink without recursing through a
# link into its target. Remove-Item -Recurse on a symlinked dir can delete the
# target's contents on Windows, so links are deleted via the reparse point.
function Remove-PathSafe([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.LinkType) { $item.Delete() }
  else { Remove-Item -LiteralPath $Path -Recurse -Force }
}

function Install-Copy([string]$Name, [string]$DestRoot) {
  $conflicts = @()
  foreach ($skill in $Skills) {
    $dest = Join-Path $DestRoot $skill.Name
    Assert-ChildPath $DestRoot $dest
    if ((Test-Path -LiteralPath $dest) -and -not $Force) {
      $conflicts += $dest
    }
  }

  if ($DryRun) {
    Write-Host "Would install $Name skills to $DestRoot"
    if ($conflicts) {
      Write-Host ("Existing skills would block install without -Force:`n{0}" -f ($conflicts -join "`n"))
    }
    return
  }

  if ($conflicts) {
    Write-Error ("{0} already has ponytail skills installed:`n{1}`nRerun with -Force to replace them." -f $Name, ($conflicts -join "`n"))
  }

  New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null

  foreach ($skill in $Skills) {
    $dest = Join-Path $DestRoot $skill.Name
    Assert-ChildPath $DestRoot $dest
    if (Test-Path -LiteralPath $dest) {
      Remove-PathSafe $dest
    }
    Copy-Item -LiteralPath $skill.FullName -Destination $DestRoot -Recurse
    Write-Host "Installed $($skill.Name) -> $dest"
  }
}

function Install-Hub([string]$Name, [string]$AgentKey, [string]$DestRoot) {
  $hubAgent = Join-Path $HubRoot $AgentKey

  # A real (non-symlink) skill dir at the destination blocks a hub install unless
  # -Force, so we never silently delete a previous copy-mode install.
  $conflicts = @()
  foreach ($skill in $Skills) {
    $link = Join-Path $DestRoot $skill.Name
    Assert-ChildPath $DestRoot $link
    $existing = if (Test-Path -LiteralPath $link) { Get-Item -LiteralPath $link -Force } else { $null }
    if ($existing -and -not $existing.LinkType -and -not $Force) {
      $conflicts += $link
    }
  }

  if ($DryRun) {
    Write-Host "Would copy $Name skills to hub $hubAgent and symlink them into $DestRoot"
    if ($conflicts) {
      Write-Host ("Existing real dirs would block without -Force:`n{0}" -f ($conflicts -join "`n"))
    }
    return
  }

  if ($conflicts) {
    Write-Error ("{0} has real skill dirs that -Hub would replace with symlinks:`n{1}`nRerun with -Force." -f $Name, ($conflicts -join "`n"))
  }

  # 1. Real files live in the hub.
  New-Item -ItemType Directory -Force -Path $hubAgent | Out-Null
  foreach ($skill in $Skills) {
    $hubDest = Join-Path $hubAgent $skill.Name
    Assert-ChildPath $hubAgent $hubDest
    if (Test-Path -LiteralPath $hubDest) { Remove-PathSafe $hubDest }
    Copy-Item -LiteralPath $skill.FullName -Destination $hubAgent -Recurse
    Write-Host "Staged $($skill.Name) -> $hubDest"
  }

  # 2. The agent's skill dir holds symlinks into the hub.
  New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null
  foreach ($skill in $Skills) {
    $link = Join-Path $DestRoot $skill.Name
    $target = Join-Path $hubAgent $skill.Name
    Assert-ChildPath $DestRoot $link
    if (Test-Path -LiteralPath $link) { Remove-PathSafe $link }
    try {
      New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
    } catch {
      throw "Failed to symlink $link -> $target. Windows needs Developer Mode (Settings > System > For developers > Developer Mode) or an elevated shell. Original: $($_.Exception.Message)"
    }
    Write-Host "Linked $($skill.Name): $link -> $target"
  }
}

function Install-Target([string]$Name, [string]$AgentKey, [string]$DestRoot) {
  if ($Hub) { Install-Hub $Name $AgentKey $DestRoot }
  else { Install-Copy $Name $DestRoot }
}

if ($Target -in @("all", "codex")) {
  Install-Target "Codex" "codex" (Get-CodexSkillDir)
}

if ($Target -in @("all", "claude")) {
  Install-Target "Claude" "claude" (Get-ClaudeSkillDir)
}

Write-Host "Restart Codex or Claude to pick up new skills."
