#!/bin/bash
# ===========================================
# Service 13: MCP Gateway
# Port: 9013 | Container: obs-13-mcp-gateway
# ===========================================
# IBM MCP Context Forge (mock) - AI Gateway with MCP Registry

set -e
cd "$(dirname "$0")/.."

echo "[13] Starting MCP Gateway on port 9013..."
docker compose up -d mcp-gateway

echo "[13] Waiting for MCP Gateway to be ready..."
sleep 10

until curl -s http://localhost:9013/health > /dev/null 2>&1; do
    echo "  Waiting..."
    sleep 3
done

echo "[13] ✅ MCP Gateway is ready"
echo "     URL:      http://localhost:9013"
echo "     Invoke:   http://localhost:9013/mcp/invoke"
echo "     Registry: http://localhost:9013/mcp/registry/list"
