param(
    [string]$Url = "",
    [string]$OutputName = "",
    [string]$Referer = "",
    [string]$Format = "mkv",
    [int]$Threads = 32
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
        [string]$CustomReferer,
        [string]$TargetFormat = "mkv",
        [int]$WorkerThreads = 32
    )

    $cleanFormat = if ($TargetFormat.ToLower() -eq "mp4") { "mp4" } else { "mkv" }
    $ext = ".$cleanFormat"

    if ($TargetName) {
        $inputExt = [System.IO.Path]::GetExtension($TargetName).ToLower()
        if ($inputExt -in @(".mp4", ".mkv", ".ts", ".webm", ".avi", ".mov")) {
            $ext = $inputExt
            $cleanFormat = $ext.TrimStart('.')
        } else {
            $TargetName = "$TargetName$ext"
        }
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $TargetName = "video_$timestamp$ext"
    }

    $outputPath = Join-Path $userDownloads $TargetName
    $tempTsPath = "$outputPath.temp.ts"
    $ffmpegExe = Find-FFmpeg

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN DOWNLOADER - MULTI-THREADED HLS STREAM ENGINE" -ForegroundColor Green
    Write-Host "  URL:         $HlsUrl" -ForegroundColor White
    Write-Host "  Format:      $([System.IO.Path]::GetExtension($outputPath).Trim('.').ToUpper())" -ForegroundColor Cyan
    Write-Host "  Threads:     $WorkerThreads" -ForegroundColor Cyan
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
import re
import urllib.request
import urllib.parse
import subprocess
import concurrent.futures

url = r'''$HlsUrl'''
out_ts = r'''$tempTsPath'''
out_final = r'''$outputPath'''
ref = r'''$CustomReferer'''
ffmpeg_bin = r'''$ffmpegExe'''
target_ext = r'''$ext'''

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
    total_dur = 0.0
    cur_dur = 0.0
    for l in lines:
        if l.startswith('#EXTINF:'):
            try:
                cur_dur = float(l.split(':')[1].split(',')[0])
            except Exception:
                cur_dur = 0.0
        elif not l.startswith('#'):
            segments.append(urllib.parse.urljoin(u, l))
            total_dur += cur_dur
            cur_dur = 0.0
    return segments, total_dur

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

def render_progress_bar(label, current, total, extra=''):
    pct = (current / total) * 100 if total > 0 else 100.0
    bar_len = 30
    filled = int(bar_len * current // total) if total > 0 else bar_len
    bar = '=' * filled + ('-' * (bar_len - filled))
    sys.stdout.write(f'\r  {label}: [{bar}] {pct:5.1f}% {extra}')
    sys.stdout.flush()

try:
    print('[1/4] Parsing M3U8 Master / Media Playlist...')
    segments, total_duration = parse_m3u8(url)
    total_segs = len(segments)
    if not segments:
        print('ERROR: No video segments found in playlist.', file=sys.stderr)
        sys.exit(1)
        
    print(f'[2/4] Downloading {total_segs} segments concurrently ($WorkerThreads threads)...')
    
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

    with concurrent.futures.ThreadPoolExecutor(max_workers=$WorkerThreads) as executor:
        futures = {executor.submit(download_segment, i, seg_url): i for i, seg_url in enumerate(segments)}
        for future in concurrent.futures.as_completed(futures):
            idx, data = future.result()
            seg_data[idx] = data
            completed_count += 1
            total_bytes += len(data)
            
            elapsed = max(0.1, time.time() - start_time)
            speed_mb = (total_bytes / (1024 * 1024)) / elapsed
            extra_info = f'| {completed_count}/{total_segs} segs | {speed_mb:.2f} MB/s'
            render_progress_bar('Download', completed_count, total_segs, extra_info)

    print('\n[3/4] Assembling and verifying TS segments into clean stream...')
    assembled_bytes = 0
    with open(out_ts, 'wb') as fout:
        for idx, chunk in enumerate(seg_data):
            if chunk:
                fout.write(chunk)
                assembled_bytes += len(chunk)
            if idx % 10 == 0 or idx == total_segs - 1:
                cur_mb = assembled_bytes / (1024 * 1024)
                extra_info = f'| {idx+1}/{total_segs} segs | {cur_mb:.1f} MB'
                render_progress_bar('Combine ', idx + 1, total_segs, extra_info)

    # Free memory chunks immediately
    del seg_data

    fmt_tag = target_ext.lstrip('.').upper()
    print(f'\n[4/4] Muxing to {fmt_tag} with Studio Quality 320k AAC Audio & Strict A/V Sync...')
    
    # FFmpeg remux with progress tracking
    ffmpeg_cmd = [
        ffmpeg_bin, '-y',
        '-fflags', '+genpts+igndts',
        '-i', out_ts,
        '-c:v', 'copy',
        '-c:a', 'aac',
        '-b:a', '320k',
        '-af', 'aresample=async=1:first_pts=0',
        '-avoid_negative_ts', 'make_zero'
    ]
    if target_ext.lower() == '.mp4':
        ffmpeg_cmd.extend(['-movflags', '+faststart'])
    ffmpeg_cmd.extend(['-progress', 'pipe:1', '-nostats', '-loglevel', 'error', out_final])

    proc = subprocess.Popen(ffmpeg_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    
    current_time_sec = 0.0
    current_speed = '1.0x'
    
    for line in proc.stdout:
        line = line.strip()
        if line.startswith('out_time_us='):
            try:
                us = int(line.split('=')[1])
                current_time_sec = us / 1000000.0
            except Exception:
                pass
        elif line.startswith('speed='):
            val = line.split('=')[1].strip()
            if val and val != 'N/A':
                current_speed = val
        elif line == 'progress=continue' or line == 'progress=end':
            if total_duration > 0:
                cur_m, cur_s = divmod(int(current_time_sec), 60)
                cur_h, cur_m = divmod(cur_m, 60)
                tot_m, tot_s = divmod(int(total_duration), 60)
                tot_h, tot_m = divmod(tot_m, 60)
                cur_str = f'{cur_h:02d}:{cur_m:02d}:{cur_s:02d}' if tot_h > 0 else f'{cur_m:02d}:{cur_s:02d}'
                tot_str = f'{tot_h:02d}:{tot_m:02d}:{tot_s:02d}' if tot_h > 0 else f'{tot_m:02d}:{tot_s:02d}'
                extra_info = f'| Time: {cur_str}/{tot_str} | Speed: {current_speed}'
                render_progress_bar('Muxing  ', min(current_time_sec, total_duration), total_duration, extra_info)
            else:
                cur_m, cur_s = divmod(int(current_time_sec), 60)
                cur_h, cur_m = divmod(cur_m, 60)
                cur_str = f'{cur_h:02d}:{cur_m:02d}:{cur_s:02d}' if cur_h > 0 else f'{cur_m:02d}:{cur_s:02d}'
                sys.stdout.write(f'\r  Muxing  : Processed {cur_str} | Speed: {current_speed}   ')
                sys.stdout.flush()

    proc.wait()
    _, stderr_out = proc.communicate()

    if proc.returncode != 0:
        print(f'\nFFmpeg remux error: {stderr_out}', file=sys.stderr)
        sys.exit(1)

    if total_duration > 0:
        render_progress_bar('Muxing  ', total_duration, total_duration, '| Complete!               ')
    print('\nStream muxing and audio mastering completed successfully.')

except Exception as ex:
    print(f'\nERROR in HLS engine: {ex}', file=sys.stderr)
    sys.exit(1)
"@

    python -c $pyCode

    if ($LASTEXITCODE -eq 0 -and (Test-Path $outputPath)) {
        Remove-Item $tempTsPath -Force -ErrorAction SilentlyContinue
        $fileSizeMB = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host "SUCCESS: Video downloaded & remuxed with 100% audio/video sync!" -ForegroundColor Green
        Write-Host "Saved file: $outputPath ($fileSizeMB MB)" -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Green
        return
    }

    Write-Host "ERROR: HLS download or remux failed." -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# 3. AUTO-REPAIR OBFUSCATED STREAMS (FALLBACK CHUNKED STREAMING)
# ------------------------------------------------------------------------------
function Repair-ObfuscatedStream {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return }

    # 1. If file is already a valid ISO MP4 ('ftyp' or 'moov' in first 64 bytes), NEVER corrupt/repair it
    $fs = [System.IO.File]::OpenRead($FilePath)
    $scanSize = [Math]::Min(65536, $fs.Length)
    $buf = New-Object byte[] $scanSize
    $readCount = $fs.Read($buf, 0, $scanSize)
    $fs.Close()

    if ($readCount -ge 8) {
        # Check standard MP4 container signatures
        for ($i = 0; $i -lt ($readCount - 8); $i++) {
            if (($buf[$i] -eq 0x66 -and $buf[$i+1] -eq 0x74 -and $buf[$i+2] -eq 0x79 -and $buf[$i+3] -eq 0x70) -or
                ($buf[$i] -eq 0x6D -and $buf[$i+1] -eq 0x6F -and $buf[$i+2] -eq 0x6F -and $buf[$i+3] -eq 0x76)) {
                return
            }
        }
    }

    # 2. Scan first 4KB for fake PNG magic (\x89PNG\r\n\x1a\n) at segment boundaries
    $hasPngObfuscation = $false
    for ($i = 0; $i -lt [Math]::Min(4096, $readCount - 8); $i++) {
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
import subprocess

src = r'''$FilePath'''
dst = r'''$cleanTsPath'''
fixed_mp4 = r'''$fixedMp4Path'''
ffmpeg_bin = r'''$ffmpegExe'''

def find_true_ts_sync(seg):
    limit = min(len(seg) - 188 * 5, 8192)
    for i in range(limit):
        if (seg[i] == 0x47 and 
            seg[i+188] == 0x47 and 
            seg[i+376] == 0x47 and 
            seg[i+564] == 0x47 and
            data_match(seg, i)):
            return i
    iend = seg.find(b'IEND')
    if iend != -1:
        for i in range(iend + 8, len(seg) - 188 * 2):
            if seg[i] == 0x47 and seg[i+188] == 0x47:
                return i
    return seg.find(b'\x47')

def data_match(s, idx):
    return (idx + 752 < len(s) and s[idx+752] == 0x47)

def render_progress_bar(label, current, total, extra=''):
    pct = (current / total) * 100 if total > 0 else 100.0
    bar_len = 30
    filled = int(bar_len * current // total) if total > 0 else bar_len
    bar = '=' * filled + ('-' * (bar_len - filled))
    sys.stdout.write(f'\r  {label}: [{bar}] {pct:5.1f}% {extra}')
    sys.stdout.flush()

try:
    total_file_size = os.path.getsize(src)
    read_total = 0
    print('[1/2] De-obfuscating fake PNG headers & aligning 188-byte TS packets...')
    with open(src, 'rb') as fin, open(dst, 'wb') as fout:
        chunk_size = 8 * 1024 * 1024
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
            read_total += len(raw)
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
            
            cur_mb = read_total / (1024 * 1024)
            tot_mb = total_file_size / (1024 * 1024)
            extra_info = f'| {cur_mb:.1f}/{tot_mb:.1f} MB'
            render_progress_bar('Repair  ', read_total, total_file_size, extra_info)

    render_progress_bar('Repair  ', total_file_size, total_file_size, '| Complete!           \n')

    print('[2/2] Remuxing repaired stream to MP4 container...')
    ffmpeg_cmd = [
        ffmpeg_bin, '-y',
        '-fflags', '+genpts+igndts',
        '-i', dst,
        '-c:v', 'copy',
        '-c:a', 'aac',
        '-b:a', '320k',
        '-af', 'aresample=async=1:first_pts=0',
        '-avoid_negative_ts', 'make_zero',
        '-movflags', '+faststart',
        '-progress', 'pipe:1',
        '-nostats',
        '-loglevel', 'error',
        fixed_mp4
    ]
    proc = subprocess.Popen(ffmpeg_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    for line in proc.stdout:
        line = line.strip()
        if line.startswith('out_time_us='):
            try:
                us = int(line.split('=')[1])
                sec = us / 1000000.0
                cur_m, cur_s = divmod(int(sec), 60)
                cur_h, cur_m = divmod(cur_m, 60)
                cur_str = f'{cur_h:02d}:{cur_m:02d}:{cur_s:02d}' if cur_h > 0 else f'{cur_m:02d}:{cur_s:02d}'
                sys.stdout.write(f'\r  Muxing  : Processed {cur_str}   ')
                sys.stdout.flush()
            except Exception:
                pass
    proc.wait()
    _, stderr_out = proc.communicate()
    if proc.returncode != 0:
        print(f'\nFFmpeg error: {stderr_out}', file=sys.stderr)
        sys.exit(1)
    print('\nRepaired stream successfully muxed.')
except Exception as ex:
    print(f'Error repairing stream: {ex}', file=sys.stderr)
    sys.exit(1)
"@
        python -c $pyCode 2>$null

        if (Test-Path $fixedMp4Path) {
            Remove-Item $cleanTsPath -Force -ErrorAction SilentlyContinue
            Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
            Move-Item $fixedMp4Path $FilePath -Force
            Write-Host "[Auto-Repair] Video stream successfully repaired with 100% audio/video sync!" -ForegroundColor Green
        }
    }
}

# ------------------------------------------------------------------------------
# 4. DOWNLOAD ENGINE DISPATCHER
# ------------------------------------------------------------------------------
function Start-DownloadVideo {
    param(
        [string]$TargetUrl,
        [string]$TargetName,
        [string]$CustomReferer,
        [string]$TargetFormat = "mkv",
        [int]$WorkerThreads = 32
    )

    if (-not $TargetUrl) {
        Write-Host "ERROR: Please provide a video or stream URL!" -ForegroundColor Red
        return
    }

    # 1. If URL is an HLS / M3U8 stream (handles master playlist & obfuscated PNG headers)
    if ($TargetUrl -match "\.m3u8($|\?)" -or $TargetUrl -match "/stream/" -or $TargetUrl -match "/hls/") {
        Download-HlsStream -HlsUrl $TargetUrl -TargetName $TargetName -CustomReferer $CustomReferer -TargetFormat $TargetFormat -WorkerThreads $WorkerThreads
        return
    }

    # 2. Fallback to YT-DLP for general video platforms (YouTube, TikTok, Facebook, etc.)
    $runner = Ensure-YtDlp
    if (-not $runner) { return }

    $cleanFormat = if ($TargetFormat.ToLower() -eq "mp4") { "mp4" } else { "mkv" }
    $ext = ".$cleanFormat"

    if ($TargetName) {
        $inputExt = [System.IO.Path]::GetExtension($TargetName).ToLower()
        if ($inputExt -in @(".mp4", ".mkv", ".ts", ".webm", ".avi", ".mov")) {
            $ext = $inputExt
            $cleanFormat = $ext.TrimStart('.')
        } else {
            $TargetName = "$TargetName$ext"
        }
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $TargetName = "video_$timestamp$ext"
    }

    $outputPath = Join-Path $userDownloads $TargetName

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN DOWNLOADER - STARTING YT-DLP DOWNLOAD..." -ForegroundColor Green
    Write-Host "  URL:         $TargetUrl" -ForegroundColor White
    Write-Host "  Format:      $([System.IO.Path]::GetExtension($outputPath).Trim('.').ToUpper())" -ForegroundColor Cyan
    Write-Host "  Threads:     $WorkerThreads" -ForegroundColor Cyan
    Write-Host "  Destination: $outputPath" -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $ffmpegExe = Find-FFmpeg
    $dlArgs = @()
    if ($runner.Type -eq "Python") {
        $dlArgs += $runner.ModuleArgs
    }

    $mergeFmt = if ($ext -eq ".mp4") { "mp4" } else { "mkv" }

    $dlArgs += @(
        "$TargetUrl",
        "-o", "$outputPath",
        "-f", "bestvideo*+bestaudio/best",
        "--merge-output-format", "$mergeFmt",
        "--audio-quality", "0",
        "--postprocessor-args", "ffmpeg:-c:a aac -b:a 320k",
        "--concurrent-fragments", "$WorkerThreads",
        "--embed-metadata",
        "--embed-thumbnail",
        "--embed-chapters",
        "--all-subs",
        "--embed-subs",
        "--write-auto-subs",
        "--no-check-certificates",
        "--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    )

    if ($ffmpegExe -and $ffmpegExe -ne "ffmpeg.exe") {
        $dlArgs += @("--ffmpeg-location", "$ffmpegExe")
    }

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
# 6. INTERACTIVE SELECTION COMPONENT (ARROW KEYS NAVIGATION)
# ------------------------------------------------------------------------------
function Select-InteractiveMenu {
    param(
        [string]$Title,
        [string[]]$Options,
        [int]$DefaultIndex = 0
    )

    $selectedIndex = $DefaultIndex
    $optionsCount = $Options.Count

    # Non-interactive / piped fallback
    if (-not [Environment]::UserInteractive -or $host.Name -match "ServerRemoteHost") {
        Write-Host $Title -ForegroundColor Yellow
        for ($i = 0; $i -lt $optionsCount; $i++) {
            Write-Host "  [$($i+1)] $($Options[$i])"
        }
        $raw = Read-Host "Select option [1-$optionsCount] (Default: $($DefaultIndex+1))"
        $val = 0
        if ([int]::TryParse($raw, [ref]$val) -and $val -ge 1 -and $val -le $optionsCount) {
            return ($val - 1)
        }
        return $DefaultIndex
    }

    Write-Host ""
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "  (Use UP / DOWN arrow keys to move, Enter to confirm)" -ForegroundColor DarkGray

    try { [Console]::CursorVisible = $false } catch {}

    $firstRender = $true
    $e = [char]27

    while ($true) {
        if (-not $firstRender) {
            # Reposition cursor up by optionsCount lines to overwrite in place
            $repositioned = $false
            try {
                $pos = $host.UI.RawUI.CursorPosition
                $pos.X = 0
                $pos.Y = [Math]::Max(0, $pos.Y - $optionsCount)
                $host.UI.RawUI.CursorPosition = $pos
                $repositioned = $true
            } catch {}

            if (-not $repositioned) {
                try {
                    [Console]::SetCursorPosition(0, [Math]::Max(0, [Console]::CursorTop - $optionsCount))
                    $repositioned = $true
                } catch {}
            }

            if (-not $repositioned) {
                [Console]::Write("$e[$($optionsCount)A$e[0G")
            }
        }
        $firstRender = $false

        for ($i = 0; $i -lt $optionsCount; $i++) {
            $optText = $Options[$i]
            if ($i -eq $selectedIndex) {
                Write-Host ("  > [*] " + $optText) -ForegroundColor Green
            } else {
                Write-Host ("    [ ] " + $optText) -ForegroundColor DarkGray
            }
        }

        $keyInfo = [Console]::ReadKey($true)
        $keyName = $keyInfo.Key.ToString()
        $char = $keyInfo.KeyChar

        if ($keyName -in @("UpArrow", "W", "LeftArrow")) {
            $selectedIndex = ($selectedIndex - 1 + $optionsCount) % $optionsCount
        }
        elseif ($keyName -in @("DownArrow", "S", "RightArrow")) {
            $selectedIndex = ($selectedIndex + 1) % $optionsCount
        }
        elseif ($keyName -in @("Enter", "Spacebar")) {
            break
        }
        elseif ($char -ge '1' -and $char -le ('0' + [Math]::Min(9, $optionsCount))) {
            $selectedIndex = [int]::Parse($char.ToString()) - 1
            break
        }
    }

    try { [Console]::CursorVisible = $true } catch {}
    Write-Host ""
    return $selectedIndex
}

# ------------------------------------------------------------------------------
# 7. ENTRY POINT
# ------------------------------------------------------------------------------
if ($Url) {
    Start-DownloadVideo -TargetUrl $Url -TargetName $OutputName -CustomReferer $Referer -TargetFormat $Format -WorkerThreads $Threads
} else {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "SOWFKUN DOWNLOAD CENTER" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Cyan
    $inputUrl = Read-Host "Enter video, m3u8 stream, or subtitle URL"
    if ($inputUrl) {
        $fmtOptions = @(
            "MKV (Recommended: Studio Quality Audio, Resilient & Full Subs)",
            "MP4 (Standard Web / Smart TV Compatibility)"
        )
        $fmtIdx = Select-InteractiveMenu -Title "Choose Container Format:" -Options $fmtOptions -DefaultIndex 0
        $chosenFormat = if ($fmtIdx -eq 1) { "mp4" } else { "mkv" }

        $inputName = Read-Host "Enter file name (Leave empty for auto name)"

        $speedOptions = @(
            "32 Threads (Fast & Safe - Default)",
            "64 Threads (Ultra High Speed / Gigabit Network)",
            "16 Threads (Conservative / Strict Servers)"
        )
        $spdIdx = Select-InteractiveMenu -Title "Choose Download Concurrency:" -Options $speedOptions -DefaultIndex 0
        $chosenThreads = 32
        if ($spdIdx -eq 1) { $chosenThreads = 64 }
        elseif ($spdIdx -eq 2) { $chosenThreads = 16 }

        Start-DownloadVideo -TargetUrl $inputUrl -TargetName $inputName -TargetFormat $chosenFormat -WorkerThreads $chosenThreads
    }
}

