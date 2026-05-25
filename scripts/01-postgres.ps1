# ===========================================
# Service 01: PostgreSQL
# Port: 9001 | Container: obs-01-postgres
# ===========================================
# Langfuse database - stores metadata, users, projects

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[01] Starting PostgreSQL on port 9001..." -ForegroundColor Cyan
docker compose up -d postgres

Write-Host "[01] Waiting for PostgreSQL to be healthy..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "[01] ✅ PostgreSQL is ready on port 9001" -ForegroundColor Green

Pop-Location
