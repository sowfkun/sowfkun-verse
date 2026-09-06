param(
    [Parameter(Position = 0)]
    [string]$Cluster = "",

    [Parameter(Position = 1)]
    [string]$TargetEnv = "dev"
)

if ($args.Count -ge 1 -and -not $Cluster) { $Cluster = $args[0] }
if ($args.Count -ge 2 -and ($TargetEnv -eq "dev" -or -not $TargetEnv)) { $TargetEnv = $args[1] }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$toolsDir      = if ($PSScriptRoot) { $PSScriptRoot } else { "F:\Coding\Project\sowfkun.verse.v2\sowfkun-verse-infrastructure\tools" }
$rootDir       = Split-Path -Parent (Split-Path -Parent $toolsDir)
$apiDir        = Join-Path $rootDir "sowfkun-verse-api"
$serversDir    = if (Test-Path (Join-Path $rootDir ".servers")) { Join-Path $rootDir ".servers" } else { Join-Path $rootDir "server-test" }
$serverTestDir = $serversDir
$binDir        = Join-Path $serversDir "bin"
$binFile       = Join-Path $binDir "app-gateway"

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
    exit 1
}

$rawJson = Get-Content -Path $configFile -Raw -Encoding UTF8
$config  = $rawJson | ConvertFrom-Json

# Resolve Cluster Profile
$profKey = if ($Cluster) { $Cluster } elseif ($config.active_profile) { $config.active_profile } else { "tailscale" }
$profData = $config.profiles.$profKey
if (-not $profData) {
    Write-Host "ERROR: Cluster profile '$profKey' not found in $configFile!" -ForegroundColor Red
    Write-Host "Available profiles: $(($config.profiles.PSObject.Properties.Name) -join ', ')" -ForegroundColor Yellow
    exit 1
}

$gwNode = $profData.nodes.gateway
if (-not $gwNode) {
    Write-Host "ERROR: No 'gateway' node found in cluster profile '$profKey'!" -ForegroundColor Red
    exit 1
}

$nodeHost = $gwNode.host
$nodeUser = if ($gwNode.user) { $gwNode.user } else { "root" }
$nodeType = $gwNode.type
$nodeName = if ($gwNode.name) { $gwNode.name } else { "Egress Gateway Server" }

# Resolve SSH Key
$keyPath = $gwNode.key_path
if ($keyPath) {
    $keyPath = $keyPath.Replace('$env:USERPROFILE', $env:USERPROFILE)
    $keyPath = [System.Environment]::ExpandEnvironmentVariables($keyPath)
    if (-not [System.IO.Path]::IsPathRooted($keyPath)) {
        $keyPath = Join-Path $serverTestDir $keyPath
    }
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "🛰️ SOWFKUN VERSE - DEPLOY EGRESS GATEWAY" -ForegroundColor Green
Write-Host "  Cluster Profile: $profKey ($($profData.name))" -ForegroundColor White
Write-Host "  Target Node:     $nodeName ($nodeHost | $nodeType)" -ForegroundColor White
Write-Host "  Target Env:      $TargetEnv" -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan

# 2. Cross-Compile Linux AMD64 Binary Locally
Write-Host ""
Write-Host '[1/4] Compiling Egress Gateway binary (Linux AMD64 Static)...' -ForegroundColor Yellow
if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }

Push-Location $apiDir
$env:CGO_ENABLED = "0"
$env:GOOS = "linux"
$env:GOARCH = "amd64"
go build -ldflags="-s -w -extldflags '-static'" -o "$binFile" ./cmd/gateway
$buildSuccess = $?
Pop-Location

if (-not $buildSuccess -or -not (Test-Path $binFile)) {
    Write-Host "ERROR: Egress Gateway binary compilation failed!" -ForegroundColor Red
    exit 1
}

$fileSize = (Get-Item $binFile).Length / 1MB
Write-Host "  -> Compilation successful! Binary size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green

# 3. Upload Binary to Target Node
Write-Host ""
Write-Host "[2/4] Uploading binary to $nodeHost..." -ForegroundColor Yellow

$remoteNewPath = "/tmp/app-gateway-new"
$scpSuccess = $false

if ($nodeType -eq "tailscale" -or ($keyPath -and (Test-Path $keyPath))) {
    $scpArgs = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10")
    if ($keyPath -and (Test-Path $keyPath)) { $scpArgs += @("-i", $keyPath) }
    $scpArgs += @($binFile, "${nodeUser}@${nodeHost}:${remoteNewPath}")
    & scp @scpArgs
    $scpSuccess = ($LASTEXITCODE -eq 0)
}

if (-not $scpSuccess -and $gwNode.gcp) {
    # Fallback to gcloud IAP SCP
    $vmName = if ($gwNode.gcp.vm_name) { $gwNode.gcp.vm_name } else { $nodeHost }
    $gcpProject = $gwNode.gcp.project
    $gcpAccount = $gwNode.gcp.account
    $gcpZone = if ($gwNode.gcp.zone) { $gwNode.gcp.zone } else { "us-central1-a" }
    
    Write-Host "  -> Attempting upload via Google IAP Tunnel ($vmName)..." -ForegroundColor Cyan
    & gcloud compute scp "$binFile" "${vmName}:${remoteNewPath}" --zone=$gcpZone --project=$gcpProject --account=$gcpAccount --tunnel-through-iap --compress --quiet
    $scpSuccess = ($LASTEXITCODE -eq 0)
}

if (-not $scpSuccess) {
    Write-Host "ERROR: Binary upload to server failed!" -ForegroundColor Red
    exit 1
}
Write-Host "  -> Upload completed successfully!" -ForegroundColor Green

# 4. Hot-swap Binary and Restart Gateway Container
Write-Host ""
Write-Host "[3/4] Hot-swapping binary and recreating Gateway container..." -ForegroundColor Yellow

$remoteCmd = "chmod +x /tmp/app-gateway-new && " +
             "(sudo mv -f /tmp/app-gateway-new /root/sowfkun-verse-infrastructure/gateway/app-gateway 2>/dev/null || sudo mv -f /tmp/app-gateway-new ~/sowfkun-verse-infrastructure/gateway/app-gateway 2>/dev/null || sudo mv -f /tmp/app-gateway-new ~/infrastructure/gateway/app-gateway 2>/dev/null || sudo mv -f /tmp/app-gateway-new /root/infrastructure/gateway/app-gateway) && " +
             "(cd /root/sowfkun-verse-infrastructure/gateway 2>/dev/null || cd ~/sowfkun-verse-infrastructure/gateway 2>/dev/null || cd ~/infrastructure/gateway 2>/dev/null || cd /root/infrastructure/gateway) && " +
             "sudo docker compose up -d --force-recreate gateway"

if ($nodeType -eq "tailscale" -or ($keyPath -and (Test-Path $keyPath))) {
    $sshArgs = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10")
    if ($keyPath -and (Test-Path $keyPath)) { $sshArgs += @("-i", $keyPath) }
    $sshArgs += @("${nodeUser}@${nodeHost}", $remoteCmd)
    & ssh @sshArgs
} else {
    $vmName = if ($gwNode.gcp.vm_name) { $gwNode.gcp.vm_name } else { $nodeHost }
    $gcpProject = $gwNode.gcp.project
    $gcpAccount = $gwNode.gcp.account
    $gcpZone = if ($gwNode.gcp.zone) { $gwNode.gcp.zone } else { "us-central1-a" }
    & gcloud compute ssh $vmName --zone=$gcpZone --project=$gcpProject --account=$gcpAccount --tunnel-through-iap --command=$remoteCmd --quiet
}

# 5. Automated Health Check Verification
Write-Host ""
Write-Host '[4/4] Verifying Gateway Health check (:8090/healthz)...' -ForegroundColor Yellow
$healthCmd = "for i in 1 2 3 4 5 6 7 8 9 10; do if curl -s -f http://localhost:8090/healthz > /dev/null 2>&1; then echo 'SUCCESS_HEALTHY'; exit 0; fi; sleep 2; done; echo 'FAILED'"

$healthRes = ""
if ($nodeType -eq "tailscale" -or ($keyPath -and (Test-Path $keyPath))) {
    $sshArgs = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10")
    if ($keyPath -and (Test-Path $keyPath)) { $sshArgs += @("-i", $keyPath) }
    $sshArgs += @("${nodeUser}@${nodeHost}", $healthCmd)
    $healthRes = & ssh @sshArgs
} else {
    $vmName = if ($gwNode.gcp.vm_name) { $gwNode.gcp.vm_name } else { $nodeHost }
    $gcpProject = $gwNode.gcp.project
    $gcpAccount = $gwNode.gcp.account
    $gcpZone = if ($gwNode.gcp.zone) { $gwNode.gcp.zone } else { "us-central1-a" }
    $healthRes = & gcloud compute ssh $vmName --zone=$gcpZone --project=$gcpProject --account=$gcpAccount --tunnel-through-iap --command=$healthCmd --quiet
}

if ($healthRes -match "SUCCESS_HEALTHY") {
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "SUCCESS: EGRESS GATEWAY DEPLOYED TO $nodeName ($nodeHost) IN 15 SECONDS!" -ForegroundColor Green
    Write-Host "  Profile:   $profKey" -ForegroundColor Cyan
    Write-Host "  Endpoint:  http://$nodeHost:8090/api/v1/egress/http" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Green
} else {
    Write-Host "Warning: Container restarted but health check response timed out." -ForegroundColor Yellow
}
