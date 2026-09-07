param(
    [string]$Mode = "tabs", # 'tabs', 'split', 'windows'
    [switch]$NoTunnel,
    [switch]$NoApi,
    [switch]$NoWeb
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$toolsDir  = Split-Path -Parent (Split-Path -Parent $scriptDir)
if (-not (Test-Path (Join-Path $toolsDir "sowfkun.ps1"))) {
    $toolsDir = "F:\Coding\Project\sowfkun.verse.v2\tools"
}
$rootDir   = Split-Path -Parent $toolsDir

$apiDir = Join-Path $rootDir "sowfkun-verse-api"
$webDir = Join-Path $rootDir "sowfkun-verse-web"
$sowfkunCmd = Join-Path $toolsDir "sowfkun.ps1"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ">>> SOWFKUN VERSE - FULLSTACK DEV ENVIRONMENT LAUNCHER" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Project Root: $rootDir" -ForegroundColor DarkGray
Write-Host "  1. Infra Tunnel -> sowfkun infra open all" -ForegroundColor White
Write-Host "  2. Go API Engine -> sowfkun-verse-api (air)" -ForegroundColor White
Write-Host "  3. Next.js Web   -> sowfkun-verse-web (npm run dev)" -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan

$hasWt = (Get-Command wt -ErrorAction SilentlyContinue) -ne $null

# Commands to run in each service terminal
$tunnelCmd = "`$host.UI.RawUI.WindowTitle = 'Sowfkun Verse - Infrastructure Tunnel'; if ((Get-Location).Path -ne '$rootDir') { Set-Location '$rootDir' }; & '$sowfkunCmd' infra open all"
$apiCmd    = "`$host.UI.RawUI.WindowTitle = 'Sowfkun Verse - Go API Backend'; if ((Get-Location).Path -ne '$apiDir') { Set-Location '$apiDir' }; if (Get-Command air -ErrorAction SilentlyContinue) { air } else { go run cmd/api/main.go }"
$webCmd    = "`$host.UI.RawUI.WindowTitle = 'Sowfkun Verse - Next.js Frontend'; if ((Get-Location).Path -ne '$webDir') { Set-Location '$webDir' }; npm run dev"

if ($hasWt -and $Mode -eq "tabs") {
    Write-Host "Launching in Windows Terminal (Multi-Tab Mode)..." -ForegroundColor Yellow
    
    $wtArgs = @()
    $first = $true

    if (-not $NoTunnel) {
        $wtArgs += @("--title", "Verse: Infra Tunnel", "-d", "$rootDir", "powershell", "-NoExit", "-Command", $tunnelCmd)
        $first = $false
    }

    if (-not $NoApi) {
        if ($first) {
            $wtArgs += @("--title", "Verse: API Backend", "-d", "$apiDir", "powershell", "-NoExit", "-Command", $apiCmd)
            $first = $false
        } else {
            $wtArgs += @(";", "new-tab", "--title", "Verse: API Backend", "-d", "$apiDir", "powershell", "-NoExit", "-Command", $apiCmd)
        }
    }

    if (-not $NoWeb) {
        if ($first) {
            $wtArgs += @("--title", "Verse: Web Frontend", "-d", "$webDir", "powershell", "-NoExit", "-Command", $webCmd)
            $first = $false
        } else {
            $wtArgs += @(";", "new-tab", "--title", "Verse: Web Frontend", "-d", "$webDir", "powershell", "-NoExit", "-Command", $webCmd)
        }
    }

    if ($wtArgs.Count -gt 0) {
        Start-Process "wt" -ArgumentList $wtArgs
    }
}
elseif ($hasWt -and $Mode -eq "split") {
    Write-Host "Launching in Windows Terminal (Split-Pane Mode)..." -ForegroundColor Yellow
    
    $wtArgs = @()
    if (-not $NoTunnel) {
        $wtArgs += @("--title", "Verse: Infra Tunnel", "-d", "$rootDir", "powershell", "-NoExit", "-Command", $tunnelCmd)
    }
    if (-not $NoApi) {
        $wtArgs += @(";", "split-pane", "-V", "--title", "Verse: API Backend", "-d", "$apiDir", "powershell", "-NoExit", "-Command", $apiCmd)
    }
    if (-not $NoWeb) {
        $wtArgs += @(";", "split-pane", "-H", "--title", "Verse: Web Frontend", "-d", "$webDir", "powershell", "-NoExit", "-Command", $webCmd)
    }

    if ($wtArgs.Count -gt 0) {
        Start-Process "wt" -ArgumentList $wtArgs
    }
}
else {
    Write-Host "Launching separate PowerShell windows..." -ForegroundColor Yellow

    if (-not $NoTunnel) {
        Write-Host "  -> [1/3] Starting Infrastructure Tunnel..." -ForegroundColor Green
        Start-Process powershell -ArgumentList "-NoExit", "-Command", $tunnelCmd
        Start-Sleep -Seconds 2
    }

    if (-not $NoApi) {
        Write-Host "  -> [2/3] Starting Go Backend API (air)..." -ForegroundColor Green
        Start-Process powershell -ArgumentList "-NoExit", "-Command", $apiCmd
        Start-Sleep -Seconds 1
    }

    if (-not $NoWeb) {
        Write-Host "  -> [3/3] Starting Next.js Web (npm run dev)..." -ForegroundColor Green
        Start-Process powershell -ArgumentList "-NoExit", "-Command", $webCmd
    }
}

Write-Host ""
Write-Host "All services have been initiated successfully!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
