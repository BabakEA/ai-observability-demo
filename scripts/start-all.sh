#!/bin/bash
# ===========================================
# Start All Services - Ordered by ID
# ===========================================
# Starts all services in the correct dependency order

set -e
cd "$(dirname "$0")/.."

echo "=========================================="
echo "AI Observability Demo - Starting All"
echo "=========================================="
echo ""
echo "Services will start in order:"
echo "  Phase 1: Infrastructure (01-05)"
echo "  Phase 2: Langfuse (07-08)"
echo "  Phase 3: Observability (09)"
echo "  Phase 4: Applications (12-14)"
echo ""

# Check .env
if [ ! -f .env ]; then
    echo "⚠️  No .env file found!"
    echo "   Run: cp .env.example .env"
    echo "   Then edit with your Dynatrace credentials"
    exit 1
fi

echo "Phase 1: Infrastructure"
echo "------------------------"
./scripts/01-postgres.sh
./scripts/02-clickhouse.sh
./scripts/04-redis.sh
./scripts/05-minio.sh
echo ""

echo "Phase 2: Langfuse Stack"
echo "-----------------------"
./scripts/07-langfuse-worker.sh
./scripts/08-langfuse-web.sh
echo ""

echo "Phase 3: Observability"
echo "----------------------"
./scripts/09-otel-collector.sh
echo ""

echo "Phase 4: Applications"
echo "---------------------"
./scripts/12-litellm.sh
./scripts/13-mcp-gateway.sh
./scripts/14-ai-agent.sh
echo ""

echo "=========================================="
echo "🎉 All Services Started!"
echo "=========================================="
echo ""
echo "📊 Access Points:"
echo "   [08] Langfuse UI:  http://localhost:9008"
echo "   [12] LiteLLM:      http://localhost:9012"
echo "   [13] MCP Gateway:  http://localhost:9013"
echo "   [14] AI Agent:     http://localhost:9014"
echo ""
echo "📖 See PORTS.md for full port reference"
