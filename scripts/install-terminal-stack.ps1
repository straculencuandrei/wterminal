<#
.SYNOPSIS
    Installs a fast, customizable Linux-like CLI stack for Windows Terminal:
    PowerShell 7, Starship, Fastfetch, eza, bat, fzf, zoxide, JetBrainsMono Nerd Font, and Clink (portable).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$packages = @(
    'Microsoft.PowerShell',
    'Starship.Starship',
    'Fastfetch-cli.Fastfetch',
    'eza-community.eza',
    'sharkdp.bat',
    'junegunn.fzf',
    'ajeetdsouza.zoxide',
    'DEVCOM.JetBrainsMonoNerdFont'
)

foreach ($id in $packages) {
    Write-Host "==> Installing $id..." -ForegroundColor Cyan
    winget install --id $id --exact --accept-package-agreements --accept-source-agreements
}

# Install Clink portable (adds GNU Readline + Starship prompt to cmd.exe with zero UAC)
$clinkDir = "$env:LOCALAPPDATA\Programs\Clink"
if (-not (Test-Path "$clinkDir\clink_x64.exe")) {
    Write-Host '==> Installing Clink portable (cmd.exe Readline + Starship)...' -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $clinkDir -Force | Out-Null
    $zipPath = "$env:TEMP\clink.zip"
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/chrisant996/clink/releases/latest' -TimeoutSec 10
        $zipAsset = $rel.assets | Where-Object { $_.name -match '^clink\..*\.zip$' -and $_.name -notmatch 'symbols' } | Select-Object -First 1
        if ($zipAsset) {
            Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $clinkDir -Force
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Warning "Failed to download Clink portable automatically: $_"
    }
}

Write-Host "`nTerminal CLI stack installation finished." -ForegroundColor Green
