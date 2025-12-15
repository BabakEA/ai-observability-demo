#!/bin/bash
# ===========================================
# Service 09: OTEL Collector (Dynatrace)
# Ports: 9009 (gRPC), 9010 (HTTP), 9011 (Metrics)
# Container: obs-09-otel-collector
# ===========================================
# OpenTelemetry Collector - sends traces/metrics to Dynatrace

set -e
cd "$(dirname "$0")/.."

echo "[09] Starting Dynatrace OTEL Collector on ports 9009, 9010, 9011..."
docker compose up -d dynatrace-otel

echo "[09] Waiting for OTEL Collector to be ready..."
sleep 5

echo "[09] ✅ OTEL Collector is ready"
echo "     gRPC:    localhost:9009"
echo "     HTTP:    localhost:9010"
echo "     Metrics: localhost:9011 (internal)"
