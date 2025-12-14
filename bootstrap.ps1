[CmdletBinding()]
Param(
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'
$env:PYTHONLEGACYWINDOWSSTDIO = '1'

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

function Ensure-Python {
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Ensure-Chocolatey
        choco install -y python
    }
}

function Ensure-Ansible {
    if (-not (Get-Command ansible-playbook -ErrorAction SilentlyContinue)) {
        Ensure-Python
        Write-Host "Installing Ansible via pip (ansible-core)..." -ForegroundColor Cyan
        python -m pip install --upgrade pip | Out-Null
        python -m pip install --upgrade "ansible-core>=2.14,<2.15" | Out-Null

        # Ensure the Python Scripts directory is on PATH for this session
        $scriptsPath = python -c "import sysconfig; print(sysconfig.get_path('scripts'))"
        $scriptsPath = $scriptsPath.Trim()
        if ($scriptsPath -and ($env:Path -notlike "*$scriptsPath*")) {
            $env:Path = "$scriptsPath;$env:Path"
        }
    }
}

Assert-Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
try { Unblock-File -Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue } catch {}
Set-Location $repoRoot

Ensure-Ansible

Write-Host "Installing Ansible collections..." -ForegroundColor Cyan
ansible-galaxy collection install -r requirements.yml

Write-Host "Running playbook..." -ForegroundColor Cyan
ansible-playbook -i inventory main.yml @ExtraArgs
