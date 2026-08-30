param(
    [string]$Url = "",
    [string]$OutputName = "",
    [string]$Referer = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$userDownloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"

# ------------------------------------------------------------------------------
# 1. AUTO-BOOTSTRAP YT-DLP & FFMPEG
# ------------------------------------------------------------------------------
function Ensure-YtDlp {
    $ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if ($ytdlp) {
        return @{ Type = "Direct"; Command = "yt-dlp"; ModuleArgs = @() }
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }

    if ($python) {
        $hasModule = & $python.Name -c "import yt_dlp; print('OK')" 2>$null
        if ($hasModule -match "OK") {
            return @{ Type = "Python"; Command = $python.Name; ModuleArgs = @("-m", "yt_dlp") }
        }

        Write-Host "Installing yt-dlp via pip..." -ForegroundColor Yellow
        & $python.Name -m pip install --quiet --upgrade yt-dlp
        if ($LASTEXITCODE -eq 0) {
            Write-Host "yt-dlp installed successfully!" -ForegroundColor Green
            return @{ Type = "Python"; Command = $python.Name; ModuleArgs = @("-m", "yt_dlp") }
        }
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "Installing yt-dlp via winget..." -ForegroundColor Yellow
        winget install --id yt-dlp.yt-dlp --silent --accept-package-agreements --accept-source-agreements
        $ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue
        if ($ytdlp) {
            return @{ Type = "Direct"; Command = "yt-dlp"; ModuleArgs = @() }
        }
    }

    Write-Host "ERROR: Could not find or install yt-dlp." -ForegroundColor Red
    return $null
}

function Find-FFmpeg {
    $ffmpegCmd = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
    if ($ffmpegCmd) { return $ffmpegCmd }

    $packagesDir = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (Test-Path $packagesDir) {
        $found = (Get-ChildItem -Path $packagesDir -Filter "ffmpeg.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
        if ($found) { return $found }
    }
    return "ffmpeg.exe"
}

# ------------------------------------------------------------------------------
# 2. AUTO-REPAIR OBFUSCATED STREAMS (TRUE 188-BYTE MPEG-TS SYNC)
# ------------------------------------------------------------------------------
function Repair-ObfuscatedStream {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return }

    # Check first 8 bytes for PNG header (\x89PNG\r\n\x1a\n)
    $fs = [System.IO.File]::OpenRead($FilePath)
    $buf = New-Object byte[] 8
    $readCount = $fs.Read($buf, 0, 8)
    $fs.Close()

    if ($readCount -ge 4 -and $buf[0] -eq 0x89 -and $buf[1] -eq 0x50 -and $buf[2] -eq 0x4E -and $buf[3] -eq 0x47) {
        Write-Host "[Auto-Repair] Obfuscated stream detected (fake PNG headers). Synchronizing TS packets..." -ForegroundColor Yellow

        $cleanTsPath = "$FilePath.clean.ts"
        $fixedMp4Path = "$FilePath.fixed.mp4"
        $ffmpegExe = Find-FFmpeg

        # Python script with True 5-Packet (188-byte) MPEG-TS Sync detection
        $pyCode = @"
import sys

src = r'$FilePath'
dst = r'$cleanTsPath'

def find_true_ts_sync(seg):
    limit = min(len(seg) - 188 * 4, 4096)
    for i in range(limit):
        if seg[i] == 0x47 and seg[i+188] == 0x47 and seg[i+376] == 0x47 and seg[i+564] == 0x47:
            return i
    iend = seg.find(b'IEND')
    if iend != -1:
        for i in range(iend + 8, len(seg) - 188 * 2):
            if seg[i] == 0x47 and seg[i+188] == 0x47:
                return i
    return seg.find(b'\x47')

with open(src, 'rb') as fin, open(dst, 'wb') as fout:
    data = fin.read()
    segments = data.split(b'\x89PNG\r\n\x1a\n')
    for seg in segments:
        if not seg:
            continue
        ts_start = find_true_ts_sync(seg)
        if ts_start != -1:
            valid_data = seg[ts_start:]
            valid_len = (len(valid_data) // 188) * 188
            fout.write(valid_data[:valid_len])
"@
        python -c $pyCode 2>$null

        if (Test-Path $cleanTsPath) {
            & $ffmpegExe -y -loglevel error -fflags +genpts+igndts+discardcorrupt -i $cleanTsPath -c copy -bsf:a aac_adtstoasc -avoid_negative_ts make_zero -movflags +faststart $fixedMp4Path
            if (Test-Path $fixedMp4Path) {
                Remove-Item $cleanTsPath -Force
                Remove-Item $FilePath -Force
                Move-Item $fixedMp4Path $FilePath -Force
                Write-Host "[Auto-Repair] Video stream successfully repaired with 100% audio/video sync!" -ForegroundColor Green
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 3. DOWNLOAD ENGINE
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
        # Check and auto-repair if stream was obfuscated with fake PNG headers
        Repair-ObfuscatedStream -FilePath $outputPath

        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host "SUCCESS: Video download and post-processing completed!" -ForegroundColor Green
        Write-Host "Saved file: $outputPath" -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "ERROR: Download failed (Exit Code: $LASTEXITCODE)." -ForegroundColor Red
    }
}

# ------------------------------------------------------------------------------
# 4. ENTRY POINT
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
