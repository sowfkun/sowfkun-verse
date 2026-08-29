---
trigger: always_on
---

# Project Context — sowfkun.verse.v2

## Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Golang (thư mục: `sowfkun-verse-api/`) |
| **Database** | MongoDB (2 clusters: `primary1`, `secondary1` via ConnectionManager) |
| **Cache** | Redis (2 clusters: `general1` DB 0, `job1` DB 2 via ConnectionManager) |
| **Message Queue** | Redpanda / Apache Kafka Self-Hosted (2 clusters: `general1`, `entity_sync1`) |
| **Background Jobs** | Asynq (Redis-backed via `job1`, dynamic concurrency via `ASYNQ_WORKER_CONCURRENCY`) |
| **Search/Logging** | OpenSearch (2 clusters: `logging1`, `activities1`) |
| **Email** | Resend platform |
| **Profiles** | On-Premise Profiles: `mini` (1-2GB), `standard` (4-8GB), `huge` (16GB+) |
| **API Docs** | Swagger UI tại `/swagger/index.html` |
| **E2EE** | Hybrid RSA-2048 + AES-256-GCM |
| **Frontend** | Next.js App Router, Tailwind CSS v4, CSS Modules (thư mục: `sowfkun-verse-web/`) |
| **Mobile** | Flutter (thư mục: `sowfkun-verse-mobile/`) |