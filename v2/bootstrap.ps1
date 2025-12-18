[CmdletBinding()]
Param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$windowsRunner = Join-Path $repoRoot "runners/windows.ps1"
if (-not (Test-Path $windowsRunner)) {
    Write-Error "Windows runner not found at $windowsRunner"
    exit 1
}

& $windowsRunner -AppArgs $ExtraArgs
