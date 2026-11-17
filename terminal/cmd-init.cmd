@echo off
set "_cmd_check=%CMDCMDLINE:"=%"
if not "%_cmd_check: /c =%"=="%_cmd_check%" goto :cmd_skip
if not "%_cmd_check: /C =%"=="%_cmd_check%" goto :cmd_skip
set "_cmd_check="

REM Ensure WinGet CLI tools and Starship are on PATH
if not exist "%LOCALAPPDATA%\Microsoft\WinGet\Links" goto :after_winget
echo "%PATH%" | findstr /i "WinGet\Links" >nul || set "PATH=%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%"
:after_winget
if not exist "%ProgramFiles%\starship\bin" goto :after_starship
echo "%PATH%" | findstr /i "starship\bin" >nul || set "PATH=%ProgramFiles%\starship\bin;%PATH%"
:after_starship

REM Inject Clink (Bash Readline + Starship prompt) into interactive cmd.exe
if defined CLINK_DIR goto :after_clink
if exist "%LOCALAPPDATA%\Programs\Clink\clink_x64.exe" "%LOCALAPPDATA%\Programs\Clink\clink_x64.exe" inject --quiet --profile "%LOCALAPPDATA%\clink"
:after_clink

prompt $E[1;37m$P $E[1;32m$G$E[0m 
doskey ls=eza --icons --group-directories-first $*
doskey ll=eza -la --icons --git --group-directories-first $*
doskey la=eza -a --icons --group-directories-first $*
doskey lt=eza --tree --level=2 --icons $*
doskey cat=bat --style=plain --paging=never $*
doskey clear=cls
doskey which=where $*
doskey ff=fastfetch $*
doskey ..=cd ..
doskey ...=cd ..\..

if defined _AMOLED_CMD_BANNER goto :eof
set "_AMOLED_CMD_BANNER=1"
cls
where fastfetch >nul 2>&1 && fastfetch
goto :eof

:cmd_skip
set "_cmd_check="
