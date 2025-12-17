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

$fontPkg     = "nerd-fonts-droidsansmono"
$fontName    = "DroidSansMono Nerd Font"     # Console (legacy) + Terminal (if available)
$terminalFontFace = "DroidSansMono Nerd Font" # Windows Terminal font face
$terminalFontSize = 14
$fontSizeHex = 0x000E0000  # 14px height (console uses this packed DWORD format)

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
        [Parameter(Mandatory)][string]$KeyPath
    )
    if (-not (Test-Path $KeyPath)) {
        New-Item -Path $KeyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $KeyPath -Name FaceName -Value $fontName
    Set-ItemProperty -Path $KeyPath -Name FontSize -Type DWord -Value $fontSizeHex
}

# PowerShell 5.1-safe: adds a property if missing (so later assignments won't throw)
function Ensure-JsonProp {
    param(
        [Parameter(Mandatory)] $Obj,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)] $Value
    )

    if (-not $Obj.PSObject.Properties.Match($Name)) {
        $Obj | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
    }
}

Ensure-Choco
Ensure-Font

Write-Host "Nerd font installation completed (DroidSansMono)." -ForegroundColor Green
