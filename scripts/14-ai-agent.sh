#!/bin/bash
# ===========================================
# Service 14: AI Agent
# Port: 9014 | Container: obs-14-ai-agent
# ===========================================
# Demo AI Agent with dual observability (Dynatrace + Langfuse)

set -e
cd "$(dirname "$0")/.."

echo "[14] Starting AI Agent on port 9014..."
docker compose up -d agent

echo "[14] Waiting for AI Agent to be ready..."
sleep 10

until curl -s http://localhost:9014/health > /dev/null 2>&1; do
    echo "  Waiting..."
    sleep 3
done

echo "[14] ✅ AI Agent is ready"
echo "     URL:    http://localhost:9014"
echo "     Run:    http://localhost:9014/run"
echo "     Config: http://localhost:9014/config"
