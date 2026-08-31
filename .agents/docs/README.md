# 📚 Sowfkun Verse — Tài Liệu Kiến Trúc & Nghiệp Vụ Hệ Thống (Master Documentation Index)

Mục lục toàn diện tổng hợp toàn bộ tài liệu đặc tả kiến trúc, thiết kế hệ thống, quy trình triển khai và luồng nghiệp vụ của dự án **Sowfkun Verse**.

---

## 🚀 1. Nhóm Tài Liệu Triển Khai & An Ninh (`deploy/`)

Tài liệu hướng dẫn vận hành, thiết lập hạ tầng, mạng và các tiêu chuẩn bảo mật đa môi trường:

| Tài Liệu | Mô Tả Tóm Tắt |
|---|---|
| 🛡️ [SECURITY_ARCHITECTURE_AND_CHECKLIST.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/deploy/SECURITY_ARCHITECTURE_AND_CHECKLIST.md) | Kiến trúc an ninh phòng thủ chiều sâu (Defense-in-Depth), ma trận chuẩn quốc tế (ZTNA, Micro-Segmentation, Strict Egress, Field Encryption, SSRF Firewall). |
| ☁️ [GCP_MULTI_SERVER_AND_VPC_PEERING.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/deploy/GCP_MULTI_SERVER_AND_VPC_PEERING.md) | Kiến trúc 3 cụm Server trên GCP (`10.10.x`, `10.20.x`, `10.30.x`), sơ đồ topology Mermaid và ma trận quyền kết nối Zero-Trust giữa các node. |
| 🏢 [ONPREMISE_AND_OPTIMIZATION.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/deploy/ONPREMISE_AND_OPTIMIZATION.md) | Hướng dẫn đóng gói On-Premise, bàn giao doanh nghiệp và bảng tối ưu hóa tài nguyên phần cứng theo 3 profile (`mini`, `standard`, `huge`). |

---

## 🏗️ 2. Nhóm Tài Liệu Thiết Kế Hệ Thống (`system_design/`)

Tài liệu đặc tả kiến trúc kỹ thuật nền tảng, cơ chế kết nối hạ tầng và các luồng cross-cutting:

| Tài Liệu | Mô Tả Tóm Tắt |
|---|---|
| 🗄️ [INFRASTRUCTURE_DESIGN.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/system_design/INFRASTRUCTURE_DESIGN.md) | Ánh xạ toàn diện kết nối hạ tầng: MongoDB 2 clusters, Redis 2 clusters, Kafka, Egress Gateway và Central Monitoring Hub. |
| 🔍 [OPENSEARCH_ARCHITECTURE_AND_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/system_design/OPENSEARCH_ARCHITECTURE_AND_FLOW.md) | Kiến trúc OpenSearch time-series logging & activity tracking, cơ chế phân vùng tự động theo tháng/quý và quản lý retention. |
| 📨 [MQ_KAFKA_DISPATCHER_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/system_design/MQ_KAFKA_DISPATCHER_FLOW.md) | Kiến trúc Global Event Dispatcher, CDC Change Stream Watcher và cơ chế phát/nhận tin bất đồng bộ. |
| 🔎 [ATLAS_SEARCH_AND_QUERY_BUILDER_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/system_design/ATLAS_SEARCH_AND_QUERY_BUILDER_FLOW.md) | Thiết kế Query Builder, tích hợp Atlas Search Lucene Engine `$search` và chuẩn hóa phân trang/lọc danh sách. |
| 🔐 [PHONE_AND_EMAIL_ENCRYPTION_AND_SEARCH_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/system_design/PHONE_AND_EMAIL_ENCRYPTION_AND_SEARCH_FLOW.md) | Kiến trúc mã hóa dữ liệu nhạy cảm AES-256-GCM và tìm kiếm trên dữ liệu mã hóa qua Blind Index HMAC-SHA256 Pepper. |
| ⚡ [FE_LOCAL_CACHING_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/system_design/FE_LOCAL_CACHING_FLOW.md) | Chiến lược Caching phía Frontend (IndexedDB / LocalStorage) giảm tải 90% request đọc lên Backend. |
| 🔌 [SOCKET_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/system_design/SOCKET_FLOW.md) | Luồng kết nối WebSocket thời gian thực, quản lý phân phối message đa server thông qua Kafka. |
| 📋 [LIST_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/system_design/LIST_FLOW.md) | Quy chuẩn phân trang danh sách (Pagination, Cursor, Projection, Scope filtering) chuẩn Golden Standard. |

---

## 💼 3. Nhóm Tài Liệu Luồng Nghiệp Vụ (`business_flows/`)

Tài liệu đặc tả các luồng nghiệp vụ chức năng (Domain Flows):

| Tài Liệu | Mô Tả Tóm Tắt |
|---|---|
| 🏢 [TENANT_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/business_flows/TENANT_FLOW.md) | Quy trình đăng ký, kích hoạt, quản lý thông tin doanh nghiệp và kiến trúc cô lập Multi-tenant (Golden Standard). |
| 👥 [USER_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/business_flows/USER_FLOW.md) | Quản lý người dùng, nhân viên, phân cấp quản lý cấp trên - cấp dưới, và trạng thái kích hoạt tài khoản. |
| 🔑 [AUTH_REGISTER_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/business_flows/AUTH_REGISTER_FLOW.md) | Luồng đăng ký tài khoản, đăng nhập JWT, phân hệ Web/Admin/Mobile và cơ chế bắt tay mã hóa E2EE. |
| 🛡️ [ROLE_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/business_flows/ROLE_FLOW.md) | Quản lý vai trò (Roles), phân quyền RBAC và cơ chế phân giải phạm vi truy cập (Scope: `ALL`, `SUBORDINATES`, `SAME_DEPT`, `OWN_ONLY`). |
| 🏷️ [ATTRIBUTE_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/business_flows/ATTRIBUTE_FLOW.md) | Quản lý thuộc tính động (Dynamic Custom Attributes) cho các module nghiệp vụ như Customer, Ticket. |
| 🔖 [TAG_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/business_flows/TAG_FLOW.md) | Hệ thống gán nhãn đa phân hệ (Tagging system) phục vụ phân loại và lọc dữ liệu doanh nghiệp. |
| 📜 [ACTIVITY_LOGS_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/business_flows/ACTIVITY_LOGS_FLOW.md) | Luồng ghi nhận và truy vết nhật ký hoạt động của người dùng (Audit Logs & Activities tracking). |
| 🛡️ [SECURITY_THREAT_SCENARIOS_FLOW.md](file:///f:/Coding/Project/sowfkun.verse.v2/.agents/docs/business_flows/SECURITY_THREAT_SCENARIOS_FLOW.md) | Đặc tả 6 kịch bản tấn công an ninh cấp ứng dụng (OWASP Top 10), thiết kế phòng thủ và lộ trình nâng cấp Go Backend. |

