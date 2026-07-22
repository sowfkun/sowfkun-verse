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
| **Frontend** | Next.js App Router, Tailwind CSS v4, CSS Modules (thư mục: `sowfkun-verse-web/`) |
| **Mobile** | Flutter (thư mục: `sowfkun-verse-mobile/`) |

