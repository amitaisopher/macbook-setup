[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$Manifest
)

$ErrorActionPreference = 'Stop'

function Ensure-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Run this script from an elevated PowerShell (Run as Administrator)."
        exit 1
    }
}

function Ensure-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Ensure-Choco {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey (fallback)..." -ForegroundColor Cyan
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

function Ensure-YamlSupport {
    if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) { return }
    Write-Host "Installing powershell-yaml module for manifest parsing..." -ForegroundColor Cyan
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force
}

function Is-InstalledWinget {
    param([string]$Id)
    if (-not $Id) { return $false }
    try {
        $null = winget list --id $Id --accept-source-agreements 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Is-InstalledChoco {
    param([string]$Pkg)
    if (-not $Pkg) { return $false }
    try {
        $null = choco list --local-only --exact $Pkg 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Invoke-Manifest {
    Ensure-Admin
    Ensure-Choco
    Ensure-YamlSupport

    if (-not (Test-Path $Manifest)) {
        Write-Error "Manifest not found at $Manifest"
        exit 1
    }

    $yaml = Get-Content $Manifest -Raw
    $data = ConvertFrom-Yaml $yaml
    if (-not $data.tools) {
        Write-Error "Manifest is missing 'tools' section."
        exit 1
    }

    foreach ($toolName in $data.tools.Keys) {
        $tool = $data.tools[$toolName]
        $winSpec = $tool.win
        if (-not $winSpec) { continue }

        Write-Host "Installing $toolName..." -ForegroundColor Cyan
        try {
            if ($winSpec.choco) {
                if (Is-InstalledChoco -Pkg $winSpec.choco) {
                    Write-Host "$toolName already installed (choco pkg: $winSpec.choco); skipping." -ForegroundColor DarkGray
                } else {
                    $args = @("install","-y",$winSpec.choco)
                    if ($winSpec.choco -ieq "googlechrome") {
                        $args += "--ignore-checksums"
                    }
                    choco @args
                }
            } elseif ($winSpec.winget) {
                if (-not (Ensure-Winget)) {
                    Write-Warning "winget not available; cannot install $toolName via winget."
                } elseif (Is-InstalledWinget -Id $winSpec.winget) {
                    Write-Host "$toolName already installed (winget id: $winSpec.winget); skipping." -ForegroundColor DarkGray
                } else {
                    winget install --id $winSpec.winget --accept-package-agreements --accept-source-agreements --silent
                }
            } elseif ($winSpec.script) {
                $scriptPath = Join-Path $RepoRoot $winSpec.script
                if (-not (Test-Path $scriptPath)) { throw "Script not found: $scriptPath" }
                & $scriptPath
            } else {
                Write-Warning "No installer mapping for $toolName on Windows."
            }

            if ($winSpec.post) {
                foreach ($postScript in $winSpec.post) {
                    $postPath = Join-Path $RepoRoot $postScript
                    if (-not (Test-Path $postPath)) { throw "Post script not found: $postPath" }
                    & $postPath
                }
            }
        } catch {
            Write-Warning ("Failed to install {0}: {1}" -f $toolName, $_)
        }
    }
}

Invoke-Manifest
