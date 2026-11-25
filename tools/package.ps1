<#
.SYNOPSIS
  Builds the release archive dist/Fixer-<version>.zip for Nexus Mods and Vortex.

.DESCRIPTION
  Layout: the archive root is the game root, so it holds only r6/scripts/Fixer/... (the same shape as every
  redscript mod on Nexus; Vortex's Cyberpunk support installs it as-is, and it can be unzipped into the game folder by
  hand). Entry names use forward slashes: PowerShell 5.1's Compress-Archive writes backslashes, which some mod
  managers flatten, so the archive is written entry by entry here.

  Naming: no Nexus mod id in the file name. Vortex reads "Name-ModID-Version-Timestamp" style names to link a mod to a
  Nexus page; a made-up id would link Fixer to somebody else's mod. Nexus renames downloads itself once uploaded.

  Gates, any of which stops the build:
   1. every localization key has English text (tools/check_loc.py);
   2. the scripts compile against the installed game (tools/validate.ps1);
   3. no .reds file from an earlier release is missing (tools/shipped-files.txt). A deleted script stays on players'
      installs after an update and breaks their compile once anything it calls is gone: stub it instead.
  After a successful build, files shipped for the first time are added to tools/shipped-files.txt.

.PARAMETER GameDir
  The Cyberpunk 2077 install used for the compile check.

.PARAMETER SkipValidate
  Skip the compile check (only for repackaging something already checked).
#>
param(
  [string]$GameDir = 'D:\SteamLibrary\steamapps\common\Cyberpunk 2077',
  [switch]$SkipValidate
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo    = Split-Path -Parent $PSScriptRoot
$src     = Join-Path $repo 'src\r6\scripts\Fixer'
$dist    = Join-Path $repo 'dist'
$shipped = Join-Path $PSScriptRoot 'shipped-files.txt'

# ---- version, from the code itself ----
$versionFile = Join-Path $src 'Core\Version.reds'
$m = Select-String -Path $versionFile -Pattern 'FXVersion\(\) -> String = "(\d+\.\d+\.\d+)"'
if (-not $m) { throw "No version found in $versionFile" }
$version = $m.Matches[0].Groups[1].Value
Write-Host "Packaging Fixer $version" -ForegroundColor Cyan

# ---- gate 1: localization ----
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw 'Python is needed for tools/check_loc.py.' }
& python (Join-Path $PSScriptRoot 'check_loc.py')
if ($LASTEXITCODE -ne 0) { throw 'Localization check failed: not packaging.' }

# ---- gate 2: compile ----
if (-not $SkipValidate) {
  & (Join-Path $PSScriptRoot 'validate.ps1') -GameDir $GameDir
  if ($LASTEXITCODE -ne 0) { throw 'Compile check failed: not packaging.' }
}

# ---- the files: every .reds under src, as game-root paths with forward slashes ----
$files = @(Get-ChildItem $src -Recurse -File -Filter *.reds | Sort-Object FullName)
$entries = @()
foreach ($f in $files) {
  $rel = $f.FullName.Substring($src.Length).TrimStart('\', '/').Replace('\', '/')
  $entries += [pscustomobject]@{ Source = $f.FullName; Entry = "r6/scripts/Fixer/$rel" }
}
if ($entries.Count -eq 0) { throw "No scripts found under $src" }

# ---- gate 3: nothing shipped before may be missing ----
$previous = @()
if (Test-Path $shipped) {
  $previous = @(Get-Content $shipped | Where-Object { $_ -and -not $_.StartsWith('#') })
}
$current = @($entries | ForEach-Object { $_.Entry })
$missing = @($previous | Where-Object { $current -notcontains $_ })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "MISSING shipped file: $_" -ForegroundColor Red }
  throw 'A file from an earlier release is gone. Restore it as an empty stub instead of deleting it.'
}

# ---- write the archive ----
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$zipPath = Join-Path $dist "Fixer-$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($e in $entries) {
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $e.Source, $e.Entry, [System.IO.Compression.CompressionLevel]::Optimal)
  }
} finally {
  $zip.Dispose()
}

# ---- verify what was written ----
$check = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
  $names = @($check.Entries | ForEach-Object { $_.FullName })
} finally {
  $check.Dispose()
}
$bad = @($names | Where-Object { $_.Contains('\') -or -not $_.StartsWith('r6/scripts/Fixer/') })
if ($bad.Count -gt 0 -or $names.Count -ne $entries.Count) {
  $bad | ForEach-Object { Write-Host "BAD entry: $_" -ForegroundColor Red }
  throw "Archive check failed ($($names.Count) entries written, $($entries.Count) expected)."
}

# ---- record what this release ships ----
$new = @($current | Where-Object { $previous -notcontains $_ })
if ($new.Count -gt 0) {
  if (-not (Test-Path $shipped)) {
    Set-Content -Path $shipped -Encoding utf8 -Value '# Every .reds file a release has shipped. Never delete one of these from src: stub it (tools/package.ps1 checks).'
  }
  Add-Content -Path $shipped -Encoding utf8 -Value $new
}

$size = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash
Write-Host ''
Write-Host "Built $zipPath" -ForegroundColor Green
Write-Host "  $($names.Count) files, $size KB, top level: r6/"
Write-Host "  SHA256 $hash"
if ($new.Count -gt 0) { Write-Host "  $($new.Count) file(s) recorded as shipped in tools/shipped-files.txt" }
