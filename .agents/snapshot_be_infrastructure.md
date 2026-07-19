# sowfkun-verse-api — Backend Infrastructure Snapshot

> Agent phải đọc file này **trước** khi làm bất kỳ task backend nào để không cần quét lại source code.
> File được cập nhật theo từng sprint. Last updated: 2026-07-19.

---

## 1. Module Name (go.mod)

```
module core-backend
```

---

## 2. Startup Order (`cmd/api/main.go`)

```
1. Load .env (godotenv)
2. Init MongoDB  → dbGeneral = mongoManager.GetDatabase("general", "general")
3. Init Redis    → generalRedisClient = redisManager.GetClient("general")
4. Init OpenSearch → loggingClient + run ISM migrations
5. Init RSA Keys  → security.InitRSAKeys() [RAM fallback nếu thiếu env]
6. Init Email Sender → setupMail(generalRedisClient, logRepo)
7. Init Kafka Manager + startGlobalConsumers(appCtx, kafkaManager, db, emailSender)
8. Init Asynq Job Manager + startJobWorkers(manager, kafkaManager, loggingClient)
9. setupRouter(dbGeneral, generalRedisClient) → mux
10. setupMiddlewares(mux, rateLimitClient, generalRedisClient, logRepo) → globalHandler
11. http.ListenAndServe(":8080", globalHandler)
```

---

## 3. Cấu trúc Thư mục

```
sowfkun-verse-api/
├── cmd/api/
│   ├── main.go           ← Entry point
│   ├── setup_db.go       ← Init MongoDB, Redis, OpenSearch
│   ├── setup_http.go     ← Register routes + middleware stack
│   ├── setup_kafka.go    ← Kafka + Global Event Dispatcher
│   ├── setup_job.go      ← Asynq background jobs
│   └── setup_mail.go     ← Email sender init
│
├── internal/
│   ├── tenant/           ← ⭐ GOLDEN STANDARD — copy cấu trúc này
│   ├── auth/             ← ⚠️ Skeleton trống — chờ implement
│   ├── email_template/   ← Email template CRUD
│   ├── employee/         ← Chưa xem
│   ├── logging/          ← OpenSearch log repo
│   ├── security/         ← E2EE handshake endpoints
│   └── system/           ← OS cleanup cron jobs
│
└── pkg/
    ├── cache/redis/       ← ConnectionManager, keys.go
    ├── constant/          ← email.go (EmailTemplateCode, Kafka events)
    ├── core/
    │   ├── application/dto/  ← CommonCommand, CommonQuery
    │   ├── domain/           ← BaseEntity, Actor, ActorType
    │   └── security/         ← RSA + AES crypto
    ├── database/
    │   ├── mongodb/       ← AbstractMongoRepository, ConnectionManager
    │   └── opensearch/    ← ConnectionManager + migrations
    ├── job/asynq/         ← Asynq Manager, KafkaRelayHandler
    ├── mail/              ← Sender interface + Resend impl
    ├── middleware/        ← Logger, RateLimit (Token Bucket), PayloadCrypto
    ├── mq/kafka/          ← Manager, EventDispatcher, topics.go
    └── utils/response/   ← BaseResponse[T], Success(), Error()
```

---

## 4. Golden Standard: `internal/tenant/`

### Domain Entity pattern

```go
// internal/tenant/domain/entity.go
type Tenant struct {
    coreDomain.BaseEntity `bson:",inline"`
    Email    string         `bson:"email" json:"email"`
    Password string         `bson:"password" json:"-"`
    Name     string         `bson:"name" json:"name"`
    Status   TenantStatus   `bson:"status" json:"status"`
    Tier     string         `bson:"tier" json:"tier"`
    Settings map[string]any `bson:"settings,omitempty" json:"settings,omitempty"`
}
```

### BaseEntity (pkg/core/domain/base_entity.go)

```go
type BaseEntity struct {
    ID              primitive.ObjectID `bson:"_id,omitempty" json:"id"`
    CreatedDate     int64              `bson:"created_date" json:"created_date"`
    LastUpdatedDate int64              `bson:"last_updated_date" json:"last_updated_date"`
    IsDeleted       bool               `bson:"is_deleted" json:"is_deleted"`
    ExpiredRef      *time.Time         `bson:"expired_ref,omitempty" json:"expired_ref,omitempty"`
    Keywords        []string           `bson:"keywords,omitempty" json:"keywords,omitempty"`
    CreatedBy       *Actor             `bson:"created_by,omitempty" json:"created_by,omitempty"`
    LastUpdatedBy   *Actor             `bson:"last_updated_by,omitempty" json:"last_updated_by,omitempty"`
}
```

### Actor (pkg/core/domain/actor.go)

```go
type Actor struct {
    ID   string    `bson:"id" json:"id"`
    Type ActorType `bson:"type" json:"type"` // "USER" | "SYSTEM"
    Name string    `bson:"name,omitempty" json:"name,omitempty"`
}
```

### Repository Interface pattern

```go
// internal/tenant/domain/repository.go
type ITenantRepository interface {
    FindByEmail(ctx context.Context, email string) *Tenant
    Add(ctx context.Context, tenant *Tenant) *Tenant
    UpdateInfo(ctx context.Context, id string, name string) *Tenant
}
```

### UseCase pattern (3 Zones)

```go
// ================= MODEL ZONE =================
type UpdateTenantInfoCommand struct {
    appDto.CommonCommand          // Nhúng CommonCommand - BẮT BUỘC
    Name string `json:"name"`
}

// ================= TYPE ZONE =================
type IUpdateTenantInfoUseCase interface {
    Execute(ctx context.Context, cmd UpdateTenantInfoCommand) error
}
type updateTenantInfoUseCase struct { tenantRepo domain.ITenantRepository }

// ================= EXECUTION ZONE =================
func NewUpdateTenantInfoUseCase(repo domain.ITenantRepository) IUpdateTenantInfoUseCase {
    return &updateTenantInfoUseCase{tenantRepo: repo}
}
func (uc *updateTenantInfoUseCase) Execute(ctx context.Context, cmd UpdateTenantInfoCommand) error {
    updated := uc.tenantRepo.UpdateInfo(ctx, cmd.TenantID, cmd.Name)
    if updated == nil { return errors.New("not found") }
    return nil
}
```

### MongoDB Repository pattern (3 Zones)

```go
// internal/tenant/infrastructure/mongodb_repository.go
type mongoTenantRepository struct {
    *mongodb.AbstractMongoRepository[domain.Tenant]
}

func NewMongoTenantRepository(db *mongo.Database) domain.ITenantRepository {
    return &mongoTenantRepository{
        AbstractMongoRepository: mongodb.NewAbstractMongoRepository[domain.Tenant](db, "tenants"),
    }
}

// ================= READ ZONE =================
func (r *mongoTenantRepository) FindByEmail(ctx context.Context, email string) *domain.Tenant {
    cmd := queries.TenantQuery{Email: email}
    return r.GetOne(ctx, r.buildQuery(cmd), nil)
}

// ================= WRITE ZONE =================
func (r *mongoTenantRepository) Add(ctx context.Context, tenant *domain.Tenant) *domain.Tenant {
    created := r.AbstractMongoRepository.Add(ctx, tenant)
    if created != nil { r.onChange(ctx, "CREATE", created) }
    return created
}
// Master Update - mọi update business nhỏ gọi hàm này
func (r *mongoTenantRepository) update(ctx context.Context, id string, data bson.M, incrData bson.M) *domain.Tenant {
    updated := r.AbstractMongoRepository.Update(ctx, id, data, incrData)
    if updated != nil { r.onChange(ctx, "UPDATE", updated) }
    return updated
}

// ================= HELPERS ZONE =================
func (r *mongoTenantRepository) buildQuery(cq queries.TenantQuery) bson.M {
    baseQuery := mongodb.BuildCommonQuery(cq.CommonQuery)
    if cq.Status != "" { baseQuery["status"] = cq.Status }
    if cq.Email != "" { baseQuery["email"] = cq.Email }
    return baseQuery
}
func (r *mongoTenantRepository) onChange(ctx context.Context, action string, data *domain.Tenant) {
    // Push Kafka event, update Redis, sync ES...
}
```

### Query Model pattern

```go
// internal/tenant/application/queries/query_models.go
type TenantQuery struct {
    appDto.CommonQuery        // BẮT BUỘC nhúng CommonQuery
    Status domain.TenantStatus
    Name   string
    Email  string
}
```

### CommonCommand (pkg/core/application/dto/common_command.go)

```go
type CommonCommand struct {
    TenantID string  // Lấy từ JWT tại Presentation layer
    ByID     string
    ByName   string
    IsOwner  bool
}
```

### HTTP Route pattern

```go
// presentation/http/route.go
func getRoutePrefix() string { return "/api/v1/tenant" }

func RegisterTenantRoutes(mux *http.ServeMux, db *mongo.Database) {
    tenantRepo := infrastructure.NewMongoTenantRepository(db)
    updateUseCase := commands.NewUpdateTenantInfoUseCase(tenantRepo)
    handler := NewTenantHandler(updateUseCase)
    prefix := getRoutePrefix()
    mux.HandleFunc("POST "+prefix+"/update-info", handler.UpdateInfoHandler)
}
```

### HTTP Handler pattern (Dumb Controller)

```go
func (h *TenantHandler) UpdateInfoHandler(w http.ResponseWriter, r *http.Request) {
    var cmd commands.UpdateTenantInfoCommand
    if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
        response.Error(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
        return
    }
    // TODO: Parse JWT → fill CommonCommand
    cmd.CommonCommand = appDto.CommonCommand{TenantID: "...", ByID: "...", IsOwner: true}
    if err := h.useCase.Execute(r.Context(), cmd); err != nil {
        response.Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
        return
    }
    response.Success(w, dto.TenantSuccessResponse{Message: "success"})
}
```

### Response Format (pkg/utils/response/http.go)

```go
type BaseResponse[T any] struct {
    Data        T      `json:"data"`
    ErrorCode   string `json:"error_code,omitempty"`
    ErrorDetail string `json:"error_detail,omitempty"`
}
// Dùng:
response.Success(w, someDTO)
response.Error(w, http.StatusBadRequest, "BAD_REQUEST", "detail message")
```

---

## 5. Middleware Stack (setup_http.go)

```
Request In
  → PayloadCrypto (E2EE) — innermost
  → Logger Middleware (log to OpenSearch)
  → RateLimit Middleware (Token Bucket via Lua/Redis)
  → HTTP Router (mux)
Response Out
```

**Env vars:**
```env
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_WINDOW_MINUTES=1
ENABLE_PAYLOAD_ENCRYPTION=false   # false=dev, true=production
```

---

## 6. E2EE Flow (Security Module)

- `GET /api/v1/security/public-key` → RSA-2048 Public Key
- `POST /api/v1/security/handshake` → client gửi AES key đã encrypt bằng RSA → server lưu AES key vào Redis `session:{id}` → trả `sessionID`
- Mọi POST/PUT/DELETE sau: Header `X-Session-ID`, Body = AES-encrypted JSON
- `PayloadCryptoMiddleware` decrypt body → Handler → chỉ encrypt field `data` của response
- **RSA Key ENV:** `RSA_PRIVATE_KEY_BASE64`, `RSA_PUBLIC_KEY_BASE64` (RAM fallback nếu thiếu)
- **Skip E2EE:** GET, OPTIONS, path `/api/v1/security/*`

---

## 7. Kafka Architecture

### 3 Global Topics (pkg/mq/kafka/topics.go)

| Constant | Topic Name | Pattern |
|---|---|---|
| `TopicLowTrafficOrderProgress` | `low-traffics-order-progress` | Ordered FIFO per Key |
| `TopicSingleParallelProgress` | `single-parallel-progress` | Parallel worker pool |
| `TopicBatchProgress` | `batch-progress` | Batch 50 msgs hoặc 2s |

### Thêm Kafka handler cho domain mới (3 bước)

```
Bước 1: pkg/constant/{domain}.go
    const EventTenantCreated = "TENANT_CREATED"

Bước 2: internal/{domain}/presentation/mq/handler.go
    type TenantMQHandler struct { ... }
    func NewTenantMQHandler(...) *TenantMQHandler { ... }
    func RegisterMQHandlers(dispatcher, db) {
        handler := NewTenantMQHandler(...)
        dispatcher.Register(constant.EventTenantCreated, handler.HandleCreated)
    }

Bước 3: cmd/api/setup_kafka.go → trong startGlobalConsumers()
    tenantMq.RegisterMQHandlers(dispatcher, db)
```

### CommonEvent format

```go
type CommonEvent struct {
    Key    string `json:"-"`       // Partition routing key (bắt buộc với Ordered topic)
    Source string `json:"source"`
    Type   string `json:"type"`   // VD: "TENANT_CREATED"
    Data   any    `json:"data"`
}
```

---

## 8. Redis Key Registry

**System-level** (`pkg/cache/redis/keys.go`):
```
"rate_limit:{path}:{ip}:tokens"
"rate_limit:{path}:{ip}:ts"
"session:{sessionID}"
"mail_quota:{hash}:{date}"
"mail_quota_month:{hash}:{month}"
"mail_alert:quota_exhausted:{date}"
```
**Domain-level:** `internal/{domain}/infrastructure/cache/keys.go`

---

## 9. Email System

```go
// pkg/mail/mail.go
type Sender interface {
    Send(ctx context.Context, msg *Message) error
    Stats(ctx context.Context) map[string]interface{}
}
type Message struct {
    To, CC, BCC []string
    Subject     string
    Body        string // HTML
}
// Implementation: pkg/mail/resend_platform.go
```

**Email Template Codes** (`pkg/constant/email.go`):
```go
TemplateWelcomeTenant  EmailTemplateCode = "TEMPLATE_WELCOME_TENANT"
TemplateForgotPassword EmailTemplateCode = "TEMPLATE_FORGOT_PASSWORD"
TemplateOrderSuccess   EmailTemplateCode = "TEMPLATE_ORDER_SUCCESS"
EventEmailSendRequested = "EMAIL_SEND_REQUESTED"
```

---

## 10. Background Jobs (Asynq)

- **Redis client:** `redis_job` (riêng với `general`)
- **Concurrency:** 10 workers
- **Job processors:** `internal/{domain}/application/jobs/`
- **Pattern:** `manager.Scheduler().Register("@monthly", task)`
- **Fallback:** Unregistered task types → Kafka relay handler

---

## 11. Checklist khi thêm module mới

- [ ] `internal/{domain}/domain/entity.go` — Entity kế thừa `BaseEntity`
- [ ] `internal/{domain}/domain/repository.go` — Interface chỉ khai báo
- [ ] `internal/{domain}/application/queries/query_models.go` — embed `CommonQuery`
- [ ] `internal/{domain}/application/commands/{action}.go` — 3 zones, embed `CommonCommand`
- [ ] `internal/{domain}/infrastructure/mongodb_repository.go` — 3 zones
- [ ] `internal/{domain}/presentation/dto/` — Request/Response DTOs
- [ ] `internal/{domain}/presentation/http/handler.go` — Dumb controller
- [ ] `internal/{domain}/presentation/http/route.go` — `getRoutePrefix()` + `Register{Domain}Routes()`
- [ ] `cmd/api/setup_http.go` — Gọi `Register{Domain}Routes(mux, db)`
- [ ] `pkg/constant/{domain}.go` — Kafka event constants nếu cần

---

## 12. Notes kết thúc

- **JWT:** Chưa implement. Hiện mock trong handler. Cần JWT middleware khi làm auth.
- **BSON abbreviation:** `desc`, `phone`, `addr`, `lang`, `subj`, `body`, `meta`, `cfg`, `qty`, `tid`, `uid`, `tmpl_id`, `c_at`, `u_at`, `d_at`, `del`
- **Time standard:** Unix Timestamp ms (`int64`), tất cả UTC
- **Port:** `:8080` | **Base URL:** `/api/v1` | **Swagger:** `/swagger/index.html`
