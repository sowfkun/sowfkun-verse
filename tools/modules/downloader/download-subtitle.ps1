param(
    [string]$Url = "",
    [string]$OutputName = "",
    [string]$Referer = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$userDownloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"

function Download-Subtitle {
    param(
        [string]$SubUrl,
        [string]$SubName,
        [string]$CustomReferer
    )

    if (-not $SubUrl) {
        Write-Host "ERROR: Please provide a subtitle URL!" -ForegroundColor Red
        return
    }

    $subExt = ".vtt"
    if ($SubUrl -match "\.(vtt|srt|ass|sub)($|\?)") {
        $subExt = "." + $Matches[1]
    }

    if ($SubName) {
        $inputExt = [System.IO.Path]::GetExtension($SubName).ToLower()
        if ($inputExt -in @(".vtt", ".srt", ".ass", ".sub", ".txt")) {
            $subExt = $inputExt
        } else {
            $SubName = "$SubName$subExt"
        }
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $SubName = "sub_$timestamp$subExt"
    }

    $outputPath = Join-Path $userDownloads $SubName

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN DOWNLOAD CENTER - SUBTITLE ENGINE" -ForegroundColor Green
    Write-Host "  URL:         $SubUrl" -ForegroundColor White
    Write-Host "  Destination: $outputPath" -ForegroundColor White
    if ($CustomReferer) {
        Write-Host "  Referer:     $CustomReferer" -ForegroundColor DarkGray
    }
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $pyCode = @"
import sys
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

try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=30) as resp, open(out, 'wb') as fout:
        fout.write(resp.read())
except Exception as ex:
    print(f'ERROR downloading subtitle: {ex}', file=sys.stderr)
    sys.exit(1)
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

if ($Url) {
    Download-Subtitle -SubUrl $Url -SubName $OutputName -CustomReferer $Referer
} else {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "SOWFKUN SUBTITLE DOWNLOADER" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Cyan
    $inputUrl = Read-Host "Enter subtitle URL (.vtt, .srt, .ass, .sub)"
    if ($inputUrl) {
        $inputName = Read-Host "Enter file name (Leave empty for auto name)"
        Download-Subtitle -SubUrl $inputUrl -SubName $inputName
    }
}
