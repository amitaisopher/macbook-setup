[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

Write-Host "Installing uv (Python package manager) via official script..." -ForegroundColor Cyan

try {
    Invoke-Expression (Invoke-RestMethod "https://astral.sh/uv/install.ps1")
    Write-Host "uv installation completed." -ForegroundColor Green
} catch {
    Write-Warning ("uv installation failed: {0}" -f $_)
}
