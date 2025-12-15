[CmdletBinding()]
Param(
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

# This entrypoint is for Windows hosts. It delegates to the v2 Windows runner
# which installs tooling via winget/chocolatey based on manifest.yaml.

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$windowsRunner = Join-Path $repoRoot "runners/windows.ps1"
if (-not (Test-Path $windowsRunner)) {
    Write-Error "Windows runner not found at $windowsRunner"
    exit 1
}

$passArgs = @()
if ($ExtraArgs) { $passArgs = $ExtraArgs }

& $windowsRunner -RepoRoot $repoRoot -Manifest (Join-Path $repoRoot "manifest.yaml") @passArgs
