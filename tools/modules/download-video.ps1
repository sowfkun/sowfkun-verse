param(
    [string]$Url,
    [string]$OutputName,
    [string]$Referer
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$userDownloads = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads")
if (-not (Test-Path $userDownloads)) {
    $userDownloads = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "downloads"
    if (-not (Test-Path $userDownloads)) { New-Item -ItemType Directory -Path $userDownloads -Force | Out-Null }
}

# ------------------------------------------------------------------------------
# 1. AUTO-BOOTSTRAP PACKAGE (PIP / WINGET / PYTHON MODULE)
# ------------------------------------------------------------------------------
function Ensure-YtDlp {
    # 1. Check direct yt-dlp in PATH
    if (Get-Command yt-dlp -ErrorAction SilentlyContinue) {
        return @{ Type = "Direct"; Command = "yt-dlp" }
    }

    # 2. Check Python yt_dlp module
    $pyCheck = & python -c "import yt_dlp; print('OK')" 2>$null
    if ($pyCheck -eq "OK") {
        return @{ Type = "Python"; Command = "python"; ModuleArgs = @("-m", "yt_dlp") }
    }

    # 3. Auto-install via pip
    Write-Host "[Auto-Install] Installing yt-dlp package via pip..." -ForegroundColor Yellow
    & pip install --user yt-dlp --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[Auto-Install] Installed yt-dlp successfully via pip!" -ForegroundColor Green
        return @{ Type = "Python"; Command = "python"; ModuleArgs = @("-m", "yt_dlp") }
    }

    # 4. Fallback via winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "[Auto-Install] Installing yt-dlp package via winget..." -ForegroundColor Yellow
        & winget install yt-dlp --silent --accept-source-agreements --accept-package-agreements 2>$null
        if (Get-Command yt-dlp -ErrorAction SilentlyContinue) {
            return @{ Type = "Direct"; Command = "yt-dlp" }
        }
    }

    Write-Host "ERROR: Failed to auto-install yt-dlp. Please run: pip install yt-dlp" -ForegroundColor Red
    return $null
}

# ------------------------------------------------------------------------------
# 2. DOWNLOAD ENGINE
# ------------------------------------------------------------------------------
function Start-DownloadVideo {
    param(
        [string]$TargetUrl,
        [string]$TargetName,
        [string]$CustomReferer
    )

    if (-not $TargetUrl) {
        Write-Host "ERROR: Please provide a video or m3u8 stream URL!" -ForegroundColor Red
        return
    }

    $runner = Ensure-YtDlp
    if (-not $runner) { return }

    if (-not $TargetName) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $TargetName = "video_$timestamp.mp4"
    }
    if (-not $TargetName.EndsWith(".mp4")) {
        $TargetName = "$TargetName.mp4"
    }

    $outputPath = Join-Path $userDownloads $TargetName

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN DOWNLOADER - STARTING STREAM DOWNLOAD..." -ForegroundColor Green
    Write-Host "  URL:         $TargetUrl" -ForegroundColor White
    Write-Host "  Destination: $outputPath" -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $dlArgs = @()
    if ($runner.Type -eq "Python") {
        $dlArgs += $runner.ModuleArgs
    }

    $dlArgs += @(
        "$TargetUrl",
        "-o", "$outputPath",
        "--concurrent-fragments", "16",
        "--embed-metadata",
        "--embed-thumbnail",
        "--embed-chapters",
        "--all-subs",
        "--embed-subs",
        "--write-auto-subs",
        "--no-check-certificates",
        "--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    )

    if ($CustomReferer) {
        $dlArgs += @("--referer", "$CustomReferer")
    }

    # Execute download
    & $runner.Command $dlArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host "SUCCESS: Video download completed!" -ForegroundColor Green
        Write-Host "Saved file: $outputPath" -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "ERROR: Download failed (Exit Code: $LASTEXITCODE)." -ForegroundColor Red
    }
}

# ------------------------------------------------------------------------------
# 3. ENTRY POINT
# ------------------------------------------------------------------------------
if ($Url) {
    Start-DownloadVideo -TargetUrl $Url -TargetName $OutputName -CustomReferer $Referer
} else {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "SOWFKUN VIDEO / M3U8 STREAM DOWNLOADER" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Cyan
    $inputUrl = Read-Host "Enter video or m3u8 stream URL"
    if ($inputUrl) {
        $inputName = Read-Host "Enter file name (Leave empty for auto name)"
        Start-DownloadVideo -TargetUrl $inputUrl -TargetName $inputName
    }
}
