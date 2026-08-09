# Tài Liệu Luồng WebSocket Server (WebSocket Flow Specification)

Tài liệu này mô tả chi tiết kiến trúc, vòng đời kết nối và dòng chảy dữ liệu 2 chiều (Bidirectional Data Flow) của hệ thống Realtime WebSocket Server tích hợp với Apache Kafka đa cụm trong dự án.

---

## 1. Luồng Bắt Tay & Thiết Lập Kết Nối (Connection & Handshake Flow)

Kết nối WebSocket sử dụng cơ chế bắt tay HTTP Upgrade và xác thực thông qua JSON Web Token (JWT) truyền qua URL Query Parameter.

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client (Frontend)
    participant API as API Server (Gateway)
    participant Hub as Global Hub (RAM)

    Client->>API: HTTP GET /api/v1/ws?token=<JWT_TOKEN> (Upgrade to WebSocket)
    Note over API: Parse JWT & Validate Signature
    alt JWT Token hợp lệ
        API->>Client: Trả về HTTP 101 Switching Protocols (Upgrade thành công)
        Note over API, Client: Thiết lập kết nối TCP WebSocket vật lý
        API->>Hub: Đăng ký Client vào Hub (map theo TenantID & UserID)
        API-->>Client: Kích hoạt Read/Write Pumps bất đồng bộ
    else JWT Token không hợp lệ hoặc thiếu
        API->>Client: Trả về HTTP 401 Unauthorized / HTTP 400 Bad Request
    end
```

### 1.1. Chi tiết thực thi:
- **Endpoint:** `ws://<api-domain>/api/v1/ws?token=<JWT_TOKEN>`
- **Xác thực:** Giao thức GET không đi qua E2EE Middleware của REST API mà giải mã JWT trực tiếp trong Handler để lấy `UserID` và `TenantID` (phục vụ phân vùng Multi-tenant).
- **Lưu trữ kết nối:** Lưu vật lý in-memory trên RAM thông qua các map 2 chiều: `tenantClients` (để broadcast theo Tenant) và `userClients` (để gửi riêng tư cho cá nhân).

---

## 2. Luồng Heartbeat & Ping/Pong (TCP Connection Keep-Alive)

Để duy trì kết nối TCP không bị ngắt bởi Nginx/Proxy do rảnh (Idle), server định kỳ gửi gói tin Ping ở cấp mạng.

```mermaid
sequenceDiagram
    autonumber
    participant Server as WebSocket Server (Write Pump)
    actor Client as Client (Browser)

    Note over Server, Client: Kết nối rảnh (Idle)
    Server->>Client: Bắn WebSocket Ping Frame (mỗi 54 giây)
    Client->>Server: Tự động phản hồi Pong Frame
    Note over Server: Nhận Pong -> Gia hạn Read Deadline của connection thêm 60 giây
```

> [!NOTE]
> Gói tin Ping/Pong ở cấp mạng (WebSocket Control Frames) chỉ có tác dụng giữ kết nối TCP không bị Timeout. 
> Trạng thái online thực tế (`user:online:{UserID}`) trên Redis được quản lý riêng biệt bởi ứng dụng thông qua tin nhắn text frame `CLIENT_PING` (Xem chi tiết tại Mục 4).

---

## 3. Chiều Gửi Tin Nhắn Từ Server Xuống Client (Send Flow - Server-to-Client)

Luồng gửi tin nhắn xuống client hoạt động theo mô hình **Fan-out qua Kafka**. Bất kỳ node nào trong hệ thống cũng có thể publish tin nhắn, Kafka sẽ phân phối đến toàn bộ API Nodes để tìm kết nối vật lý.

```mermaid
sequenceDiagram
    autonumber
    participant App as Business Usecase (API/Worker Node)
    participant Kafka as Kafka (Topic: send-socket-progress)
    participant APINode as API Server Instances
    participant Hub as Hub (RAM)
    actor Client as Client Browser

    App->>App: Tạo SocketMessagePayload (Target, Event, Data)
    App->>Kafka: Publish event SOCKET_PROGRESS_SEND (Partition Key = TargetID)
    Note over Kafka: Đảm bảo FIFO (tuần tự) cho cùng 1 TargetID
    Kafka->>APINode: Phân phối (fan-out) sự kiện đến tất cả API instances
    Note over APINode: Giải mã Event Envelope lấy SocketMessagePayload
    APINode->>Hub: Kiểm tra connection local của TargetID
    alt Node đang giữ kết nối vật lý với TargetID
        Hub->>Client: Đẩy WebSocket text frame (JSON data)
    else Node không giữ kết nối
        Note over Hub: Bỏ qua tin nhắn
    end
```

### 3.1. Định dạng JSON Frame Server phát xuống:
```json
{
  "event": "NOTIFICATION_RECEIVED",
  "data": {
    "title": "New Message",
    "content": "Hello World"
  }
}
```

---

## 4. Chiều Client Gửi Tin Nhắn Lên Server (Receive Flow - Client-to-Server)

Khi client gửi tin nhắn lên WebSocket, server sẽ nhận được, đóng gói và đẩy lên Kafka chiều nhận để các consumer nghiệp vụ tiêu thụ bất đồng bộ nhằm phân rã liên kết (decoupling).

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client Browser
    participant ClientWS as client.go (readPump)
    participant Gateway as setup_socket.go (OnMessage Callback)
    participant Kafka as Kafka (Topic: receive-socket-progress)
    participant MQ as User MQ Handler (HandleClientPing)
    participant Redis as Redis Agent Business

    Client->>ClientWS: Gửi WebSocket Text Frame (JSON format)
    Note over ClientWS: Unmarshal JSON thành SocketMessagePayload
    ClientWS->>Gateway: Trigger Hub.OnMessage(client, payload)
    Note over Gateway: Ghi đè Source = "CLIENT:" + UserID (Chống giả mạo)
    Gateway->>Kafka: Publish event với type = payload.Event (ví dụ: CLIENT_PING)
    
    Note over Kafka: Phân phối sự kiện đến Consumer tương ứng
    Kafka->>MQ: Consume event CLIENT_PING
    MQ->>Redis: Cập nhật online status (Set key user:online:{UserID} = 1, TTL=120s)
```

### 4.1. Định dạng JSON Client gửi lên:
```json
{
  "target_type": "USER",
  "target_id": "user_recipient_id",
  "event": "CLIENT_PING",
  "data": {}
}
```

---

## 5. Danh Sách Các Event Định Sẵn (Built-in Events)

| Tên Event (payload.Event) | Chiều (Direction) | Logic Xử Lý Ở Backend |
| :--- | :--- | :--- |
| `CLIENT_PING` | Client $\rightarrow$ Server | Trigger `HandleClientPing` của User MQ Handler gia hạn trạng thái online (`user:online:{UserID}`) trên Redis Agent Business. |
| `SOCKET_PROGRESS_SEND` | Server $\rightarrow$ Client | Topic `send-socket-progress` dùng event type này làm envelope điều hướng dispatcher toàn cục chuyển tin cho Hub. |

---

## 6. Hướng Dẫn Tích Hợp Client (Frontend Integration Guide)

### 6.1. Thiết Lập Kết Nối (Connection Setup)
Client sử dụng thư viện WebSocket chuẩn của trình duyệt (hoặc các wrapper) để bắt đầu kết nối. Token JWT bắt buộc phải được truyền qua query parameter `token`.

```javascript
const JWT_TOKEN = "your_jwt_token_here";
const socketUrl = `ws://localhost:8080/api/v1/ws?token=${JWT_TOKEN}`;

const ws = new WebSocket(socketUrl);

ws.onopen = () => {
    console.log("🔌 WebSocket connected successfully!");
    // Khởi động gửi Ping định kỳ để duy trì online status
    startHeartbeat();
};

ws.onmessage = (event) => {
    try {
        const payload = JSON.parse(event.data);
        console.log(`📩 Nhận sự kiện [${payload.event}]:`, payload.data);
        
        // Xử lý logic theo từng sự kiện nhận được
        if (payload.event === "NOTIFICATION_RECEIVED") {
            showNotification(payload.data);
        }
    } catch (e) {
        console.error("❌ Lỗi parse JSON socket frame:", e);
    }
};

ws.onclose = (event) => {
    console.log("🔌 WebSocket disconnected. Reason:", event.reason);
    stopHeartbeat();
    // Thực hiện logic tự động kết nối lại (Auto Reconnect) sau 3-5 giây
};
```

### 6.2. Giao Thức Gửi Tin (Client-to-Server)
Khi client gửi tin nhắn lên, do các tag JSON của `SocketMessagePayload` ở server đã được bổ sung `omitempty`, client chỉ cần gửi đúng schema tối thiểu có chứa `event` và `data`. Backend sẽ tự động điền `source` ở gateway.

#### A. Gửi Ping Duy Trì Kết Nối (CLIENT_PING)
Client nên gửi Ping định kỳ mỗi **54 giây** (theo cấu hình `pingPeriod` của server) để đảm bảo TTL `user:online` trên Redis luôn được gia hạn và tránh bị gateway ngắt kết nối do Idle timeout.

```javascript
let heartbeatInterval;

function startHeartbeat() {
    heartbeatInterval = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
            const pingFrame = {
                event: "CLIENT_PING",
                data: {} // data có thể để trống
            };
            ws.send(JSON.stringify(pingFrame));
            console.log("🛰️ Heartbeat CLIENT_PING sent.");
        }
    }, 54000); // 54 giây
}

function stopHeartbeat() {
    clearInterval(heartbeatInterval);
}
```

#### B. Gửi Tin Nhắn Nghiệp Vụ Khác (Ví dụ gửi Chat)
```javascript
function sendChatMessage(recipientUserId, text) {
    const chatFrame = {
        target_type: "USER",
        target_id: recipientUserId,
        event: "CHAT_MESSAGE_SENT",
        data: {
            content: text,
            sent_at: new Date().toISOString()
        }
    };
    ws.send(JSON.stringify(chatFrame));
}
```
