[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Ensure-Fnm {
    if (Get-Command fnm -ErrorAction SilentlyContinue) { return $true }
    Write-Warning "fnm is required to install Claude Code CLI. Install fnm and rerun."
    return $false
}

if (-not (Ensure-Fnm)) { exit 0 }

try {
    fnm env --use-on-cd | Out-String | Invoke-Expression
    fnm install --lts
    fnm use lts-latest

    Write-Host "Installing Claude Code CLI via npm (using fnm-managed Node)..." -ForegroundColor Cyan
    npm install -g @anthropic-ai/claude-code
    Write-Host "Claude Code CLI installed." -ForegroundColor Green
} catch {
    Write-Warning ("Failed to install Claude Code CLI: {0}" -f $_)
}
