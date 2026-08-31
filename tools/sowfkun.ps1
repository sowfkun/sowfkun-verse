param(
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsList
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$toolsDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $toolsDir) { $toolsDir = "F:\Coding\Project\sowfkun.verse.v2\tools" }
$rootDir = Split-Path -Parent $toolsDir
$serverTestDir = Join-Path $rootDir "server-test"
$modulesDir = Join-Path $toolsDir "modules"

function Show-Banner {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN MASTER CLI TOOL SUITE v1.0" -ForegroundColor Green
    Write-Host "    Multi-Purpose Automation & Project Management Engine" -ForegroundColor DarkGray
    Write-Host "=================================================================" -ForegroundColor Cyan
}

function Show-Help {
    Show-Banner
    Write-Host "Supported Commands:" -ForegroundColor Yellow
    Write-Host "  [Media Utilities]" -ForegroundColor Cyan
    Write-Host "    1. download <URL> [output_name] [referer]" -ForegroundColor White
    Write-Host "       -> Download video / m3u8 stream with auto metadata & subtitles." -ForegroundColor DarkGray
    Write-Host "    2. download-subtitle <URL> [output_name] [referer]" -ForegroundColor White
    Write-Host "       -> Download subtitle file directly (.vtt, .srt, .ass)." -ForegroundColor DarkGray
    Write-Host "    3. sync-audio <file_path> <offset_ms> [output_file]" -ForegroundColor White
    Write-Host "       -> Lossless Audio/Video Synchronizer (Shift sound forward/backward by ms)." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [Project: Sowfkun Verse]" -ForegroundColor Cyan
    Write-Host "    4. verse-deploy [dev|prod]" -ForegroundColor White
    Write-Host "       -> Build and deploy Go API to Server 2 via Google IAP in 15 seconds." -ForegroundColor DarkGray
    Write-Host "    5. verse-deploy-gateway [dev|prod]" -ForegroundColor White
    Write-Host "       -> Build and deploy Egress Gateway to Server 3 via Google IAP in 15 seconds." -ForegroundColor DarkGray
    Write-Host "    6. verse-tunnel [server1|server2|server3|all]" -ForegroundColor White
    Write-Host "       -> Open secure IAP tunnels to internal services (Mongo, Redis, API, Kafka, Gateway, SSH)." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [System]" -ForegroundColor Cyan
    Write-Host "    7. help" -ForegroundColor White
    Write-Host "       -> Show this help message." -ForegroundColor DarkGray
    Write-Host ""
}

# ------------------------------------------------------------------------------
# ROUTING
# ------------------------------------------------------------------------------
if (-not $Command) {
    Show-Banner
    Write-Host "Select a tool to use:" -ForegroundColor Yellow
    Write-Host "  [1] Video / M3U8 Stream Downloader (download)" -ForegroundColor Cyan
    Write-Host "  [2] Subtitle Downloader (download-subtitle)" -ForegroundColor Cyan
    Write-Host "  [3] Audio / Video Synchronizer (sync-audio)" -ForegroundColor Cyan
    Write-Host "  [4] Deploy Go API to Server 2 (verse-deploy)" -ForegroundColor Cyan
    Write-Host "  [5] Deploy Egress Gateway to Server 3 (verse-deploy-gateway)" -ForegroundColor Cyan
    Write-Host "  [6] Open Google IAP Tunnels across 3 Servers (verse-tunnel)" -ForegroundColor Cyan
    Write-Host "  [7] Exit" -ForegroundColor Gray
    Write-Host ""
    $choice = Read-Host "Enter option [1-7]"

    switch ($choice) {
        "1" {
            $script = Join-Path $modulesDir "download-video.ps1"
            & $script
        }
        "2" {
            $script = Join-Path $modulesDir "download-video.ps1"
            & $script
        }
        "3" {
            $script = Join-Path $modulesDir "sync-audio.ps1"
            & $script
        }
        "4" {
            $script = Join-Path $serverTestDir "deploy-api.ps1"
            & $script
        }
        "5" {
            $script = Join-Path $serverTestDir "deploy-gateway.ps1"
            & $script
        }
        "6" {
            $script = Join-Path $serverTestDir "iap-tunnel.ps1"
            & $script
        }
        Default {
            Write-Host "Goodbye!" -ForegroundColor Gray
        }
    }
    exit 0
}

$cmdLower = $Command.ToLower()

# Support "sync audio" as an alias to sync-audio
if ($cmdLower -eq "sync" -and $ArgsList.Count -ge 1 -and $ArgsList[0].ToLower() -eq "audio") {
    $cmdLower = "sync-audio"
    if ($ArgsList.Count -gt 1) {
        $ArgsList = $ArgsList[1..($ArgsList.Count - 1)]
    } else {
        $ArgsList = @()
    }
}

if ($cmdLower -eq "download") {
    $script = Join-Path $modulesDir "download-video.ps1"
    $url = if ($ArgsList.Count -ge 1) { $ArgsList[0] } else { "" }
    $outName = if ($ArgsList.Count -ge 2) { $ArgsList[1] } else { "" }
    $ref = if ($ArgsList.Count -ge 3) { $ArgsList[2] } else { "" }
    & $script -Url $url -OutputName $outName -Referer $ref
}
elseif ($cmdLower -in @("download-subtitle", "download-sub")) {
    $script = Join-Path $modulesDir "download-video.ps1"
    $url = if ($ArgsList.Count -ge 1) { $ArgsList[0] } else { "" }
    $outName = if ($ArgsList.Count -ge 2) { $ArgsList[1] } else { "" }
    $ref = if ($ArgsList.Count -ge 3) { $ArgsList[2] } else { "" }
    & $script -Url $url -OutputName $outName -Referer $ref
}
elseif ($cmdLower -eq "sync-audio") {
    $script = Join-Path $modulesDir "sync-audio.ps1"
    $src = if ($ArgsList.Count -ge 1) { $ArgsList[0] } else { "" }
    $offset = if ($ArgsList.Count -ge 2) { $ArgsList[1] } else { "" }
    $dst = if ($ArgsList.Count -ge 3) { $ArgsList[2] } else { "" }
    & $script -FilePath $src -OffsetMs $offset -OutputPath $dst
}
elseif ($cmdLower -eq "verse-deploy") {
    $script = Join-Path $serverTestDir "deploy-api.ps1"
    $targetEnv = if ($ArgsList.Count -ge 1) { $ArgsList[0] } else { "dev" }
    & $script -TargetEnv $targetEnv
}
elseif ($cmdLower -in @("verse-deploy-gateway", "verse-deploy-gw")) {
    $script = Join-Path $serverTestDir "deploy-gateway.ps1"
    $targetEnv = if ($ArgsList.Count -ge 1) { $ArgsList[0] } else { "dev" }
    & $script -TargetEnv $targetEnv
}
elseif ($cmdLower -eq "verse-tunnel") {
    $script = Join-Path $serverTestDir "iap-tunnel.ps1"
    $target = if ($ArgsList.Count -ge 1) { $ArgsList[0] } else { "" }
    & $script -Target $target
}
elseif ($cmdLower -in @("help", "-h", "--help", "/?")) {
    Show-Help
}
else {
    Write-Host "Error: Invalid command '$Command'" -ForegroundColor Red
    Show-Help
}
