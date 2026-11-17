# wterminal — AMOLED Dark-Grey Windows 11 Terminal, Dock & Spotlight Suite

![Platform](https://img.shields.io/badge/platform-Windows%2011-0078D4?style=flat&logo=windows11&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-7.7-5391FE?style=flat&logo=powershell&logoColor=white)
![Windows Terminal](https://img.shields.io/badge/Windows%20Terminal-Acrylic-121216?style=flat&logo=windowsterminal&logoColor=white)
![Starship](https://img.shields.io/badge/Starship-1.27-DD0B78?style=flat&logo=starship&logoColor=white)
![Fastfetch](https://img.shields.io/badge/Fastfetch-2.71-4ADE80?style=flat)
![Clink](https://img.shields.io/badge/Clink-1.9-27272A?style=flat)
![Flow Launcher](https://img.shields.io/badge/Flow%20Launcher-2.1-0A0A0D?style=flat)
![Rainmeter](https://img.shields.io/badge/Rainmeter-4.5-1F2937?style=flat)
![Seelen UI](https://img.shields.io/badge/Seelen%20UI-2.8-18181B?style=flat)

A lightweight, fast Windows 11 desktop + terminal suite built around **AMOLED true black (`#000000`)**, **translucent dark-grey glass**, **Linux-style shells** (`PowerShell 7` + `cmd.exe` via `Clink`), **Starship**, **Fastfetch** (with a TrueColor rainbow `Alpha` **`W`** ASCII logo), a **Spotlight launcher** (`Flow Launcher`), a **macOS-style dock & top bar** (`Seelen UI`), and **9 modular desktop widgets** (`Rainmeter`, Wallpaper Engine compatible).

---

## What’s Included

```text
wterminal/
├── flow-launcher/
│   └── AmoledTerminal.xaml         # Acrylic blurred Spotlight theme (Cascadia / SF Pro Display)
├── rainmeter/AmoledTerminal/
│   ├── @Resources/                 # Shared palette, WeekCal.lua, ReadNotes.lua, notes.txt
│   ├── AudioFFT/                   # 24-band monochrome audio spectrum pill above the dock
│   ├── Calendar/                   # 7-day rolling week strip with today highlighted in #4ADE80
│   ├── Clock/                      # Compact clock/uptime pill
│   ├── GpuThermals/                # Live NVIDIA GPU temp (°C), load %, and VRAM via nvidia-smi
│   ├── HeroClock/                  # Large minimal clock, seconds, date, and uptime card
│   ├── Notes/                      # Click-to-edit desktop scratchpad (notes.txt)
│   ├── PowerAudio/                 # Battery %, AC/BAT badge, C:\ free space, scroll-wheel volume
│   ├── Settings/                   # Control panel: 1-click Reset Layout, layer toggle & widget switches
│   ├── SysPill/                    # CPU temp (Core Temp), CPU %, RAM %, and net.rx telemetry
│   ├── TerminalDock/               # Quick-launch pill (> wt | dir | web | cfg | rst)
│   └── Weather/                    # Auto-located live weather via wttr.in
├── scripts/
│   ├── install-tools.ps1           # Installs Seelen UI, Rainmeter, Flow Launcher, and Core Temp
│   ├── install-terminal-stack.ps1  # Installs pwsh 7, Starship, Fastfetch, eza, bat, fzf, zoxide, JetBrainsMono NF, Clink
│   ├── reset-widgets.ps1           # Snaps all 9 desktop widgets back to default coordinates
│   ├── setup-coretemp-background.ps1 # Configures Core Temp to run minimized in tray for live CPU °C
│   └── apply-theme.ps1             # Deploys themes, profiles, Start Menu WT/widget shortcuts, console palette & layout
├── seelen-ui/amoled-terminal/      # Custom AMOLED Dark-Grey CSS theme for Seelen UI (macOS dock + top bar)
├── terminal/
│   ├── amoled-terminal-scheme.json # Windows Terminal AMOLED scheme, tab-bar theme & acrylic defaults
│   ├── cmd-init.cmd                # Quote-safe cmd.exe AutoRun (Clink + Starship + Fastfetch + doskey aliases)
│   ├── fastfetch.jsonc             # Fastfetch config (custom rainbow W logo + concise single-line GPU)
│   ├── logo.txt                    # 24-bit TrueColor diagonal rainbow Alpha "W" ASCII art
│   ├── profile.ps1                 # Shared PSReadLine + aliases + zoxide + fzf + Starship + Fastfetch profile
│   ├── starship.toml               # Minimal AMOLED Starship prompt (~/.config/starship.toml)
│   ├── starship-clink.lua          # Clink Lua hook loading Starship inside cmd.exe
│   └── wt-open.vbs                 # Windowless ShellExecute router into Windows Terminal profiles
├── wallpaper/
│   ├── amoled-terminal-4k.png      # Pre-rendered 3840x2160 dithered AMOLED wallpaper
│   └── generate_wallpaper.py       # Regenerate wallpaper at any resolution
└── windhawk/
    └── taskbar-floating-dock.json  # Windows 11 Taskbar Styler floating pill dock preset
```

---

## Step-by-Step Setup

### Step 1 — Clone the Repository
```powershell
git clone https://github.com/straculencuandrei/wterminal.git
cd wterminal
```

### Step 2 — Install the Desktop & Terminal Stack
Run from an **Administrator** PowerShell window (so UAC prompts for Windhawk/Rainmeter don't get buried):

```powershell
# Desktop layer: Windhawk, Rainmeter, Flow Launcher
.\scripts\install-tools.ps1

# Linux-like CLI stack: PowerShell 7, Starship, Fastfetch, eza, bat, fzf, zoxide, JetBrainsMono NF, Clink
.\scripts\install-terminal-stack.ps1
```

### Step 3 — Optional: Install SF Pro Display Fonts for Widgets & Launcher
Rainmeter and Flow Launcher default to **`SF Pro Display`** in this theme.
1. Install your `SF Pro Display` `.OTF`/`.TTF` files into `C:\Windows\Fonts` (prefer `Regular`, `Medium`, and `Bold` upright files—avoid using `FontWeight=600` if your `SemiBold` file is italic).
2. Or edit `FontMono` / `FontText` in [Variables.inc](rainmeter/AmoledTerminal/@Resources/Variables.inc) to `Segoe UI Variable Display` / `JetBrainsMono NF`.

### Step 4 — Deploy Everything
```powershell
.\scripts\apply-theme.ps1 -ApplyTerminalTheme -SetupRainmeterLayout -AutoHideTaskbar -HideDesktopIcons
```
- **Using Wallpaper Engine?** The script detects `Wallpaper Engine` automatically and leaves your animated wallpaper active (`AlwaysOnTop=0` keeps widgets above it). Add `-SetStaticWallpaper` if you want the static 4K AMOLED PNG instead.
- **To revert taskbar/desktop icon changes anytime:**
  ```powershell
  .\scripts\apply-theme.ps1 -RestoreDefaults
  ```

### Step 5 — Final 1-Minute UI Activation
1. **Seelen UI (macOS Dock & Top Bar):**
   - Launch **Seelen UI** → open **Settings** → **Themes** → select **`AMOLED Terminal`** (`@wterminal/amoled-terminal`).
   - *(Optional)* Under **Settings → Tiling WM / Wallpaper**, disable Seelen's built-in wallpaper manager if you use **Wallpaper Engine**, and customize pinned dock apps on the bottom bar (`Weg`).
   - *(If upgrading from Windhawk)* Open **Windhawk** → **Disable** *Windows 11 Taskbar Styler*.
2. **Flow Launcher (`Alt+Space`):**
   - Open **Flow Launcher** → press **`Ctrl+I`** (Settings):
     - **Theme:** select **`AmoledTerminal`**.
     - **General → Hotkey:** `Alt + Space` (enable **Start Flow Launcher on system startup** + **Use Logon Task** if you want `Alt+Space` to pop over Administrator windows too).
     - **Plugins → Program:** uncheck **`Enable PATH`** (so `wt` and `cmd` always resolve to the Start Menu Windows Terminal shortcuts instead of raw `WindowsApps\wt.exe` / `System32\cmd.exe`).
     - **Plugins → Shell:** enable **Use Windows Terminal** and **Leave shell open**.
3. **Windows Terminal:**
   - Open **Windows Terminal** (`wt`) → **Settings** (`Ctrl+,`) → **Startup** → set **Default terminal application** to **Windows Terminal** → **Save**.
4. **Rainmeter:**
   - Launch **Rainmeter** — all 9 `AmoledTerminal` widgets load around the screen edges with `AudioFFT` positioned above the taskbar.

---

## Terminal Shortcuts & Aliases (`PowerShell 7` & `cmd.exe`)

| Command / Key | Action |
| :--- | :--- |
| `ls`, `ll`, `la`, `lt` | `eza` icons, git-aware listing, and 2-level tree |
| `cat <file>` | `bat` syntax-highlighted output |
| `z <dir>` | `zoxide` smart directory jump (PowerShell) |
| `ff` | Run `fastfetch` with the rainbow `Alpha` `W` logo |
| `mkcd`, `touch`, `which`, `grep` | Linux-style helpers |
| `..`, `...` | Jump up 1 or 2 directories |
| `edit-prompt`, `edit-profile`, `reload` | Edit `starship.toml` / `$PROFILE` and reload |
| `reset-widgets`, `widget-settings` | Snap all widgets to default layout or toggle the Settings panel |
| `Ctrl+R` | Fuzzy command-history search (`fzf` in PowerShell / Clink in `cmd`) |
| `Ctrl+A / E / W / U / K`, `Tab` | Emacs/Bash line editing & Zsh-style menu completion |

---

## Bugs & Gotchas Already Solved in This Repo

- **Rainmeter `Â°C` / `Â·` encoding:** `apply-theme.ps1` converts deployed `.ini`/`.inc` files to **UTF-16 LE** with BOM so Rainmeter renders `°C` and `·` cleanly.
- **Rainmeter `nvidia-smi` overlap (`Error 101`) & newline wrap:** `GpuThermals.ini` uses `(?s)` regex to strip `\r\n` and a modulo `IfCondition` ticker so `nvidia-smi` never overlaps on refresh.
- **`Win7AudioPlugin` showing `Speakers%`:** `PowerAudio.ini` reads `[MeasureVolNum]` (`Calc` wrapping `MeasureVol`) so the numeric volume `%` is shown.
- **Windows 11 Notepad click error (`Microsoft.UI.Windowing.Core.dll`):** `Notes.ini` uses `LeftMouseUpAction=["#@#notes.txt"]` (`ShellExecute`) instead of calling the `WindowsApps\notepad.exe` alias directly.
- **`AudioFFT` hidden behind taskbar:** Positioned with `#WORKAREAHEIGHT#-48` (`984px` on `1080p`) rather than `#SCREENAREAHEIGHT#`.
- **Widgets disappearing behind Wallpaper Engine / `Win+D` on Win11 `24H2`/`26H2`:** Widgets use `AlwaysOnTop=0` so they stay above Wallpaper Engine; use **`Win+M`** (or minimize) instead of `Win+D`.
- **Flow Launcher `BlurBlack%20Darker.xaml` URI error:** `AmoledTerminal.xaml` inherits directly from `pack://application:,,,/Themes/Base.xaml` (no spaces in pack URI).
- **`cmd.exe` `\Common was unexpected` (`(x86)` in `%PATH%`):** `cmd-init.cmd` avoids putting `%PATH%` inside `if (...)` blocks and uses a quote-safe `/c` guard so scripted `cmd /c` calls stay 0ms and error-free.
- **Starship `System32` timeout warning & `)` prompt glyph:** `starship.toml` sets `scan_timeout = 500` and uses `»` for clean rendering in both Windows Terminal and `conhost.exe`.
- **Elevated launcher bypassing Windows Terminal:** Start Menu `.lnk` shortcuts route through `wscript.exe wt-open.vbs` (`ShellExecute wt.exe -p <guid>`) so `cmd`, `pwsh`, and `wt` open inside Windows Terminal with no `conhost` flash.
- **Seelen UI `Wallpaper Manager` crash with Wallpaper Engine:** `apply-theme.ps1` disables `@seelen/wallpaper-manager` in `%APPDATA%\com.seelen.seelen-ui\settings.json` so it doesn't freeze or fight Wallpaper Engine.
