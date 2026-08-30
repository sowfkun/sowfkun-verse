#!/usr/bin/env bash
# ==============================================================================
# SOWFKUN MASTER TOOL SUITE (BASH WRAPPER)
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pwsh -NoProfile -File "$SCRIPT_DIR/sowfkun.ps1" "$@" 2>/dev/null || powershell -NoProfile -File "$SCRIPT_DIR/sowfkun.ps1" "$@"
