[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Ensure-Fnm {
    if (Get-Command fnm -ErrorAction SilentlyContinue) { return $true }
    Write-Warning "fnm is required to install Gemini CLI. Install fnm (already defined in manifest) and rerun."
    return $false
}

if (-not (Ensure-Fnm)) { exit 0 }

try {
    # Initialize fnm in this session
    fnm env --use-on-cd | Out-String | Invoke-Expression
    fnm install --lts
    fnm use lts-latest

    Write-Host "Installing Gemini CLI via npm (using fnm-managed Node)..." -ForegroundColor Cyan
    npm install -g @google/gemini-cli
    Write-Host "Gemini CLI installed." -ForegroundColor Green
} catch {
    Write-Warning ("Gemini CLI installation failed: {0}" -f $_)
}
