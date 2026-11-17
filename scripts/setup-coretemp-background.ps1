<#
.SYNOPSIS
    Configures Core Temp to run invisibly in the background (starts minimized, hides taskbar button,
    closes to tray instead of exiting) and registers a logon Scheduled Task so CPU temps always stay live.
    Run this script from an Administrator PowerShell window.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error 'Run this script from an Administrator PowerShell window.'
}

$ctExe = Join-Path $env:ProgramFiles 'Core Temp\Core Temp.exe'
$ctIni = Join-Path $env:ProgramFiles 'Core Temp\CoreTemp.ini'
if (-not (Test-Path $ctExe)) {
    Write-Error "Core Temp not found at $ctExe. Install it first: winget install --id ALCPU.CoreTemp --exact"
}

# Stop running instance briefly so INI changes aren't overwritten on exit
Stop-Process -Name 'Core Temp' -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

if (Test-Path $ctIni) {
    $ini = Get-Content $ctIni -Raw
    $ini = $ini -replace 'CloseToSystray=\d+;', 'CloseToSystray=1;'
    $ini = $ini -replace 'HideTaskbarButton=\d+;', 'HideTaskbarButton=1;'
    $ini = $ini -replace 'Minimized=\d+;', 'Minimized=1;'
    $ini = $ini -replace 'SingleInstance=\d+;', 'SingleInstance=1;'
    $ini | Set-Content -Path $ctIni -Encoding ASCII
    Write-Host '==> Updated CoreTemp.ini (Minimized=1, CloseToSystray=1, HideTaskbarButton=1, SingleInstance=1).' -ForegroundColor Cyan
}

# Register silent AtLogon Highest-privilege task (no UAC prompts on boot)
$taskName = 'CoreTempBackground'
$action = New-ScheduledTaskAction -Execute $ctExe
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 0)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Start-ScheduledTask -TaskName $taskName
Write-Host '==> Core Temp is now running silently in the background and will auto-start on login.' -ForegroundColor Green
