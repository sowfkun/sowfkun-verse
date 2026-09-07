# ==============================================================================
# Script: apply-airgap-cluster.ps1
# Purpose: Orchestrate True One-Way Air-Gapped DMZ across cluster nodes
# Supports: Tailscale Mesh, GCP Direct (JIT), Hybrid, and On-Premise LAN
# ==============================================================================

param (
    [string]$ProfileName = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shScript = Join-Path $scriptDir "apply_airgap_matrix.sh"
$serversJsonPath = "f:\Coding\Project\sowfkun.verse.v2\.servers\servers.json"

if (-not (Test-Path $serversJsonPath)) {
    Write-Error "Không tìm thấy file cấu hình: $serversJsonPath"
}

$serversConfig = Get-Content $serversJsonPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($ProfileName)) {
    $ProfileName = $serversConfig.active_profile
}

$profile = $serversConfig.profiles.$ProfileName
if ($null -eq $profile) {
    Write-Error "Profile '$ProfileName' không tồn tại trong servers.json!"
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "🛡️  DEPLOYING ONE-WAY AIR-GAPPED DMZ FIREWALL" -ForegroundColor Cyan
Write-Host "📌 Profile: $ProfileName ($($profile.name))" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan

# Resolve Node IPs
$mongoHost = if ($profile.nodes.mongo) { $profile.nodes.mongo.host } else { "100.70.62.111" }
$cacheHost = if ($profile.nodes.cache_mq) { $profile.nodes.cache_mq.host } else { "100.98.199.44" }
$appHost   = if ($profile.nodes.app) { $profile.nodes.app.host } else { "100.115.97.125" }
$gwHost    = if ($profile.nodes.gateway) { $profile.nodes.gateway.host } else { "100.82.253.55" }

$nodesToDeploy = @()

if ($profile.nodes.mongo) {
    $nodesToDeploy += @{ Role = "mongo"; Host = $profile.nodes.mongo.host; User = $profile.nodes.mongo.user; Key = $profile.nodes.mongo.key_path; NodeObj = $profile.nodes.mongo; Name = "MongoDB Node" }
}
if ($profile.nodes.cache_mq) {
    $nodesToDeploy += @{ Role = "cache_mq"; Host = $profile.nodes.cache_mq.host; User = $profile.nodes.cache_mq.user; Key = $profile.nodes.cache_mq.key_path; NodeObj = $profile.nodes.cache_mq; Name = "Server 1: Cache & MQ" }
}
if ($profile.nodes.app) {
    $nodesToDeploy += @{ Role = "app"; Host = $profile.nodes.app.host; User = $profile.nodes.app.user; Key = $profile.nodes.app.key_path; NodeObj = $profile.nodes.app; Name = "Server 2: Core App" }
}
if ($profile.nodes.gateway) {
    $nodesToDeploy += @{ Role = "gateway"; Host = $profile.nodes.gateway.host; User = $profile.nodes.gateway.user; Key = $profile.nodes.gateway.key_path; NodeObj = $profile.nodes.gateway; Name = "Server 3: Egress Gateway" }
}

foreach ($n in $nodesToDeploy) {
    $resolvedKey = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($n.Key)
    if ($resolvedKey -match '^\$env:USERPROFILE\\') {
        $resolvedKey = $resolvedKey -replace '^\$env:USERPROFILE', $env:USERPROFILE
    }

    Write-Host "`n🚀 Deploying to $($n.Name) ($($n.Host)) [Role: $($n.Role)]..." -ForegroundColor Yellow

    # JIT Firewall open if type is gcp_jit
    if ($n.NodeObj.type -eq "gcp_jit" -and $n.NodeObj.gcp) {
        Write-Host "🔑 Opening GCP JIT SSH Firewall for $($n.Name)..." -ForegroundColor DarkCyan
        $myPublicIp = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()
        gcloud compute firewall-rules update $n.NodeObj.gcp.ingress_rule --source-ranges="$myPublicIp/32" --project=$n.NodeObj.gcp.project --account=$n.NodeObj.gcp.account --quiet 2>$null
    }

    # 1. SCP the script
    scp -i $resolvedKey -o StrictHostKeyChecking=no $shScript "$($n.User)@$($n.Host):/tmp/apply_airgap_matrix.sh"
    
    # 2. Execute with sudo and pass the 4 resolved IPs
    ssh -i $resolvedKey -o StrictHostKeyChecking=no "$($n.User)@$($n.Host)" "chmod +x /tmp/apply_airgap_matrix.sh && sudo /tmp/apply_airgap_matrix.sh $($n.Role) $mongoHost $cacheHost $appHost $gwHost"
    
    Write-Host "✅ $($n.Name) configured successfully!" -ForegroundColor Green
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "🎉 AIR-GAPPED DMZ DEPLOYED SUCCESSFULLY FOR PROFILE [$ProfileName]!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
