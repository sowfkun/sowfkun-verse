param(
    [string]$Url = "",
    [string]$OutputName = "",
    [string]$Referer = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$userDownloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"

# ------------------------------------------------------------------------------
# 1. AUTO-BOOTSTRAP TOOLS (FFMPEG & YT-DLP)
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 2. HIGH-SPEED HLS / M3U8 STREAM DOWNLOADER (AUTO TS DE-OBFUSCATION)
# ------------------------------------------------------------------------------
function Download-HlsStream {
    param(
        [string]$HlsUrl,
        [string]$TargetName,
        [string]$CustomReferer
    )

    if (-not $TargetName) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $TargetName = "video_$timestamp.mp4"
    }
    if (-not $TargetName.EndsWith(".mp4")) {
        $TargetName = "$TargetName.mp4"
    }

    $outputPath = Join-Path $userDownloads $TargetName
    $tempTsPath = "$outputPath.temp.ts"
    $ffmpegExe = Find-FFmpeg

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN DOWNLOADER - MULTI-THREADED HLS STREAM ENGINE" -ForegroundColor Green
    Write-Host "  URL:         $HlsUrl" -ForegroundColor White
    Write-Host "  Destination: $outputPath" -ForegroundColor White
    if ($CustomReferer) {
        Write-Host "  Referer:     $CustomReferer" -ForegroundColor DarkGray
    }
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $pyCode = @"
import sys
import os
import ssl
import time
import urllib.request
import urllib.parse
import concurrent.futures

url = r'''$HlsUrl'''
out_ts = r'''$tempTsPath'''
ref = r'''$CustomReferer'''

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
}
if ref:
    headers['Referer'] = ref

def fetch_bytes(u):
    req = urllib.request.Request(u, headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=25) as resp:
        return resp.read()

def parse_m3u8(u):
    raw = fetch_bytes(u).decode('utf-8', errors='ignore')
    lines = [l.strip() for l in raw.splitlines() if l.strip()]
    
    is_master = any('EXT-X-STREAM-INF' in l for l in lines)
    if is_master:
        sub_list = []
        for i, l in enumerate(lines):
            if l.startswith('#EXT-X-STREAM-INF'):
                bw = 0
                if 'BANDWIDTH=' in l:
                    try:
                        bw = int(l.split('BANDWIDTH=')[1].split(',')[0].replace('\"', ''))
                    except Exception:
                        pass
                if i + 1 < len(lines):
                    sub_url = urllib.parse.urljoin(u, lines[i+1])
                    sub_list.append((bw, sub_url))
        if sub_list:
            sub_list.sort(key=lambda x: x[0], reverse=True)
            return parse_m3u8(sub_list[0][1])
            
    segments = []
    for l in lines:
        if not l.startswith('#'):
            segments.append(urllib.parse.urljoin(u, l))
    return segments

def find_ts_start(data):
    limit = min(len(data) - 188 * 5, 16384)
    for i in range(limit):
        if (data[i] == 0x47 and 
            data[i+188] == 0x47 and 
            data[i+376] == 0x47 and 
            data[i+564] == 0x47 and
            data[i+752] == 0x47):
            return i
    iend = data.find(b'IEND')
    if iend != -1:
        for i in range(iend + 4, min(len(data) - 188 * 2, iend + 2048)):
            if data[i] == 0x47 and data[i+188] == 0x47:
                return i
    return data.find(b'\x47')

try:
    print('[1/3] Parsing M3U8 Master / Media Playlist...')
    segments = parse_m3u8(url)
    total_segs = len(segments)
    if not segments:
        print('ERROR: No video segments found in playlist.', file=sys.stderr)
        sys.exit(1)
        
    print(f'[2/3] Downloading {total_segs} segments concurrently (16 threads)...')
    
    seg_data = [None] * total_segs
    completed_count = 0
    total_bytes = 0
    start_time = time.time()
    
    def download_segment(idx, seg_url):
        for attempt in range(4):
            try:
                raw = fetch_bytes(seg_url)
                ts_pos = find_ts_start(raw)
                if ts_pos != -1:
                    clean = raw[ts_pos:]
                    valid_len = (len(clean) // 188) * 188
                    return idx, clean[:valid_len]
                return idx, raw
            except Exception:
                time.sleep(1 + attempt)
        return idx, b''

    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as executor:
        futures = {executor.submit(download_segment, i, seg_url): i for i, seg_url in enumerate(segments)}
        for future in concurrent.futures.as_completed(futures):
            idx, data = future.result()
            seg_data[idx] = data
            completed_count += 1
            total_bytes += len(data)
            
            elapsed = max(0.1, time.time() - start_time)
            speed_mb = (total_bytes / (1024 * 1024)) / elapsed
            percent = (completed_count / total_segs) * 100
            
            bar_len = 30
            filled = int(bar_len * completed_count // total_segs)
            bar = '=' * filled + '-' * (bar_len - filled)
            sys.stdout.write(f'\r  Progress: [{bar}] {completed_count}/{total_segs} ({percent:.1f}%) | {speed_mb:.2f} MB/s')
            sys.stdout.flush()

    print('\n[3/3] Assembling clean TS stream...')
    with open(out_ts, 'wb') as fout:
        for chunk in seg_data:
            if chunk:
                fout.write(chunk)
                
    print('TS stream saved successfully.')
except Exception as ex:
    print(f'\nERROR in HLS engine: {ex}', file=sys.stderr)
    sys.exit(1)
"@

    python -c $pyCode

    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempTsPath)) {
        Write-Host "Muxing clean TS stream to MP4 container via FFmpeg..." -ForegroundColor Yellow
        & $ffmpegExe -y -loglevel error -fflags +genpts+igndts+discardcorrupt -i $tempTsPath -c copy -bsf:a aac_adtstoasc -avoid_negative_ts make_zero -movflags +faststart $outputPath

        if (Test-Path $outputPath) {
            Remove-Item $tempTsPath -Force -ErrorAction SilentlyContinue
            $fileSizeMB = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
            Write-Host ""
            Write-Host "=================================================================" -ForegroundColor Green
            Write-Host "SUCCESS: Video downloaded & remuxed with 100% audio/video sync!" -ForegroundColor Green
            Write-Host "Saved file: $outputPath ($fileSizeMB MB)" -ForegroundColor Cyan
            Write-Host "=================================================================" -ForegroundColor Green
            return
        }
    }

    Write-Host "ERROR: HLS download or remux failed." -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# 3. AUTO-REPAIR OBFUSCATED STREAMS (FALLBACK CHUNKED STREAMING)
# ------------------------------------------------------------------------------
function Repair-ObfuscatedStream {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return }

    # Scan first 64KB for PNG magic (\x89PNG\r\n\x1a\n)
    $hasPngObfuscation = $false
    $fs = [System.IO.File]::OpenRead($FilePath)
    $scanSize = [Math]::Min(65536, $fs.Length)
    $buf = New-Object byte[] $scanSize
    $readCount = $fs.Read($buf, 0, $scanSize)
    $fs.Close()

    for ($i = 0; $i -lt ($readCount - 8); $i++) {
        if ($buf[$i] -eq 0x89 -and $buf[$i+1] -eq 0x50 -and $buf[$i+2] -eq 0x4E -and $buf[$i+3] -eq 0x47) {
            $hasPngObfuscation = $true
            break
        }
    }

    if ($hasPngObfuscation) {
        Write-Host "[Auto-Repair] Obfuscated stream detected (fake PNG headers). Synchronizing 188-byte TS packets..." -ForegroundColor Yellow

        $cleanTsPath = "$FilePath.clean.ts"
        $fixedMp4Path = "$FilePath.fixed.mp4"
        $ffmpegExe = Find-FFmpeg

        $pyCode = @"
import sys
import os

src = r'''$FilePath'''
dst = r'''$cleanTsPath'''

def find_true_ts_sync(seg):
    limit = min(len(seg) - 188 * 5, 8192)
    for i in range(limit):
        if (seg[i] == 0x47 and 
            seg[i+188] == 0x47 and 
            seg[i+376] == 0x47 and 
            seg[i+564] == 0x47 and
            seg[i+752] == 0x47):
            return i
    iend = seg.find(b'IEND')
    if iend != -1:
        for i in range(iend + 8, len(seg) - 188 * 2):
            if seg[i] == 0x47 and seg[i+188] == 0x47:
                return i
    return seg.find(b'\x47')

try:
    with open(src, 'rb') as fin, open(dst, 'wb') as fout:
        chunk_size = 10 * 1024 * 1024
        remainder = b''
        while True:
            raw = fin.read(chunk_size)
            if not raw:
                if remainder:
                    ts_start = find_true_ts_sync(remainder)
                    if ts_start != -1:
                        valid = remainder[ts_start:]
                        fout.write(valid[:(len(valid)//188)*188])
                break
            data = remainder + raw
            segments = data.split(b'\x89PNG\r\n\x1a\n')
            remainder = segments.pop()
            for seg in segments:
                if not seg:
                    continue
                ts_start = find_true_ts_sync(seg)
                if ts_start != -1:
                    valid = seg[ts_start:]
                    fout.write(valid[:(len(valid)//188)*188])
except Exception as ex:
    print(f'Error repairing stream: {ex}', file=sys.stderr)
"@
        python -c $pyCode 2>$null

        if (Test-Path $cleanTsPath) {
            & $ffmpegExe -y -loglevel error -fflags +genpts+igndts+discardcorrupt -i $cleanTsPath -c copy -bsf:a aac_adtstoasc -avoid_negative_ts make_zero -movflags +faststart $fixedMp4Path
            if (Test-Path $fixedMp4Path) {
                Remove-Item $cleanTsPath -Force -ErrorAction SilentlyContinue
                Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
                Move-Item $fixedMp4Path $FilePath -Force
                Write-Host "[Auto-Repair] Video stream successfully repaired with 100% audio/video sync!" -ForegroundColor Green
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 4. DIRECT SUBTITLE DOWNLOADER (.vtt, .srt, .ass)
# ------------------------------------------------------------------------------
function Download-Subtitle {
    param(
        [string]$SubUrl,
        [string]$SubName,
        [string]$CustomReferer
    )

    $subExt = ".vtt"
    if ($SubUrl -match "\.(vtt|srt|ass|sub)($|\?)") {
        $subExt = "." + $Matches[1]
    }

    if (-not $SubName) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $SubName = "sub_$timestamp$subExt"
    }
    if (-not ($SubName.EndsWith(".vtt") -or $SubName.EndsWith(".srt") -or $SubName.EndsWith(".ass") -or $SubName.EndsWith(".sub"))) {
        $SubName = "$SubName$subExt"
    }

    $outputPath = Join-Path $userDownloads $SubName

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN DOWNLOADER - DOWNLOADING SUBTITLE FILE..." -ForegroundColor Green
    Write-Host "  URL:         $SubUrl" -ForegroundColor White
    Write-Host "  Destination: $outputPath" -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $pyCode = @"
import urllib.request
import ssl

url = r'''$SubUrl'''
out = r'''$outputPath'''
ref = r'''$CustomReferer'''

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
}
if ref:
    headers['Referer'] = ref

req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, context=ctx) as resp, open(out, 'wb') as fout:
    fout.write(resp.read())
"@
    python -c $pyCode 2>$null

    if (Test-Path $outputPath) {
        $subSize = [math]::Round((Get-Item $outputPath).Length / 1KB, 2)
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host "SUCCESS: Subtitle downloaded successfully!" -ForegroundColor Green
        Write-Host "Saved Subtitle: $outputPath ($subSize KB)" -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to download subtitle from $SubUrl" -ForegroundColor Red
    }
}

# ------------------------------------------------------------------------------
# 5. DOWNLOAD ENGINE DISPATCHER
# ------------------------------------------------------------------------------
function Start-DownloadVideo {
    param(
        [string]$TargetUrl,
        [string]$TargetName,
        [string]$CustomReferer
    )

    if (-not $TargetUrl) {
        Write-Host "ERROR: Please provide a video, stream, or subtitle URL!" -ForegroundColor Red
        return
    }

    # 1. If URL is a direct subtitle file (.vtt, .srt, .ass, /subtitle/)
    if ($TargetUrl -match "\.(vtt|srt|ass|sub)($|\?)" -or $TargetUrl -match "/subtitle/") {
        Download-Subtitle -SubUrl $TargetUrl -SubName $TargetName -CustomReferer $CustomReferer
        return
    }

    # 2. If URL is an HLS / M3U8 stream (handles master playlist & obfuscated PNG headers)
    if ($TargetUrl -match "\.m3u8($|\?)" -or $TargetUrl -match "/stream/" -or $TargetUrl -match "/hls/") {
        Download-HlsStream -HlsUrl $TargetUrl -TargetName $TargetName -CustomReferer $CustomReferer
        return
    }

    # 3. Fallback to YT-DLP for general video platforms (YouTube, TikTok, Facebook, etc.)
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
    Write-Host ">>> SOWFKUN DOWNLOADER - STARTING YT-DLP DOWNLOAD..." -ForegroundColor Green
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
        Write-Host "SUCCESS: Video download completed!" -ForegroundColor Green
        Write-Host "Saved file: $outputPath" -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "ERROR: Download failed (Exit Code: $LASTEXITCODE)." -ForegroundColor Red
    }
}

# ------------------------------------------------------------------------------
# 6. ENTRY POINT
# ------------------------------------------------------------------------------
if ($Url) {
    Start-DownloadVideo -TargetUrl $Url -TargetName $OutputName -CustomReferer $Referer
} else {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "SOWFKUN VIDEO / M3U8 STREAM / SUBTITLE DOWNLOADER" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Cyan
    $inputUrl = Read-Host "Enter video, m3u8 stream, or subtitle URL"
    if ($inputUrl) {
        $inputName = Read-Host "Enter file name (Leave empty for auto name)"
        Start-DownloadVideo -TargetUrl $inputUrl -TargetName $inputName
    }
}
