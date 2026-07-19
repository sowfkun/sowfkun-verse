# Project Context — sowfkun.verse.v2

## Overview
Full-stack SaaS platform. Backend đã có infra base, chưa có nghiệp vụ cụ thể.

## Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Golang (thư mục: `sowfkun-verse-api/`) |
| **Database** | MongoDB (multi-server via ConnectionManager) |
| **Cache** | Redis (multi-client: `general`, `rate_limit`, `redis_job`) |
| **Message Queue** | Apache Kafka (Aiven Free Tier — tối đa 5 topics) |
| **Background Jobs** | Asynq (Redis-backed, concurrency=10) |
| **Search/Logging** | OpenSearch |
| **Email** | Resend platform |
| **API Docs** | Swagger UI tại `/swagger/index.html` |
| **E2EE** | Hybrid RSA-2048 + AES-256-GCM |
| **Frontend** | Next.js (thư mục: `sowfkun-verse-web/`) |
| **Mobile** | Flutter (thư mục: `sowfkun-verse-mobile/`) |

## Trạng thái các Backend Module

| Module | Path | Trạng thái |
|---|---|---|
| `tenant` | `internal/tenant/` | ✅ Cơ bản — entity, repo, update info |
| `auth` | `internal/auth/` | ⚠️ **Skeleton/trống** — chờ implement đăng ký + đăng nhập |
| `email_template` | `internal/email_template/` | ✅ Cơ bản |
| `employee` | `internal/employee/` | ❓ Chưa có thông tin |
| `logging` | `internal/logging/` | ✅ OpenSearch integration |
| `security` | `internal/security/` | ✅ E2EE Handshake endpoint |
| `system` | `internal/system/` | ✅ OpenSearch cleanup cron jobs |

## Quan trọng — Chưa implement

- **JWT Middleware**: Chưa có. Handler hiện mock `TenantID="tenant_123"`. Cần implement khi làm auth.
- **Auth luồng đăng ký/đăng nhập**: Module `internal/auth/` đang trống hoàn toàn.

## Tài liệu chi tiết

→ Đọc `.agents/snapshot_be_infrastructure.md` để có full snapshot kiến trúc BE (patterns, code examples, file map).
