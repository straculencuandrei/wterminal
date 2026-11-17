<#
.SYNOPSIS
    Snaps all 9 AmoledTerminal Rainmeter widgets cleanly onto the current display
    with crisp DPI awareness, adaptive scaling, and WorkArea-safe margins.
#>
[CmdletBinding()]
param(
    [switch]$OpenSettings
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WtermDpiHelper {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("shcore.dll")] public static extern int GetProcessDpiAwareness(IntPtr hprocess, out int awareness);
}
"@
[void][WtermDpiHelper]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms

$rainmeterExe = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
if (-not (Test-Path $rainmeterExe)) {
    Write-Error "Rainmeter.exe not found at $rainmeterExe"
    exit 1
}

# Ensure Rainmeter renders crisp native pixels on high-DPI laptop displays (125%/150%)
$layersKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
New-Item -Path $layersKey -Force | Out-Null
$curLayer = (Get-ItemProperty -Path $layersKey -Name $rainmeterExe -ErrorAction SilentlyContinue).$rainmeterExe
if ($curLayer -ne '~ HIGHDPIAWARE') {
    Set-ItemProperty -Path $layersKey -Name $rainmeterExe -Value '~ HIGHDPIAWARE' -Type String
}

$scr = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$work = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

$wx = $work.X; $wy = $work.Y; $ww = $work.Width; $wh = $work.Height
$sx = $scr.X;  $sy = $scr.Y;  $sw = $scr.Width;  $sh = $scr.Height

$rw = $ww / 1920.0
$rh = $wh / 1048.0
$raw = [Math]::Min($rw, $rh)
if ($raw -ge 1.0) {
    $s = 1.0 + ($raw - 1.0) * 0.75
} else {
    $s = 1.0 - (1.0 - $raw) * 0.65
}
$s = [Math]::Min(1.50, [Math]::Max(0.78, $s))

$workBottom = $wy + $wh
$screenBottom = $sy + $sh
$bottomReserved = [Math]::Max(0, $screenBottom - $workBottom)
$hasExternalBottomDock = ($bottomReserved -lt 36)
$dockPerUnit = if ($hasExternalBottomDock) { 96 } else { 18 }

$maxVerticalRatio = ($wh - 16) / (16 + 476 + 14 + 34 + $dockPerUnit)
if ($maxVerticalRatio -lt $s) {
    $s = [Math]::Min(1.50, [Math]::Max(0.68, $maxVerticalRatio))
}
$maxWidthRatio = ($ww * 0.36) / 272.0
if ($maxWidthRatio -lt $s) {
    $s = [Math]::Min(1.50, [Math]::Max(0.68, $maxWidthRatio))
}
$s = [Math]::Round($s, 2)
$sStr = $s.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)
$areaKey = "$wx,$wy,$ww,$wh,$sw,$sh"

$varPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins\AmoledTerminal\@Resources\Variables.inc'
if (Test-Path $varPath) {
    $vtxt = [System.IO.File]::ReadAllText($varPath)
    $setVar = {
        param([string]$text, [string]$k, [string]$val)
        $pat = "(?m)^" + [regex]::Escape($k) + "=.*$"
        if ($text -match $pat) {
            return [regex]::Replace($text, $pat, "$k=$val")
        }
        if (-not $text.EndsWith("`n")) { $text += "`r`n" }
        return $text + "$k=$val`r`n"
    }
    $vtxt = & $setVar $vtxt 'S' $sStr
    $vtxt = & $setVar $vtxt 'LastAreaKey' $areaKey
    $vtxt = & $setVar $vtxt 'PendingLayout' '0'
    [System.IO.File]::WriteAllText($varPath, $vtxt, [System.Text.UTF8Encoding]::new($false))
}

$rmProc = Get-Process -Name 'Rainmeter' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($rmProc) {
    $aw = -1
    [void][WtermDpiHelper]::GetProcessDpiAwareness($rmProc.Handle, [ref]$aw)
    if ($aw -eq 0) {
        Stop-Process -Name 'Rainmeter' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        $rmProc = $null
    }
}
if (-not $rmProc) {
    Start-Process -FilePath $rainmeterExe
    Start-Sleep -Seconds 2
}

$marginX = [Math]::Max(12, [int][Math]::Round(24 * $s))
$topY = $wy + [Math]::Max(12, [int][Math]::Round(16 * $s))
$gapY = [Math]::Max(8, [int][Math]::Round(12 * $s))
$cardW = [int][Math]::Round(272 * $s)
$leftX = $wx + $marginX
$rightX = $wx + $ww - $cardW - $marginX

$hHero = [int][Math]::Round(122 * $s)
$hWeather = [int][Math]::Round(96 * $s)
$hCalendar = [int][Math]::Round(82 * $s)
$hSys = [int][Math]::Round(122 * $s)
$hGpu = [int][Math]::Round(110 * $s)
$hPwr = [int][Math]::Round(110 * $s)

$fftW = 2 * [int][Math]::Round(12 * $s) + 24 * [Math]::Max(2, [int][Math]::Round(8 * $s)) + 23 * [Math]::Max(1, [int][Math]::Round(4 * $s))
$fftH = [int][Math]::Round(34 * $s)
$fftX = $wx + [int][Math]::Floor(($ww - $fftW) / 2)
$dockClear = if ($hasExternalBottomDock) { [Math]::Max(82, [int][Math]::Round(96 * $s)) } else { [Math]::Max(14, [int][Math]::Round(18 * $s)) }
$fftY = $workBottom - $dockClear - $fftH

$layout = @(
    @{ Cfg = 'AmoledTerminal\HeroClock';    Ini = 'HeroClock.ini';    X = $leftX;  Y = $topY },
    @{ Cfg = 'AmoledTerminal\Weather';      Ini = 'Weather.ini';      X = $leftX;  Y = ($topY + $hHero + $gapY) },
    @{ Cfg = 'AmoledTerminal\Calendar';     Ini = 'Calendar.ini';     X = $leftX;  Y = ($topY + $hHero + $gapY + $hWeather + $gapY) },
    @{ Cfg = 'AmoledTerminal\Notes';        Ini = 'Notes.ini';        X = $leftX;  Y = ($topY + $hHero + $gapY + $hWeather + $gapY + $hCalendar + $gapY) },
    @{ Cfg = 'AmoledTerminal\SysPill';      Ini = 'SysPill.ini';      X = $rightX; Y = $topY },
    @{ Cfg = 'AmoledTerminal\GpuThermals';  Ini = 'GpuThermals.ini';  X = $rightX; Y = ($topY + $hSys + $gapY) },
    @{ Cfg = 'AmoledTerminal\PowerAudio';   Ini = 'PowerAudio.ini';   X = $rightX; Y = ($topY + $hSys + $gapY + $hGpu + $gapY) },
    @{ Cfg = 'AmoledTerminal\TerminalDock'; Ini = 'TerminalDock.ini'; X = $rightX; Y = ($topY + $hSys + $gapY + $hGpu + $gapY + $hPwr + $gapY) },
    @{ Cfg = 'AmoledTerminal\AudioFFT';     Ini = 'AudioFFT.ini';     X = $fftX;   Y = $fftY }
)

& $rainmeterExe !RefreshGroup AmoledTerminal
Start-Sleep -Milliseconds 400

foreach ($w in $layout) {
    & $rainmeterExe !ActivateConfig "$($w.Cfg)" "$($w.Ini)"
    & $rainmeterExe !Move $w.X $w.Y "$($w.Cfg)"
    & $rainmeterExe !ZPos 0 "$($w.Cfg)"
}
& $rainmeterExe !Draggable 0 'AmoledTerminal\AudioFFT'
& $rainmeterExe !ClickThrough 1 'AmoledTerminal\AudioFFT'

if ($OpenSettings) {
    $setW = [int][Math]::Round(280 * $s)
    $setH = [int][Math]::Round(328 * $s)
    & $rainmeterExe !ToggleConfig 'AmoledTerminal\Settings' 'Settings.ini'
    & $rainmeterExe !Move ($wx + [int][Math]::Floor(($ww - $setW) / 2)) ($wy + [int][Math]::Floor(($wh - $setH) / 2)) 'AmoledTerminal\Settings'
}

Write-Host "Reset all AmoledTerminal widgets (scale=${sStr}, area=${ww}x${wh})." -ForegroundColor Green
