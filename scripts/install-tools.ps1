<#
.SYNOPSIS
    Installs lightweight Windows 11 customization tools via winget for the Obsidian Glass theme.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$packages = @(
    @{ Id = 'RamenSoftware.Windhawk'; Name = 'Windhawk (Taskbar Floating Dock)' },
    @{ Id = 'Rainmeter.Rainmeter'; Name = 'Rainmeter (Minimal Desktop Widgets)' },
    @{ Id = 'Flow-Launcher.Flow-Launcher'; Name = 'Flow Launcher (Spotlight Replacement)' },
    @{ Id = 'ALCPU.CoreTemp'; Name = 'Core Temp (CPU Temperature Sensor for SysPill)' }
)

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error 'winget was not found on PATH. Install App Installer from the Microsoft Store first.'
}

foreach ($pkg in $packages) {
    Write-Host "==> Installing $($pkg.Name) [$($pkg.Id)]..." -ForegroundColor Cyan
    winget install --id $pkg.Id --exact --accept-package-agreements --accept-source-agreements
}

Write-Host "`nDone! PowerToys is already on your system if you prefer PowerToys Run / Command Palette." -ForegroundColor Green
Write-Host "Next step: run .\scripts\apply-theme.ps1 to deploy skins, Flow theme, and wallpaper." -ForegroundColor Gray
