# 🏢 On-Premise & Bare-Metal Multi-Server Architecture

Thư mục này hướng dẫn cấu hình hạ tầng cho môi trường **On-Premise (Máy chủ vật lý / Private Cloud / Proxmox / VMware)**.

---

## 1. Nguyên Tắc Phân Tách Mạng Vật Lý (VLAN & Subnet Isolation)

* **VLAN 10 (Data Network)**: Dải mạng nội bộ riêng cho máy chủ dữ liệu (MongoDB, Redis, Kafka, OpenSearch).
  * Gateway chặn toàn bộ định tuyến ra Router Internet (No WAN Gateway).
  * Chỉ cho phép kết nối từ VLAN 20 trên các port cụ thể.
* **VLAN 20 (App & DMZ Network)**: Dải mạng cho máy chủ API và Web tiếp nhận kết nối bên ngoài.

---

## 2. Hardening Với UFW & IPTables Nội Bộ

Trên máy chủ vật lý, sử dụng:
1. `infrastructure/scripts/provisioning/common/os-hardening.sh`: Khóa SSH Password, tắt Root login, tune sysctl.
2. Cấu hình UFW Firewall nội bộ:
   ```bash
   sudo ufw default deny incoming
   sudo ufw default deny outgoing # Trên Data Node
   sudo ufw allow in on eth0 to any port 27017 proto tcp from 192.168.20.0/24
   sudo ufw allow in on eth0 to any port 6379 proto tcp from 192.168.20.0/24
   sudo ufw enable
   ```
