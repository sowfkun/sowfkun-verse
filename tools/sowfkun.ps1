param(
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsList
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$toolsDir      = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $toolsDir) { $toolsDir = "F:\Coding\Project\sowfkun.verse.v2\tools" }
$rootDir       = Split-Path -Parent $toolsDir
$serversDir    = if (Test-Path (Join-Path $rootDir ".servers")) { Join-Path $rootDir ".servers" } else { Join-Path $rootDir "server-test" }
$infraToolsDir = Join-Path $rootDir "sowfkun-verse-infrastructure\tools"
$modulesDir    = Join-Path $toolsDir "modules"

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
    Write-Host "    1. download <URL> [output_name] [referer] [format] [threads]" -ForegroundColor White
    Write-Host "       -> Universal Media Downloader (Auto-detects Video/Stream/Subtitle with studio quality audio)." -ForegroundColor DarkGray
    Write-Host "    2. sync-audio <file_path> <offset_ms> [output_file]" -ForegroundColor White
    Write-Host "       -> Lossless Audio/Video Synchronizer (Shift sound forward/backward by ms)." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [Project: Sowfkun Verse - Infrastructure & Deployment]" -ForegroundColor Cyan
    Write-Host "    3. verse-start [tabs|split|windows]" -ForegroundColor White
    Write-Host "       -> Fullstack Dev Launcher: Mo infra tunnel, Go API (air), Next.js Web (npm run dev)." -ForegroundColor DarkGray
    Write-Host "    4. deploy [cluster] [dev|prod]" -ForegroundColor White
    Write-Host "       -> Build and deploy Go Core API to cluster (Tailscale / GCP IAP) in 15s." -ForegroundColor DarkGray
    Write-Host "    5. deploy-gateway [cluster] [dev|prod]" -ForegroundColor White
    Write-Host "       -> Build and deploy Egress Gateway to cluster (Tailscale / GCP IAP) in 15s." -ForegroundColor DarkGray
    Write-Host "    6. infra [open|close|switch|status] [cluster/service]" -ForegroundColor White
    Write-Host "       -> Infrastructure Tunnel: Mo/Dong ket noi toc do cao toi Database, Redis, Kafka, Gateway theo tung cum." -ForegroundColor DarkGray
    Write-Host "    7. sync-infra [cluster] [node/all]" -ForegroundColor White
    Write-Host "       -> Sync & Clean Infrastructure: Dong bo ha tang va don dep script rac tren toan bo cum server." -ForegroundColor DarkGray
    Write-Host "    8. logs [cluster] [node] [container] [-f] [--tail <n>]" -ForegroundColor White
    Write-Host "       -> Multi-Cluster Infrastructure Logs: Xem va stream log container truc tiep tren tung cum server." -ForegroundColor DarkGray
    Write-Host "    9. devtools [web|desktop|install|uninstall]" -ForegroundColor White
    Write-Host "       -> Sowfkun Verse DevTools: GUI Dashboard quan tri MongoDB, Redis, Kafka, Postgres, RabbitMQ, Office, API Explorer..." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [System]" -ForegroundColor Cyan
    Write-Host "    10. help" -ForegroundColor White
    Write-Host "       -> Show this help message." -ForegroundColor DarkGray
    Write-Host ""
}

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
# ROUTING
# ------------------------------------------------------------------------------
if (-not $Command) {
    Show-Banner
    $menuOptions = @(
        "Sowfkun Verse - Fullstack Dev Launcher (verse-start)",
        "Sowfkun Download Center (download)",
        "Audio / Video Synchronizer (sync-audio)",
        "Sowfkun Verse DevTools - Web (devtools web)",
        "Sowfkun Verse DevTools - Desktop (devtools desktop)",
        "Deploy Go API to Server 2 (verse-deploy)",
        "Deploy Egress Gateway to Server 3 (verse-deploy-gateway)",
        "JIT Direct SSH Infrastructure Tunnel (infra open/close)",
        "View Infrastructure & Container Logs (infra-logs)",
        "Exit"
    )

    $chosen = Select-InteractiveMenu -Title "Select a tool to use:" -Options $menuOptions -DefaultIndex 0

    switch ($chosen) {
        0 {
            $script = Join-Path $modulesDir "verse\verse-start.ps1"
            & $script
        }
        1 {
            $script = Join-Path $modulesDir "downloader\download-center.ps1"
            & $script
        }
        2 {
            $script = Join-Path $modulesDir "audio\sync-audio.ps1"
            & $script
        }
        3 {
            $devToolsDir = Join-Path $rootDir "sowfkun-verse-dev-tools"
            Push-Location $devToolsDir
            try { npm run dev } finally { Pop-Location }
        }
        4 {
            $devToolsDir = Join-Path $rootDir "sowfkun-verse-dev-tools"
            Push-Location $devToolsDir
            try { npm run desktop } finally { Pop-Location }
        }
        5 {
            $script = if (Test-Path (Join-Path $infraToolsDir "deploy-api.ps1")) { Join-Path $infraToolsDir "deploy-api.ps1" } else { Join-Path $serversDir "deploy-api.ps1" }
            & $script
        }
        6 {
            $script = if (Test-Path (Join-Path $infraToolsDir "deploy-gateway.ps1")) { Join-Path $infraToolsDir "deploy-gateway.ps1" } else { Join-Path $serversDir "deploy-gateway.ps1" }
            & $script
        }
        7 {
            $script = if (Test-Path (Join-Path $infraToolsDir "infra-tunnel.ps1")) { Join-Path $infraToolsDir "infra-tunnel.ps1" } else { Join-Path $serversDir "infra-tunnel.ps1" }
            & $script
        }
        8 {
            $script = if (Test-Path (Join-Path $infraToolsDir "infra-logs.ps1")) { Join-Path $infraToolsDir "infra-logs.ps1" } else { Join-Path $serversDir "infra-logs.ps1" }
            & $script
        }
        Default {
            Write-Host "Goodbye!" -ForegroundColor Gray
        }
    }
    return
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

# Support "infra logs" / "infra log" as an alias to infra-logs
if ($cmdLower -eq "infra" -and $ArgsList.Count -ge 1 -and $ArgsList[0].ToLower() -in @("logs", "log")) {
    $cmdLower = "infra-logs"
    if ($ArgsList.Count -gt 1) {
        $ArgsList = $ArgsList[1..($ArgsList.Count - 1)]
    } else {
        $ArgsList = @()
    }
}

if ($cmdLower -in @("verse-start", "verss-start", "start", "dev-start", "run-dev", "verse-dev")) {
    if ((Get-Location).Path -ne $rootDir) {
        Set-Location $rootDir
        Write-Host "Auto CD to: $rootDir" -ForegroundColor DarkGray
    }
    $script = Join-Path $modulesDir "verse\verse-start.ps1"
    . $script @ArgsList
}
elseif ($cmdLower -in @("download", "download-subtitle", "download-sub", "dl")) {
    $script = Join-Path $modulesDir "downloader\download-center.ps1"
    $url = if ($ArgsList.Count -ge 1) { $ArgsList[0] } else { "" }
    $outName = if ($ArgsList.Count -ge 2) { $ArgsList[1] } else { "" }
    $ref = if ($ArgsList.Count -ge 3) { $ArgsList[2] } else { "" }
    $fmt = if ($ArgsList.Count -ge 4) { $ArgsList[3] } else { "" }
    $th = if ($ArgsList.Count -ge 5) { [int]$ArgsList[4] } else { 0 }
    & $script -Url $url -OutputName $outName -Referer $ref -Format $fmt -Threads $th
}
elseif ($cmdLower -eq "sync-audio") {
    $script = Join-Path $modulesDir "audio\sync-audio.ps1"
    $src = if ($ArgsList.Count -ge 1) { $ArgsList[0] } else { "" }
    $offset = if ($ArgsList.Count -ge 2) { $ArgsList[1] } else { "" }
    $dst = if ($ArgsList.Count -ge 3) { $ArgsList[2] } else { "" }
    & $script -FilePath $src -OffsetMs $offset -OutputPath $dst
}
elseif ($cmdLower -in @("verse-deploy", "deploy-api", "deploy")) {
    $script = if (Test-Path (Join-Path $infraToolsDir "deploy-api.ps1")) { Join-Path $infraToolsDir "deploy-api.ps1" } else { Join-Path $serversDir "deploy-api.ps1" }
    & $script @ArgsList
}
elseif ($cmdLower -in @("verse-deploy-gateway", "verse-deploy-gw", "deploy-gw", "deploy-gateway")) {
    $script = if (Test-Path (Join-Path $infraToolsDir "deploy-gateway.ps1")) { Join-Path $infraToolsDir "deploy-gateway.ps1" } else { Join-Path $serversDir "deploy-gateway.ps1" }
    & $script @ArgsList
}
elseif ($cmdLower -in @("infra", "infra-tunnel", "tunnel")) {
    $script = if (Test-Path (Join-Path $infraToolsDir "infra-tunnel.ps1")) { Join-Path $infraToolsDir "infra-tunnel.ps1" } else { Join-Path $serversDir "infra-tunnel.ps1" }
    & $script @ArgsList
}
elseif ($cmdLower -in @("sync-infra", "sync-infrastructure", "infra-sync")) {
    $script = if (Test-Path (Join-Path $infraToolsDir "sync-infrastructure.ps1")) { Join-Path $infraToolsDir "sync-infrastructure.ps1" } else { Join-Path $serversDir "sync-infrastructure.ps1" }
    & $script @ArgsList
}
elseif ($cmdLower -in @("logs", "infra-logs", "infra-log", "log", "verse-logs")) {
    $script = if (Test-Path (Join-Path $infraToolsDir "infra-logs.ps1")) { Join-Path $infraToolsDir "infra-logs.ps1" } else { Join-Path $serversDir "infra-logs.ps1" }
    & $script @ArgsList
}
elseif ($cmdLower -in @("devtools", "dev-tools", "devbox", "dev-box", "dev")) {
    $devToolsDir = Join-Path $rootDir "sowfkun-verse-dev-tools"
    if (-not (Test-Path $devToolsDir)) {
        Write-Host "Error: Directory '$devToolsDir' not found." -ForegroundColor Red
        exit 1
    }

    $subAction = if ($ArgsList.Count -ge 1) { $ArgsList[0].ToLower() } else { "web" }

    if (-not (Test-Path (Join-Path $devToolsDir "node_modules"))) {
        Write-Host "Initializing dependencies in $devToolsDir (npm install)..." -ForegroundColor Yellow
        Push-Location $devToolsDir
        try { npm install } finally { Pop-Location }
    }

    Push-Location $devToolsDir
    try {
        switch ($subAction) {
            "desktop" {
                Write-Host "Launching Sowfkun Verse DevTools (Desktop App)..." -ForegroundColor Green
                npm run desktop
            }
            "install" {
                Write-Host "Installing Sowfkun Verse DevTools Desktop Shortcuts..." -ForegroundColor Green
                npm run desktop:install
            }
            "uninstall" {
                Write-Host "Uninstalling Sowfkun Verse DevTools Desktop Shortcuts..." -ForegroundColor Yellow
                npm run desktop:uninstall
            }
            Default {
                Write-Host "Launching Sowfkun Verse DevTools (Web Dev Server on port 3000)..." -ForegroundColor Green
                npm run dev
            }
        }
    }
    finally {
        Pop-Location
    }
}
elseif ($cmdLower -in @("help", "-h", "--help", "/?")) {
    Show-Help
}
else {
    Write-Host "Error: Invalid command '$Command'" -ForegroundColor Red
    Show-Help
}
