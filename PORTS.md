# Port Dictionary - AI Observability Demo

All services use ports in the **9000-900XX** range for easy management.

## Port Assignments

| ID | Port  | Service           | Description                          | Protocol | Internal/External |
|----|-------|-------------------|--------------------------------------|----------|-------------------|
| 01 | 9001  | PostgreSQL        | Langfuse database                    | TCP      | Internal (127.0.0.1) |
| 02 | 9002  | ClickHouse HTTP   | Langfuse analytics (HTTP API)        | HTTP     | Internal (127.0.0.1) |
| 03 | 9003  | ClickHouse Native | Langfuse analytics (Native protocol) | TCP      | Internal (127.0.0.1) |
| 04 | 9004  | Redis             | Langfuse cache & queue               | TCP      | Internal (127.0.0.1) |
| 05 | 9005  | MinIO API         | S3-compatible object storage         | HTTP     | External |
| 06 | 9006  | MinIO Console     | MinIO web dashboard                  | HTTP     | Internal (127.0.0.1) |
| 07 | 9007  | Langfuse Worker   | Background job processor             | HTTP     | Internal (127.0.0.1) |
| 08 | 9008  | Langfuse Web      | Langfuse UI & API                    | HTTP     | External |
| 09 | 9009  | OTEL gRPC         | Dynatrace OTEL Collector (gRPC)      | gRPC     | External |
| 10 | 9010  | OTEL HTTP         | Dynatrace OTEL Collector (HTTP)      | HTTP     | External |
| 11 | 9011  | OTEL Metrics      | Collector self-metrics (Prometheus)  | HTTP     | Internal (127.0.0.1) |
| 12 | 9012  | LiteLLM           | LLM Gateway (OpenAI-compatible)      | HTTP     | External |
| 13 | 9013  | MCP Gateway       | IBM MCP Context Forge mock           | HTTP     | External |
| 14 | 9014  | AI Agent          | Demo AI Agent service                | HTTP     | External |

## Quick Reference

### User-Facing Services (External Access)

```
┌─────────────────────────────────────────────────────────────┐
│  Langfuse UI          http://localhost:9008                 │
│  LiteLLM Gateway      http://localhost:9012                 │
│  MCP Gateway          http://localhost:9013                 │
│  AI Agent             http://localhost:9014                 │
│  MinIO Storage        http://localhost:9005                 │
└─────────────────────────────────────────────────────────────┘
```

### Infrastructure Services (Internal Only)

```
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL           localhost:9001 (127.0.0.1 only)       │
│  ClickHouse HTTP      localhost:9002 (127.0.0.1 only)       │
│  ClickHouse Native    localhost:9003 (127.0.0.1 only)       │
│  Redis                localhost:9004 (127.0.0.1 only)       │
│  MinIO Console        localhost:9006 (127.0.0.1 only)       │
│  Langfuse Worker      localhost:9007 (127.0.0.1 only)       │
└─────────────────────────────────────────────────────────────┘
```

### Observability Endpoints

```
┌─────────────────────────────────────────────────────────────┐
│  OTEL gRPC Ingest     localhost:9009                        │
│  OTEL HTTP Ingest     localhost:9010                        │
│  OTEL Metrics         localhost:9011 (127.0.0.1 only)       │
└─────────────────────────────────────────────────────────────┘
```

## Startup Order

Services must be started in the following order due to dependencies:

```
Phase 1: Infrastructure (ID 01-06)
├── 01. PostgreSQL      (no dependencies)
├── 02. ClickHouse      (no dependencies)
├── 03. Redis           (no dependencies)
└── 04. MinIO           (no dependencies)

Phase 2: Langfuse Stack (ID 07-08)
├── 07. Langfuse Worker (depends on: postgres, clickhouse, redis, minio)
└── 08. Langfuse Web    (depends on: postgres, clickhouse, redis, minio)

Phase 3: Observability (ID 09-11)
└── 09. OTEL Collector  (no dependencies, but needed by apps)

Phase 4: Application Layer (ID 12-14)
├── 12. LiteLLM         (depends on: otel-collector)
├── 13. MCP Gateway     (depends on: litellm, otel-collector)
└── 14. AI Agent        (depends on: litellm, otel-collector)
```

## Health Check URLs

| ID | Service       | Health Check URL                        |
|----|---------------|-----------------------------------------|
| 08 | Langfuse      | http://localhost:9008/api/public/health |
| 12 | LiteLLM       | http://localhost:9012/health            |
| 13 | MCP Gateway   | http://localhost:9013/health            |
| 14 | AI Agent      | http://localhost:9014/health            |

## Network Diagram

```
                    ┌──────────────────┐
                    │   User/Client    │
                    └────────┬─────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
    ┌─────────┐        ┌──────────┐        ┌─────────┐
    │Langfuse │        │   MCP    │        │ LiteLLM │
    │  :9008  │        │ Gateway  │        │  :9012  │
    └─────────┘        │  :9013   │        └────┬────┘
         │             └────┬─────┘              │
         │                  │                    │
         │                  ▼                    │
         │             ┌─────────┐               │
         │             │   AI    │◄──────────────┘
         │             │  Agent  │
         │             │  :9014  │
         │             └────┬────┘
         │                  │
         │    ┌─────────────┼─────────────┐
         │    │             │             │
         ▼    ▼             ▼             ▼
    ┌──────────────┐   ┌─────────┐   ┌──────────┐
    │     OTEL     │   │Langfuse │   │Dynatrace │
    │   Collector  │   │   SDK   │   │  (SaaS)  │
    │ :9009/:9010  │   │         │   │          │
    └──────────────┘   └─────────┘   └──────────┘
```

## Environment Variables

Update your `.env` file with these port references:

```bash
# Port Configuration
POSTGRES_PORT=9001
CLICKHOUSE_HTTP_PORT=9002
CLICKHOUSE_NATIVE_PORT=9003
REDIS_PORT=9004
MINIO_API_PORT=9005
MINIO_CONSOLE_PORT=9006
LANGFUSE_WORKER_PORT=9007
LANGFUSE_WEB_PORT=9008
OTEL_GRPC_PORT=9009
OTEL_HTTP_PORT=9010
OTEL_METRICS_PORT=9011
LITELLM_PORT=9012
MCP_GATEWAY_PORT=9013
AGENT_PORT=9014
```
