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

function Ensure-WSL {
    $needsReboot = $false
    $wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue

    if (-not $wslCmd) {
        Write-Host "Enabling Windows Subsystem for Linux and Virtual Machine Platform..." -ForegroundColor Cyan
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -All | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -All | Out-Null
        $needsReboot = $true
    }

    if (-not $needsReboot) {
        try {
            $distroList = & wsl.exe -l --quiet 2>$null
        } catch {
            $distroList = $null
        }

        if (-not $distroList) {
            Write-Host "Installing Ubuntu distro for WSL..." -ForegroundColor Cyan
            & wsl.exe --install -d Ubuntu
            if ($LASTEXITCODE -ne 0) {
                Write-Error "WSL installation failed. Please install WSL/Ubuntu from the Microsoft Store and rerun."
                exit 1
            }
            $needsReboot = $true
        }
    }

    if ($needsReboot) {
        Write-Host "WSL components installed. Please reboot, complete the initial Ubuntu setup if prompted, then rerun bootstrap.ps1." -ForegroundColor Yellow
        exit 0
    }
}

function Invoke-InWSL {
    param(
        [string]$RepoRoot,
        [string[]]$Args
    )

    $wslPath = wsl.exe wslpath -a "$RepoRoot"
    if ($LASTEXITCODE -ne 0 -or -not $wslPath) {
        Write-Error "Failed to resolve WSL path for $RepoRoot. Launch WSL once to complete distro setup, then rerun this script."
        exit 1
    }
    $joinedArgs = $Args -join ' '
    $cmd = "cd '$wslPath' && ./bootstrap.sh $joinedArgs"
    Write-Host "Delegating to WSL: $cmd" -ForegroundColor Cyan
    wsl.exe -- bash -lc "$cmd"
}

Assert-Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
try { Unblock-File -Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue } catch {}
Set-Location $repoRoot

Ensure-WSL
Invoke-InWSL -RepoRoot $repoRoot -Args $ExtraArgs
