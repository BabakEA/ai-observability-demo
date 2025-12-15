#!/bin/bash
# ===========================================
# Service 04: Redis
# Port: 9004 | Container: obs-04-redis
# ===========================================
# Langfuse cache and message queue

set -e
cd "$(dirname "$0")/.."

echo "[04] Starting Redis on port 9004..."
docker compose up -d redis

echo "[04] Waiting for Redis to be healthy..."
until docker compose exec redis redis-cli -a myredissecret ping > /dev/null 2>&1; do
    echo "  Waiting..."
    sleep 2
done

echo "[04] ✅ Redis is ready on port 9004"
