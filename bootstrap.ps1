[CmdletBinding()]
Param(
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

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

function Ensure-Ansible {
    if (-not (Get-Command ansible-playbook -ErrorAction SilentlyContinue)) {
        Ensure-Chocolatey
        choco install -y python ansible
    }
}

Assert-Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

Ensure-Ansible

Write-Host "Installing Ansible collections..." -ForegroundColor Cyan
ansible-galaxy collection install -r requirements.yml

Write-Host "Running playbook..." -ForegroundColor Cyan
ansible-playbook -i inventory main.yml @ExtraArgs
