# ===========================================
# Service 02: ClickHouse
# Ports: 9002 (HTTP), 9003 (Native) | Container: obs-02-clickhouse
# ===========================================
# Langfuse analytics - high-volume time-series data

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[02] Starting ClickHouse on ports 9002, 9003..." -ForegroundColor Cyan
docker compose up -d clickhouse

Write-Host "[02] Waiting for ClickHouse to be healthy..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "[02] ✅ ClickHouse is ready on ports 9002 (HTTP), 9003 (Native)" -ForegroundColor Green

Pop-Location
