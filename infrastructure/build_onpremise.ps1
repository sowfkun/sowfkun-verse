# ==============================================================================
# Script đóng gói On-Premise Binary tĩnh cho Linux (AMD64) trên PowerShell Windows
# ==============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "🔨 Đang biên dịch Go Backend API thành Binary tĩnh cho On-Premise..." -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

Set-Location "$RootDir\sowfkun-verse-api"

$env:CGO_ENABLED = "0"
$env:GOOS = "linux"
$env:GOARCH = "amd64"

go build -ldflags="-s -w -extldflags -static" -o "$RootDir\infrastructure\api\app-api" ./cmd/api

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "🎉 ĐÓNG GÓI ON-PREMISE BINARY THÀNH CÔNG!" -ForegroundColor Green
Write-Host "👉 File binary: infrastructure\api\app-api" -ForegroundColor Yellow
Write-Host "👉 Bạn chỉ cần copy toàn bộ thư mục [infrastructure\] và file [.env] đi bàn giao On-Premise." -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Green
