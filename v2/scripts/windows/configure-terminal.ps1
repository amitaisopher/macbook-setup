[CmdletBinding()]
param(
    [ValidateSet("Regular", "Mono")]
    [string]$FontVariant = "Regular",
    [string]$BackgroundColor = "#4B0082",
    [ValidateRange(0, 100)]
    [int]$Opacity = 90,
    [string]$ColorScheme = "Dark+",
    [bool]$EnableAcrylic = $false
)

$ErrorActionPreference = 'Stop'

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$selectedFont = if ($FontVariant -eq "Mono") { "DroidSansM Nerd Font Mono" } else { "DroidSansM Nerd Font" }

Write-Host "Windows Terminal Configuration" -ForegroundColor Yellow
Write-Host "Font: $selectedFont (size 14)" -ForegroundColor Cyan
Write-Host "Color Scheme: $ColorScheme" -ForegroundColor Cyan
Write-Host "Background: $BackgroundColor" -ForegroundColor Cyan
Write-Host "Opacity: ${Opacity}%" -ForegroundColor Cyan
Write-Host "Acrylic (blur): $(if ($EnableAcrylic) {'Enabled'} else {'Disabled'})" -ForegroundColor Cyan

if (Test-Path $settingsPath) {
    try {
        $jsonContent = Get-Content $settingsPath -Raw -Encoding UTF8
        $settings = $jsonContent | ConvertFrom-Json

        $psProfile = $settings.profiles.list | Where-Object { $_.name -eq "Windows PowerShell" } | Select-Object -First 1
        if ($psProfile) {
            $profileIndex = [array]::IndexOf($settings.profiles.list, $psProfile)
            if ($profileIndex -ge 0) {
                $newProfile = [ordered]@{}
                foreach ($prop in $psProfile.PSObject.Properties) {
                    if ($prop.Name -notin @('font','useAcrylic','acrylicOpacity','opacity','colorScheme','background')) {
                        $newProfile[$prop.Name] = $prop.Value
                    }
                }
                $newProfile['name'] = "Windows PowerShell"
                $newProfile['guid'] = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
                $newProfile['font'] = @{ face = $selectedFont; size = 14 }
                $newProfile['useAcrylic'] = [bool]$EnableAcrylic
                $newProfile['colorScheme'] = $ColorScheme
                $newProfile['background'] = $BackgroundColor
                if ($EnableAcrylic) {
                    $newProfile['acrylicOpacity'] = $Opacity / 100.0
                    if ($newProfile.Contains('opacity')) { $newProfile.Remove('opacity') }
                } else {
                    $newProfile['opacity'] = $Opacity
                    if ($newProfile.Contains('acrylicOpacity')) { $newProfile.Remove('acrylicOpacity') }
                }
                if (-not $newProfile.Contains('hidden')) { $newProfile['hidden'] = $false }

                $settings.profiles.list[$profileIndex] = $newProfile

                $jsonOutput = $settings | ConvertTo-Json -Depth 10
                $jsonOutput | Set-Content -Path $settingsPath -Encoding UTF8

                $backupPath = "$settingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                Copy-Item $settingsPath $backupPath -Force
                Write-Host "Updated Windows Terminal settings. Backup: $backupPath" -ForegroundColor DarkGray
                Write-Host "Restart Windows Terminal to see changes." -ForegroundColor Yellow
            } else {
                Write-Warning "Could not determine profile index for PowerShell in Windows Terminal settings."
            }
        } else {
            Write-Warning "PowerShell profile not found in Windows Terminal settings."
        }
    } catch {
        Write-Warning "Error updating Windows Terminal settings at $settingsPath: $($_.Exception.Message)"
    }
} else {
    Write-Warning "Windows Terminal settings.json not found at $settingsPath. Open Terminal → Settings → Open JSON and confirm it's installed."
}

# Initialize oh-my-posh for this session (if installed)
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        oh-my-posh init pwsh | Invoke-Expression
    } catch {
        Write-Warning "Failed to initialize oh-my-posh in current session: $($_.Exception.Message)"
    }

    # Ensure profile exists and contains init line with Atomic theme
    $profilePath = $PROFILE
    $initLine = 'oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\atomic.omp.json" | Invoke-Expression'
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -notmatch [regex]::Escape($initLine)) {
        Add-Content -Path $profilePath -Value "`n$initLine"
        Write-Host "Added oh-my-posh init line to $profilePath" -ForegroundColor DarkGray
    } else {
        Write-Host "oh-my-posh init line already present in $profilePath" -ForegroundColor DarkGray
    }

    # Reload profile
    try {
        . $profilePath
        Write-Host "Reloaded PowerShell profile from $profilePath" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Could not reload profile $profilePath: $($_.Exception.Message)"
    }
} else {
    Write-Warning "oh-my-posh not found on PATH; skip shell prompt configuration."
}
