# Hướng Dẫn Triển Khai Mạng Riêng Ảo Tailscale Mesh VPN

Tài liệu này hướng dẫn cách kết nối các máy chủ phân tán (Netcup, GCP, Bare-metal, On-Premise) thành một mạng riêng ảo bảo mật chuẩn **Zero-Trust** thông qua **Tailscale Mesh (WireGuard E2EE)**.

---

## 1. Mô Hình Kiến Trúc Mạng Tailscale Mesh

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        TAILSCALE MESH OVERLAY (100.64.0.0/10)                          │
│                                                                                        │
│   ┌──────────────────────────┐                               ┌─────────────────────┐   │
│   │ Server Netcup (IPv6-Only)│                               │ Server 2 (GCP - App)│   │
│   │ • Dedicated MongoDB      │◄─────────────────────────────►│ • Go API Backend    │   │
│   │   (:27017)               │        WireGuard E2EE         │   (:8080)           │   │
│   │ • TS: 100.64.0.1         │                               │ • TS: 100.64.0.3    │   │
│   └─────────────▲────────────┘                               └──────────┬──────────┘   │
│                 │                                                       │              │
│  WireGuard E2EE │                                        WireGuard E2EE │              │
│                 ▼                                                       ▼              │
│   ┌──────────────────────────┐                               ┌─────────────────────┐   │
│   │ Server 1 (GCP - Cache/MQ)│                               │ Server 3 (GCP - GW) │   │
│   │ • Redis Cache (:6379)    │◄─────────────────────────────►│ • Egress Gateway    │   │
│   │ • Redpanda / Kafka       │        WireGuard E2EE         │   (:8090)           │   │
│   │   (:9092, Console :8085) │                               │ • TS: 100.64.0.4    │   │
│   │ • TS: 100.64.0.2         │                               └─────────────────────┘   │
│   └──────────────────────────┘                                                         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Các Bước Triển Khai Từng Node Vào Cụm

### A. Node 1: Server Netcup (Dedicated MongoDB - IPv6-Only)
1. Cài Tailscale và Hardening UFW:
   ```bash
   sudo bash sowfkun-verse-infrastructure/scripts/provisioning/tailscale/01-setup-tailscale.sh --hostname=s-netcup-mongo
   ```
2. Khởi tạo MongoDB Container:
   ```bash
   sudo bash sowfkun-verse-infrastructure/bootstrap.sh --service=mongo --profile=standard --tailscale --mode=fresh
   ```

### B. Node 2: Server 1 GCP (Redis Cache & Kafka Broker Node)
1. Cài Tailscale:
   ```bash
   sudo bash sowfkun-verse-infrastructure/scripts/provisioning/tailscale/01-setup-tailscale.sh --hostname=s1-gcp-cache-mq
   ```
2. Khởi tạo Redis & Kafka:
   ```bash
   sudo bash sowfkun-verse-infrastructure/bootstrap.sh --services=redis,kafka --profile=standard --tailscale --mode=fresh
   ```

### C. Node 3: Server 2 GCP (Dedicated Go API Backend)
1. Cài Tailscale:
   ```bash
   sudo bash sowfkun-verse-infrastructure/scripts/provisioning/tailscale/01-setup-tailscale.sh --hostname=s2-gcp-app-api
   ```
2. Khởi tạo Go API:
   ```bash
   sudo bash sowfkun-verse-infrastructure/bootstrap.sh --service=api --api-mode=binary --profile=standard --tailscale --mode=fresh
   ```

### D. Node 4: Server 3 GCP (Egress Gateway Node)
1. Cài Tailscale:
   ```bash
   sudo bash sowfkun-verse-infrastructure/scripts/provisioning/tailscale/01-setup-tailscale.sh --hostname=s3-gcp-egress-gw
   ```
2. Khởi tạo Egress Gateway:
   ```bash
   sudo bash sowfkun-verse-infrastructure/bootstrap.sh --service=gateway --profile=mini --tailscale --mode=fresh
   ```

---

## 3. Mở Tunnel Kết Nối từ Máy Local

Chỉ cần chạy lệnh sau từ máy Windows phát triển:
```powershell
sowfkun infra open tailscale-dev
# hoặc:
.\sowfkun-verse-infrastructure\tools\infra-tunnel.ps1 -Action open -Profile tailscale-dev
```
Toàn bộ cổng MongoDB (`27017`), Redis (`6379`), Kafka (`9092`), Console (`8085`), Egress Gateway (`8090`) sẽ được forward an toàn về `localhost` qua đường truyền WireGuard cực nhanh mà không cần mở bất kỳ cổng public nào!

