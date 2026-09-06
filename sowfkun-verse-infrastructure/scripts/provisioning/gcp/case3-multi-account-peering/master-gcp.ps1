# ==============================================================================
# GCP MULTI-ACCOUNT MASTER CONTROL CENTER (POWERSHELL ALL-IN-ONE)
# ==============================================================================

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "GCP MULTI-ACCOUNT MASTER CONTROL CENTER (POWERSHELL)" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan

# 0. Quet danh sach tai khoan
Write-Host ""
Write-Host "[BUOC 0] XAC DINH TAI KHOAN GOOGLE CLOUD:" -ForegroundColor Yellow
$accounts = gcloud auth list --format="value(account)" 2>$null

if ($accounts) {
    Write-Host "Danh sach tai khoan da dang nhap tren may:"
    $i = 1
    $accMap = @{}
    foreach ($acc in $accounts) {
        Write-Host "  [$i] $acc"
        $accMap[$i] = $acc
        $i++
    }
    Write-Host "  [$i] Dang nhap tai khoan Google khac"
    $accChoice = Read-Host "Chon tai khoan [1-$i, Mac dinh: 1]"
    if ([string]::IsNullOrEmpty($accChoice)) { $accChoice = 1 }

    if ([int]$accChoice -eq $i -or -not $accMap[[int]$accChoice]) {
        gcloud auth login
    } else {
        $selectedAcc = $accMap[[int]$accChoice]
        gcloud config set account $selectedAcc 2>$null | Out-Null
    }
}

$activeAcc = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
Write-Host "Dang thao tac voi tai khoan: [ $activeAcc ]" -ForegroundColor Green

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "BANG DIEU KHIEN TRUNG TAM (CHON TAC VU CAN THUC HIEN):" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  [1] Mo Google IAP SSH Truc Tiep Vao May Chu  (Instant Shell)" -ForegroundColor Green
Write-Host "  [2] Mo Duong Ham IAP Tunnel (Port Forwarding)" -ForegroundColor Green
Write-Host "  [3] Chay Bo Script Khoi Tao Ha Tang Mang (01-05 qua Git Bash)"
Write-Host "  [0] Thoat"
Write-Host "=================================================================" -ForegroundColor Cyan

$choice = Read-Host "Nhap lua chon [0-3, Mac dinh: 1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "DANH SACH MAY AO TRONG PROJECT HIEN TAI:" -ForegroundColor Yellow
        $vms = gcloud compute instances list --format="value(name,zone)" 2>$null
        if (-not $vms) {
            Write-Host "Khong tim thay may ao nao!" -ForegroundColor Red
            break
        }
        $i = 1
        $vmMap = @{}
        $zoneMap = @{}
        foreach ($line in $vms) {
            $parts = $line -split "\t"
            $vn = $parts[0]
            $vz = $parts[1]
            Write-Host "  [$i] $vn (Zone: $vz)"
            $vmMap[$i] = $vn
            $zoneMap[$i] = $vz
            $i++
        }
        $vchoice = Read-Host "Chon may can SSH [1-$($i-1), Mac dinh: 1]"
        if ([string]::IsNullOrEmpty($vchoice)) { $vchoice = 1 }
        $selVM = $vmMap[[int]$vchoice]
        $selZone = $zoneMap[[int]$vchoice]
        Write-Host "Dang mo ket noi SSH qua Google IAP vao $selVM..." -ForegroundColor Green
        gcloud compute ssh $selVM --zone=$selZone --tunnel-through-iap
    }
    "2" {
        $tunnelVM = Read-Host "Nhap ten may ao"
        $tunnelPort = Read-Host "Nhap cong can mo tunnel (vi du: 27017, 6379, 8085)"
        $tunnelZone = Read-Host "Nhap Zone [Mac dinh: us-central1-a]"
        if ([string]::IsNullOrEmpty($tunnelZone)) { $tunnelZone = "us-central1-a" }
        Write-Host "Dang mo IAP Tunnel toi [$tunnelVM : $tunnelPort] -> localhost:$tunnelPort..." -ForegroundColor Green
        gcloud compute start-iap-tunnel $tunnelVM $tunnelPort --local-host-port="localhost:$tunnelPort" --zone=$tunnelZone
    }
    "3" {
        Write-Host "Vui long chay qua Git Bash: bash sowfkun-verse-infrastructure/scripts/provisioning/gcp/case3-multi-account-peering/master-gcp.sh" -ForegroundColor Yellow
    }
    "0" {
        Write-Host "Tam biet!" -ForegroundColor Green
        exit 0
    }
}
