param(
    [Parameter(Position = 0)]
    [string]$Cluster = "",

    [Parameter(Position = 1)]
    [string]$Node = "mongo"
)

if ($args.Count -ge 1 -and -not $Cluster) { $Cluster = $args[0] }
if ($args.Count -ge 2 -and ($Node -eq "mongo" -or -not $Node)) { $Node = $args[1] }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$toolsDir      = if ($PSScriptRoot) { $PSScriptRoot } else { "F:\Coding\Project\sowfkun.verse.v2\sowfkun-verse-infrastructure\tools" }
$rootDir       = Split-Path -Parent (Split-Path -Parent $toolsDir)
$serversDir    = if (Test-Path (Join-Path $rootDir ".servers")) { Join-Path $rootDir ".servers" } else { Join-Path $rootDir "server-test" }
$serverTestDir = $serversDir
$src           = Join-Path $rootDir "sowfkun-verse-infrastructure\bootstrap.sh"

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

$profKey = if ($Cluster) { $Cluster } elseif ($config.active_profile) { $config.active_profile } else { "tailscale" }
$profData = $config.profiles.$profKey
if (-not $profData) {
    Write-Host "ERROR: Cluster profile '$profKey' not found!" -ForegroundColor Red
    exit 1
}

$targetNode = $profData.nodes.$Node
if (-not $targetNode) {
    Write-Host "ERROR: Node '$Node' not found in cluster '$profKey'!" -ForegroundColor Red
    exit 1
}

$ip       = $targetNode.host
$nodeUser = if ($targetNode.user) { $targetNode.user } else { "root" }
$keyPath  = $targetNode.key_path
if ($keyPath) {
    $keyPath = $keyPath.Replace('$env:USERPROFILE', $env:USERPROFILE)
    $keyPath = [System.Environment]::ExpandEnvironmentVariables($keyPath)
    if (-not [System.IO.Path]::IsPathRooted($keyPath)) {
        $keyPath = Join-Path $serverTestDir $keyPath
    }
}

Write-Host "Updating bootstrap.sh on Node '$Node' ($ip) for cluster '$profKey'..." -ForegroundColor Cyan

$bytes = [System.IO.File]::ReadAllBytes($src)
$b64 = [Convert]::ToBase64String($bytes)

# Split b64 into 4000-char chunks to avoid Windows line-length limits
$chunks = [regex]::Matches($b64, ".{1,4000}") | ForEach-Object { $_.Value }

$sshArgs = @("-o", "StrictHostKeyChecking=no")
if ($keyPath -and (Test-Path $keyPath)) { $sshArgs += @("-i", $keyPath) }

& ssh @sshArgs "${nodeUser}@${ip}" "rm -f /tmp/bootstrap.b64"

foreach ($c in $chunks) {
    & ssh @sshArgs "${nodeUser}@${ip}" "printf '%s' '$c' >> /tmp/bootstrap.b64"
}

& ssh @sshArgs "${nodeUser}@${ip}" "base64 -d /tmp/bootstrap.b64 > /root/sowfkun-verse-infrastructure/bootstrap.sh 2>/dev/null || base64 -d /tmp/bootstrap.b64 > ~/sowfkun-verse-infrastructure/bootstrap.sh 2>/dev/null || base64 -d /tmp/bootstrap.b64 > /root/infrastructure/bootstrap.sh && chmod +x /root/sowfkun-verse-infrastructure/bootstrap.sh 2>/dev/null || chmod +x ~/sowfkun-verse-infrastructure/bootstrap.sh 2>/dev/null || chmod +x /root/infrastructure/bootstrap.sh && rm -f /tmp/bootstrap.b64"

Write-Host "Bootstrap updated successfully on $ip!" -ForegroundColor Green
