<#
.SYNOPSIS
  Compile-checks the Fixer redscript against an installed Cyberpunk 2077, without touching the game folder.

.DESCRIPTION
  Builds a fresh sandbox (a new folder every run: a reused one leaves files behind that confuse scc), copies in
  Codeware's and Mod Settings' scripts from the game's RED4ext plugins plus this mod's source, and compiles it with
  the game's own scc.exe against a private copy of the vanilla script blob. Prints every compile diagnostic, unfiltered.

  scc sometimes does not exit after an error, so it runs as a child process with a time limit and is killed if it
  overstays.

.PARAMETER GameDir
  The Cyberpunk 2077 install (the folder holding bin, r6, engine, red4ext).

.PARAMETER Source
  The folder of .reds files to compile. Defaults to this repo's src/r6/scripts/Fixer.

.PARAMETER Extra
  More script folders to compile alongside (another mod, to catch name clashes and hook conflicts).

.PARAMETER Keep
  Leave the sandbox on disk afterwards, for reading the full log.
#>
param(
  [string]$GameDir = 'D:\SteamLibrary\steamapps\common\Cyberpunk 2077',
  [string]$Source,
  [string[]]$Extra = @(),
  [int]$TimeoutSeconds = 180,
  [switch]$Keep
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
if (-not $Source) { $Source = Join-Path $repo 'src\r6\scripts\Fixer' }

$scc       = Join-Path $GameDir 'engine\tools\scc.exe'
$vanilla   = Join-Path $GameDir 'r6\cache\final.redscripts'
$cwScripts = Join-Path $GameDir 'red4ext\plugins\Codeware\Scripts'
$msDir     = Join-Path $GameDir 'red4ext\plugins\mod_settings'

foreach ($p in @($scc, $vanilla, $cwScripts, $msDir, $Source)) {
  if (-not (Test-Path $p)) { throw "Required path not found: $p" }
}

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('fixer-validate-' + [Guid]::NewGuid().ToString('N'))
$scripts = Join-Path $sandbox 'scripts'
New-Item -ItemType Directory -Path $scripts -Force | Out-Null

try {
  Copy-Item $cwScripts (Join-Path $scripts 'Codeware') -Recurse
  New-Item -ItemType Directory -Path (Join-Path $scripts 'mod_settings') -Force | Out-Null
  Copy-Item (Join-Path $msDir '*.reds') (Join-Path $scripts 'mod_settings')
  Copy-Item $Source (Join-Path $scripts (Split-Path -Leaf $Source)) -Recurse
  # Each extra folder gets its own directory: plugin script folders are all called 'Scripts', so name by the
  # folder and, while that is taken, by its parent too (ArchiveXL_Scripts, TweakXL_Scripts, ...).
  $n = 0
  foreach ($e in $Extra) {
    $leaf = Split-Path -Leaf $e
    $dest = Join-Path $scripts $leaf
    if (Test-Path $dest) {
      $n += 1
      $dest = Join-Path $scripts ('{0}_{1}_{2}' -f (Split-Path -Leaf (Split-Path -Parent $e)), $leaf, $n)
    }
    Copy-Item $e $dest -Recurse
  }

  $base = Join-Path $sandbox 'base.redscripts'
  $out  = Join-Path $sandbox 'out.redscripts'
  Copy-Item $vanilla $base

  $files = @(Get-ChildItem $Source -Recurse -Filter *.reds).Count
  Write-Host "Compiling $files file(s) from $Source against $vanilla ..."

  $proc = Start-Process -FilePath $scc -ArgumentList @('-compile', "`"$scripts`"", '-outputCacheFile', "`"$out`"", "`"$base`"") `
            -WorkingDirectory $sandbox -NoNewWindow -PassThru `
            -RedirectStandardOutput (Join-Path $sandbox 'stdout.txt') -RedirectStandardError (Join-Path $sandbox 'stderr.txt')
  # scc often hangs after reporting a failure. Poll its log for a final verdict and stop it as soon as one is there.
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while (-not $proc.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $probe = Get-ChildItem $sandbox -Recurse -Filter 'redscript*.log' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($probe) {
      $sofar = Get-Content $probe.FullName -Raw -ErrorAction SilentlyContinue
      if ($sofar -match 'compilation has failed' -or $sofar -match 'successfully saved' -or $sofar -match 'Output successfully') {
        Start-Sleep -Milliseconds 1500
        break
      }
    }
  }
  if (-not $proc.HasExited) {
    try { $proc.Kill() } catch {}
  }

  # scc writes its log next to the scripts folder; find it wherever it landed.
  $log = Get-ChildItem $sandbox -Recurse -Filter 'redscript*.log' -ErrorAction SilentlyContinue | Select-Object -First 1
  # The log and stdout carry the same diagnostics; read the log, and stdout/stderr only when no log was written.
  $text = ''
  if ($log) {
    $text = Get-Content $log.FullName -Raw
  } else {
    foreach ($s in @('stdout.txt', 'stderr.txt')) {
      $p = Join-Path $sandbox $s
      if (Test-Path $p) { $text += (Get-Content $p -Raw) }
    }
  }

  # Print every diagnostic in full (ERROR and WARN blocks, with their source excerpts).
  $diag = @()
  if ($text) {
    $blocks = $text -split "(?m)^(?=\[(?:ERROR|WARN|INFO))"
    foreach ($b in $blocks) {
      if ($b -match '^\[(ERROR|WARN)') { $diag += $b.TrimEnd() }
    }
  }
  foreach ($d in $diag) {
    if ($d -match '^\[ERROR') { Write-Host $d -ForegroundColor Red } else { Write-Host $d -ForegroundColor Yellow }
    Write-Host ''
  }

  $errors = @($diag | Where-Object { $_ -match '^\[ERROR' }).Count
  $warns  = @($diag | Where-Object { $_ -match '^\[WARN' }).Count
  $ok = (Test-Path $out) -and ((Get-Item $out).Length -gt 0) -and ($errors -eq 0)

  Write-Host "Errors: $errors  Warnings: $warns"
  if ($ok) {
    Write-Host 'OK: compiles cleanly against this game version.' -ForegroundColor Green
  } else {
    if ($log) { Write-Host "Full log: $($log.FullName)" }
    $Keep = $true
    Write-Host "FAILED. Sandbox kept at $sandbox" -ForegroundColor Red
    exit 1
  }
}
finally {
  if (-not $Keep -and (Test-Path $sandbox)) { Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue }
}
