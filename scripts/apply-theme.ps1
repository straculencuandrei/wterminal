<#
.SYNOPSIS
    Deploys the complete wterminal AMOLED Dark-Grey suite:
    Rainmeter widgets, Flow Launcher theme & settings, Windows Terminal acrylic theme,
    Starship/Fastfetch/Clink configs, PowerShell & cmd profiles, and Start Menu WT routing.
.PARAMETER ApplyTerminalTheme
    Deploys Windows Terminal AMOLED theme, Starship, Fastfetch, Clink, PowerShell profiles, cmd AutoRun, console palette, and Start Menu WT shortcuts.
.PARAMETER SetupRainmeterLayout
    Writes the non-overlapping 9-widget Rainmeter.ini layout (AlwaysOnTop=0 for Wallpaper Engine compatibility, AudioFFT above taskbar).
.PARAMETER DeclutterTaskbar
    Applies reversible Windows 11 taskbar declutter registry tweaks (centered icons, hide Search/Widgets/Task View).
.PARAMETER AutoHideTaskbar
    Auto-hides the native Windows 11 taskbar (recommended when using Seelen UI's macOS dock).
.PARAMETER HideDesktopIcons
    Hides desktop icons for an ultra-minimal canvas (reversible via -RestoreDefaults).
.PARAMETER SetStaticWallpaper
    Applies the included 4K AMOLED wallpaper (skipped automatically if Wallpaper Engine is detected).
.PARAMETER RestoreDefaults
    Restores taskbar declutter and desktop icon visibility to standard Windows 11 defaults.
#>
[CmdletBinding()]
param(
    [switch]$ApplyTerminalTheme,
    [switch]$SetupRainmeterLayout,
    [switch]$DeclutterTaskbar,
    [switch]$AutoHideTaskbar,
    [switch]$HideDesktopIcons,
    [switch]$SetStaticWallpaper,
    [switch]$RestoreDefaults
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Set-DesktopWallpaper {
    param([Parameter(Mandatory)][string]$ImagePath)

    Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class WallpaperHelper {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    $SPI_SETDESKWALLPAPER = 0x0014
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDCHANGE = 0x02
    $ok = [WallpaperHelper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, ($SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE))
    if (-not $ok) {
        Write-Warning "Failed to set wallpaper automatically. Set $ImagePath manually in Settings -> Personalization."
    }
}

$advKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$searchKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'

if ($RestoreDefaults) {
    Write-Host '==> Restoring taskbar and desktop icon defaults...' -ForegroundColor Yellow
    Set-ItemProperty -Path $advKey -Name 'TaskbarAl' -Value 1 -Type DWord
    Set-ItemProperty -Path $advKey -Name 'TaskbarMn' -Value 1 -Type DWord
    Set-ItemProperty -Path $advKey -Name 'ShowTaskViewButton' -Value 1 -Type DWord
    Set-ItemProperty -Path $advKey -Name 'HideIcons' -Value 0 -Type DWord
    if (Test-Path $searchKey) {
        Set-ItemProperty -Path $searchKey -Name 'SearchboxTaskbarMode' -Value 2 -Type DWord
    }
    $srKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    if (Test-Path $srKey) {
        $sr = (Get-ItemProperty $srKey).Settings
        $sr[8] = 0x02
        Set-ItemProperty -Path $srKey -Name 'Settings' -Value $sr -Type Binary
    }
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Write-Host 'Defaults restored.' -ForegroundColor Green
    return
}

# 1. Deploy Rainmeter skins (.ini as UTF-16 LE for symbol fidelity; .inc/.lua as UTF-8 without BOM for Lua/Rainmeter)
$rainmeterDest = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins\AmoledTerminal'
$rainmeterSrc = Join-Path $RepoRoot 'rainmeter\AmoledTerminal'
Write-Host "==> Deploying Rainmeter skins to $rainmeterDest" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $rainmeterDest -Force | Out-Null
Copy-Item -Path "$rainmeterSrc\*" -Destination $rainmeterDest -Recurse -Force
Get-ChildItem $rainmeterDest -Recurse -Include '*.ini' | ForEach-Object {
    $txt = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($_.FullName, $txt, [System.Text.Encoding]::Unicode)
}
Get-ChildItem $rainmeterDest -Recurse -Include '*.inc','*.lua','*.py','*.json' | ForEach-Object {
    $txt = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($_.FullName, $txt, [System.Text.UTF8Encoding]::new($false))
}

if ($SetupRainmeterLayout) {
    $rmDir = Join-Path $env:APPDATA 'Rainmeter'
    New-Item -ItemType Directory -Path $rmDir -Force | Out-Null
    $rainmeterIni = @"
[Rainmeter]
Logging=0
SkinPath=$env:USERPROFILE\Documents\Rainmeter\Skins\

[AmoledTerminal\HeroClock]
Active=1
WindowX=(#WORKAREAX#+24)
WindowY=(#WORKAREAY#+16)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\Weather]
Active=1
WindowX=(#WORKAREAX#+24)
WindowY=(#WORKAREAY#+150)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\Calendar]
Active=1
WindowX=(#WORKAREAX#+24)
WindowY=(#WORKAREAY#+258)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\Notes]
Active=1
WindowX=(#WORKAREAX#+24)
WindowY=(#WORKAREAY#+352)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\SysPill]
Active=1
WindowX=(#WORKAREAX#+#WORKAREAWIDTH#-296)
WindowY=(#WORKAREAY#+16)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\GpuThermals]
Active=1
WindowX=(#WORKAREAX#+#WORKAREAWIDTH#-296)
WindowY=(#WORKAREAY#+150)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\PowerAudio]
Active=1
WindowX=(#WORKAREAX#+#WORKAREAWIDTH#-296)
WindowY=(#WORKAREAY#+272)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\AgyTokens]
Active=1
WindowX=(#WORKAREAX#+#WORKAREAWIDTH#-296)
WindowY=(#WORKAREAY#+394)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\TerminalDock]
Active=1
WindowX=(#WORKAREAX#+#WORKAREAWIDTH#-296)
WindowY=(#WORKAREAY#+528)
AlwaysOnTop=0
Draggable=1
SnapEdges=1
KeepOnScreen=1

[AmoledTerminal\AudioFFT]
Active=1
WindowX=(#WORKAREAX#+#WORKAREAWIDTH#/2-154)
WindowY=(#WORKAREAY#+#WORKAREAHEIGHT#-130)
AlwaysOnTop=0
Draggable=0
ClickThrough=1
SnapEdges=1
KeepOnScreen=1
"@
    $rainmeterIni | Set-Content -Path (Join-Path $rmDir 'Rainmeter.ini') -Encoding Unicode
    Write-Host '==> Wrote WorkArea-adaptive Rainmeter.ini widget layout.' -ForegroundColor Cyan
}

# Ensure Rainmeter renders crisp native DPI pixels (prevents blurry 125%/150% DWM bitmap scaling)
$rmExePath = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
if (Test-Path $rmExePath) {
    $layersKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    New-Item -Path $layersKey -Force | Out-Null
    Set-ItemProperty -Path $layersKey -Name $rmExePath -Value '~ HIGHDPIAWARE' -Type String
}

# 2. Deploy Flow Launcher & Seelen UI themes
$flowThemesDir = Join-Path $env:APPDATA 'FlowLauncher\Themes'
$flowSrc = Join-Path $RepoRoot 'flow-launcher\AmoledTerminal.xaml'
Write-Host "==> Deploying Flow Launcher theme to $flowThemesDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $flowThemesDir -Force | Out-Null
Copy-Item -Path $flowSrc -Destination (Join-Path $flowThemesDir 'AmoledTerminal.xaml') -Force

$seelenSrc = Join-Path $RepoRoot 'seelen-ui\amoled-terminal'
$seelenDst = Join-Path $env:APPDATA 'com.seelen.seelen-ui\themes\amoled-terminal'
if (Test-Path $seelenSrc) {
    Write-Host "==> Deploying Seelen UI AMOLED theme to $seelenDst" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $seelenDst -Force | Out-Null
    Copy-Item -Path "$seelenSrc\*" -Destination $seelenDst -Recurse -Force
    $seelenPkg = Get-AppxPackage 'Seelen.SeelenUI' -ErrorAction SilentlyContinue
    if ($seelenPkg) {
        $sluExe = Join-Path $seelenPkg.InstallLocation 'slu.exe'
        if (Test-Path $sluExe) {
            & $sluExe resource load theme $seelenDst 2>$null
        }
    }
    $seelenCfgPath = Join-Path $env:APPDATA 'com.seelen.seelen-ui\settings.json'
    if (Test-Path $seelenCfgPath) {
        $scfg = [System.IO.File]::ReadAllText($seelenCfgPath) | ConvertFrom-Json
        if ($scfg.byWidget.'@seelen/wallpaper-manager') {
            $scfg.byWidget.'@seelen/wallpaper-manager'.enabled = $false
        }
        $scfg | Add-Member -NotePropertyName 'suspendOnGameMode' -NotePropertyValue $true -Force
        # Write UTF-8 without BOM; Seelen UI's Rust serde_json parser rejects a leading BOM
        [System.IO.File]::WriteAllText(
            $seelenCfgPath,
            ($scfg | ConvertTo-Json -Depth 12),
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}

# 3. Apply 4K AMOLED Wallpaper only when requested or when Wallpaper Engine isn't installed
$wallpaperEngineInstalled = (Test-Path "${env:ProgramFiles(x86)}\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe") -or (Get-Process -Name 'wallpaper64','wallpaper32','wallpaperservice64' -ErrorAction SilentlyContinue)
$wallpaperPath = Join-Path $RepoRoot 'wallpaper\amoled-terminal-4k.png'
if ($SetStaticWallpaper -or (-not $wallpaperEngineInstalled)) {
    if (Test-Path $wallpaperPath) {
        Write-Host "==> Applying 4K AMOLED wallpaper: $wallpaperPath" -ForegroundColor Cyan
        Set-DesktopWallpaper -ImagePath $wallpaperPath
    }
} else {
    Write-Host '==> Wallpaper Engine detected; keeping your Wallpaper Engine background active.' -ForegroundColor Gray
}

# 4. Terminal, Starship, Fastfetch, Clink, Profiles & Start Menu WT routing
if ($ApplyTerminalTheme) {
    $cfgDir = Join-Path $env:USERPROFILE '.config'
    $ffDir = Join-Path $cfgDir 'fastfetch'
    $clinkCfg = Join-Path $env:LOCALAPPDATA 'clink'
    $ps7Dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
    $ps5Dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell'

    New-Item -ItemType Directory -Path $cfgDir, $ffDir, $clinkCfg, $ps7Dir, $ps5Dir -Force | Out-Null

    Copy-Item (Join-Path $RepoRoot 'terminal\starship.toml') (Join-Path $cfgDir 'starship.toml') -Force
    Copy-Item (Join-Path $RepoRoot 'terminal\fastfetch.jsonc') (Join-Path $ffDir 'config.jsonc') -Force
    Copy-Item (Join-Path $RepoRoot 'terminal\logo.txt') (Join-Path $ffDir 'logo.txt') -Force
    Copy-Item (Join-Path $RepoRoot 'terminal\cmd-init.cmd') (Join-Path $cfgDir 'cmd-init.cmd') -Force
    Copy-Item (Join-Path $RepoRoot 'terminal\wt-open.vbs') (Join-Path $cfgDir 'wt-open.vbs') -Force
    Copy-Item (Join-Path $RepoRoot 'terminal\starship-clink.lua') (Join-Path $clinkCfg 'starship.lua') -Force
    Copy-Item (Join-Path $RepoRoot 'terminal\profile.ps1') (Join-Path $ps7Dir 'Microsoft.PowerShell_profile.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'terminal\profile.ps1') (Join-Path $ps5Dir 'Microsoft.PowerShell_profile.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\reset-widgets.ps1') (Join-Path $cfgDir 'reset-widgets.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\startup-widgets.ps1') (Join-Path $cfgDir 'startup-widgets.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\startup-widgets.vbs') (Join-Path $cfgDir 'startup-widgets.vbs') -Force
    Write-Host '==> Deployed Starship, Fastfetch, Clink, cmd-init, wt-open, reset-widgets, startup-widgets, and PowerShell profiles.' -ForegroundColor Cyan

    # Register silent interactive logon task for Rainmeter (waits for Wallpaper Engine & Seelen UI)
    $vbsStartup = Join-Path $cfgDir 'startup-widgets.vbs'
    if (Test-Path "$env:ProgramFiles\Rainmeter\Rainmeter.exe") {
        $stAction = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\wscript.exe" -Argument "`"$vbsStartup`""
        $stTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $stTrigger.Delay = 'PT3S'
        $stPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        $stSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
        Register-ScheduledTask -TaskName 'WterminalRainmeterStartup' -Action $stAction -Trigger $stTrigger -Principal $stPrincipal -Settings $stSettings -Force | Out-Null
    }

    # Safe cmd AutoRun (skips /c scripts cleanly)
    $cmdProcKey = 'HKCU:\Software\Microsoft\Command Processor'
    New-Item -Path $cmdProcKey -Force | Out-Null
    Set-ItemProperty -Path $cmdProcKey -Name 'AutoRun' -Value 'if exist "%USERPROFILE%\.config\cmd-init.cmd" call "%USERPROFILE%\.config\cmd-init.cmd"' -Type String

    # Windows Terminal settings.json
    $wtSettings = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wtSettings) {
        $backupPath = "$($wtSettings.FullName).bak"
        Copy-Item -Path $wtSettings.FullName -Destination $backupPath -Force
        Write-Host "==> Backed up Windows Terminal settings to $backupPath" -ForegroundColor Gray

        $cfg = Get-Content -Path $wtSettings.FullName -Raw | ConvertFrom-Json
        $amoled = Get-Content -Path (Join-Path $RepoRoot 'terminal\amoled-terminal-scheme.json') -Raw | ConvertFrom-Json

        $ps7Guid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
        $hasPs7 = @($cfg.profiles.list | Where-Object { $_.guid -eq $ps7Guid -or $_.name -like 'PowerShell 7*' }).Count -gt 0
        if (-not $hasPs7) {
            $ps7Profile = [PSCustomObject]@{
                guid                     = $ps7Guid
                name                     = 'PowerShell 7'
                commandline              = 'pwsh.exe -NoLogo'
                hidden                   = $false
                suppressApplicationTitle = $true
            }
            $cfg.profiles.list = @($ps7Profile) + @($cfg.profiles.list)
        } else {
            foreach ($p in $cfg.profiles.list) {
                if ($p.guid -eq $ps7Guid) {
                    $p | Add-Member -NotePropertyName 'suppressApplicationTitle' -NotePropertyValue $true -Force
                }
            }
        }
        $cfg.defaultProfile = $ps7Guid

        $schemes = @($cfg.schemes | Where-Object { $_.name -ne $amoled.scheme.name })
        $schemes += $amoled.scheme
        $cfg.schemes = $schemes

        if (-not ($cfg.PSObject.Properties.Name -contains 'themes')) {
            $cfg | Add-Member -NotePropertyName 'themes' -NotePropertyValue @()
        }
        $themes = @($cfg.themes | Where-Object { $_.name -ne $amoled.theme.name })
        $themes += $amoled.theme
        $cfg.themes = $themes
        $cfg | Add-Member -NotePropertyName 'theme' -NotePropertyValue $amoled.theme.name -Force
        $cfg | Add-Member -NotePropertyName 'useAcrylicInTabRow' -NotePropertyValue $true -Force
        $cfg | Add-Member -NotePropertyName 'tabWidthMode' -NotePropertyValue 'compact' -Force

        if (-not $cfg.profiles.defaults) {
            $cfg.profiles.defaults = [PSCustomObject]@{}
        }
        foreach ($prop in $amoled.profileDefaults.PSObject.Properties) {
            $cfg.profiles.defaults | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
        }

        $cfg | ConvertTo-Json -Depth 12 | Set-Content -Path $wtSettings.FullName -Encoding UTF8
        Write-Host '==> Applied AMOLED Terminal theme & PowerShell 7 default to Windows Terminal.' -ForegroundColor Green
    }

    # Windows 11 Default Terminal Delegation -> Windows Terminal
    $startupKey = 'HKCU:\Console\%%Startup'
    New-Item -Path $startupKey -Force | Out-Null
    Set-ItemProperty -Path $startupKey -Name 'DelegationConsole' -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}' -Type String
    Set-ItemProperty -Path $startupKey -Name 'DelegationTerminal' -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}' -Type String

    # Fallback conhost.exe AMOLED palette & transparency
    $palette = @{
        'ColorTable00' = 0x00000000; 'ColorTable01' = 0x007A7171; 'ColorTable02' = 0x0080DE4A; 'ColorTable03' = 0x00AAA1A1
        'ColorTable04' = 0x007171F8; 'ColorTable05' = 0x00FC84C0; 'ColorTable06' = 0x0024BFFB; 'ColorTable07' = 0x00E7E4E4
        'ColorTable08' = 0x005B5252; 'ColorTable09' = 0x00D8D4D4; 'ColorTable10' = 0x00ACEF86; 'ColorTable11' = 0x00F5F4F4
        'ColorTable12' = 0x00A5A5FC; 'ColorTable13' = 0x00FEB4D8; 'ColorTable14' = 0x008AE6FD; 'ColorTable15' = 0x00FFFFFF
    }
    foreach ($k in @('HKCU:\Console', 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe', 'HKCU:\Console\%SystemRoot%_SysWOW64_WindowsPowerShell_v1.0_powershell.exe')) {
        New-Item -Path $k -Force | Out-Null
        Set-ItemProperty -Path $k -Name 'FaceName' -Value 'JetBrainsMono NF' -Type String
        Set-ItemProperty -Path $k -Name 'FontFamily' -Value 54 -Type DWord
        Set-ItemProperty -Path $k -Name 'FontSize' -Value 0x00100000 -Type DWord
        Set-ItemProperty -Path $k -Name 'FontWeight' -Value 400 -Type DWord
        Set-ItemProperty -Path $k -Name 'WindowAlpha' -Value 212 -Type DWord
        Set-ItemProperty -Path $k -Name 'ScreenColors' -Value 0x07 -Type DWord
        Set-ItemProperty -Path $k -Name 'VirtualTerminalLevel' -Value 1 -Type DWord
        foreach ($entry in $palette.GetEnumerator()) {
            Set-ItemProperty -Path $k -Name $entry.Key -Value $entry.Value -Type DWord
        }
    }

    # Route Start Menu terminal shortcuts cleanly into Windows Terminal via wt-open.vbs
    $ws = New-Object -ComObject WScript.Shell
    $wtExe = Get-Item 'C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_*\WindowsTerminal.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    $shortcuts = @(
        @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk"; Guid = '{0caa0dad-35be-5f56-a8ff-afceeeaa6101}'; Icon = "$env:WINDIR\System32\cmd.exe,0" },
        @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\cmd.lnk"; Guid = '{0caa0dad-35be-5f56-a8ff-afceeeaa6101}'; Icon = "$env:WINDIR\System32\cmd.exe,0" },
        @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk"; Guid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'; Icon = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe,0" },
        @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\pwsh.lnk"; Guid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'; Icon = '' },
        @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\wt.lnk"; Guid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'; Icon = '' }
    )
    foreach ($item in $shortcuts) {
        $parent = Split-Path -Parent $item.Path
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $sc = $ws.CreateShortcut($item.Path)
        $sc.TargetPath = "$env:WINDIR\System32\wscript.exe"
        $sc.Arguments = "`"$cfgDir\wt-open.vbs`" `"$($item.Guid)`""
        if ($item.Icon) {
            $sc.IconLocation = $item.Icon
        } elseif ($wtExe) {
            $sc.IconLocation = "$($wtExe.FullName),0"
        }
        $sc.Save()
    }
    $rmExe = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
    if (Test-Path $rmExe) {
        $scRst = $ws.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Reset Widgets.lnk")
        $scRst.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        $scRst.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$cfgDir\reset-widgets.ps1`""
        $scRst.IconLocation = "$rmExe,0"
        $scRst.Save()

        $scCfg = $ws.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Widget Settings.lnk")
        $scCfg.TargetPath = $rmExe
        $scCfg.Arguments = '!ToggleConfig "AmoledTerminal\Settings" "Settings.ini"'
        $scCfg.IconLocation = "$rmExe,0"
        $scCfg.Save()
    }
    Write-Host '==> Routed Start Menu shortcuts (cmd, Command Prompt, Windows PowerShell, pwsh, wt, Reset Widgets, Widget Settings).' -ForegroundColor Cyan
}

# 5. Optional Windows 11 declutter tweaks
$restartExplorer = $false
if ($DeclutterTaskbar) {
    Write-Host '==> Decluttering Windows 11 taskbar (centered, hiding Search/TaskView/Chat)...' -ForegroundColor Cyan
    Set-ItemProperty -Path $advKey -Name 'TaskbarAl' -Value 1 -Type DWord
    Set-ItemProperty -Path $advKey -Name 'TaskbarMn' -Value 0 -Type DWord
    Set-ItemProperty -Path $advKey -Name 'ShowTaskViewButton' -Value 0 -Type DWord
    if (Test-Path $searchKey) {
        Set-ItemProperty -Path $searchKey -Name 'SearchboxTaskbarMode' -Value 0 -Type DWord
    }
    $restartExplorer = $true
}

if ($AutoHideTaskbar) {
    Write-Host '==> Enabling Windows 11 taskbar auto-hide for Seelen UI dock...' -ForegroundColor Cyan
    $srKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    if (Test-Path $srKey) {
        $sr = (Get-ItemProperty $srKey).Settings
        $sr[8] = 0x03
        Set-ItemProperty -Path $srKey -Name 'Settings' -Value $sr -Type Binary
        $restartExplorer = $true
    }
}

if ($HideDesktopIcons) {
    Write-Host '==> Hiding desktop icons for a clean canvas...' -ForegroundColor Cyan
    Set-ItemProperty -Path $advKey -Name 'HideIcons' -Value 1 -Type DWord
    $restartExplorer = $true
}

if ($restartExplorer) {
    Write-Host '==> Restarting Explorer to apply taskbar/icon changes...' -ForegroundColor Gray
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
}

Write-Host "`nDeployed wterminal AMOLED suite!" -ForegroundColor Green
