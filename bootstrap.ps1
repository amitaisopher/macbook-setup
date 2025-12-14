[CmdletBinding()]
Param(
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'
$env:PYTHONLEGACYWINDOWSSTDIO = '1'
$env:PYTHONUTF8 = '1'
$Global:PyCmd = $null

function Assert-Administrator {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script must be run from an elevated PowerShell session (Run as Administrator)."
        exit 1
    }
}

function Ensure-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

function Resolve-Python {
    $candidates = @(
        'py -3.11',
        'py -3.12',
        'python'
    )
    foreach ($cmd in $candidates) {
        try {
            $out = & $cmd -c "import sys; print(sys.executable)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $out) {
                return $cmd
            }
        } catch {}
    }
    return $null
}

function Ensure-Python {
    $resolved = Resolve-Python
    if (-not $resolved) {
        Ensure-Chocolatey
        # Prefer a stable Python version (3.11) to avoid prerelease issues
        choco install -y python311
        $resolved = Resolve-Python
    }
    if (-not $resolved) {
        Write-Error "Unable to locate or install Python. Please install Python 3.11+ and re-run."
        exit 1
    }
    $Global:PyCmd = $resolved
}

function Ensure-Ansible {
    Ensure-Python
    Write-Host "Installing Ansible via pip (ansible>=9.0.0) using [$Global:PyCmd]..." -ForegroundColor Cyan
    & $Global:PyCmd -m pip install --upgrade pip | Out-Null
    & $Global:PyCmd -m pip install --upgrade "ansible>=9.0.0" | Out-Null
}

Assert-Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
try { Unblock-File -Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue } catch {}
Set-Location $repoRoot

Ensure-Ansible

Write-Host "Installing Ansible collections..." -ForegroundColor Cyan
& $Global:PyCmd -m ansible.galaxy collection install -r requirements.yml

Write-Host "Running playbook..." -ForegroundColor Cyan
& $Global:PyCmd -m ansible.playbook -i inventory main.yml @ExtraArgs
