# ===========================================
# Service 04: Redis
# Port: 9004 | Container: obs-04-redis
# ===========================================
# Langfuse cache and message queue

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[04] Starting Redis on port 9004..." -ForegroundColor Cyan
docker compose up -d redis

Write-Host "[04] Waiting for Redis to be healthy..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "[04] ✅ Redis is ready on port 9004" -ForegroundColor Green

Pop-Location
