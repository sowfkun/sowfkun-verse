# ==============================================================================
# Script đóng gói On-Premise Binary tĩnh cho Linux (AMD64) trên Windows PowerShell
# ==============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path "$ScriptDir\..\..\.."

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "🔨 Đang biên dịch Go Backend API va Egress Gateway thanh Linux Binary tinh..." -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan

Set-Location "$RootDir\sowfkun-verse-api"

$env:CGO_ENABLED = "0"
$env:GOOS = "linux"
$env:GOARCH = "amd64"

# 1. Build Core API
go build --ldflags="-s -w" -o "$RootDir\sowfkun-verse-infrastructure\api\app-api" ./cmd/api

# 2. Build Egress Gateway
go build --ldflags="-s -w" -o "$RootDir\sowfkun-verse-infrastructure\gateway\app-gateway" ./cmd/gateway

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "🎉 ĐÓNG GÓI ON-PREMISE BINARY THÀNH CÔNG!" -ForegroundColor Green
Write-Host "👉 File binary API:     sowfkun-verse-infrastructure/api/app-api" -ForegroundColor White
Write-Host "👉 File binary Gateway: sowfkun-verse-infrastructure/gateway/app-gateway" -ForegroundColor White
Write-Host "👉 Bạn chỉ cần copy toàn bộ thư mục [sowfkun-verse-infrastructure/] và file [.env] đi bàn giao On-Premise." -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Green
