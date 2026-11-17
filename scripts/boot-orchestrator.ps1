<#
.SYNOPSIS
    Fast, boot-order-safe, self-healing launcher for the wterminal desktop (Seelen UI + Rainmeter widgets).

.DESCRIPTION
    Runs at logon (scheduled task 'WterminalBoot').
      1. Waits briefly for Explorer's Shell_TrayWnd to appear and settle (~1-2 s).
      2. Immediately enforces native Windows taskbar auto-hide (StuckRects3 + SHAppBarMessage)
         and dismisses noisy modal boot dialogs (duplicate Core Temp / Widget Error / Flow hotkey).
      3. Ensures Seelen UI Service + Seelen UI reach ready state without killing cold-boot
         Start Menu indexing prematurely, and recovers slu-service if it hung during boot.
      4. Waits briefly for Wallpaper Engine (max 8 s) and runs ~/.config/reset-widgets.ps1 so
         Rainmeter applies native DPI scaling (#S# / #FS#) onto the settled WorkArea.
    Everything is logged to %LOCALAPPDATA%\wterminal\boot.log.
#>
$ErrorActionPreference = 'SilentlyContinue'

# ---- single instance ---------------------------------------------------------------------------------
$mutex = New-Object System.Threading.Mutex($false, 'Local\WterminalBoot')
if (-not $mutex.WaitOne(0)) { exit 0 }

# ---- logging -----------------------------------------------------------------------------------------
$logDir = Join-Path $env:LOCALAPPDATA 'wterminal'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir 'boot.log'
if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 256KB)) { Move-Item $logFile "$logFile.bak" -Force }
$sw = [System.Diagnostics.Stopwatch]::StartNew()
function Log([string]$m) { Add-Content -Path $logFile -Value ("{0} [+{1,5:N1}s] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $sw.Elapsed.TotalSeconds, $m) }
Log '--- boot orchestrator start ---'

# ---- native helpers ----------------------------------------------------------------------------------
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class WtBootNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct APPBARDATA {
        public uint cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public IntPtr lParam;
    }
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("shell32.dll")] public static extern UIntPtr SHAppBarMessage(uint dwMessage, ref APPBARDATA pData);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    public static int CountLargeVisibleWindows(int[] pids, int minW, int minH) {
        if (pids == null || pids.Length == 0) return 0;
        var set = new HashSet<int>(pids);
        int count = 0;
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            uint p;
            GetWindowThreadProcessId(h, out p);
            if (!set.Contains((int)p)) return true;
            RECT r;
            if (GetWindowRect(h, out r)) {
                int w = r.right - r.left;
                int hgt = r.bottom - r.top;
                if (w >= minW && hgt >= minH) count++;
            }
            return true;
        }, IntPtr.Zero);
        return count;
    }
}
"@

$seelenPkgFamily = 'Seelen.SeelenUI_p6yyn03m1894e'
$seelenLog = Join-Path $env:LOCALAPPDATA 'com.seelen.seelen-ui\logs\Seelen UI.log'
$WM_CLOSE = 0x0010

function Get-TrayPid {
    $h = [WtBootNative]::FindWindow('Shell_TrayWnd', $null)
    if ($h -eq [IntPtr]::Zero) { return 0 }
    $p = 0
    [void][WtBootNative]::GetWindowThreadProcessId($h, [ref]$p)
    return [int]$p
}

# Dismiss modal boot error popups (duplicate Core Temp / Seelen Widget Error / Flow Launcher hotkey dialog)
function Dismiss-BootDialogs {
    foreach ($title in @('Core Temp', 'Widget Error')) {
        $hwnd = [WtBootNative]::FindWindow('#32770', $title)
        if ($hwnd -ne [IntPtr]::Zero -and [WtBootNative]::IsWindowVisible($hwnd)) {
            $r = New-Object WtBootNative+RECT
            [void][WtBootNative]::GetWindowRect($hwnd, [ref]$r)
            $w = $r.right - $r.left
            $h = $r.bottom - $r.top
            if ($w -le 560 -and $h -le 340) {
                [void][WtBootNative]::PostMessage($hwnd, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
                Log "dismissed modal dialog: '$title' (${w}x${h})"
            }
        }
    }

    $flowHwnd = [WtBootNative]::FindWindow($null, 'Flow Launcher')
    if ($flowHwnd -ne [IntPtr]::Zero -and [WtBootNative]::IsWindowVisible($flowHwnd)) {
        $r = New-Object WtBootNative+RECT
        [void][WtBootNative]::GetWindowRect($flowHwnd, [ref]$r)
        $w = $r.right - $r.left
        $h = $r.bottom - $r.top
        if ($w -le 520 -and $h -ge 140 -and $h -le 340) {
            [void][WtBootNative]::PostMessage($flowHwnd, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
            Log "dismissed dialog: 'Flow Launcher' (${w}x${h})"
        }
    }
}

# 1. Wait for Explorer shell (Shell_TrayWnd present with same PID for 2 checks, 500ms interval, max 30s)
function Wait-Shell([int]$timeoutSec = 30) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $stable = 0
    $last = 0
    while ((Get-Date) -lt $deadline) {
        Dismiss-BootDialogs
        $p = Get-TrayPid
        if ($p -gt 0 -and $p -eq $last) { $stable++ } else { $stable = 0 }
        $last = $p
        if ($stable -ge 2) { Log "shell ready (explorer pid $p)"; return $true }
        Start-Sleep -Milliseconds 500
    }
    Log 'shell wait timed out - continuing anyway'
    return $false
}

# 2. Native Windows taskbar -> auto-hide (StuckRects3 registry + live SHAppBarMessage)
function Ensure-NativeTaskbarAutoHide {
    $srKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    if (Test-Path $srKey) {
        $sr = (Get-ItemProperty -Path $srKey -Name 'Settings').Settings
        if ($sr -and $sr.Length -gt 8 -and $sr[8] -ne 0x03) {
            $sr[8] = 0x03
            Set-ItemProperty -Path $srKey -Name 'Settings' -Value $sr -Type Binary
            Log 'updated StuckRects3[8] = 0x03'
        }
    }

    $hwnd = [WtBootNative]::FindWindow('Shell_TrayWnd', $null)
    if ($hwnd -eq [IntPtr]::Zero) { return }
    $abd = New-Object WtBootNative+APPBARDATA
    $abd.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($abd)
    $abd.hWnd = $hwnd
    $state = [int][WtBootNative]::SHAppBarMessage(4, [ref]$abd)   # ABM_GETSTATE
    if (($state -band 1) -eq 0) {
        $abd.lParam = [IntPtr]3                                     # ABS_AUTOHIDE | ABS_ALWAYSONTOP
        [void][WtBootNative]::SHAppBarMessage(10, [ref]$abd)        # ABM_SETSTATE
        Log 'native taskbar set to auto-hide'
    }
}

# 3. Seelen UI Service (supervises seelen-ui, hides native taskbar, registers shortcuts)
function Start-SeelenService {
    if (Get-Process slu-service) { return $true }
    Log 'starting Seelen UI Service via scheduled task'
    Start-ScheduledTask -TaskPath '\Seelen\' -TaskName 'Seelen UI Service'
    for ($i = 0; $i -lt 5; $i++) {
        if (Get-Process slu-service) { Log 'service running (task)'; return $true }
        Start-Sleep -Seconds 1
    }
    Log 'task start failed - activating Service app by AppUserModelID'
    Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$seelenPkgFamily!Service"
    for ($i = 0; $i -lt 8; $i++) {
        if (Get-Process slu-service) { Log 'service running (AppsFolder)'; return $true }
        Start-Sleep -Seconds 1
    }
    Log 'WARNING: Seelen UI Service could not be started'
    return $false
}

function Start-SeelenUi {
    Log 'launching Seelen UI by AppUserModelID'
    Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$seelenPkgFamily!App"
}

# Fast, log-spam-safe readiness check: checks visible Seelen bar/dock windows first (<2ms),
# falling back to head+tail chunks of Seelen UI.log (never scanning multi-MB full log).
function Test-SeelenReady {
    $procs = @(Get-Process seelen-ui -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { return $false }

    [int[]]$pids = @($procs | ForEach-Object { [int]$_.Id })
    if ([WtBootNative]::CountLargeVisibleWindows($pids, 200, 24) -ge 2) {
        return $true
    }

    if (-not (Test-Path $seelenLog)) { return $false }
    try {
        $fs = [System.IO.File]::Open($seelenLog, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $chunkBytes = 262144
            $len = $fs.Length
            $enc = [System.Text.Encoding]::UTF8
            $sample = ''
            if ($len -le ($chunkBytes * 2)) {
                $buf = New-Object byte[] $len
                $read = $fs.Read($buf, 0, [int]$len)
                $sample = $enc.GetString($buf, 0, $read)
            } else {
                $buf1 = New-Object byte[] $chunkBytes
                $r1 = $fs.Read($buf1, 0, $chunkBytes)
                [void]$fs.Seek(-$chunkBytes, [System.IO.SeekOrigin]::End)
                $buf2 = New-Object byte[] $chunkBytes
                $r2 = $fs.Read($buf2, 0, $chunkBytes)
                $sample = $enc.GetString($buf1, 0, $r1) + "`n" + $enc.GetString($buf2, 0, $r2)
            }
        } finally {
            $fs.Dispose()
        }

        $startIdx = $sample.LastIndexOf('Starting Seelen UI v')
        $exitIdx  = $sample.LastIndexOf('Exiting Seelen UI')
        $readyMatches = [regex]::Matches($sample, '@seelen/weg\?monitorId=[^\]]+\] status changed to: Ready')
        if ($readyMatches.Count -eq 0) { return $false }
        $readyIdx = $readyMatches[$readyMatches.Count - 1].Index
        return ($readyIdx -gt $startIdx) -and ($readyIdx -gt $exitIdx)
    } catch {
        return $false
    }
}

function Ensure-Seelen {
    [void](Start-SeelenService)

    $launchedUi = $false
    for ($sec = 0; $sec -lt 35; $sec++) {
        Dismiss-BootDialogs
        if (Test-SeelenReady) {
            Log 'Seelen UI READY'
            break
        }
        if ($sec -ge 3 -and -not $launchedUi -and -not (Get-Process seelen-ui)) {
            Start-SeelenUi
            $launchedUi = $true
        }
        Start-Sleep -Seconds 1
    }

    if (-not (Test-SeelenReady)) {
        Log 'Seelen UI not ready after 35s - recycling once'
        Get-Process seelen-ui | Stop-Process -Force
        Start-Sleep -Seconds 2
        Start-SeelenUi
        for ($sec = 0; $sec -lt 20; $sec++) {
            Dismiss-BootDialogs
            if (Test-SeelenReady) {
                Log 'Seelen UI READY (after recycle)'
                break
            }
            Start-Sleep -Seconds 1
        }
    }

    $ok = Test-SeelenReady
    if ($ok -and -not (Get-Process slu-service)) {
        Log 'slu-service not running after Seelen UI ready - recovering service'
        [void](Start-SeelenService)
        Start-Sleep -Seconds 2
        Ensure-NativeTaskbarAutoHide
    }
    return $ok
}

# 4. Wallpaper Engine (optional, max 8s wait)
function Wait-WallpaperEngine([int]$timeoutSec = 8) {
    $installed = (Get-Service 'Wallpaper Engine Service') -or (Test-Path "${env:ProgramFiles(x86)}\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe")
    if (-not $installed) { return }
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        if ((Get-Process wallpaper64) -or (Get-Process wallpaper32)) {
            Log 'wallpaper engine running'
            Start-Sleep -Seconds 1
            return
        }
        Start-Sleep -Seconds 1
    }
    Log 'wallpaper engine not detected in 8s - continuing'
}

# ---- main --------------------------------------------------------------------------------------------
[void](Wait-Shell)
Ensure-NativeTaskbarAutoHide
Dismiss-BootDialogs

$seelenOk = Ensure-Seelen
Ensure-NativeTaskbarAutoHide
Wait-WallpaperEngine
Ensure-NativeTaskbarAutoHide
Dismiss-BootDialogs

$resetScript = Join-Path $env:USERPROFILE '.config\reset-widgets.ps1'
if (Test-Path $resetScript) {
    Log 'running reset-widgets.ps1'
    & $resetScript *>> $logFile
} else {
    $rmExe = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
    if (Test-Path $rmExe) {
        if (-not (Get-Process Rainmeter)) { Log 'starting Rainmeter'; Start-Process -FilePath $rmExe; Start-Sleep -Seconds 2 }
        & $rmExe '!ZPosGroup' '0' 'AmoledTerminal' | Out-Null
    }
}

Start-Sleep -Seconds 3
Dismiss-BootDialogs
Ensure-NativeTaskbarAutoHide
if ($seelenOk -and -not (Get-Process slu-service)) {
    Log 'late check: slu-service missing - restarting'
    [void](Start-SeelenService)
    Start-Sleep -Seconds 2
    Ensure-NativeTaskbarAutoHide
}

Log ('--- boot orchestrator done (seelen ready: {0}) ---' -f $seelenOk)
$mutex.ReleaseMutex()
