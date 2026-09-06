# Case 4: Multi-Cloud Tailscale Mesh Architecture (Netcup Mongo + 3 GCP Nodes)

## 📌 Tổng quan Kiến trúc
**Case 4** là mô hình mạng tối tân nhất của dự án **sowfkun.verse.v2**, thay thế toàn bộ mô hình VPC Peering phức tạp (Case 3) bằng **Mạng phủ mã hóa đầu cuối Tailscale WireGuard Mesh (E2EE)**.

### 4 Node trong cụm hệ thống:
1. **Server Netcup (IPv6-Only)**: Dedicated MongoDB Replica Set (`<TAILSCALE_IP_MONGO>:27017`).
2. **Server 1 (GCP `sowfkun-dev`)**: Redis Cache (`:6379`), Redpanda Kafka (`:9092`, Web Console `:8085`), Loki (`:3100`).
3. **Server 2 (GCP `sowfkun-dev-api`)**: Go API Backend (`:8080`).
4. **Server 3 (GCP `sowfkun-dev-egress-gateway`)**: Egress Gateway (`:8090`).

---

## 🚀 Điểm đột phá so với Case 3 (VPC Peering)
- ❌ **Không cần tạo VPC Peering**: Loại bỏ hoàn toàn 6 đường Peering chéo giữa các Google Account.
- ❌ **Không phụ thuộc dải IP Private**: Không cần chia `10.10.0.0/24`, `10.20.0.0/24`, `10.30.0.0/24`.
- ❌ **Không cần JIT SSH mở/đóng thủ công**: SSH an toàn 24/7 qua giao thức Tailscale SSH / Google IAP.
- 🌐 **Đa đám mây thực thụ (Multi-Cloud)**: Kết nối thông suốt Server Netcup (Đức) và 3 Server GCP (Mỹ) với độ trễ tối ưu nhất qua WireGuard.

---

## 📂 Danh mục Scripts

| Script | Chức năng |
|---|---|
| [`01-apply-tailscale-firewalls.sh`](file:///f:/Coding/Project/sowfkun.verse.v2/sowfkun-verse-infrastructure/scripts/provisioning/gcp/case4-tailscale-mesh/01-apply-tailscale-firewalls.sh) | Thiết lập bộ quy tắc tường lửa Zero-Trust trên GCP VPC cho từng Server. |
| [`02-setup-tailscale-node.sh`](file:///f:/Coding/Project/sowfkun.verse.v2/sowfkun-verse-infrastructure/scripts/provisioning/gcp/case4-tailscale-mesh/02-setup-tailscale-node.sh) | Cài đặt Tailscale, đặt hostname, bật IP forwarding & join vào Tailnet. |
| [`03-audit-security.sh`](file:///f:/Coding/Project/sowfkun.verse.v2/sowfkun-verse-infrastructure/scripts/provisioning/gcp/case4-tailscale-mesh/03-audit-security.sh) | Tự động kiểm toán kết nối Mesh, độ trễ và cô lập cổng. |
| [`reset-firewalls.sh`](file:///f:/Coding/Project/sowfkun.verse.v2/sowfkun-verse-infrastructure/scripts/provisioning/gcp/case4-tailscale-mesh/reset-firewalls.sh) | *(Tiện ích độc lập)* Quét và xóa sạch các firewall rule cũ của Case 3 khi cần. |
| [`master-gcp.ps1`](file:///f:/Coding/Project/sowfkun.verse.v2/sowfkun-verse-infrastructure/scripts/provisioning/gcp/case4-tailscale-mesh/master-gcp.ps1) / [`.sh`](file:///f:/Coding/Project/sowfkun.verse.v2/sowfkun-verse-infrastructure/scripts/provisioning/gcp/case4-tailscale-mesh/master-gcp.sh) | Menu điều phối 1-click chọn tác vụ từ A-Z. |

---

## 🛠️ Quy trình Triển khai

### Bước 1: Dọn dẹp Firewall Rules cũ (Nếu cần)
```bash
bash reset-firewalls.sh
```

### Bước 2: Thiết lập Firewall Rules cho Tailscale Mesh
Chạy trên từng Google Account cho Server tương ứng:
```bash
bash 01-apply-tailscale-firewalls.sh
```

### Bước 3: Cài đặt Tailscale trên từng Server GCP
SSH vào từng Server (hoặc qua Google IAP) và chạy:
```bash
sudo bash 02-setup-tailscale-node.sh
```

### Bước 4: Kiểm tra & Cập nhật Topology
- Chạy `03-audit-security.sh` để kiểm tra thông suốt tới Netcup Mongo node.
- Cập nhật IP Tailscale thật vào profile `tailscale-dev` trong [`.servers/servers.json`](file:///f:/Coding/Project/sowfkun.verse.v2/.servers/servers.json) (hoặc copy từ [`servers.example.json`](file:///f:/Coding/Project/sowfkun.verse.v2/sowfkun-verse-infrastructure/tools/servers.example.json)).

