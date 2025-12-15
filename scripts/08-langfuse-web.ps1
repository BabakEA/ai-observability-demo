# ===========================================
# Service 08: Langfuse Web
# Port: 9008 | Container: obs-08-langfuse-web
# ===========================================
# Langfuse UI and API - AI/LLM Observability Dashboard

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[08] Starting Langfuse Web on port 9008..." -ForegroundColor Cyan
docker compose up -d langfuse-web

Write-Host "[08] Waiting for Langfuse Web to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "[08] ✅ Langfuse Web is ready" -ForegroundColor Green
Write-Host "     URL: http://localhost:9008" -ForegroundColor Gray

Pop-Location
