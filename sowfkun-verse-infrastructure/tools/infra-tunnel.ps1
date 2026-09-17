param(
    [Parameter(Position = 0)]
    [string]$Action = "open",

    [Parameter(Position = 1)]
    [string]$Target = "",

    [Parameter(Position = 2)]
    [string]$Profile = ""
)

if ($args.Count -ge 1 -and -not $Action) { $Action = $args[0] }
if ($args.Count -ge 2 -and -not $Target) { $Target = $args[1] }
if ($args.Count -ge 3 -and -not $Profile) { $Profile = $args[2] }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$toolsDir = if ($PSScriptRoot) { $PSScriptRoot } else { "F:\Coding\Project\sowfkun.verse.v2\sowfkun-verse-infrastructure\tools" }
$rootDir  = Split-Path -Parent (Split-Path -Parent $toolsDir)
$serversDir = if (Test-Path (Join-Path $rootDir ".servers")) { Join-Path $rootDir ".servers" } else { Join-Path $rootDir "server-test" }
$serverTestDir = $serversDir

$configFile = if ($env:SOWFKUN_SERVERS_CONFIG -and (Test-Path $env:SOWFKUN_SERVERS_CONFIG)) {
    $env:SOWFKUN_SERVERS_CONFIG
} elseif (Test-Path (Join-Path $serversDir "servers.json")) {
    Join-Path $serversDir "servers.json"
} elseif (Test-Path (Join-Path $toolsDir "servers.json")) {
    Join-Path $toolsDir "servers.json"
} else {
    Join-Path $toolsDir "servers.example.json"
}

if (-not (Test-Path $configFile)) {
    Write-Host "Khong tim thay file cau hinh: $configFile" -ForegroundColor Red
    Write-Host "Vui long tao file .servers/servers.json (tham khao sowfkun-verse-infrastructure/tools/servers.example.json)" -ForegroundColor Yellow
    exit 1
}

$rawJson = Get-Content -Path $configFile -Raw -Encoding UTF8
$config  = $rawJson | ConvertFrom-Json

# Detect gcloud SDK path on Windows
$gcloudCmd = (Get-Command gcloud -ErrorAction SilentlyContinue).Source
if (-not $gcloudCmd -or $gcloudCmd.EndsWith(".ps1")) {
    $fallbackPaths = @(
        "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        "C:\Users\truon\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        "$env:ProgramFiles\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        "${env:ProgramFiles(x86)}\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
    )
    foreach ($p in $fallbackPaths) {
        if (Test-Path $p) {
            $gcloudCmd = $p
            break
        }
    }
}
if (-not $gcloudCmd) { $gcloudCmd = "gcloud" }

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

function Show-Header {
    param([string]$profileName, [string]$serviceName = "All Services")
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ">>> SOWFKUN VERSE - MULTI-SERVER INFRASTRUCTURE TUNNEL" -ForegroundColor Green
    Write-Host "    Profile : $profileName" -ForegroundColor White
    Write-Host "    Services: $serviceName" -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Cyan
}

function Get-ActiveProfile {
    param([string]$targetProfile = "")
    $profKey = if ($targetProfile) { $targetProfile } elseif ($Profile -and $config.profiles.PSObject.Properties[$Profile]) { $Profile } else { $config.active_profile }
    $profObj = $config.profiles.PSObject.Properties[$profKey]
    if (-not $profObj) {
        $validProfiles = @($config.profiles.PSObject.Properties.Name) -join ', '
        Write-Host "Profile '$profKey' khong ton tai trong servers.json!" -ForegroundColor Red
        Write-Host "Cac profile kha dung: $validProfiles" -ForegroundColor Yellow
        exit 1
    }
    return @{
        Key  = $profKey
        Data = $profObj.Value
    }
}

function Switch-Profile {
    param([string]$targetProfile)
    if (-not $targetProfile) {
        Write-Host "Vui long chi dinh ten Profile muon switch!" -ForegroundColor Red
        return
    }
    if (-not $config.profiles.PSObject.Properties[$targetProfile]) {
        $validProfiles = @($config.profiles.PSObject.Properties.Name) -join ', '
        Write-Host "Profile '$targetProfile' khong hop le! Cac profile kha dung: $validProfiles" -ForegroundColor Red
        return
    }
    $config.active_profile = $targetProfile
    $newJson = $config | ConvertTo-Json -Depth 10
    Set-Content -Path $configFile -Value $newJson -Encoding UTF8
    Write-Host "-> Da chuyen active profile sang: '$targetProfile'" -ForegroundColor Green
}

function Close-Infra {
    $activeProf = Get-ActiveProfile
    $profData = $activeProf.Data

    Write-Host "`nTerminating Tunnels and Cleaning Up Firewalls..." -ForegroundColor Yellow

    # Collect all ports across all profiles to be safe
    $allPorts = @()
    foreach ($pName in $config.profiles.PSObject.Properties.Name) {
        $pObj = $config.profiles.PSObject.Properties[$pName].Value
        if ($pObj.nodes) {
            foreach ($nKey in $pObj.nodes.PSObject.Properties.Name) {
                $n = $pObj.nodes.PSObject.Properties[$nKey].Value
                if ($n.tunnels) {
                    foreach ($t in $n.tunnels) {
                        $allPorts += $t.local_port
                    }
                }
            }
        }
    }
    $allPorts = $allPorts | Select-Object -Unique

    Get-NetTCPConnection -LocalPort $allPorts -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  -> Local port forwardings terminated ($($allPorts -join ', '))." -ForegroundColor Green

    # Clean up GCP firewalls for GCP JIT nodes
    $gcpNodes = @()
    foreach ($nodeKey in $profData.nodes.PSObject.Properties.Name) {
        $node = $profData.nodes.PSObject.Properties[$nodeKey].Value
        if ($node.type -eq "gcp_jit" -and $node.gcp) {
            $gcpNodes += $node
        }
    }

    if ($gcpNodes.Count -gt 0) {
        Write-Host "  -> Removing temporary GCP firewall rules..." -ForegroundColor Yellow
        $jobs = @()
        foreach ($node in $gcpNodes) {
            $p = $node.gcp.project
            $a = $node.gcp.account
            $r1 = $node.gcp.ingress_rule
            $r2 = $node.gcp.egress_rule
            $jobs += Start-Job -ScriptBlock {
                param($cmd, $p, $a, $r1, $r2)
                if ($r1 -and $r2) {
                    & $cmd compute firewall-rules delete $r1 $r2 --project=$p --account=$a --quiet 2>$null
                } elseif ($r1) {
                    & $cmd compute firewall-rules delete $r1 --project=$p --account=$a --quiet 2>$null
                }
            } -ArgumentList $gcloudCmd, $p, $a, $r1, $r2
        }
        $null = $jobs | Wait-Job -Timeout 15
        $jobs | Remove-Job -Force 2>$null
    }

    Write-Host "  -> All tunnels closed and locked down securely." -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Cyan
}

function Open-Infra {
    param(
        [string]$TargetService = "all"
    )

    $activeProf = Get-ActiveProfile
    $profKey  = $activeProf.Key
    $profData = $activeProf.Data

    # Filter active nodes by target service
    $selectedNodeKeys = @()
    $svcLower = if ($TargetService) { $TargetService.ToLower().Trim() } else { "all" }

    if ($svcLower -in @("all", "", "*", "full")) {
        $selectedNodeKeys = @($profData.nodes.PSObject.Properties.Name)
        $svcDisplay = "All Services"
    } elseif ($svcLower -in @("data", "infra", "deps", "local", "dev")) {
        $selectedNodeKeys = @()
        foreach ($k in $profData.nodes.PSObject.Properties.Name) {
            if ($k -ne "app") {
                $selectedNodeKeys += $k
            }
        }
        $svcDisplay = "Data & Gateway Dependencies (Excluding App Node)"
    } elseif ($svcLower -in @("mongo", "mongodb", "db", "database", "netcup")) {
        $selectedNodeKeys = @("mongo")
        $svcDisplay = "MongoDB (Netcup Node)"
    } elseif ($svcLower -in @("cache", "redis", "kafka", "mq", "cache_mq", "server1", "redpanda")) {
        $selectedNodeKeys = @("cache_mq")
        $svcDisplay = "Redis & Kafka (Server 1)"
    } elseif ($svcLower -in @("app", "api", "backend", "server2", "go")) {
        $selectedNodeKeys = @("app")
        $svcDisplay = "Go API Backend (Server 2)"
    } elseif ($svcLower -in @("gateway", "gw", "egress", "server3")) {
        $selectedNodeKeys = @("gateway")
        $svcDisplay = "Egress Gateway (Server 3)"
    } else {
        if ($profData.nodes.PSObject.Properties[$svcLower]) {
            $selectedNodeKeys = @($svcLower)
            $svcDisplay = "$svcLower Node"
        } else {
            $selectedNodeKeys = @($profData.nodes.PSObject.Properties.Name)
            $svcDisplay = "All Services"
        }
    }

    Show-Header -profileName "$profKey ($($profData.name))" -serviceName $svcDisplay

    # 1. Collect all ports and kill existing processes
    $allPorts = @()
    foreach ($nodeKey in $selectedNodeKeys) {
        $prop = $profData.nodes.PSObject.Properties[$nodeKey]
        if (-not $prop) { continue }
        $node = $prop.Value
        if ($node.tunnels) {
            foreach ($t in $node.tunnels) {
                $allPorts += $t.local_port
            }
        }
    }
    $allPorts = $allPorts | Select-Object -Unique

    if ($allPorts.Count -gt 0) {
        Write-Host "[1/3] Clearing local ports ($($allPorts -join ', '))..." -ForegroundColor Yellow
        Get-NetTCPConnection -LocalPort $allPorts -ErrorAction SilentlyContinue | ForEach-Object {
            Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
        }
    }

    # 2. Activate temporary firewall rules for GCP JIT nodes
    $gcpNodes = @()
    foreach ($nodeKey in $selectedNodeKeys) {
        $prop = $profData.nodes.PSObject.Properties[$nodeKey]
        if (-not $prop) { continue }
        $node = $prop.Value
        if ($node.type -eq "gcp_jit" -and $node.gcp) {
            $gcpNodes += $node
        }
    }

    if ($gcpNodes.Count -gt 0) {
        $nodeCount = $gcpNodes.Count
        Write-Host "[2/3] Activating temporary SSH firewall rules on GCP ($nodeCount nodes)..." -ForegroundColor Yellow
        $createRuleBlock = {
            param($cmd, $p, $a, $net, $rule, $dir, $target, $ruleSpec)
            if ($dir -eq "INGRESS") {
                & $cmd compute firewall-rules create $rule --project=$p --account=$a --network=$net --direction=INGRESS --action=ALLOW --source-ranges=$target --rules=$ruleSpec --priority=800 --quiet 2>$null
            } else {
                & $cmd compute firewall-rules create $rule --project=$p --account=$a --network=$net --direction=EGRESS --action=ALLOW --destination-ranges=$target --rules=$ruleSpec --priority=800 --quiet 2>$null
            }
        }

        $fwJobs = @()
        foreach ($node in $gcpNodes) {
            $p = $node.gcp.project
            $a = $node.gcp.account
            $net = $node.gcp.network
            $rIn = $node.gcp.ingress_rule
            $rEg = $node.gcp.egress_rule

            if ($rIn) {
                $fwJobs += Start-Job -ScriptBlock $createRuleBlock -ArgumentList $gcloudCmd, $p, $a, $net, $rIn, "INGRESS", "0.0.0.0/0", "tcp:22"
            }
            if ($rEg) {
                $fwJobs += Start-Job -ScriptBlock $createRuleBlock -ArgumentList $gcloudCmd, $p, $a, $net, $rEg, "EGRESS", "0.0.0.0/0", "all"
            }
        }

        $null = $fwJobs | Wait-Job -Timeout 25
        $fwJobs | Remove-Job -Force 2>$null
        Write-Host "  -> Temporary firewall rules unlocked on GCP!" -ForegroundColor Green
        Start-Sleep -Seconds 3
    } else {
        Write-Host "[2/3] Overlay Network Mode: Native Tailscale WireGuard Mesh (No Cloud Firewall rules needed)." -ForegroundColor Green
    }

    # 3. Launch Native OpenSSH Port Forwarding for each node
    Write-Host "[3/3] Establishing SSH Tunnel Connections..." -ForegroundColor Yellow

    $processes = @{}
    $nodeArgsMap = @{}

    foreach ($nodeKey in $selectedNodeKeys) {
        $prop = $profData.nodes.PSObject.Properties[$nodeKey]
        if (-not $prop) { continue }
        $node = $prop.Value
        if (-not $node.tunnels -or $node.tunnels.Count -eq 0) { continue }

        $keyPath = $node.key_path
        if ($keyPath) {
            $keyPath = $keyPath.Replace('$env:USERPROFILE', $env:USERPROFILE)
            $keyPath = [System.Environment]::ExpandEnvironmentVariables($keyPath)
            if (-not [System.IO.Path]::IsPathRooted($keyPath)) {
                $keyPath = Join-Path $serverTestDir $keyPath
            }
        }

        $sshArgs = @(
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=NUL",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-N"
        )

        if ($keyPath -and (Test-Path $keyPath)) {
            $sshArgs += @("-i", $keyPath)
        }

        foreach ($t in $node.tunnels) {
            $sshArgs += @("-L", "$($t.local_port):127.0.0.1:$($t.remote_port)")
        }

        $sshArgs += "$($node.user)@$($node.host)"
        $nodeArgsMap[$nodeKey] = $sshArgs

        $proc = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -PassThru -NoNewWindow
        $processes[$nodeKey] = $proc
    }

    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "INFRASTRUCTURE SERVICES ARE LIVE! ($svcDisplay)" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green

    foreach ($nodeKey in $selectedNodeKeys) {
        $prop = $profData.nodes.PSObject.Properties[$nodeKey]
        if (-not $prop) { continue }
        $node = $prop.Value
        $nodeTypeLabel = if ($node.type -eq "tailscale") { "Tailscale WireGuard" } else { "Direct JIT SSH" }
        Write-Host "  [$($node.name) - $($node.host) ($nodeTypeLabel)]" -ForegroundColor Yellow
        foreach ($t in $node.tunnels) {
            $proto = if ($t.local_port -in @(80, 443, 8080, 8085, 8090, 3000)) { "http://" } else { "" }
            Write-Host "    * $($t.desc): $proto" -NoNewline -ForegroundColor DarkGray
            Write-Host "localhost:$($t.local_port)" -ForegroundColor Cyan
        }
        Write-Host ""
    }

    Write-Host "-----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Status: High-Speed Native Tunnel Active" -ForegroundColor Green
    Write-Host "Press Ctrl+C at any time to disconnect and lock down firewalls." -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Green

    try {
        $retryCounts = @{}
        while ($true) {
            Start-Sleep -Seconds 2
            $keys = @($processes.Keys)
            foreach ($nodeKey in $keys) {
                $p = $processes[$nodeKey]
                if ($p -and $p.HasExited) {
                    $retryCounts[$nodeKey] = ($retryCounts[$nodeKey] -as [int]) + 1
                    if ($retryCounts[$nodeKey] -le 2) {
                        Write-Host "  [!] Node '$nodeKey' tunnel dropped, reconnecting ($($retryCounts[$nodeKey])/2)..." -ForegroundColor Yellow
                        $argsList = $nodeArgsMap[$nodeKey]
                        $processes[$nodeKey] = Start-Process -FilePath "ssh" -ArgumentList $argsList -PassThru -NoNewWindow
                    } else {
                        Write-Host "  [x] Node '$nodeKey' is unreachable (offline). Keeping other healthy tunnels alive." -ForegroundColor Red
                        $processes[$nodeKey] = $null
                    }
                }
            }
        }
    }
    finally {
        foreach ($p in $processes.Values) {
            if ($p -and -not $p.HasExited) {
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            }
        }
        Close-Infra
    }
}

function Show-Interactive-Menu {
    $menuOptions = @(
        "All Services (Mongo, Redis, Kafka, App, Gateway)",
        "MongoDB Database Only (Mongo Node : 27017)",
        "Redis Cache & Kafka MQ Only (Cache/MQ Node : 6379, 9092, 8085)",
        "Go API Backend Only (App Node : 8080)",
        "Egress Gateway Only (Gateway Node : 8090)",
        "Close All Tunnels",
        "Switch Profile (tailscale-dev / hybrid-dev / gcp-direct-dev / tailscale-prod)",
        "Exit"
    )

    $chosen = Select-InteractiveMenu -Title "Select service to open tunnel:" -Options $menuOptions -DefaultIndex 0
    switch ($chosen) {
        0 { Open-Infra -TargetService "all" }
        1 { Open-Infra -TargetService "mongo" }
        2 { Open-Infra -TargetService "cache_mq" }
        3 { Open-Infra -TargetService "app" }
        4 { Open-Infra -TargetService "gateway" }
        5 { Close-Infra }
        6 {
            $profOptions = @("hybrid", "netcup", "tailscale", "gcp_direct")
            $profChosen = Select-InteractiveMenu -Title "Select Profile to switch:" -Options $profOptions -DefaultIndex 0
            Switch-Profile -targetProfile $profOptions[$profChosen]
        }
        Default { Write-Host "Goodbye!" -ForegroundColor Gray }
    }
}

# ------------------------------------------------------------------------------
# ENTRYPOINT ROUTER
# ------------------------------------------------------------------------------
$knownServices = @("mongo", "mongodb", "redis", "kafka", "cache", "app", "api", "gateway", "gw", "all", "cache_mq", "netcup", "db", "database")
$actLower = if ($Action) { $Action.ToLower().Trim() } else { "open" }
$targetLower = if ($Target) { $Target.ToLower().Trim() } else { "" }

if ($actLower -in @("open", "start")) {
    if ($targetLower -and ($targetLower -in $knownServices)) {
        Open-Infra -TargetService $targetLower
    } elseif ($targetLower -and $config.profiles.PSObject.Properties[$targetLower]) {
        # target specified as profile name
        Open-Infra -TargetService "all"
    } else {
        # Open with interactive service selection
        Show-Interactive-Menu
    }
}
elseif ($actLower -in $knownServices) {
    # Direct service shortcut: e.g. "sowfkun infra mongo"
    Open-Infra -TargetService $actLower
}
elseif ($actLower -eq "close") {
    Close-Infra
}
elseif ($actLower -eq "switch") {
    $targetProf = if ($Target) { $Target } else { $Profile }
    Switch-Profile -targetProfile $targetProf
}
elseif ($actLower -eq "status") {
    $activeProf = Get-ActiveProfile
    Show-Header -profileName "$($activeProf.Key) ($($activeProf.Data.name))"
    Write-Host "Active Profile: $($activeProf.Key)" -ForegroundColor Green
    Write-Host "Description   : $($activeProf.Data.description)" -ForegroundColor DarkGray
    Write-Host "`nConfigured Nodes:" -ForegroundColor Cyan
    foreach ($nodeKey in $activeProf.Data.nodes.PSObject.Properties.Name) {
        $node = $activeProf.Data.nodes.PSObject.Properties[$nodeKey].Value
        Write-Host "  * $nodeKey ($($node.name)): $($node.host) [Type: $($node.type)]" -ForegroundColor White
    }
}
else {
    Show-Interactive-Menu
}
