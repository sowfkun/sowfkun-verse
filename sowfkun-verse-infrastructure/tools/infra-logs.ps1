param(
    [Parameter(Position = 0)]
    [string]$Cluster = "",

    [Parameter(Position = 1)]
    [string]$Node = "",

    [Parameter(Position = 2)]
    [string]$Container = "",

    [object]$Tail = 100,

    [switch]$Follow,
    [switch]$F,
    [switch]$Timestamps,
    [switch]$T,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

# Parse legacy or additional flags
$extraArgs = @()
$isFollow = $Follow.IsPresent -or $F.IsPresent
$isTimestamps = $Timestamps.IsPresent -or $T.IsPresent

# Combine remaining args with $args if any
$allArgsToParse = @()
if ($RemainingArgs) { $allArgsToParse += $RemainingArgs }
if ($args) { $allArgsToParse += $args }

$tailCount = 100
if ($Tail) {
    $parsedT = 0
    if ([int]::TryParse($Tail.ToString(), [ref]$parsedT) -and $parsedT -gt 0) {
        $tailCount = $parsedT
    }
}

$i = 0
while ($i -lt $allArgsToParse.Count) {
    $arg = $allArgsToParse[$i]
    if ($arg -in @("-f", "--follow", "-follow", "-F")) {
        $isFollow = $true
    }
    elseif ($arg -in @("-t", "--timestamps", "-timestamps", "-T")) {
        $isTimestamps = $true
    }
    elseif ($arg -in @("-n", "--tail", "-tail", "-tail=") -and ($i + 1) -lt $allArgsToParse.Count) {
        $i++
        $parsedTail = 0
        if ([int]::TryParse($allArgsToParse[$i], [ref]$parsedTail) -and $parsedTail -gt 0) {
            $tailCount = $parsedTail
        }
    }
    elseif ($arg -match "^--tail=(\d+)$") {
        $tailCount = [int]$matches[1]
    }
    elseif ($arg -match "^\d+$") {
        $tailCount = [int]$arg
    }
    else {
        if (-not $Cluster) { $Cluster = $arg }
        elseif (-not $Node) { $Node = $arg }
        elseif (-not $Container) { $Container = $arg }
        else { $extraArgs += $arg }
    }
    $i++
}

$Tail = $tailCount

# Ignore if first parameter is the command name 'logs'
if ($Cluster.ToLower() -in @("logs", "infra-logs", "infra-log", "log")) {
    $Cluster = $Node
    $Node = $Container
    $Container = if ($extraArgs.Count -gt 0) { $extraArgs[0] } else { "" }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$toolsDir   = if ($PSScriptRoot) { $PSScriptRoot } else { "F:\Coding\Project\sowfkun.verse.v2\sowfkun-verse-infrastructure\tools" }
$rootDir    = Split-Path -Parent (Split-Path -Parent $toolsDir)
$serversDir = if (Test-Path (Join-Path $rootDir ".servers")) { Join-Path $rootDir ".servers" } else { Join-Path $rootDir "server-test" }

# 1. Load Server Configuration
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
    Write-Host "ERROR: Config file not found: $configFile" -ForegroundColor Red
    Write-Host "Please ensure .servers/servers.json exists." -ForegroundColor Yellow
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
        for ($k = 0; $k -lt $optionsCount; $k++) {
            Write-Host "  [$($k+1)] $($Options[$k])"
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

        for ($k = 0; $k -lt $optionsCount; $k++) {
            $optText = $Options[$k]
            if ($k -eq $selectedIndex) {
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
# STEP 1: RESOLVE CLUSTER PROFILE (with Smart Inference)
# ------------------------------------------------------------------------------
$profileProps = @($config.profiles.PSObject.Properties)
$profileKeys  = @($profileProps | ForEach-Object { $_.Name })
$activeProf   = if ($config.active_profile) { $config.active_profile } else { $profileKeys[0] }
$activeProfData = $config.profiles.$activeProf

# Smart CLI Inference: If $Cluster is not a profile key, check if it's a node or container in active profile
if ($Cluster -and (-not ($profileKeys -contains $Cluster))) {
    $activeNodeKeys = @($activeProfData.nodes.PSObject.Properties.Name)
    if ($activeNodeKeys -contains $Cluster) {
        # e.g.: sowfkun logs cache_mq redis -> Cluster=tailscale-dev, Node=cache_mq, Container=redis
        if ($Node -and (-not $Container)) { $Container = $Node }
        $Node = $Cluster
        $Cluster = $activeProf
    }
    elseif ($Cluster.ToLower() -in @("redis", "redpanda", "console", "redpanda-console", "redis-insight")) {
        $Container = $Cluster
        $Node = "cache_mq"
        $Cluster = $activeProf
    }
    elseif ($Cluster.ToLower() -in @("api", "app-api", "backend")) {
        $Container = "api"
        $Node = "app"
        $Cluster = $activeProf
    }
    elseif ($Cluster.ToLower() -in @("gateway", "app-gateway", "egress")) {
        $Container = "gateway"
        $Node = "gateway"
        $Cluster = $activeProf
    }
    elseif ($Cluster.ToLower() -in @("mongo", "mongodb")) {
        $Container = "mongo"
        $Node = "mongo"
        $Cluster = $activeProf
    }
}

if (-not $Cluster) {
    $defaultProfIdx = [Array]::IndexOf($profileKeys, $activeProf)
    if ($defaultProfIdx -lt 0) { $defaultProfIdx = 0 }

    $profileMenuOptions = @()
    foreach ($pKey in $profileKeys) {
        $pData = $config.profiles.$pKey
        $isAct = if ($pKey -eq $activeProf) { " (ACTIVE)" } else { "" }
        $profileMenuOptions += "$pKey$isAct - $($pData.name)"
    }

    $chosenProfIdx = Select-InteractiveMenu -Title "Step 1/4: Select Cluster Profile:" -Options $profileMenuOptions -DefaultIndex $defaultProfIdx
    $Cluster = $profileKeys[$chosenProfIdx]
}

$profData = $config.profiles.$Cluster
if (-not $profData) {
    Write-Host "ERROR: Cluster profile '$Cluster' not found in $configFile!" -ForegroundColor Red
    Write-Host "Available profiles: $($profileKeys -join ', ')" -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------------------------
# STEP 2: RESOLVE TARGET NODE
# ------------------------------------------------------------------------------
$nodeProps = @($profData.nodes.PSObject.Properties)
$nodeKeys  = @($nodeProps | ForEach-Object { $_.Name })

if ($nodeKeys.Count -eq 0) {
    Write-Host "ERROR: No nodes configured in cluster profile '$Cluster'!" -ForegroundColor Red
    exit 1
}

if (-not $Node) {
    $nodeMenuOptions = @()
    foreach ($nKey in $nodeKeys) {
        $nData = $profData.nodes.$nKey
        $nodeMenuOptions += "[$nKey] $($nData.name) ($($nData.host) | $($nData.type))"
    }

    $chosenNodeIdx = Select-InteractiveMenu -Title "Step 2/4: Select Target Server Node:" -Options $nodeMenuOptions -DefaultIndex 0
    $Node = $nodeKeys[$chosenNodeIdx]
}

$targetNode = $profData.nodes.$Node
if (-not $targetNode) {
    # Check case-insensitive match
    $matchedKey = $nodeKeys | Where-Object { $_ -eq $Node -or $_.ToLower() -eq $Node.ToLower() } | Select-Object -First 1
    if ($matchedKey) {
        $Node = $matchedKey
        $targetNode = $profData.nodes.$Node
    } else {
        Write-Host "ERROR: Node '$Node' not found in cluster profile '$Cluster'!" -ForegroundColor Red
        Write-Host "Available nodes: $($nodeKeys -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$nodeHost = $targetNode.host
$nodeUser = if ($targetNode.user) { $targetNode.user } else { "root" }
$nodeType = $targetNode.type
$nodeName = if ($targetNode.name) { $targetNode.name } else { $Node }

# Resolve SSH Key Path
$keyPath = $targetNode.key_path
if ($keyPath) {
    $keyPath = $keyPath.Replace('$env:USERPROFILE', $env:USERPROFILE)
    $keyPath = [System.Environment]::ExpandEnvironmentVariables($keyPath)
    if (-not [System.IO.Path]::IsPathRooted($keyPath)) {
        $keyPath = Join-Path $serversDir $keyPath
    }
}

# Helper function to execute remote command
function Invoke-RemoteCommand {
    param(
        [string]$RemoteCmd,
        [switch]$Interactive
    )

    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($RemoteCmd))
    $safeCmd = "echo '$b64' | base64 -d | bash"

    if ($nodeType -eq "tailscale" -or ($keyPath -and (Test-Path $keyPath))) {
        $sshArgs = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=8")
        if ($Interactive) {
            $sshArgs += @("-t")
        }
        if ($keyPath -and (Test-Path $keyPath)) {
            $sshArgs += @("-i", $keyPath)
        }
        $sshArgs += @("${nodeUser}@${nodeHost}", $safeCmd)
        if ($Interactive) {
            & ssh @sshArgs
        } else {
            return (& ssh @sshArgs 2>$null)
        }
    }
    elseif ($targetNode.gcp) {
        $vmName = if ($targetNode.gcp.vm_name) { $targetNode.gcp.vm_name } else { $nodeHost }
        $gcpProject = $targetNode.gcp.project
        $gcpAccount = $targetNode.gcp.account
        $gcpZone = if ($targetNode.gcp.zone) { $targetNode.gcp.zone } else { "us-central1-a" }

        $gcpArgs = @("compute", "ssh", $vmName, "--zone=$gcpZone", "--project=$gcpProject", "--account=$gcpAccount", "--tunnel-through-iap", "--quiet", "--command=$safeCmd")
        if ($Interactive) {
            & $gcloudCmd @gcpArgs
        } else {
            return (& $gcloudCmd @gcpArgs 2>$null)
        }
    }
    else {
        # Default direct SSH
        $sshArgs = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=8")
        if ($Interactive) { $sshArgs += @("-t") }
        $sshArgs += @("${nodeUser}@${nodeHost}", $safeCmd)
        if ($Interactive) {
            & ssh @sshArgs
        } else {
            return (& ssh @sshArgs 2>$null)
        }
    }
}

# ------------------------------------------------------------------------------
# STEP 3: RESOLVE TARGET CONTAINER
# ------------------------------------------------------------------------------
if (-not $Container) {
    Write-Host "Querying active containers on [$Node] ($nodeHost)..." -ForegroundColor DarkGray
    
    $listCmd = 'sudo docker ps -a --format "{{.Names}}:::{{.Status}}:::{{.Image}}" 2>/dev/null || docker ps -a --format "{{.Names}}:::{{.Status}}:::{{.Image}}" 2>/dev/null'
    $rawContainers = Invoke-RemoteCommand -RemoteCmd $listCmd
    $parsedContainers = @()
    
    if ($rawContainers) {
        foreach ($line in ($rawContainers -split "`n")) {
            $trimmed = $line.Trim()
            if ($trimmed -and $trimmed.Contains(":::")) {
                $parts = $trimmed -split ":::"
                if ($parts.Count -ge 1 -and $parts[0]) {
                    $cName   = $parts[0].Trim()
                    $cStatus = if ($parts.Count -ge 2) { $parts[1].Trim() } else { "" }
                    $cImage  = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "" }
                    $parsedContainers += [PSCustomObject]@{
                        Name   = $cName
                        Status = $cStatus
                        Image  = $cImage
                    }
                }
            }
        }
    }

    $containerOptions = @()
    if ($parsedContainers.Count -gt 0) {
        foreach ($c in $parsedContainers) {
            $statusShort = if ($c.Status -match "^Up") { "RUNNING" } else { "STOPPED" }
            $containerOptions += "$($c.Name)  [$statusShort] ($($c.Image))"
        }
        $containerOptions += "[ALL] View logs of all containers on this node (compose logs)"
        $containerOptions += "[CUSTOM] Enter a custom container name..."
    } else {
        # Fallback presets with standard app_* naming
        $presets = @(
            @{ Label = "Redis Cache (app_redis / redis)"; Value = "redis" },
            @{ Label = "Redpanda Kafka Broker (app_kafka / redpanda)"; Value = "kafka" },
            @{ Label = "Kafka Web Console (app_kafka_console / console)"; Value = "console" },
            @{ Label = "MongoDB (app_mongo / mongo)"; Value = "mongo" },
            @{ Label = "Go Backend API (app_api / api)"; Value = "api" },
            @{ Label = "Egress Gateway (app_gateway / gateway)"; Value = "gateway" },
            @{ Label = "OpenSearch (app_opensearch / opensearch)"; Value = "opensearch" },
            @{ Label = "OpenSearch Dashboards (app_dashboards / dashboards)"; Value = "dashboards" },
            @{ Label = "Central Monitoring (app_grafana / prometheus / loki)"; Value = "monitoring" },
            @{ Label = "Promtail Log Shipper (app_promtail)"; Value = "promtail" }
        )
        foreach ($pr in $presets) {
            $containerOptions += "$($pr.Label)"
        }
        $containerOptions += "[ALL] View logs of all containers on this node (compose logs)"
        $containerOptions += "[CUSTOM] Enter a custom container name..."
    }

    $chosenContainerIdx = Select-InteractiveMenu -Title "Step 3/4: Select Container to Inspect Logs:" -Options $containerOptions -DefaultIndex 0

    if ($parsedContainers.Count -gt 0) {
        if ($chosenContainerIdx -lt $parsedContainers.Count) {
            $Container = $parsedContainers[$chosenContainerIdx].Name
        }
        elseif ($chosenContainerIdx -eq $parsedContainers.Count) {
            $Container = "all"
        }
        else {
            $Container = Read-Host "Enter container name"
        }
    } else {
        $presetsCount = $presets.Count
        if ($chosenContainerIdx -lt $presetsCount) {
            $Container = $presets[$chosenContainerIdx].Value
        }
        elseif ($chosenContainerIdx -eq $presetsCount) {
            $Container = "all"
        }
        else {
            $Container = Read-Host "Enter container name"
        }
    }
}

if (-not $Container) {
    Write-Host "ERROR: No container specified!" -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------------------------
# STEP 4: RESOLVE LOG OPTIONS (Tail & Follow if in interactive terminal)
# ------------------------------------------------------------------------------
# If not passed via command line flags and interactive
if (-not $isFollow -and ($args.Count -eq 0 -and -not $Follow.IsPresent)) {
    $logModeOptions = @(
        "Realtime Stream (Follow -f) with last $Tail lines",
        "Dump last $Tail lines and exit",
        "Dump last 500 lines and exit",
        "Realtime Stream (Follow -f) with last 500 lines"
    )
    $chosenMode = Select-InteractiveMenu -Title "Step 4/4: Select Log Stream Mode:" -Options $logModeOptions -DefaultIndex 0
    switch ($chosenMode) {
        0 { $isFollow = $true }
        1 { $isFollow = $false }
        2 { $isFollow = $false; $Tail = 500 }
        3 { $isFollow = $true; $Tail = 500 }
    }
}

# ------------------------------------------------------------------------------
# STEP 5: EXECUTE DOCKER LOGS WITH SMART AUTO-RESOLUTION
# ------------------------------------------------------------------------------
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ">>> SOWFKUN VERSE - INFRASTRUCTURE CONTAINER LOGS" -ForegroundColor Green
Write-Host "    Cluster Profile: $Cluster ($($profData.name))" -ForegroundColor White
Write-Host "    Target Node:     $nodeName ($nodeHost | $nodeType)" -ForegroundColor White
Write-Host "    Target Container:$Container" -ForegroundColor Yellow
Write-Host "    Log Settings:    Tail=$Tail lines, Follow=$($isFollow.ToString().ToUpper()), Timestamps=$($isTimestamps.ToString().ToUpper())" -ForegroundColor DarkGray
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  (Press Ctrl+C to stop streaming at any time)" -ForegroundColor DarkGray
Write-Host ""

$flags = ""
if ($isFollow) { $flags += " -f" }
if ($isTimestamps) { $flags += " -t" }
if ($Tail -gt 0) { $flags += " --tail=$Tail" }

$finalCmd = ""
if ($Container.ToLower() -in @("all", "compose")) {
    $finalCmd = "cd ~/sowfkun-verse-infrastructure 2>/dev/null || cd /root/sowfkun-verse-infrastructure 2>/dev/null; sudo docker compose logs$flags"
} else {
    $finalCmd = @"
T="$Container"
if sudo docker inspect "`$T" >/dev/null 2>&1; then
  sudo docker logs$flags "`$T"
else
  F=`$(sudo docker ps -a --format '{{.Names}}' | grep -iE "(^|_)${Container}($|_)" | head -n 1)
  if [ -z "`$F" ]; then F=`$(sudo docker ps -a --format '{{.Names}}' | grep -i "${Container}" | head -n 1); fi
  if [ -n "`$F" ]; then
    echo "[Target auto-resolved: '$Container' -> '`$F']"
    sudo docker logs$flags "`$F"
  else
    echo "Error: No container matching '$Container' found on `$(hostname)!"
    echo "Available containers on this node:"
    sudo docker ps -a --format "   - {{.Names}} ({{.Status}})"
    exit 1
  fi
fi
"@
}

Invoke-RemoteCommand -RemoteCmd $finalCmd -Interactive
