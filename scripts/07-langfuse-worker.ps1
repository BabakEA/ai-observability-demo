# ===========================================
# Service 07: Langfuse Worker
# Port: 9007 | Container: obs-07-langfuse-worker
# ===========================================
# Background job processor for Langfuse

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[07] Starting Langfuse Worker on port 9007..." -ForegroundColor Cyan
docker compose up -d langfuse-worker

Write-Host "[07] Waiting for Langfuse Worker to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "[07] ✅ Langfuse Worker is ready on port 9007" -ForegroundColor Green

Pop-Location
