# ===========================================
# Service 09: OTEL Collector (Dynatrace)
# Ports: 9009 (gRPC), 9010 (HTTP), 9011 (Metrics)
# Container: obs-09-otel-collector
# ===========================================
# OpenTelemetry Collector - sends traces/metrics to Dynatrace

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[09] Starting Dynatrace OTEL Collector on ports 9009, 9010, 9011..." -ForegroundColor Cyan
docker compose up -d dynatrace-otel

Write-Host "[09] Waiting for OTEL Collector to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "[09] ✅ OTEL Collector is ready" -ForegroundColor Green
Write-Host "     gRPC:    localhost:9009" -ForegroundColor Gray
Write-Host "     HTTP:    localhost:9010" -ForegroundColor Gray
Write-Host "     Metrics: localhost:9011 (internal)" -ForegroundColor Gray

Pop-Location
