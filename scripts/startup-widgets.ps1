<#
.SYNOPSIS
    Boot-order-safe launcher for AmoledTerminal Rainmeter widgets.
    Waits for Wallpaper Engine and Seelen UI to initialize their desktop layers
    before launching Rainmeter so widgets sit cleanly above the wallpaper and
    respect Seelen UI's WorkArea bar and bottom dock.
#>
$ErrorActionPreference = 'SilentlyContinue'

$rmExe = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
if (-not (Test-Path $rmExe)) { exit 0 }

$hasWE = (Test-Path "${env:ProgramFiles(x86)}\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe") -or
         (Get-Service 'Wallpaper Engine Service' -ErrorAction SilentlyContinue)
$hasSeelen = [bool](Get-AppxPackage -Name 'Seelen.SeelenUI' -ErrorAction SilentlyContinue)

# Wait up to 20s for desktop shell overlays (Wallpaper Engine + Seelen UI) to start
$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
    $weReady = (-not $hasWE) -or [bool](Get-Process -Name 'wallpaper64','wallpaper32' -ErrorAction SilentlyContinue)
    $seelenReady = (-not $hasSeelen) -or [bool](Get-Process -Name 'seelen-ui' -ErrorAction SilentlyContinue)
    if ($weReady -and $seelenReady) { break }
    Start-Sleep -Milliseconds 500
}

# Allow WorkerW and AppBar WorkingArea to settle
Start-Sleep -Seconds 2

if (-not (Get-Process -Name 'Rainmeter' -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $rmExe
    Start-Sleep -Seconds 3
}

# Ensure widgets sit at desktop layer above Wallpaper Engine WorkerW without overriding custom drags
& $rmExe !ZPosGroup 0 AmoledTerminal | Out-Null
