#!/bin/bash
# ===========================================
# Service 07: Langfuse Worker
# Port: 9007 | Container: obs-07-langfuse-worker
# ===========================================
# Background job processor for Langfuse

set -e
cd "$(dirname "$0")/.."

echo "[07] Starting Langfuse Worker on port 9007..."
docker compose up -d langfuse-worker

echo "[07] Waiting for Langfuse Worker to be ready..."
sleep 10

echo "[07] ✅ Langfuse Worker is ready on port 9007"
