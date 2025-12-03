Param(
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

function Ensure-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

function Ensure-Ansible {
    if (-not (Get-Command ansible-playbook -ErrorAction SilentlyContinue)) {
        Ensure-Chocolatey
        choco install -y python ansible
    }
}

Ensure-Ansible

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

ansible-galaxy collection install -r requirements.yml | Out-Null
ansible-playbook -i inventory main.yml @ExtraArgs
