#!/bin/bash
# ===========================================
# Service 01: PostgreSQL
# Port: 9001 | Container: obs-01-postgres
# ===========================================
# Langfuse database - stores metadata, users, projects

set -e
cd "$(dirname "$0")/.."

echo "[01] Starting PostgreSQL on port 9001..."
docker compose up -d postgres

echo "[01] Waiting for PostgreSQL to be healthy..."
until docker compose exec postgres pg_isready -U langfuse > /dev/null 2>&1; do
    echo "  Waiting..."
    sleep 2
done

echo "[01] ✅ PostgreSQL is ready on port 9001"
