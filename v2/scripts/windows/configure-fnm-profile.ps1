[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$profilePath = $PROFILE
$initLine = 'fnm env --use-on-cd | Out-String | Invoke-Expression'

Write-Host "Ensuring fnm init line exists in PowerShell profile..." -ForegroundColor Cyan

if (-not (Test-Path $profilePath)) {
    Write-Host "Profile not found. Creating $profilePath" -ForegroundColor DarkGray
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -notmatch [regex]::Escape($initLine)) {
    Write-Host "Adding fnm init line to $profilePath" -ForegroundColor DarkGray
    Add-Content -Path $profilePath -Value "`n$initLine"
} else {
    Write-Host "fnm init line already present in $profilePath" -ForegroundColor DarkGray
}

# Reload the profile
try {
    . $profilePath
    Write-Host "Reloaded PowerShell profile from $profilePath" -ForegroundColor Green
} catch {
    Write-Warning "Could not reload profile $profilePath: $($_.Exception.Message)"
}
