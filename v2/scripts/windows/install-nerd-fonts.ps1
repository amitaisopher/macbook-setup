[CmdletBinding()]
param()

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

Write-Host "Configuring legacy console fonts to '$fontName' (size 14) and opacity 90%..." -ForegroundColor Cyan
$consoleKeys = @(
    "HKCU:\Console\Windows PowerShell",
    "HKCU:\Console\%SystemRoot%_system32_windowsPowerShell_v1.0_powershell.exe",
    "HKCU:\Console"
)
foreach ($key in $consoleKeys) {
    Configure-ConsoleFont -KeyPath $key
    # WindowAlpha is 0-255; 90% ~ 229
    Set-ItemProperty -Path $key -Name WindowAlpha -Type DWord -Value 229
}

Write-Host "Updating Windows Terminal defaults to '$terminalFontFace' size $terminalFontSize..." -ForegroundColor Cyan

$path = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $path)) {
    Write-Warning "Windows Terminal settings.json not found at $path. Open Terminal → Settings → Open JSON and confirm it's installed."
}
else {
    try {
        # IMPORTANT: Close Windows Terminal before running this, or it may overwrite on exit.
        $json = Get-Content $path -Raw | ConvertFrom-Json

        # Ensure nested objects exist (PowerShell 5.1-friendly)
        Ensure-JsonProp $json 'profiles' ([pscustomobject]@{})
        Ensure-JsonProp $json.profiles 'defaults' ([pscustomobject]@{})
        Ensure-JsonProp $json.profiles.defaults 'font' ([pscustomobject]@{})

        # Apply changes
        $json.profiles.defaults.font.face = $terminalFontFace
        $json.profiles.defaults.font.size = $terminalFontSize

        # Write back
        $json | ConvertTo-Json -Depth 50 | Set-Content $path -Encoding UTF8
        Write-Host "Updated Windows Terminal settings at $path" -ForegroundColor DarkGray
    }
    catch {
        Write-Warning ("Could not update Windows Terminal settings at {0}: {1}" -f $path, $_.Exception.Message)
    }
}

Write-Host "Nerd font install and console configuration completed." -ForegroundColor Green
