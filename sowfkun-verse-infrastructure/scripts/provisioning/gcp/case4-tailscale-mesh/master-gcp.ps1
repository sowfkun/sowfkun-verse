# ==============================================================================
# CASE 4: GCP TAILSCALE MESH MASTER CONTROLLER (POWERSHELL FOR WINDOWS)
# ==============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Show-Banner {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "🌐 CASE 4: GCP TAILSCALE MESH PROVISIONER & MASTER CONTROLLER" -ForegroundColor Green
    Write-Host "    Mo hinh 4 Server Zero-Trust: Netcup (Mongo) + 3 GCP Nodes" -ForegroundColor DarkGray
    Write-Host "=================================================================" -ForegroundColor Cyan
}

function Show-Menu {
    Show-Banner
    Write-Host ""
    Write-Host "Chon tac vu muon thuc hien:" -ForegroundColor Yellow
    Write-Host "  [1] Ap dung Firewall Tailscale Zero-Trust tren GCP   (01-apply-tailscale-firewalls.sh)" -ForegroundColor White
    Write-Host "  [2] Cai dat & Khoi chay Tailscale Node tren GCP VM   (02-setup-tailscale-node.sh)" -ForegroundColor White
    Write-Host "  [3] Kiem toan An ninh & Do tre Mesh (Audit)          (03-audit-security.sh)" -ForegroundColor White
    Write-Host "  [4] Reset & Don dep Firewall Rules cu tren GCP       (reset-firewalls.sh)" -ForegroundColor DarkYellow
    Write-Host "  [5] Thoat" -ForegroundColor Gray
    Write-Host ""
    $choice = Read-Host "Nhap lua chon [1-5]"

    switch ($choice) {
        "1" {
            Write-Host "`n>>> Dang chay 01-apply-tailscale-firewalls.sh..." -ForegroundColor Cyan
            bash "$scriptDir/01-apply-tailscale-firewalls.sh"
        }
        "2" {
            Write-Host "`n>>> Dang chay 02-setup-tailscale-node.sh..." -ForegroundColor Cyan
            bash "$scriptDir/02-setup-tailscale-node.sh"
        }
        "3" {
            Write-Host "`n>>> Dang chay 03-audit-security.sh..." -ForegroundColor Cyan
            bash "$scriptDir/03-audit-security.sh"
        }
        "4" {
            Write-Host "`n>>> Dang chay reset-firewalls.sh..." -ForegroundColor Yellow
            bash "$scriptDir/reset-firewalls.sh"
        }
        Default {
            Write-Host "Tam biet!" -ForegroundColor Gray
            exit 0
        }
    }
}

Show-Menu
