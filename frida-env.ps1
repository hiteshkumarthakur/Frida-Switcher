# =============================================================================
# frida-env.ps1  -  Frida version manager  (Windows / PowerShell 5.1+)
#
# Dot-source from your PowerShell profile ($PROFILE):
#   $env:FRIDA_HOME = "$HOME\.frida-envs"   # optional, this is the default
#   . "C:\path\to\repo\frida-env.ps1"
#
# Commands:
#   frida-16.6.3      activate (or auto-create) frida 16.6.3 environment
#   frida-X.Y.Z       any version - created on first use
#   frida-list        list all environments
#   frida-deactivate  deactivate the active environment
# =============================================================================

Set-StrictMode -Off

# -- Configuration ------------------------------------------------------------
if (-not $env:FRIDA_HOME) {
    $env:FRIDA_HOME = Join-Path $HOME ".frida-envs"
}
if (-not (Test-Path $env:FRIDA_HOME)) {
    New-Item -ItemType Directory -Path $env:FRIDA_HOME -Force | Out-Null
}

# -- Core helper --------------------------------------------------------------
function Invoke-FridaActivateVersion {
    param([Parameter(Mandatory)][string]$Version)

    $envDir      = Join-Path $env:FRIDA_HOME "frida_$Version"
    $venvDir     = Join-Path $envDir ".venv"
    $activatePs1 = Join-Path $venvDir "Scripts\Activate.ps1"

    if (-not (Test-Path $activatePs1)) {
        Write-Host "[frida-env] frida $Version not found - creating environment..."
        if (-not (Test-Path $envDir)) {
            New-Item -ItemType Directory -Path $envDir -Force | Out-Null
        }

        $pythonCmd = $null
        foreach ($cmd in @("python3", "python", "py")) {
            if (Get-Command $cmd -ErrorAction SilentlyContinue) {
                $pythonCmd = $cmd; break
            }
        }
        if (-not $pythonCmd) {
            Write-Error "[frida-env] Python not found. Install from https://python.org"
            return
        }

        Write-Host "[frida-env] Creating venv with $pythonCmd..."
        & $pythonCmd -m venv $venvDir
        if ($LASTEXITCODE -ne 0) {
            Write-Error "[frida-env] Failed to create venv."
            Remove-Item $envDir -Recurse -Force -ErrorAction SilentlyContinue
            return
        }

        Write-Host "[frida-env] Installing frida==$Version, frida-tools, objection..."
        & "$venvDir\Scripts\pip.exe" install --quiet --upgrade pip
        & "$venvDir\Scripts\pip.exe" install "frida==$Version" frida-tools objection
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "[frida-env] Some packages may have failed to install."
        }
    }

    & $activatePs1
    $fridaPath = (Get-Command frida -ErrorAction SilentlyContinue)?.Source
    Write-Host "[frida-env] Activated  frida $Version  ->  $fridaPath"
}

# -- Register frida-X.Y.Z as a PowerShell function ---------------------------
function Register-FridaVersion {
    param([Parameter(Mandatory)][string]$Version)
    $sb = [scriptblock]::Create("Invoke-FridaActivateVersion -Version '$Version'")
    Set-Item -Path "Function:frida-$Version" -Value $sb -Force
}

# -- Pre-register all existing frida_* dirs at shell startup -----------------
Get-ChildItem -Path $env:FRIDA_HOME -Directory -Filter "frida_*" -ErrorAction SilentlyContinue |
    ForEach-Object { Register-FridaVersion ($_.Name -replace '^frida_', '') }

# -- command-not-found handler: auto-create frida-X.Y.Z envs -----------------
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($Name, $EventArgs)
    if ($Name -match '^frida-(\d+\.\d+\.\d+)$') {
        $ver = $Matches[1]
        Register-FridaVersion $ver
        $EventArgs.Command = [scriptblock]::Create(
            "Invoke-FridaActivateVersion -Version '$ver'"
        ).GetNewClosure()
        $EventArgs.StopSearch = $true
    }
}

# -- Convenience commands -----------------------------------------------------
function frida-list {
    Write-Host "Frida environments in $($env:FRIDA_HOME):"
    $found = $false
    Get-ChildItem -Path $env:FRIDA_HOME -Directory -Filter "frida_*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $venvPath = Join-Path $_.FullName ".venv"
            if (Test-Path $venvPath) {
                $ver    = $_.Name -replace '^frida_', ''
                $marker = if ($env:VIRTUAL_ENV -eq $venvPath) { "  <- active" } else { "" }
                Write-Host ("  frida-{0,-16}{1}" -f $ver, $marker)
                $found = $true
            }
        }
    if (-not $found) { Write-Host "  (none yet - type frida-X.Y.Z to create one)" }
}

function frida-deactivate {
    if (Get-Command deactivate -ErrorAction SilentlyContinue) {
        deactivate
        Write-Host "[frida-env] Deactivated."
    } else {
        Write-Host "[frida-env] No active frida environment."
    }
}
