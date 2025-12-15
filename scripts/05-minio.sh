#!/bin/bash
# ===========================================
# Service 05: MinIO
# Ports: 9005 (API), 9006 (Console) | Container: obs-05-minio
# ===========================================
# S3-compatible object storage for Langfuse

set -e
cd "$(dirname "$0")/.."

echo "[05] Starting MinIO on ports 9005, 9006..."
docker compose up -d minio

echo "[05] Waiting for MinIO to be healthy..."
sleep 5

echo "[05] ✅ MinIO is ready"
echo "     API:     http://localhost:9005"
echo "     Console: http://localhost:9006 (internal only)"
