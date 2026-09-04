param(
    [string]$Url = "",
    [string]$OutputName = "",
    [string]$Referer = "",
    [string]$Format = "",
    [int]$Threads = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$modulesDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $modulesDir) { $modulesDir = "F:\Coding\Project\sowfkun.verse.v2\tools\modules" }

$videoScript = Join-Path $modulesDir "download-video.ps1"
$subScript = Join-Path $modulesDir "download-subtitle.ps1"

# ------------------------------------------------------------------------------
# INTERACTIVE SELECTION COMPONENT (ARROW KEYS NAVIGATION)
# ------------------------------------------------------------------------------
function Select-InteractiveMenu {
    param(
        [string]$Title,
        [string[]]$Options,
        [int]$DefaultIndex = 0
    )

    $selectedIndex = $DefaultIndex
    $optionsCount = $Options.Count

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
# SMART URL DETECTOR / CLASSIFIER
# ------------------------------------------------------------------------------
function Detect-MediaType {
    param([string]$TargetUrl)

    if (-not $TargetUrl) { return "UNKNOWN" }

    $urlLower = $TargetUrl.ToLower()

    # 1. Subtitle detection
    if ($urlLower -match "\.(vtt|srt|ass|sub|sbv)($|\?)" -or 
        $urlLower -match "/subtitle/" -or 
        $urlLower -match "/subtitles/" -or 
        $urlLower -match "/subs/") {
        return "SUBTITLE"
    }

    # 2. Video / Stream detection
    if ($urlLower -match "\.(m3u8|mp4|mkv|webm|ts|flv|avi|mov|m4v)($|\?)" -or 
        $urlLower -match "/stream/" -or 
        $urlLower -match "/hls/" -or 
        $urlLower -match "/playlist/" -or 
        $urlLower -match "(youtube\.com|youtu\.be|tiktok\.com|facebook\.com|fb\.watch|instagram\.com|vimeo\.com|bilibili|dailymotion|twitter\.com|x\.com)") {
        return "VIDEO"
    }

    # 3. Audio detection
    if ($urlLower -match "\.(mp3|m4a|aac|flac|wav|ogg|opus)($|\?)") {
        return "AUDIO"
    }

    return "UNKNOWN"
}

# ------------------------------------------------------------------------------
# UNIFIED DOWNLOAD CENTER ENTRY POINT
# ------------------------------------------------------------------------------
$targetUrl = $Url
if (-not $targetUrl) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN DOWNLOAD CENTER" -ForegroundColor Green
    Write-Host "    Universal Multi-Stream, Video & Subtitle Extraction Engine" -ForegroundColor DarkGray
    Write-Host "=================================================================" -ForegroundColor Cyan
    $targetUrl = Read-Host "Enter Video, Stream (.m3u8), or Subtitle (.vtt, .srt) URL"
}

if (-not $targetUrl) {
    Write-Host "No URL entered. Exiting." -ForegroundColor Gray
    exit 0
}

# 1. Detect media type
$mediaType = Detect-MediaType -TargetUrl $targetUrl

if ($mediaType -eq "UNKNOWN") {
    $typeOptions = @(
        "Video / Online Stream (M3U8, MP4, HLS, Web Streams)",
        "Subtitle File (.vtt, .srt, .ass, .sub)",
        "Audio Stream / Music (.mp3, .m4a, .aac)"
    )
    $typeIdx = Select-InteractiveMenu -Title "Could not auto-detect stream type. Please select:" -Options $typeOptions -DefaultIndex 0
    switch ($typeIdx) {
        0 { $mediaType = "VIDEO" }
        1 { $mediaType = "SUBTITLE" }
        2 { $mediaType = "AUDIO" }
    }
}

# 2. Common Name Input & Extension Resolution
$targetName = $OutputName
if (-not $targetName) {
    $targetName = Read-Host "Enter file name (Leave empty for auto name)"
}

# 3. Dispatch to Specialized Pipeline
switch ($mediaType) {
    "SUBTITLE" {
        & $subScript -Url $targetUrl -OutputName $targetName -Referer $Referer
    }
    Default {
        # Video / Audio Stream Pipeline
        $chosenFormat = $Format
        if (-not $chosenFormat) {
            $fmtOptions = @(
                "MKV (Recommended: Studio Quality Audio, Resilient & Full Subs)",
                "MP4 (Standard Web / Smart TV Compatibility)"
            )
            $fmtIdx = Select-InteractiveMenu -Title "Choose Container Format:" -Options $fmtOptions -DefaultIndex 0
            $chosenFormat = if ($fmtIdx -eq 1) { "mp4" } else { "mkv" }
        }

        $chosenThreads = $Threads
        if ($chosenThreads -le 0) {
            $speedOptions = @(
                "32 Threads (Fast & Safe - Default)",
                "64 Threads (Ultra High Speed / Gigabit Network)",
                "16 Threads (Conservative / Strict Servers)"
            )
            $spdIdx = Select-InteractiveMenu -Title "Choose Download Concurrency:" -Options $speedOptions -DefaultIndex 0
            $chosenThreads = 32
            if ($spdIdx -eq 1) { $chosenThreads = 64 }
            elseif ($spdIdx -eq 2) { $chosenThreads = 16 }
        }

        & $videoScript -Url $targetUrl -OutputName $targetName -Referer $Referer -Format $chosenFormat -Threads $chosenThreads
    }
}
