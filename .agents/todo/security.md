Kiến Trúc Hạ Tầng & Bảo Mật: Core Server & Hook Dispatcher
1. Sơ Đồ Tổng Quan
• Server Core (10.128.0.2): Quản lý State, Database, Redis, Kafka Core. Chặn hoàn toàn Internet (EGRESS DENY 0.0.0.0/0), không có Service Account.
• Server Hook (10.128.0.3): Stateless Egress Proxy. Nhận HTTP từ Core bắn Webhook ra Internet qua Cloud NAT. Không có Service Account, chặn truy cập metadata GCP.
[CLIENT / INTERNET]
│
▼ (Port 8080)
┌─────────────────────────────────────────────────────────────┐
│ SERVER CORE (10.128.0.2) - No SA │
│ - Egress: DENY ALL (0.0.0.0/0) │
│ │
│ [API] ──► [Kafka Topic: webhooks] │
│ │ │
│ Worker lấy job │
│ (HTTP Keep-Alive, Timeout: 3.5s) │
└─────────────────┼───────────────────────────────────────────┘
│
│ TCP Port 8080 (Mạng nội bộ VPC)
│ (Firewall: ALLOW Core -> Hook | DENY Hook -> Core)
▼
┌─────────────────────────────────────────────────────────────┐
│ SERVER HOOK (10.128.0.3) - No SA │
│ - Chặn Metadata 169.254.169.254 │
│ - Có Cloud NAT ra Internet │
│ │
│ Dispatcher API (Timeout: 2.5s) ──(HTTP POST)──► [ĐỐI TÁC] │
│ │ │ │
│ └── Trả response/status ngược về Core ────────┘ │
└─────────────────────────────────────────────────────────────┘
───
2. Phase 1: Tạo Hạ Tầng & Khóa Mạng (Chạy trên Local / Cloud Shell)
A. Tạo 2 VM Không Gắn Service Account
gcloud compute instances create core-server 
 --zone=asia-southeast1-a 
 --machine-type=e2-standard-2 
 --no-address 
 --tags=core-backend 
 --no-service-account 
 --no-scopes 
 --metadata=disable-legacy-endpoints=true
gcloud compute instances create hook-server 
 --zone=asia-southeast1-a 
 --machine-type=e2-small 
 --no-address 
 --tags=hook-worker 
 --no-service-account 
 --no-scopes 
 --metadata=disable-legacy-endpoints=true
B. Cấu Hình Tường Lửa GCP (Firewall Rules)
1. Cho phép Core gọi sang Dispatcher trên Hook (Port 8080)
gcloud compute firewall-rules create allow-core-to-hook 
 --network=default 
 --action=ALLOW 
 --direction=INGRESS 
 --source-tags=core-backend 
 --target-tags=hook-worker 
 --rules=tcp:8080 
 --priority=1000
2. Chặn toàn bộ kết nối từ Hook quay ngược vào Core
gcloud compute firewall-rules create deny-hook-to-core 
 --network=default 
 --action=DENY 
 --direction=INGRESS 
 --source-tags=hook-worker 
 --target-tags=core-backend 
 --rules=all 
 --priority=500
3. Cấm Core Server tự ý kết nối ra ngoài Internet (Chống Reverse Shell)
gcloud compute firewall-rules create deny-core-egress-internet 
 --network=default 
 --action=DENY 
 --direction=EGRESS 
 --target-tags=core-backend 
 --destination-ranges=0.0.0.0/0 
 --priority=1000
4. Mở dải Google IAP để SSH và xem Dashboard Monitoring an toàn
gcloud compute firewall-rules create allow-iap-ingress 
 --network=default 
 --action=ALLOW 
 --direction=INGRESS 
 --source-ranges=35.235.240.0/20 
 --rules=tcp:22,tcp:3000 
 --priority=1000
───
3. Phase 2: Cấu Hình Bên Trong Server (OS & Services)
A. Hardening Trên Server Hook (Chặn SSRF lấy Token)
Chạy trong bash của Hook Server:
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get install -y iptables-persistent
sudo iptables -A OUTPUT -d 169.254.169.254 -j DROP
sudo netfilter-persistent save
B. Code Mẫu Dispatcher API (Chạy trên Server Hook - Node.js)
// File: dispatcher.js
const express = require('express');
const axios = require('axios');
const app = express();
app.use(express.json());
// Timeout gọi ra đối tác: tối đa 2.5s
const partnerClient = axios.create({ timeout: 2500 });
app.post('/dispatch', async (req, res) => {
const { webhook_url, payload, idempotency_key } = req.body;
try {
const response = await partnerClient.post(webhook_url, payload, {
headers: { 'X-Idempotency-Key': idempotency_key }
});
return res.status(200).json({ status: 'SUCCESS', http_code: response.status });
} catch (error) {
const status_code = error.response ? error.response.status : 504;
return res.status(200).json({ status: 'FAILED', http_code: status_code, message: error.message });
}
});
app.listen(8080, '0.0.0.0', () => console.log('Dispatcher listening on 8080'));
C. Code Mẫu Worker Trên Server Core (HTTP Keep-Alive + Timeout)
// File: worker.js
const http = require('http');
const axios = require('axios');
// Tái sử dụng socket TCP, tránh cạn port
const hookClient = axios.create({
baseURL: 'http://10.128.0.3:8080',
timeout: 3500, // Timeout dài hơn Hook (3.5s > 2.5s)
httpAgent: new http.Agent({
keepAlive: true,
maxSockets: 100,
maxFreeSockets: 10,
timeout: 60000,
}),
});
async function processWebhookJob(job) {
try {
const res = await hookClient.post('/dispatch', {
webhook_url: job.target_url,
payload: job.data,
idempotency_key: job.id,
});
if (res.data.status === 'SUCCESS') {
await updateDbStatus(job.id, 'SUCCESS');
} else {
await pushToRetryTopic(job);
}
} catch (err) {
// Lỗi mạng hoặc quá 3.5s
await pushToRetryTopic(job);
}
}
───
4. Cụm Giám Sát Tài Nguyên Nội Bộ (Monitoring Trên Server Core)
File: docker-compose.monitoring.yml
version: '3.8'
services:
cadvisor:
image: gcr.io/cadvisor/cadvisor:latest
container_name: cadvisor
restart: unless-stopped
volumes:
- /:/rootfs:ro
- /var/run:/var/run:ro
- /sys:/sys:ro
- /var/lib/docker/:/var/lib/docker:ro
expose:
- 8080
prometheus:
image: prom/prometheus:latest
container_name: prometheus
restart: unless-stopped
volumes:
- ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
- prometheus_data:/prometheus
expose:
- 9090
grafana:
image: grafana/grafana:latest
container_name: grafana
restart: unless-stopped
ports:
- "127.0.0.1:3000:3000"
volumes:
- grafana_data:/var/lib/grafana
environment:
- GF_SECURITY_ADMIN_USER=admin
- GF_SECURITY_ADMIN_PASSWORD=MatKhauManh123@!
volumes:
prometheus_data:
grafana_data:
File: prometheus.yml
global:
scrape_interval: 15s
scrape_configs:
• job_name: 'cadvisor'
static_configs: 
◦ targets: ['cadvisor:8080']
───
5. Hướng Dẫn Vận Hành & Xem Dashboard Từ Máy Local
1. Mở đường hầm IAP từ máy cá nhân (chạy trên Terminal Local)
gcloud compute start-iap-tunnel core-server 3000 
 --local-host-port=localhost:3000 
 --zone=asia-southeast1-a
2. Truy cập bằng trình duyệt web máy cá nhân:
URL: http://localhost:3000
User: admin / Pass: MatKhauManh123@!
Import Dashboard ID: 14282 (Docker cAdvisor) để xem biểu đồ CPU/RAM từng service
ĐÃ GIẢI QUYẾT (Hạ tầng & Ranh giới mạng)
• ​Egress Filtering: Chặn hoàn toàn Internet ở Core Server để chống Reverse Shell và Data Exfiltration.
• ​Network Segmentation & DMZ: Cách ly Core nội bộ khỏi Hook Dispatcher (vùng đệm tiếp xúc Internet).
• ​Unidirectional Traffic (Data Diode): Thiết lập mạng 1 chiều (Core \rightarrow Hook), cấm Hook truy cập ngược vào Core.
• ​Principle of Least Privilege (PoLP): Gỡ bỏ toàn bộ Service Account / RAM Role trên máy ảo.
•  ​Cloud Metadata Protection: Chặn IP Link-Local (169.254.169.254) qua iptables để chống Cloud SSRF. 
•  ​Container Isolation: Sử dụng Docker Network (internal: true) để khóa mạng khi gom chung trên 1 server. 
• ​Non-blocking Architecture: Giữ Kafka/Queue tại Core, Worker gọi Hook có Strict Timeout (2.5s / 3.5s) chống nghẽn luồng (Cascading Failure).
• ​Connection Pooling: Bật HTTP Keep-Alive tránh cạn kiệt socket port (TIME_WAIT).
• ​Zero Public Exposure: Giám sát nội bộ qua IAP Tunnel / SSH Tunnel, không public Dashboard ra ngoài.
​CHƯA GIẢI QUYẾT (Ứng dụng, Tải & Vận hành)
• ​Internal IP / LAN SSRF: Chưa validate URL/IP để chặn Hook gọi vào dải mạng private (RFC 1918) hoặc localhost.
• ​DNS Rebinding Protection: Chưa ghim IP (IP Pinning) khi phân giải tên miền đối tác trước khi gửi request.
• ​Response Bomb Mitigation: Chưa giới hạn kích thước nhận về (Max Response Payload) khiến Hook dễ bị tràn RAM (OOM).
• ​Internal Core Resolution: Chưa mở whitelist cho DNS (Port 53) và NTP (Port 123) nội bộ khiến Core có nguy cơ lệch giờ hoặc lỗi SSL.
• ​Exponential Backoff & DLQ: Chưa có thuật toán giãn cách retry và hàng đợi thư chết (Dead Letter Queue) chống nghẽn Kafka.
• ​Proactive Alerting: Chưa tích hợp Alertmanager để tự động gửi thông báo (Telegram/Slack) khi container crash hoặc đầy disk.
