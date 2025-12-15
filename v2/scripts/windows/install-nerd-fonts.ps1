[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$fontPkg = "nerd-fonts-droidsansmono"
$fontName = "DroidSansMono Nerd Font"
$fontSizeHex = 0x000E0000  # 14px height

function Ensure-Choco {
    if (Get-Command choco -ErrorAction SilentlyContinue) { return }
    Write-Host "Installing Chocolatey..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Ensure-Font {
    if (choco list --local-only --exact $fontPkg | Select-String $fontPkg) {
        Write-Host "$fontPkg already installed; skipping install." -ForegroundColor DarkGray
        return
    }
    Write-Host "Installing $fontPkg via Chocolatey..." -ForegroundColor Cyan
    choco install -y $fontPkg
}

function Configure-ConsoleFont {
    param(
        [string]$KeyPath
    )
    if (-not (Test-Path $KeyPath)) {
        New-Item -Path $KeyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $KeyPath -Name FaceName -Value $fontName
    Set-ItemProperty -Path $KeyPath -Name FontSize -Type DWord -Value $fontSizeHex
}

Ensure-Choco
Ensure-Font

Write-Host "Configuring console fonts to $fontName size 14 and opacity 90%..." -ForegroundColor Cyan
$consoleKeys = @(
    "HKCU:\Console",
    "HKCU:\Console\%SystemRoot%_system32_windowsPowerShell_v1.0_powershell.exe",
    "HKCU:\Console\Windows PowerShell"
)
foreach ($key in $consoleKeys) {
    Configure-ConsoleFont -KeyPath $key
    # WindowAlpha is 0-255; 90% ~ 229
    Set-ItemProperty -Path $key -Name WindowAlpha -Type DWord -Value 229
}

Write-Host "Updating Windows Terminal profiles for PowerShell..." -ForegroundColor Cyan
$wtPaths = @(
    Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"
)

foreach ($path in $wtPaths) {
    if (-not (Test-Path $path)) { continue }
    try {
        $json = Get-Content -Raw -Path $path | ConvertFrom-Json
        if (-not $json.profiles) { continue }
        $changed = $false
        foreach ($p in $json.profiles.list) {
            if ($p.name -notmatch 'PowerShell') { continue }
            $p.fontFace = $fontName
            $p.fontSize = 14
            $p.useAcrylic = $true
            $p.opacity = 90
            $changed = $true
        }
        if ($changed) {
            $json | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
            Write-Host "Updated Windows Terminal settings at $path" -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "Could not update Windows Terminal settings at $path: $_"
    }
}

Write-Host "Nerd font install and console configuration completed." -ForegroundColor Green
