# ===========================================
# Service 14: AI Agent
# Port: 9014 | Container: obs-14-ai-agent
# ===========================================
# Demo AI Agent with dual observability (Dynatrace + Langfuse)

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[14] Starting AI Agent on port 9014..." -ForegroundColor Cyan
docker compose up -d agent

Write-Host "[14] Waiting for AI Agent to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "[14] ✅ AI Agent is ready" -ForegroundColor Green
Write-Host "     URL:    http://localhost:9014" -ForegroundColor Gray
Write-Host "     Run:    http://localhost:9014/run" -ForegroundColor Gray
Write-Host "     Config: http://localhost:9014/config" -ForegroundColor Gray

Pop-Location
