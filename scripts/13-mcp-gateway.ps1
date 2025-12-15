# ===========================================
# Service 13: MCP Gateway
# Port: 9013 | Container: obs-13-mcp-gateway
# ===========================================
# IBM MCP Context Forge (mock) - AI Gateway with MCP Registry

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[13] Starting MCP Gateway on port 9013..." -ForegroundColor Cyan
docker compose up -d mcp-gateway

Write-Host "[13] Waiting for MCP Gateway to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "[13] ✅ MCP Gateway is ready" -ForegroundColor Green
Write-Host "     URL:      http://localhost:9013" -ForegroundColor Gray
Write-Host "     Invoke:   http://localhost:9013/mcp/invoke" -ForegroundColor Gray
Write-Host "     Registry: http://localhost:9013/mcp/registry/list" -ForegroundColor Gray

Pop-Location
