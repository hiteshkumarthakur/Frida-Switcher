# =============================================================================
# install.ps1  -  Frida version manager installer  (Windows / PowerShell 5.1+)
# =============================================================================

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = Join-Path $ScriptDir "frida-env.ps1"

# -- Determine FRIDA_HOME -----------------------------------------------------
$defaultHome = Join-Path $HOME ".frida-envs"
if (-not $env:FRIDA_HOME) {
    $inp = Read-Host "Where should frida envs be stored? [$defaultHome]"
    $env:FRIDA_HOME = if ($inp) { $inp } else { $defaultHome }
}
if (-not (Test-Path $env:FRIDA_HOME)) {
    New-Item -ItemType Directory -Path $env:FRIDA_HOME -Force | Out-Null
}

# -- Create profile if it doesn't exist ---------------------------------------
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

# -- Bail if already installed ------------------------------------------------
$existing = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($existing -and $existing.Contains($ScriptPath)) {
    Write-Host "Already installed in $PROFILE" -ForegroundColor Green
    exit 0
}

# -- Append to profile --------------------------------------------------------
@"

# -- Frida version manager --
`$env:FRIDA_HOME = "$($env:FRIDA_HOME)"
. "$ScriptPath"
"@ | Add-Content -Path $PROFILE

Write-Host ""
Write-Host "Installed!  Added to $PROFILE" -ForegroundColor Green
Write-Host "  `$env:FRIDA_HOME = `"$($env:FRIDA_HOME)`""
Write-Host "  . `"$ScriptPath`""
Write-Host ""
Write-Host "Reload your profile:"
Write-Host "  . `$PROFILE"
Write-Host ""
Write-Host "Then try:"
Write-Host "  frida-16.6.3    # activate or auto-create frida 16.6.3"
Write-Host "  frida-list      # list all available environments"
