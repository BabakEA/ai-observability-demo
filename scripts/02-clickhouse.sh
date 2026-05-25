#!/bin/bash
# ===========================================
# Service 02: ClickHouse
# Ports: 9002 (HTTP), 9003 (Native) | Container: obs-02-clickhouse
# ===========================================
# Langfuse analytics - high-volume time-series data

set -e
cd "$(dirname "$0")/.."

echo "[02] Starting ClickHouse on ports 9002, 9003..."
docker compose up -d clickhouse

echo "[02] Waiting for ClickHouse to be healthy..."
until curl -s http://localhost:9002/ping > /dev/null 2>&1; do
    echo "  Waiting..."
    sleep 2
done

echo "[02] ✅ ClickHouse is ready on ports 9002 (HTTP), 9003 (Native)"
