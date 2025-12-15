#!/bin/bash
# ===========================================
# AI Observability Demo - Test Script
# ===========================================
# Tests all services using the 9000-900XX port range

set -e

# Port configuration (see PORTS.md)
PORT_LANGFUSE=9008
PORT_OTEL_GRPC=9009
PORT_OTEL_HTTP=9010
PORT_LITELLM=9012
PORT_MCP=9013
PORT_AGENT=9014

echo "=========================================="
echo "AI Observability Demo - Test Suite"
echo "=========================================="
echo ""
echo "Port Range: 9001-9014 (see PORTS.md)"
echo ""

# Test 1: Health Checks
echo "📋 Test 1: Health Checks"
echo "------------------------"

echo -n "  [08] Langfuse (9008):   "
curl -s "http://localhost:$PORT_LANGFUSE" > /dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "  [12] LiteLLM (9012):    "
curl -s "http://localhost:$PORT_LITELLM/health" > /dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "  [13] MCP Gateway (9013): "
curl -s "http://localhost:$PORT_MCP/health" | jq -r '.status // "error"' 2>/dev/null || echo "❌ FAIL"

echo -n "  [14] AI Agent (9014):   "
curl -s "http://localhost:$PORT_AGENT/health" | jq -r '.status // "error"' 2>/dev/null || echo "❌ FAIL"

echo ""

# Test 2: Simple Prompt through MCP Gateway
echo "📋 Test 2: Simple Prompt (MCP Gateway :9013)"
echo "---------------------------------------------"
response=$(curl -s -X POST "http://localhost:$PORT_MCP/mcp/invoke" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is 2+2? Answer briefly."}')

echo "  Request ID: $(echo $response | jq -r '.request_id')"
echo "  Model:      $(echo $response | jq -r '.model')"
echo "  Latency:    $(echo $response | jq -r '.latency_ms')ms"
echo "  Response:   $(echo $response | jq -r '.response' | head -c 100)..."
echo ""

# Test 3: Complex Prompt with Agent
echo "📋 Test 3: Complex Prompt (AI Agent :9014)"
echo "-------------------------------------------"
response=$(curl -s -X POST "http://localhost:$PORT_AGENT/run" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Explain the benefits of hybrid observability for AI systems in 3 bullet points",
    "model": "llama-3.1-8b-instant"
  }')

echo "  Request ID:   $(echo $response | jq -r '.request_id')"
echo "  Total Tokens: $(echo $response | jq -r '.total_tokens')"
echo "  Steps:        $(echo $response | jq -r '.steps | length')"
echo "  Latency:      $(echo $response | jq -r '.latency_ms')ms"
echo ""

# Test 4: MCP Registry Operations
echo "📋 Test 4: MCP Registry (:9013)"
echo "--------------------------------"

echo "  Listing registered servers..."
servers=$(curl -s "http://localhost:$PORT_MCP/mcp/registry/list")
echo "  Count: $(echo $servers | jq -r '.count') servers registered"
echo ""

echo "  Adding custom MCP server..."
curl -s -X POST "http://localhost:$PORT_MCP/mcp/registry/add" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-mcp",
    "url": "http://test-mcp:8000",
    "capabilities": ["test_function"],
    "description": "Test MCP server"
  }' | jq -r '.status'

echo "  Verifying registration..."
curl -s "http://localhost:$PORT_MCP/mcp/registry/test-mcp" | jq -r '.name'

echo "  Removing test server..."
curl -s -X DELETE "http://localhost:$PORT_MCP/mcp/registry/remove/test-mcp" | jq -r '.status'
echo ""

# Test 5: Chaos Testing
echo "📋 Test 5: Chaos Testing (:9014)"
echo "---------------------------------"

echo "  Enabling chaos mode (2s delay)..."
curl -s -X POST "http://localhost:$PORT_AGENT/config" \
  -H "Content-Type: application/json" \
  -d '{"chaos_mode": true, "latency_ms": 2000}' | jq -r '.status'

echo "  Running request with chaos..."
start_time=$(date +%s%N)
response=$(curl -s -X POST "http://localhost:$PORT_AGENT/run" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello"}')
end_time=$(date +%s%N)
actual_latency=$(( (end_time - start_time) / 1000000 ))
echo "  Actual latency: ${actual_latency}ms (expected ~2000ms+)"

echo "  Disabling chaos mode..."
curl -s -X POST "http://localhost:$PORT_AGENT/config" \
  -H "Content-Type: application/json" \
  -d '{"chaos_mode": false, "latency_ms": 0}' | jq -r '.status'
echo ""

# Test 6: Direct LiteLLM Call
echo "📋 Test 6: Direct LiteLLM (:9012)"
echo "----------------------------------"
response=$(curl -s -X POST "http://localhost:$PORT_LITELLM/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3.1-8b-instant",
    "messages": [{"role": "user", "content": "Say hello"}]
  }')

echo "  Model:  $(echo $response | jq -r '.model')"
echo "  Tokens: $(echo $response | jq -r '.usage.total_tokens')"
echo ""

echo "=========================================="
echo "✅ All tests completed!"
echo "=========================================="
echo ""
echo "📊 Port Reference (PORTS.md):"
echo "   [08] Langfuse:    http://localhost:9008"
echo "   [12] LiteLLM:     http://localhost:9012"
echo "   [13] MCP Gateway: http://localhost:9013"
echo "   [14] AI Agent:    http://localhost:9014"
