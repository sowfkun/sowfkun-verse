param(
    [Parameter(Position = 0)]
    [string]$Cluster = "",

    [Parameter(Position = 1)]
    [string]$Node = "all"
)

if ($args.Count -ge 1 -and -not $Cluster) { $Cluster = $args[0] }
if ($args.Count -ge 2 -and ($Node -eq "all" -or -not $Node)) { $Node = $args[1] }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$toolsDir       = if ($PSScriptRoot) { $PSScriptRoot } else { "F:\Coding\Project\sowfkun.verse.v2\sowfkun-verse-infrastructure\tools" }
$rootDir        = Split-Path -Parent (Split-Path -Parent $toolsDir)
$serversDir     = if (Test-Path (Join-Path $rootDir ".servers")) { Join-Path $rootDir ".servers" } else { Join-Path $rootDir "server-test" }
$infraSourceDir = Join-Path $rootDir "sowfkun-verse-infrastructure"
$binDir         = Join-Path $rootDir "tools\bin"
if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
$archivePath    = Join-Path $binDir "infra-sync.tar.gz"

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

$profKey = if ($Cluster) { $Cluster } elseif ($config.active_profile) { $config.active_profile } else { "tailscale-dev" }
$profData = $config.profiles.$profKey
if (-not $profData) {
    Write-Host "ERROR: Cluster profile '$profKey' not found!" -ForegroundColor Red
    exit 1
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ">>> SOWFKUN INFRASTRUCTURE SYNC & SANITIZE ENGINE" -ForegroundColor Green
Write-Host "    Target Cluster: $profKey ($($profData.name))" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Package clean infrastructure archive
Write-Host "`n[1/3] Packaging clean infrastructure directory..." -ForegroundColor Cyan
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $infraSourceDir "api\app-api"), (Join-Path $infraSourceDir "gateway\app-gateway")
tar --exclude="app-api" --exclude="app-gateway" --exclude="*.exe" --exclude="*.bin" -czf $archivePath -C $infraSourceDir .
$archiveSize = (Get-Item $archivePath).Length
Write-Host "  -> Archive created: $([math]::Round($archiveSize / 1024, 2)) KB" -ForegroundColor Green

# 2. Iterate through nodes
$nodesToProcess = @()
if ($Node -eq "all" -or [string]::IsNullOrWhiteSpace($Node)) {
    $nodesToProcess = $profData.nodes.PSObject.Properties | ForEach-Object { @{ Key = $_.Name; Data = $_.Value } }
} else {
    if ($profData.nodes.$Node) {
        $nodesToProcess = @(@{ Key = $Node; Data = $profData.nodes.$Node })
    } else {
        Write-Host "ERROR: Node '$Node' not found in profile '$profKey'!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n[2/3] Synchronizing & cleaning nodes..." -ForegroundColor Cyan

foreach ($item in $nodesToProcess) {
    $nodeKey  = $item.Key
    $nodeData = $item.Data
    $ip       = $nodeData.host
    $user     = if ($nodeData.user) { $nodeData.user } else { "root" }
    $keyPath  = $nodeData.key_path

    if ($keyPath) {
        $keyPath = $keyPath.Replace('$env:USERPROFILE', $env:USERPROFILE)
        $keyPath = [System.Environment]::ExpandEnvironmentVariables($keyPath)
        if (-not [System.IO.Path]::IsPathRooted($keyPath)) {
            $keyPath = Join-Path $serversDir $keyPath
        }
    }

    Write-Host "`n>>> Processing Node: [$nodeKey] ($ip) as user '$user'..." -ForegroundColor Yellow

    $sshArgs = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=8")
    if ($keyPath -and (Test-Path $keyPath)) { $sshArgs += @("-i", $keyPath) }

    # SCP archive to /tmp/infra-sync.tar.gz
    Write-Host "  -> Uploading archive to /tmp/infra-sync.tar.gz..." -ForegroundColor DarkGray
    & scp @sshArgs $archivePath "${user}@${ip}:/tmp/infra-sync.tar.gz"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [!] SCP failed for $nodeKey ($ip). Skipping." -ForegroundColor Red
        continue
    }

    # Remote cleanup and extract
    $remoteCmd = @'
set -e
TARGET_DIR="$HOME/sowfkun-verse-infrastructure"
if [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/root/sowfkun-verse-infrastructure"
fi

echo "  -> Cleaning obsolete directories & test scripts..."
rm -rf "$HOME/infrastructure" /root/infrastructure 2>/dev/null || true
rm -f "$HOME/infra.tar.gz" /root/infra.tar.gz 2>/dev/null || true
rm -f "$HOME/clean_server1.sh" "$HOME/test_mongo.py" "$HOME/test_redis.py" 2>/dev/null || true

echo "  -> Extracting updated infrastructure to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"
tar -xzf /tmp/infra-sync.tar.gz -C "$TARGET_DIR"
find "$TARGET_DIR" -type f -name "*.sh" -exec chmod +x {} +
chmod +x "$TARGET_DIR/bootstrap.sh" 2>/dev/null || true
rm -f /tmp/infra-sync.tar.gz

echo "  -> Node synchronized successfully! Directory: $TARGET_DIR"
'@

    $remoteCmd | & ssh @sshArgs "${user}@${ip}" "bash"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Node '$nodeKey' synchronized and cleaned successfully!" -ForegroundColor Green
    } else {
        Write-Host "  [!] Error processing Node '$nodeKey'!" -ForegroundColor Red
    }
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host ">>> ALL INFRASTRUCTURE NODES SYNCHRONIZED & SANITIZED!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
