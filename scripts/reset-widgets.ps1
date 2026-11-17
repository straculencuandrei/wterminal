<#
.SYNOPSIS
    Snaps all 9 AmoledTerminal Rainmeter widgets back to their default positions (live, without restarting Rainmeter).
#>
[CmdletBinding()]
param(
    [switch]$OpenSettings
)

Add-Type -AssemblyName System.Windows.Forms
$rainmeterExe = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
if (-not (Test-Path $rainmeterExe)) {
    Write-Error "Rainmeter.exe not found at $rainmeterExe"
}

$scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$rightX = $scr.Width - 300
$fftX = [int]($scr.Width / 2 - 154)
$fftY = $scr.Height - 48

if (-not (Get-Process -Name 'Rainmeter' -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe -ArgumentList "`"$rainmeterExe`""
    Start-Sleep -Seconds 2
}

$layout = @(
    @{ Cfg = 'AmoledTerminal\HeroClock';    Ini = 'HeroClock.ini';    X = 28;      Y = 28 },
    @{ Cfg = 'AmoledTerminal\Weather';      Ini = 'Weather.ini';      X = 28;      Y = 162 },
    @{ Cfg = 'AmoledTerminal\Calendar';     Ini = 'Calendar.ini';     X = 28;      Y = 270 },
    @{ Cfg = 'AmoledTerminal\Notes';        Ini = 'Notes.ini';        X = 28;      Y = 364 },
    @{ Cfg = 'AmoledTerminal\SysPill';      Ini = 'SysPill.ini';      X = $rightX; Y = 28 },
    @{ Cfg = 'AmoledTerminal\GpuThermals';  Ini = 'GpuThermals.ini';  X = $rightX; Y = 162 },
    @{ Cfg = 'AmoledTerminal\PowerAudio';   Ini = 'PowerAudio.ini';   X = $rightX; Y = 284 },
    @{ Cfg = 'AmoledTerminal\TerminalDock'; Ini = 'TerminalDock.ini'; X = $rightX; Y = 406 },
    @{ Cfg = 'AmoledTerminal\AudioFFT';     Ini = 'AudioFFT.ini';     X = $fftX;   Y = $fftY }
)

foreach ($w in $layout) {
    & $rainmeterExe !ActivateConfig "$($w.Cfg)" "$($w.Ini)"
    & $rainmeterExe !Move $w.X $w.Y "$($w.Cfg)"
    & $rainmeterExe !ZPos 0 "$($w.Cfg)"
}

if ($OpenSettings) {
    & $rainmeterExe !ToggleConfig 'AmoledTerminal\Settings' 'Settings.ini'
    & $rainmeterExe !Move ([int]($scr.Width / 2 - 140)) ([int]($scr.Height / 2 - 164)) 'AmoledTerminal\Settings'
}

Write-Host 'Reset all AmoledTerminal widgets to default positions.' -ForegroundColor Green
