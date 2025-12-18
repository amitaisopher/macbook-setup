[CmdletBinding()]
param(
    [string[]]$AppArgs
)

$ErrorActionPreference = 'Stop'

function Ensure-Choco {
    if (Get-Command choco -ErrorAction SilentlyContinue) { return }
    Write-Host "Installing Chocolatey..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) 2>&1 | Out-File -FilePath $RunnerLog -Append
}

function Ensure-Uv {
    if (Get-Command uv -ErrorAction SilentlyContinue) { return }
    Write-Host "Installing uv via Chocolatey..." -ForegroundColor Cyan
    choco install -y uv 2>&1 | Out-File -FilePath $RunnerLog -Append
}

function Ensure-Venv {
    param([string]$RepoRoot)
    $venvPath = Join-Path $RepoRoot ".venv"
    if (Test-Path $venvPath) { return $venvPath }
    Write-Host "Creating virtual environment with uv..." -ForegroundColor Cyan
    $proc = Start-Process -FilePath "uv" -ArgumentList @("venv", $venvPath) -NoNewWindow -PassThru -Wait -RedirectStandardOutput $RunnerLog -RedirectStandardError $RunnerLog
    if ($proc.ExitCode -ne 0) {
        throw "uv venv failed. See $RunnerLog"
    }
    return $venvPath
}

function Install-Deps {
    param([string]$RepoRoot, [string]$VenvPath)
    $pythonExe = Join-Path $VenvPath "Scripts/python.exe"
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uvCmd) {
        throw "uv not found on PATH after installation"
    }
    # Use uv to drive installation against the venv's interpreter (works even if pip isn't bundled)
    $proc = Start-Process -FilePath $uvCmd.Source -ArgumentList @("pip","install","--python",$pythonExe,"-e",$RepoRoot) -NoNewWindow -PassThru -Wait -RedirectStandardOutput $RunnerLog -RedirectStandardError $RunnerLog
    if ($proc.ExitCode -ne 0) {
        throw "uv pip install failed. See $RunnerLog"
    }
}

function Run-App {
    param([string]$RepoRoot, [string]$VenvPath, [string[]]$AppArgs)
    Push-Location $RepoRoot
    try {
        & (Join-Path $VenvPath "Scripts/python.exe") -m app.main @AppArgs
    } finally {
        Pop-Location
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$RunnerLog = Join-Path $repoRoot "logs/runner-windows.log"
New-Item -ItemType Directory -Force -Path (Split-Path $RunnerLog) | Out-Null
Ensure-Choco
Ensure-Uv
$venv = Ensure-Venv -RepoRoot $repoRoot
Install-Deps -RepoRoot $repoRoot -VenvPath $venv
Run-App -RepoRoot $repoRoot -VenvPath $venv -AppArgs $AppArgs
