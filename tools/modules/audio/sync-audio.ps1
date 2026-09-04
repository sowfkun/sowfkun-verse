param(
    [string]$FilePath = "",
    [string]$OffsetMs = "",
    [string]$OutputPath = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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

function Show-Header {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "SOWFKUN AUDIO / VIDEO SYNCHRONIZER" -ForegroundColor Green
    Write-Host "Fast Lossless Stream Remuxer" -ForegroundColor DarkGray
    Write-Host "=================================================================" -ForegroundColor Cyan
}

function Start-SyncAudio {
    param(
        [string]$SrcFile,
        [string]$Offset,
        [string]$DstFile
    )

    if (-not $SrcFile) {
        Show-Header
        Write-Host ""
        $SrcFile = Read-Host "Enter video file path"
    }

    if (-not $SrcFile) {
        Write-Host "Operation cancelled." -ForegroundColor Gray
        return
    }

    # Remove enclosing quotes if dragged & dropped from Explorer
    $SrcFile = $SrcFile.Trim('"').Trim("'")

    if (-not (Test-Path $SrcFile)) {
        Write-Host ("ERROR: Source file '" + $SrcFile + "' not found!") -ForegroundColor Red
        return
    }

    if (-not $Offset) {
        Write-Host ""
        Write-Host "Enter offset in milliseconds (ms):" -ForegroundColor Yellow
        Write-Host "  -> Positive (+500): Delays audio (moves sound forward)" -ForegroundColor Cyan
        Write-Host "  -> Negative (-500): Advances audio (moves sound backward)" -ForegroundColor Cyan
        $Offset = Read-Host "Offset in ms"
    }

    $offsetNum = 0
    if (-not [int]::TryParse($Offset, [ref]$offsetNum)) {
        Write-Host ("ERROR: Invalid offset '" + $Offset + "'. Please provide an integer like 500 or -300.") -ForegroundColor Red
        return
    }

    $ffmpegExe = Find-FFmpeg

    $fileDir  = Split-Path -Parent $SrcFile
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($SrcFile)
    $fileExt  = [System.IO.Path]::GetExtension($SrcFile)

    if (-not $DstFile) {
        $sign = if ($offsetNum -ge 0) { "+$offsetNum" } else { "$offsetNum" }
        $DstFile = Join-Path $fileDir ($fileName + "_sync_" + $sign + "ms" + $fileExt)
    } else {
        $DstFile = $DstFile.Trim('"').Trim("'")
    }

    $offsetSec = [math]::Round($offsetNum / 1000.0, 4)

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Processing Audio Synchronization..." -ForegroundColor Yellow
    Write-Host ("  Source:      " + $SrcFile) -ForegroundColor White
    Write-Host ("  Offset:      " + $offsetNum + " ms [" + $offsetSec + " seconds]") -ForegroundColor Cyan
    Write-Host ("  Destination: " + $DstFile) -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Stream Copy with itsoffset (Blazing Fast, No Re-encoding)
    if ($offsetNum -ge 0) {
        # Audio Delayed by offsetSec: Delay audio stream (Input 1)
        & $ffmpegExe -y -loglevel error -i $SrcFile -itsoffset $offsetSec -i $SrcFile -map 0:v:0 -map 1:a:0 -c copy -movflags +faststart $DstFile
    } else {
        # Audio Advanced by abs(offsetSec): Delay video stream (Input 0)
        $absOffsetSec = [math]::Abs($offsetSec)
        & $ffmpegExe -y -loglevel error -itsoffset $absOffsetSec -i $SrcFile -i $SrcFile -map 0:v:0 -map 1:a:0 -c copy -avoid_negative_ts make_zero -movflags +faststart $DstFile
    }

    if ($LASTEXITCODE -eq 0 -and (Test-Path $DstFile)) {
        $outSize = [math]::Round((Get-Item $DstFile).Length / 1MB, 2)
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host "SUCCESS: Audio synchronized perfectly!" -ForegroundColor Green
        Write-Host ("Saved File: " + $DstFile + " [" + $outSize + " MB]") -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "ERROR: Synchronization failed via FFmpeg." -ForegroundColor Red
    }
}

# Entry point
Start-SyncAudio -SrcFile $FilePath -Offset $OffsetMs -DstFile $OutputPath
