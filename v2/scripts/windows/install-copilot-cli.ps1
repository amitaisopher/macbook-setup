[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Ensure-Fnm {
    if (Get-Command fnm -ErrorAction SilentlyContinue) { return $true }
    Write-Warning "fnm is required to install GitHub Copilot CLI. Install fnm and rerun."
    return $false
}

if (-not (Ensure-Fnm)) { exit 0 }

try {
    fnm env --use-on-cd | Out-String | Invoke-Expression
    fnm install --lts
    fnm use lts-latest

    Write-Host "Installing GitHub Copilot CLI via npm (using fnm-managed Node)..." -ForegroundColor Cyan
    npm install -g @githubnext/github-copilot-cli
    Write-Host "GitHub Copilot CLI installed. Run 'github-copilot-cli auth' to authenticate." -ForegroundColor Green
} catch {
    Write-Warning ("Failed to install GitHub Copilot CLI: {0}" -f $_)
}
