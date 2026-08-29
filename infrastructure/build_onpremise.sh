#!/usr/bin/env bash
# ==============================================================================
# Script đóng gói On-Premise Binary tĩnh cho Linux (AMD64)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================================="
echo "🔨 Đang biên dịch Go Backend API thành Binary tĩnh cho On-Premise..."
echo "================================================================="

cd "$ROOT_DIR/sowfkun-verse-api"

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -extldflags '-static'" \
    -o "$ROOT_DIR/infrastructure/api/app-api" \
    ./cmd/api

chmod +x "$ROOT_DIR/infrastructure/api/app-api"

echo "================================================================="
echo "🎉 ĐÓNG GÓI ON-PREMISE BINARY THÀNH CÔNG!"
echo "👉 File binary: infrastructure/api/app-api"
echo "👉 Bạn chỉ cần copy toàn bộ thư mục [infrastructure/] và file [.env] đi bàn giao On-Premise."
echo "================================================================="
