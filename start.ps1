# =============================================================================
# AI Observability Demo - Full Stack Startup Script (PowerShell)
# =============================================================================
# Starts all services in the correct order with health checks
# Port Range: 9001-9014 (see PORTS.md for full dictionary)
# =============================================================================

param(
    [switch]$SkipHealthChecks,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  AI Observability Demo - Startup Script" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# Function to wait for HTTP service
function Wait-ForService {
    param(
        [string]$ServiceName,
        [string]$Url,
        [int]$MaxAttempts = 30
    )
    
    Write-Host "Waiting for $ServiceName..." -ForegroundColor Yellow
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "✓ $ServiceName is ready!" -ForegroundColor Green
                return $true
            }
        }
        catch {
            # Service not ready yet
        }
        Write-Host "  Attempt $attempt/$MaxAttempts..."
        Start-Sleep -Seconds 2
        $attempt++
    }
    Write-Host "✗ $ServiceName failed to start" -ForegroundColor Red
    return $false
}

# Function to wait for TCP port
function Wait-ForPort {
    param(
        [string]$ServiceName,
        [string]$Host,
        [int]$Port,
        [int]$MaxAttempts = 30
    )
    
    Write-Host "Waiting for $ServiceName on port $Port..." -ForegroundColor Yellow
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $result = $tcpClient.BeginConnect($Host, $Port, $null, $null)
            $success = $result.AsyncWaitHandle.WaitOne(2000)
            $tcpClient.Close()
            
            if ($success) {
                Write-Host "✓ $ServiceName is ready on port $Port!" -ForegroundColor Green
                return $true
            }
        }
        catch {
            # Service not ready yet
        }
        Write-Host "  Attempt $attempt/$MaxAttempts..."
        Start-Sleep -Seconds 2
        $attempt++
    }
    Write-Host "✗ $ServiceName failed to start on port $Port" -ForegroundColor Red
    return $false
}

# Check for .env file
if (-not (Test-Path ".env")) {
    Write-Host "No .env file found. Creating from .env.example..." -ForegroundColor Yellow
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "Created .env file. Please update with your API keys." -ForegroundColor Green
    }
    else {
        Write-Host "ERROR: .env.example not found!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Starting services in order..." -ForegroundColor Blue
Write-Host "See PORTS.md for port dictionary"
Write-Host ""

# =============================================================================
# PHASE 1: Infrastructure Services (IDs 01-06)
# =============================================================================
Write-Host "=== PHASE 1: Infrastructure ===" -ForegroundColor Blue

Write-Host "[01] Starting PostgreSQL (Port 9001)..." -ForegroundColor White
docker-compose up -d postgres
if (-not $SkipHealthChecks) { Wait-ForPort "PostgreSQL" "localhost" 9001 60 }

Write-Host "[02] Starting ClickHouse (Ports 9002-9003)..." -ForegroundColor White
docker-compose up -d clickhouse
if (-not $SkipHealthChecks) { Wait-ForPort "ClickHouse HTTP" "localhost" 9002 60 }

Write-Host "[04] Starting Redis (Port 9004)..." -ForegroundColor White
docker-compose up -d redis
if (-not $SkipHealthChecks) { Wait-ForPort "Redis" "localhost" 9004 30 }

Write-Host "[05] Starting MinIO (Ports 9005-9006)..." -ForegroundColor White
docker-compose up -d minio
if (-not $SkipHealthChecks) { Wait-ForService "MinIO Console" "http://localhost:9006" 30 }

# =============================================================================
# PHASE 2: Langfuse Platform (IDs 07-08)
# =============================================================================
Write-Host ""
Write-Host "=== PHASE 2: Langfuse Platform ===" -ForegroundColor Blue

Write-Host "[07] Starting Langfuse Worker (Port 9007)..." -ForegroundColor White
docker-compose up -d langfuse-worker
Start-Sleep -Seconds 10  # Give worker time to initialize

Write-Host "[08] Starting Langfuse Web (Port 9008)..." -ForegroundColor White
docker-compose up -d langfuse-web
if (-not $SkipHealthChecks) { Wait-ForService "Langfuse Web" "http://localhost:9008" 60 }

# =============================================================================
# PHASE 3: Observability (IDs 09-11)
# =============================================================================
Write-Host ""
Write-Host "=== PHASE 3: Observability ===" -ForegroundColor Blue

Write-Host "[09-11] Starting OTEL Collector (Ports 9009-9011)..." -ForegroundColor White
docker-compose up -d otel-collector
if (-not $SkipHealthChecks) { Wait-ForPort "OTEL gRPC" "localhost" 9009 30 }

# =============================================================================
# PHASE 4: AI Services (IDs 12-14)
# =============================================================================
Write-Host ""
Write-Host "=== PHASE 4: AI Services ===" -ForegroundColor Blue

Write-Host "[12] Starting LiteLLM Gateway (Port 9012)..." -ForegroundColor White
docker-compose up -d litellm
if (-not $SkipHealthChecks) { Wait-ForService "LiteLLM" "http://localhost:9012/health" 60 }

Write-Host "[13] Starting MCP Gateway (Port 9013)..." -ForegroundColor White
docker-compose up -d mcp-gateway
if (-not $SkipHealthChecks) { Wait-ForService "MCP Gateway" "http://localhost:9013/health" 30 }

Write-Host "[14] Starting AI Agent (Port 9014)..." -ForegroundColor White
docker-compose up -d agent
if (-not $SkipHealthChecks) { Wait-ForService "AI Agent" "http://localhost:9014/health" 30 }

# =============================================================================
# Startup Complete
# =============================================================================
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  All Services Started Successfully!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Blue
Write-Host "  • Langfuse UI:      http://localhost:9008"
Write-Host "  • LiteLLM Gateway:  http://localhost:9012"
Write-Host "  • MCP Gateway:      http://localhost:9013"
Write-Host "  • AI Agent:         http://localhost:9014"
Write-Host "  • MinIO Console:    http://localhost:9006"
Write-Host ""
Write-Host "API Documentation:" -ForegroundColor Blue
Write-Host "  • LiteLLM Docs:     http://localhost:9012/docs"
Write-Host "  • MCP Gateway Docs: http://localhost:9013/docs"
Write-Host "  • AI Agent Docs:    http://localhost:9014/docs"
Write-Host ""
Write-Host "Quick Test:" -ForegroundColor Yellow
Write-Host '  Invoke-RestMethod -Uri "http://localhost:9014/agent/invoke" -Method POST -ContentType "application/json" -Body ''{"input": "Hello, AI!"}'''
Write-Host ""
Write-Host "Run .\test-demo.ps1 for full integration tests"
