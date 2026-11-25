<#
.SYNOPSIS
  Copies the mod's scripts into the game for testing (r6\scripts\Fixer). Compile-checks first.

.DESCRIPTION
  Copies only; it never deletes anything in the game folder. If a file was removed from src since the last install,
  delete it from r6\scripts\Fixer by hand (a release never deletes a shipped file: it stubs it).
#>
param(
  [string]$GameDir = 'D:\SteamLibrary\steamapps\common\Cyberpunk 2077',
  [switch]$SkipValidate
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repo 'src\r6\scripts\Fixer'
$dst = Join-Path $GameDir 'r6\scripts\Fixer'

if (-not $SkipValidate) {
  & (Join-Path $PSScriptRoot 'validate.ps1') -GameDir $GameDir
  if ($LASTEXITCODE -ne 0) { throw 'Compile check failed: not installing.' }
}

New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item (Join-Path $src '*') $dst -Recurse -Force
$n = @(Get-ChildItem $dst -Recurse -Filter *.reds).Count
Write-Host "Installed $n script file(s) to $dst" -ForegroundColor Green
