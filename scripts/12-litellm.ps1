# ===========================================
# Service 12: LiteLLM
# Port: 9012 | Container: obs-12-litellm
# ===========================================
# OpenAI-compatible LLM Gateway

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[12] Starting LiteLLM on port 9012..." -ForegroundColor Cyan
docker compose up -d litellm

Write-Host "[12] Waiting for LiteLLM to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "[12] ✅ LiteLLM is ready" -ForegroundColor Green
Write-Host "     URL:    http://localhost:9012" -ForegroundColor Gray
Write-Host "     OpenAI: http://localhost:9012/v1/chat/completions" -ForegroundColor Gray

Pop-Location
