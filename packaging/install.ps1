# WorkLoom CLI installer (Windows).
#
#   irm https://raw.githubusercontent.com/catesandrew/work-loom-releases/main/packaging/install.ps1 | iex
#
# Prefer inspect-before-run:
#   irm <url> -OutFile install.ps1; Get-Content install.ps1; ./install.ps1
#
# Downloads the prebuilt, self-contained `wl.exe` for Windows x64 from the
# GitHub Release, verifies its SHA-256 against the published SHA256SUMS.txt, and
# installs it to %LOCALAPPDATA%\Workloom\bin (override with INSTALL_DIR). No Node
# required — the binary bundles its own runtime.
#
# Env overrides:
#   $env:VERSION = 'cli-v0.2.0'     pin a release tag (default: latest)
#   $env:INSTALL_DIR = 'C:\tools'   install location (default: %LOCALAPPDATA%\Workloom\bin)
$ErrorActionPreference = 'Stop'

# Public mirror repo (source lives in the private catesandrew/work-loom repo).
# Anonymous irm|iex can't reach private-repo release assets, so binaries +
# checksums are mirrored here by the CLI Release workflow.
$Repo = 'catesandrew/work-loom-releases'
$Binary = 'wl'
$Asset = 'wl-windows-x64.exe'
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Workloom\bin' }

function Info($msg) { Write-Host "==> $msg" -ForegroundColor Blue }
function Warn($msg) { Write-Warning $msg }
function Die($msg)  { throw $msg }

# --- resolve release tag ---------------------------------------------------
if ($env:VERSION) {
  $Tag = $env:VERSION
} else {
  Info 'resolving latest release'
  try {
    $release = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$Repo/releases/latest"
    $Tag = $release.tag_name
  } catch {
    Die "could not resolve latest release tag (set `$env:VERSION=cli-vX.Y.Z to pin)"
  }
  if (-not $Tag) { Die "could not resolve latest release tag (set `$env:VERSION=cli-vX.Y.Z to pin)" }
}

$Base = "https://github.com/$Repo/releases/download/$Tag"
Info "installing $Binary $Tag (windows-x64)"

# --- download binary + checksums into a temp dir ---------------------------
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("wl-" + [System.Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
try {
  $exe = Join-Path $Tmp $Asset
  try { Invoke-WebRequest -UseBasicParsing -Uri "$Base/$Asset" -OutFile $exe }
  catch { Die "download failed: $Base/$Asset" }

  $sums = Join-Path $Tmp 'SHA256SUMS.txt'
  try { Invoke-WebRequest -UseBasicParsing -Uri "$Base/SHA256SUMS.txt" -OutFile $sums }
  catch { Die 'download failed: SHA256SUMS.txt' }

  # --- verify checksum -----------------------------------------------------
  $entry = Select-String -Path $sums -Pattern " $([regex]::Escape($Asset))$" | Select-Object -First 1
  if (-not $entry) { Die "no checksum for $Asset in SHA256SUMS.txt" }
  $expected = (($entry.Line -split '\s+') | Select-Object -First 1).ToLower()
  $actual = (Get-FileHash -Algorithm SHA256 -Path $exe).Hash.ToLower()
  if ($expected -ne $actual) {
    Die "checksum mismatch for $Asset`n  expected: $expected`n  actual:   $actual"
  }
  Info 'checksum verified'

  # --- install -------------------------------------------------------------
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  $dest = Join-Path $InstallDir "$Binary.exe"
  Move-Item -Force -Path $exe -Destination $dest
  Info "installed to $dest"

  # --- PATH hint (persist to the user PATH if missing) ---------------------
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (($userPath -split ';') -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$InstallDir", 'User')
    Warn "$InstallDir was added to your user PATH. Restart your shell, then run '$Binary --help'."
  } else {
    Info "run '$Binary --help' to get started"
  }

  & $dest --version *> $null
  if ($LASTEXITCODE -eq 0) {
    Info "installed $Binary successfully"
  } else {
    Warn "installed, but '$Binary --version' did not run cleanly"
  }
}
finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
