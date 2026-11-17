# AMOLED Linux-Like PowerShell Profile
# Customize aliases/functions here; prompt is in ~/.config/starship.toml

# 1. Ensure Antigravity CLI and WinGet CLI tools are in PATH
$extraPaths = @(
    "$env:LOCALAPPDATA\agy\bin",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
    "$env:ProgramFiles\starship\bin",
    "$env:ProgramFiles\fzf\bin"
)
foreach ($p in $extraPaths) {
    if ((Test-Path $p) -and ($env:Path -notlike "*$p*")) {
        $env:Path = "$p;$env:Path"
    }
}

# 2. Linux-like Readline editing & inline ghost predictions (interactive TTY only)
if ((-not [Console]::IsOutputRedirected) -and ($Host.Name -eq 'ConsoleHost') -and (Get-Module -ListAvailable -Name PSReadLine)) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -HistoryNoDuplicates:$true
    Set-PSReadLineOption -BellStyle None
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle InlineView
        Set-PSReadLineOption -Colors @{
            InlinePrediction = '#52525B'
            Command          = '#F4F4F5'
            Parameter        = '#A1A1AA'
            String           = '#4ADE80'
            Operator         = '#D4D4D8'
        }
    }
    # Tab completion menu like zsh
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Fuzzy Ctrl+R command history search if fzf is installed
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        Set-PSReadLineKeyHandler -Key 'Ctrl+r' -ScriptBlock {
            $histPath = (Get-PSReadLineOption).HistorySavePath
            if (Test-Path $histPath) {
                $sel = Get-Content $histPath | Select-Object -Unique | fzf --tac --height=40% --layout=reverse --border --prompt="hist> "
                if ($sel) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($sel)
                }
            }
        }
    }
}

# 3. Linux-style commands & aliases
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons --group-directories-first @args }
    function ll { eza -la --icons --git --group-directories-first @args }
    function la { eza -a --icons --group-directories-first @args }
    function lt { eza --tree --level=2 --icons --group-directories-first @args }
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    function cat { bat --style=plain --paging=never @args }
}

function which { param([string]$Name) (Get-Command $Name -ErrorAction SilentlyContinue).Source }
function grep  { param([string]$Pattern, [string]$Path = '*') Select-String -Pattern $Pattern -Path $Path }
function touch { param([string]$Path) if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path $Path | Out-Null } }
function mkcd  { param([string]$Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null; Set-Location $Path }
function ..    { Set-Location .. }
function ...   { Set-Location ..\.. }
function ff    { if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch } }
function reload { . $PROFILE }
function edit-profile { & $env:EDITOR $PROFILE 2>$null; if (-not $?) { Start-Process $PROFILE } }
function edit-prompt  { Start-Process "$env:USERPROFILE\.config\starship.toml" }
function reset-widgets {
    $rm = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
    if (Test-Path $rm) {
        Add-Type -AssemblyName System.Windows.Forms
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $work = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $topY = [Math]::Max($work.Top + 18, 50)
        $rx = $bounds.Width - 300
        & $rm !Move 28 $topY "AmoledTerminal\HeroClock"
        & $rm !Move 28 ($topY + 134) "AmoledTerminal\Weather"
        & $rm !Move 28 ($topY + 242) "AmoledTerminal\Calendar"
        & $rm !Move 28 ($topY + 336) "AmoledTerminal\Notes"
        & $rm !Move $rx $topY "AmoledTerminal\SysPill"
        & $rm !Move $rx ($topY + 134) "AmoledTerminal\GpuThermals"
        & $rm !Move $rx ($topY + 256) "AmoledTerminal\PowerAudio"
        & $rm !Move $rx ($topY + 378) "AmoledTerminal\TerminalDock"
        & $rm !Move ([int]($bounds.Width / 2 - 154)) ($bounds.Height - 124) "AmoledTerminal\AudioFFT"
    }
}
function widget-settings {
    $rm = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
    if (Test-Path $rm) { & $rm !ToggleConfig "AmoledTerminal\Settings" "Settings.ini" }
}

# 4. Smart cd (zoxide)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# 5. Starship prompt
$env:STARSHIP_CONFIG = "$env:USERPROFILE\.config\starship.toml"
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# 6. Show fastfetch only in interactive terminal sessions (skip -Command / -File scripts)
$cliArgs = [Environment]::GetCommandLineArgs()
$isScripted = [bool]($cliArgs | Where-Object { $_ -match '^-(c|command|f|file|ec|encodedcommand)$' })
if ([Environment]::UserInteractive -and (-not $isScripted) -and ($Host.Name -eq 'ConsoleHost')) {
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
        fastfetch
    }
}
