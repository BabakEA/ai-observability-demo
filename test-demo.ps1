# ===========================================
# AI Observability Demo - Test Script (PowerShell)
# ===========================================
# Tests all services using the 9000-900XX port range

$ErrorActionPreference = "Stop"

# Port configuration (see PORTS.md)
$PORT_LANGFUSE = 9008
$PORT_OTEL_GRPC = 9009
$PORT_OTEL_HTTP = 9010
$PORT_LITELLM = 9012
$PORT_MCP = 9013
$PORT_AGENT = 9014

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AI Observability Demo - Test Suite" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Port Range: 9001-9014 (see PORTS.md)" -ForegroundColor Gray
Write-Host ""

# Test 1: Health Checks
Write-Host "📋 Test 1: Health Checks" -ForegroundColor Blue
Write-Host "------------------------" -ForegroundColor Blue

try {
    Invoke-WebRequest -Uri "http://localhost:$PORT_LANGFUSE" -TimeoutSec 5 -ErrorAction Stop | Out-Null
    Write-Host "  [08] Langfuse (9008):    ✅ OK" -ForegroundColor Green
} catch {
    Write-Host "  [08] Langfuse (9008):    ❌ FAIL" -ForegroundColor Red
}

try {
    $response = Invoke-RestMethod -Uri "http://localhost:$PORT_LITELLM/health" -TimeoutSec 5
    Write-Host "  [12] LiteLLM (9012):     ✅ OK" -ForegroundColor Green
} catch {
    Write-Host "  [12] LiteLLM (9012):     ❌ FAIL" -ForegroundColor Red
}

try {
    $response = Invoke-RestMethod -Uri "http://localhost:$PORT_MCP/health" -TimeoutSec 5
    Write-Host "  [13] MCP Gateway (9013): $($response.status)" -ForegroundColor Green
} catch {
    Write-Host "  [13] MCP Gateway (9013): ❌ FAIL" -ForegroundColor Red
}

try {
    $response = Invoke-RestMethod -Uri "http://localhost:$PORT_AGENT/health" -TimeoutSec 5
    Write-Host "  [14] AI Agent (9014):    $($response.status)" -ForegroundColor Green
} catch {
    Write-Host "  [14] AI Agent (9014):    ❌ FAIL" -ForegroundColor Red
}

Write-Host ""

# Test 2: Simple Prompt through MCP Gateway
Write-Host "📋 Test 2: Simple Prompt (MCP Gateway :9013)" -ForegroundColor Blue
Write-Host "---------------------------------------------" -ForegroundColor Blue

$body = @{ prompt = "What is 2+2? Answer briefly." } | ConvertTo-Json
$response = Invoke-RestMethod -Uri "http://localhost:$PORT_MCP/mcp/invoke" -Method Post -ContentType "application/json" -Body $body

Write-Host "  Request ID: $($response.request_id)" -ForegroundColor Gray
Write-Host "  Model:      $($response.model)" -ForegroundColor Gray
Write-Host "  Latency:    $($response.latency_ms)ms" -ForegroundColor Gray
Write-Host "  Response:   $($response.response.Substring(0, [Math]::Min(100, $response.response.Length)))..." -ForegroundColor Gray
Write-Host ""

# Test 3: Complex Prompt with Agent
Write-Host "📋 Test 3: Complex Prompt (AI Agent :9014)" -ForegroundColor Blue
Write-Host "-------------------------------------------" -ForegroundColor Blue

$body = @{
    prompt = "Explain the benefits of hybrid observability for AI systems in 3 bullet points"
    model = "llama-3.1-8b-instant"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:$PORT_AGENT/run" -Method Post -ContentType "application/json" -Body $body

Write-Host "  Request ID:   $($response.request_id)" -ForegroundColor Gray
Write-Host "  Total Tokens: $($response.total_tokens)" -ForegroundColor Gray
Write-Host "  Steps:        $($response.steps.Count)" -ForegroundColor Gray
Write-Host "  Latency:      $($response.latency_ms)ms" -ForegroundColor Gray
Write-Host ""

# Test 4: MCP Registry Operations
Write-Host "📋 Test 4: MCP Registry (:9013)" -ForegroundColor Blue
Write-Host "--------------------------------" -ForegroundColor Blue

Write-Host "  Listing registered servers..." -ForegroundColor Gray
$servers = Invoke-RestMethod -Uri "http://localhost:$PORT_MCP/mcp/registry/list" -Method Get
Write-Host "  Count: $($servers.count) servers registered" -ForegroundColor Gray
Write-Host ""

Write-Host "  Adding custom MCP server..." -ForegroundColor Gray
$body = @{
    name = "test-mcp"
    url = "http://test-mcp:8000"
    capabilities = @("test_function")
    description = "Test MCP server"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:$PORT_MCP/mcp/registry/add" -Method Post -ContentType "application/json" -Body $body
Write-Host "  Status: $($response.status)" -ForegroundColor Gray

Write-Host "  Verifying registration..." -ForegroundColor Gray
$response = Invoke-RestMethod -Uri "http://localhost:$PORT_MCP/mcp/registry/test-mcp" -Method Get
Write-Host "  Found: $($response.name)" -ForegroundColor Gray

Write-Host "  Removing test server..." -ForegroundColor Gray
$response = Invoke-RestMethod -Uri "http://localhost:$PORT_MCP/mcp/registry/remove/test-mcp" -Method Delete
Write-Host "  Status: $($response.status)" -ForegroundColor Gray
Write-Host ""

# Test 5: Chaos Testing
Write-Host "📋 Test 5: Chaos Testing (:9014)" -ForegroundColor Blue
Write-Host "---------------------------------" -ForegroundColor Blue

Write-Host "  Enabling chaos mode (2s delay)..." -ForegroundColor Gray
$body = @{ chaos_mode = $true; latency_ms = 2000 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri "http://localhost:$PORT_AGENT/config" -Method Post -ContentType "application/json" -Body $body
Write-Host "  Status: $($response.status)" -ForegroundColor Gray

Write-Host "  Running request with chaos..." -ForegroundColor Gray
$startTime = Get-Date
$body = @{ prompt = "Hello" } | ConvertTo-Json
$response = Invoke-RestMethod -Uri "http://localhost:$PORT_AGENT/run" -Method Post -ContentType "application/json" -Body $body
$endTime = Get-Date
$actualLatency = ($endTime - $startTime).TotalMilliseconds
Write-Host "  Actual latency: $([Math]::Round($actualLatency))ms (expected ~2000ms+)" -ForegroundColor Gray

Write-Host "  Disabling chaos mode..." -ForegroundColor Gray
$body = @{ chaos_mode = $false; latency_ms = 0 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri "http://localhost:$PORT_AGENT/config" -Method Post -ContentType "application/json" -Body $body
Write-Host "  Status: $($response.status)" -ForegroundColor Gray
Write-Host ""

# Test 6: Direct LiteLLM Call
Write-Host "📋 Test 6: Direct LiteLLM (:9012)" -ForegroundColor Blue
Write-Host "----------------------------------" -ForegroundColor Blue

$body = @{
    model = "llama-3.1-8b-instant"
    messages = @(
        @{ role = "user"; content = "Say hello" }
    )
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "http://localhost:$PORT_LITELLM/v1/chat/completions" -Method Post -ContentType "application/json" -Body $body
Write-Host "  Model:  $($response.model)" -ForegroundColor Gray
Write-Host "  Tokens: $($response.usage.total_tokens)" -ForegroundColor Gray
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✅ All tests completed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Port Reference (PORTS.md):" -ForegroundColor White
Write-Host "   [08] Langfuse:    http://localhost:9008" -ForegroundColor Gray
Write-Host "   [12] LiteLLM:     http://localhost:9012" -ForegroundColor Gray
Write-Host "   [13] MCP Gateway: http://localhost:9013" -ForegroundColor Gray
Write-Host "   [14] AI Agent:    http://localhost:9014" -ForegroundColor Gray
