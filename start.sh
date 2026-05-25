#!/bin/bash
# =============================================================================
# AI Observability Demo - Full Stack Startup Script
# =============================================================================
# Starts all services in the correct order with health checks
# Port Range: 9001-9014 (see PORTS.md for full dictionary)
# =============================================================================

set -e

echo "=============================================="
echo "  AI Observability Demo - Startup Script"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local url=$2
    local max_attempts=${3:-30}
    local attempt=1
    
    echo -e "${YELLOW}Waiting for $service_name...${NC}"
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $service_name is ready!${NC}"
            return 0
        fi
        echo "  Attempt $attempt/$max_attempts..."
        sleep 2
        ((attempt++))
    done
    echo -e "${RED}✗ $service_name failed to start${NC}"
    return 1
}

# Function to wait for TCP port
wait_for_port() {
    local service_name=$1
    local host=$2
    local port=$3
    local max_attempts=${4:-30}
    local attempt=1
    
    echo -e "${YELLOW}Waiting for $service_name on port $port...${NC}"
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            echo -e "${GREEN}✓ $service_name is ready on port $port!${NC}"
            return 0
        fi
        echo "  Attempt $attempt/$max_attempts..."
        sleep 2
        ((attempt++))
    done
    echo -e "${RED}✗ $service_name failed to start on port $port${NC}"
    return 1
}

# Check for .env file
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found. Creating from .env.example...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${GREEN}Created .env file. Please update with your API keys.${NC}"
    else
        echo -e "${RED}ERROR: .env.example not found!${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}Starting services in order...${NC}"
echo "See PORTS.md for port dictionary"
echo ""

# =============================================================================
# PHASE 1: Infrastructure Services (IDs 01-06)
# =============================================================================
echo -e "${BLUE}=== PHASE 1: Infrastructure ===${NC}"

echo "[01] Starting PostgreSQL (Port 9001)..."
docker-compose up -d postgres
wait_for_port "PostgreSQL" "localhost" 9001 60

echo "[02] Starting ClickHouse (Ports 9002-9003)..."
docker-compose up -d clickhouse
wait_for_port "ClickHouse HTTP" "localhost" 9002 60

echo "[04] Starting Redis (Port 9004)..."
docker-compose up -d redis
wait_for_port "Redis" "localhost" 9004 30

echo "[05] Starting MinIO (Ports 9005-9006)..."
docker-compose up -d minio
wait_for_service "MinIO Console" "http://localhost:9006" 30

# =============================================================================
# PHASE 2: Langfuse Platform (IDs 07-08)
# =============================================================================
echo ""
echo -e "${BLUE}=== PHASE 2: Langfuse Platform ===${NC}"

echo "[07] Starting Langfuse Worker (Port 9007)..."
docker-compose up -d langfuse-worker
sleep 10  # Give worker time to initialize

echo "[08] Starting Langfuse Web (Port 9008)..."
docker-compose up -d langfuse-web
wait_for_service "Langfuse Web" "http://localhost:9008" 60

# =============================================================================
# PHASE 3: Observability (IDs 09-11)
# =============================================================================
echo ""
echo -e "${BLUE}=== PHASE 3: Observability ===${NC}"

echo "[09-11] Starting OTEL Collector (Ports 9009-9011)..."
docker-compose up -d otel-collector
wait_for_port "OTEL gRPC" "localhost" 9009 30

# =============================================================================
# PHASE 4: AI Services (IDs 12-14)
# =============================================================================
echo ""
echo -e "${BLUE}=== PHASE 4: AI Services ===${NC}"

echo "[12] Starting LiteLLM Gateway (Port 9012)..."
docker-compose up -d litellm
wait_for_service "LiteLLM" "http://localhost:9012/health" 60

echo "[13] Starting MCP Gateway (Port 9013)..."
docker-compose up -d mcp-gateway
wait_for_service "MCP Gateway" "http://localhost:9013/health" 30

echo "[14] Starting AI Agent (Port 9014)..."
docker-compose up -d agent
wait_for_service "AI Agent" "http://localhost:9014/health" 30

# =============================================================================
# Startup Complete
# =============================================================================
echo ""
echo -e "${GREEN}=============================================="
echo "  All Services Started Successfully!"
echo "==============================================${NC}"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo "  • Langfuse UI:      http://localhost:9008"
echo "  • LiteLLM Gateway:  http://localhost:9012"
echo "  • MCP Gateway:      http://localhost:9013"
echo "  • AI Agent:         http://localhost:9014"
echo "  • MinIO Console:    http://localhost:9006"
echo ""
echo -e "${BLUE}API Documentation:${NC}"
echo "  • LiteLLM Docs:     http://localhost:9012/docs"
echo "  • MCP Gateway Docs: http://localhost:9013/docs"
echo "  • AI Agent Docs:    http://localhost:9014/docs"
echo ""
echo -e "${YELLOW}Quick Test:${NC}"
echo "  curl http://localhost:9014/agent/invoke -X POST \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"input\": \"Hello, AI!\"}'"
echo ""
echo "Run ./test-demo.sh for full integration tests"
