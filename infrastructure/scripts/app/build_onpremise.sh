#!/usr/bin/env bash
# ==============================================================================
# Script đóng gói On-Premise Binary tĩnh cho Linux (AMD64)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "================================================================="
echo "🔨 Đang biên dịch Go Backend API & Egress Gateway thành Binary tĩnh..."
echo "================================================================="

cd "$ROOT_DIR/sowfkun-verse-api"

# 1. Build Core API
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -extldflags '-static'" \
    -o "$ROOT_DIR/infrastructure/api/app-api" \
    ./cmd/api

chmod +x "$ROOT_DIR/infrastructure/api/app-api"

# 2. Build Egress Gateway
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -extldflags '-static'" \
    -o "$ROOT_DIR/infrastructure/gateway/app-gateway" \
    ./cmd/gateway

chmod +x "$ROOT_DIR/infrastructure/gateway/app-gateway"

echo "================================================================="
echo "🎉 ĐÓNG GÓI ON-PREMISE BINARY THÀNH CÔNG!"
echo "👉 File binary API:     infrastructure/api/app-api"
echo "👉 File binary Gateway: infrastructure/gateway/app-gateway"
echo "👉 Bạn chỉ cần copy toàn bộ thư mục [infrastructure/] và file [.env] đi bàn giao On-Premise."
echo "================================================================="
