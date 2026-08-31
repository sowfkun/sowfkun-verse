# 01. DevOps & Infrastructure Naming Standards

Đây là các "Luật Thép" về quy chuẩn đặt tên, cấu hình hạ tầng, Docker Compose, máy chủ và hệ thống giám sát (Monitoring) trong toàn bộ dự án.

---

## 1. Nguyên Tắc On-Premise First (Tuyệt Đối KHÔNG Hardcode Tên Thương Hiệu)

> **LUẬT THÉP**: Mọi cấu hình hạ tầng, Dockerfile, Docker Compose, script shell, dashboard giám sát và cấu hình agent **BẮT BUỘC** phải mang tính trung lập (Generic/On-Premise), sẵn sàng đóng gói bàn giao cho bất kỳ khách hàng doanh nghiệp nào.
>
> ❌ **TUYỆT ĐỐI CẤM**:
> - Hardcode tên thương hiệu cá nhân/nội bộ (như `sowfkun`, `sowfkun-node`, `sowfkun_promtail`, `sowfkun_monitoring`) vào file compose, script, nhãn log, hay tiêu đề dashboard.
> - Hardcode IP public, domain cá nhân hoặc mật khẩu mặc định.
>
> ✅ **BẮT BUỘC**:
> - Tất cả phải được tham số hóa qua biến môi trường kèm giá trị mặc định trung lập: `${SERVER_NAME:-app-node}`, `${LOKI_HOST:-10.20.0.2}`.

---

## 2. Quy Chuẩn Đặt Tên Docker Container & Service (Container Naming Standard)

Tất cả các container Docker khi khai báo trong `docker-compose.yml` **BẮT BUỘC** tuân thủ quy tắc phân nhóm tiền tố (Prefix-based Naming) bằng chữ thường `snake_case`:

| Tiền Tố (Prefix) | Phạm Vi Áp Dụng | Quy Tắc Đặt Tên (`container_name` & `service`) | Ví Dụ Chuẩn |
|---|---|---|---|
| **`app_*`** | Các dịch vụ ứng dụng cốt lõi & cơ sở dữ liệu nghiệp vụ | `app_<tên_dịch_vụ>` | `app_api`, `app_gateway`, `app_mongo`, `app_redis`, `app_kafka`, `app_kafka_console` |
| **`mon_*`** | Các dịch vụ thuộc trung tâm giám sát (Monitoring Hub) | `mon_<tên_công_cụ>` | `mon_loki`, `mon_grafana`, `mon_prometheus` |
| **`agent_*`** | Các agent chạy ngầm thu thập log & metrics trên từng node | `agent_<tên_agent>` | `agent_promtail`, `agent_node_exporter` |

- **Docker Compose Project Name (`name: ...`)**:
  - Hub: `name: mon_hub`
  - Agent: `name: mon_agent`
  - Core App Stack: `name: app_stack`
  - Data Stack: `name: data_stack`

---

## 3. Quy Chuẩn Đặt Tên Máy Chủ & Nhãn Metrics (Server Node Labeling)

Khi gắn nhãn định danh máy chủ (`server` label trong Prometheus & Promtail):

| Vai Trò Máy Chủ | Nhãn Chuẩn (Prometheus / Promtail) | Fallback Biến Môi Trường |
|---|---|---|
| **Cụm Dữ Liệu (Database Cluster)** | `DATA-NODE-01` | `${SERVER_NAME:-data-node-01}` |
| **Cụm Ứng Dụng (App & Hub Cluster)** | `APP-NODE-02` | `${SERVER_NAME:-app-node-02}` |
| **Cụm Cửa Ngõ (Egress Gateway Node)** | `GATEWAY-NODE-03` | `${SERVER_NAME:-gateway-node-03}` |

---

## 4. Quy Chuẩn Đặt Tên Dashboard & Thư Mục Giám Sát (Grafana & Loki)

1. **Thư Mục Dashboard (Folder Provisioning)**:
   - Dùng tên trung lập: `folder: 'Infrastructure Overview'` hoặc `folder: 'System Observability'` (cấm `folder: 'Sowfkun Infrastructure'`).
2. **Tiêu Đề Dashboard (`title`)**:
   - `title: "Infrastructure & Container Observability"`
   - `uid: "infra-overview"`
3. **Thẻ Phân Loại (`tags`)**:
   - `tags: ["infrastructure", "observability", "mongodb", "logs", "metrics"]`

---

## 5. Quy Chuẩn Mạng Docker & Volume Lưu Trữ (Network & Volume Standards)

1. **Docker Network**:
   - Toàn bộ container giao tiếp nội bộ qua mạng `app_net` (driver: `bridge`, `external: true`).
2. **Docker Volumes (Dữ liệu bền vững)**:
   - Dùng named volumes dạng `<service>_data`: `mongo_data`, `redis_data`, `loki_data`, `prometheus_data`, `grafana_data`.
   - Mount host log phải luôn ở chế độ chỉ đọc (`:ro`):
     - `/var/lib/docker/containers:/var/lib/docker/containers:ro`
     - `/var/run/docker.sock:/var/run/docker.sock:ro`
     - `/var/log:/var/log:ro`
