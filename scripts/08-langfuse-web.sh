#!/bin/bash
# ===========================================
# Service 08: Langfuse Web
# Port: 9008 | Container: obs-08-langfuse-web
# ===========================================
# Langfuse UI and API - AI/LLM Observability Dashboard

set -e
cd "$(dirname "$0")/.."

echo "[08] Starting Langfuse Web on port 9008..."
docker compose up -d langfuse-web

echo "[08] Waiting for Langfuse Web to be ready..."
sleep 15

until curl -s http://localhost:9008 > /dev/null 2>&1; do
    echo "  Waiting..."
    sleep 3
done

echo "[08] ✅ Langfuse Web is ready"
echo "     URL: http://localhost:9008"
