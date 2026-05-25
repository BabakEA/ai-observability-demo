# ===========================================
# Service 05: MinIO
# Ports: 9005 (API), 9006 (Console) | Container: obs-05-minio
# ===========================================
# S3-compatible object storage for Langfuse

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..

Write-Host "[05] Starting MinIO on ports 9005, 9006..." -ForegroundColor Cyan
docker compose up -d minio

Write-Host "[05] Waiting for MinIO to be healthy..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "[05] ✅ MinIO is ready" -ForegroundColor Green
Write-Host "     API:     http://localhost:9005" -ForegroundColor Gray
Write-Host "     Console: http://localhost:9006 (internal only)" -ForegroundColor Gray

Pop-Location
