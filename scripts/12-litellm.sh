#!/bin/bash
# ===========================================
# Service 12: LiteLLM
# Port: 9012 | Container: obs-12-litellm
# ===========================================
# OpenAI-compatible LLM Gateway

set -e
cd "$(dirname "$0")/.."

echo "[12] Starting LiteLLM on port 9012..."
docker compose up -d litellm

echo "[12] Waiting for LiteLLM to be ready..."
sleep 10

until curl -s http://localhost:9012/health > /dev/null 2>&1; do
    echo "  Waiting..."
    sleep 3
done

echo "[12] ✅ LiteLLM is ready"
echo "     URL:    http://localhost:9012"
echo "     OpenAI: http://localhost:9012/v1/chat/completions"
