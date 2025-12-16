[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$extensions = @(
    "edacconmaakjimmfgnblocblbcdcpbko", # Session Buddy
    "nngceckbapebfimnlniiiahkandclblb", # Bitwarden
    "gighmmpiobklfepjocnamgkkbiglidom"  # AdBlock
)
$baseKey = "HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist"
$updateUrl = "https://clients2.google.com/service/update2/crx"

Write-Host "Configuring Chrome ExtensionInstallForcelist..." -ForegroundColor Cyan

if (-not (Test-Path $baseKey)) {
    New-Item -Path $baseKey -Force | Out-Null
}

$i = 1
foreach ($id in $extensions) {
    $valueName = $i.ToString()
    $valueData = "$id;$updateUrl"
    Set-ItemProperty -Path $baseKey -Name $valueName -Value $valueData -Type String
    $i++
}

Write-Host "Chrome extensions policy applied (Session Buddy, Bitwarden, AdBlock)." -ForegroundColor Green
