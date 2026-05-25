# Hybrid Observability for LLMs & AI Agents

## Executive Summary

This white paper proposes a **hybrid observability architecture** for Large Language Models (LLMs) and AI Agents, combining **enterprise-grade observability** (Dynatrace) with **AI-native observability** (Langfuse). The approach is designed to support environments where a **central gateway (e.g., IBM MCP Context Forge)** orchestrates AI traffic while multiple observability layers provide complementary insights.

The document includes:
- Architecture rationale
- Required observability layers
- Mermaid diagrams for demos and presentations
- A concrete demo flow

---

## 1. Problem Statement

Traditional observability platforms (APM, infra monitoring, logs, traces) are not sufficient for AI workloads:
- They do **not track prompts, responses, tokens, or agent reasoning steps**
- They lack **LLM session awareness**
- They cannot evaluate **model quality, hallucinations, or prompt regressions**

At the same time, AI-native tools alone cannot replace:
- Infrastructure metrics
- Network visibility
- Enterprise-grade governance and SRE workflows

**Conclusion:** A hybrid observability model is required.

---

## 2. Observability Layers (Conceptual Model)

### Required Layers

1. **Infrastructure & Platform Observability**  
   CPU, memory, GPU, containers, network, failures

2. **Application & Gateway Observability**  
   API latency, error rates, dependency mapping (IBM MCP Gateway)

3. **AI / LLM Observability**  
   Prompts, responses, token usage, model versions, agent steps

4. **Correlation Layer**  
   Ability to correlate AI behavior with infra or gateway issues

---

## 3. High-Level Hybrid Architecture (Mermaid)

### Diagram 1 – Hybrid Observability Overview

```mermaid
flowchart LR
    User[User / Supervisor]
    User --> MCP[IBM MCP Context Forge Gateway]

    MCP --> Agent[AI Agent / LLM Service]

    %% Observability paths
    Agent -->|OTel Traces & Metrics| OTel[OpenTelemetry SDK]
    OTel --> DTCollector[Dynatrace OTEL Collector]
    DTCollector --> Dynatrace[Dynatrace Platform]

    Agent -->|LLM Events| LangfuseSDK[Langfuse SDK]
    LangfuseSDK --> Langfuse[Langfuse Platform]

    Dynatrace --> Dash1[Infra & APM Dashboards]
    Langfuse --> Dash2[LLM & Agent Dashboards]
```

### Explanation
- **IBM MCP Gateway** acts as the centralized AI control plane
- AI agents emit telemetry through **two channels**:
  - OpenTelemetry → Dynatrace (performance, infra, reliability)
  - Langfuse SDK → Langfuse (LLM-specific semantics)
- Dashboards are **separate but correlated**

---

## 4. Runtime Telemetry Flow (Mermaid)

### Diagram 2 – Telemetry Data Flow

```mermaid
sequenceDiagram
    participant U as User
    participant G as MCP Gateway
    participant A as AI Agent
    participant D as Dynatrace
    participant L as Langfuse

    U->>G: Prompt / Request
    G->>A: Routed AI Call

    A->>L: Prompt, Response, Tokens, Metadata
    A->>D: Latency, Errors, Traces (OTel)

    A-->>G: AI Response
    G-->>U: Final Output
```

### Explanation
- **Dynatrace** captures *how well* the system performs
- **Langfuse** captures *what the model did and why*
- Both observe the same request but from different lenses

---

## 5. Langfuse Internal Architecture (Mermaid)

### Diagram 3 – Langfuse Stack (Self-Hosted)

```mermaid
flowchart TB
    App[AI Agent]
    App --> SDK[Langfuse SDK]

    SDK --> API[Langfuse API]
    API --> DB[(PostgreSQL)]
    API --> CH[(ClickHouse)]
    API --> Redis[(Redis)]

    CH --> UI[Langfuse Dashboard]
    DB --> UI
```

### Explanation
- Langfuse stores:
  - Structured metadata (Postgres)
  - High-volume analytics (ClickHouse)
- Enables **prompt comparison, latency histograms, token analysis**

---

## 6. Dynatrace Role in the Architecture

### What Dynatrace Covers
- Gateway latency (IBM MCP)
- AI service response times
- Container, VM, GPU metrics
- Distributed tracing across services

### Diagram 4 – Dynatrace Observability Scope

```mermaid
flowchart LR
    Infra[Containers / GPUs / VMs]
    Infra --> Dynatrace

    Gateway[MCP Gateway]
    Gateway --> Dynatrace

    Agent[AI Agent]
    Agent --> Dynatrace

    Dynatrace --> Smartscape[Service Map & APM Views]
```

---

## 7. Correlation Model

### Key Correlation Keys

| Dimension | Used By | Purpose |
|--------|--------|--------|
| request_id | Dynatrace + Langfuse | End-to-end tracing |
| session_id | Langfuse | Agent session analysis |
| model_version | Langfuse | Regression detection |
| service.name | Dynatrace | Dependency mapping |
| environment | Both | Prod / Test separation |

---

## 8. Demo Scenario (Recommended)

### Step-by-Step Demo Flow

1. Start Docker Compose:
   - Langfuse stack
   - AI Agent service
   - Dynatrace OTEL Collector

2. Send sample prompts through MCP Gateway

3. Show **Dynatrace Dashboard**:
   - Latency spikes
   - Error rates
   - Dependency graph

4. Show **Langfuse Dashboard**:
   - Prompt/response history
   - Token usage
   - Agent steps

5. Correlate:
   - High latency in Dynatrace ↔ Long prompt chain in Langfuse

---

## 9. Why Hybrid Observability Is Strategic

- Avoids vendor lock-in
- Separates infra health from AI quality
- Enables AI governance and auditability
- Aligns with OpenTelemetry standards
- Future-proof for multi-model and multi-agent systems

---

## 10. Conclusion

A **hybrid observability architecture** is the only scalable way to monitor AI systems in regulated, enterprise environments.

- **Dynatrace** ensures reliability, performance, and SRE excellence
- **Langfuse** ensures transparency, quality, and explainability of AI behavior

Together, they form a **complete observability fabric** for AI-powered platforms.

---

## 11. Local Demo Setup – Docker Compose

This section explains **how to run the full hybrid observability demo locally** using **Git Bash + Docker Compose**.

### 11.1 Prerequisites

- Docker Desktop (with Docker Compose v2)
- Git Bash (Windows) or any Unix shell
- Dynatrace SaaS or Managed environment (trial is sufficient)
- Dynatrace API Token with:
  - Ingest metrics
  - Ingest traces

---

## 12. Folder Structure (Recommended)

```text
hybrid-observability-demo/
├── docker-compose.yml
├── otel/
│   └── otel-config.yaml
├── agent/
│   └── app.py
└── README.md
```

---

## 13. Docker Compose – Langfuse + OTEL + Agent

```yaml
version: "3.9"

services:
  # -------------------
  # Langfuse Stack
  # -------------------
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: langfuse
      POSTGRES_PASSWORD: langfuse
      POSTGRES_DB: langfuse
    ports:
      - "5432:5432"

  clickhouse:
    image: clickhouse/clickhouse-server:latest
    ports:
      - "8123:8123"

  redis:
    image: redis:7
    ports:
      - "6379:6379"

  langfuse:
    image: ghcr.io/langfuse/langfuse:latest
    depends_on:
      - postgres
      - clickhouse
      - redis
    environment:
      DATABASE_URL: postgresql://langfuse:langfuse@postgres:5432/langfuse
      CLICKHOUSE_URL: http://clickhouse:8123
      REDIS_URL: redis://redis:6379
      NEXTAUTH_URL: http://localhost:3000
      NEXTAUTH_SECRET: dev-secret
    ports:
      - "3000:3000"

  # -------------------
  # Dynatrace OTEL Collector
  # -------------------
  dynatrace-otel:
    image: ghcr.io/dynatrace/dynatrace-otel-collector/dynatrace-otel-collector:latest
    volumes:
      - ./otel/otel-config.yaml:/etc/otelcol/config.yaml
    command: ["--config=/etc/otelcol/config.yaml"]
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP

  # -------------------
  # AI Agent / LLM Gateway
  # -------------------
  agent:
    build: ./agent
    environment:
      OTEL_EXPORTER_OTLP_ENDPOINT: http://dynatrace-otel:4317
      LANGFUSE_HOST: http://langfuse:3000
      LANGFUSE_PUBLIC_KEY: demo-public
      LANGFUSE_SECRET_KEY: demo-secret
    ports:
      - "8080:8080"
    depends_on:
      - dynatrace-otel
      - langfuse
```

---

## 14. OpenTelemetry Configuration for Dynatrace

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

exporters:
  otlp/dynatrace:
    endpoint: "https://<YOUR_ENV>.live.dynatrace.com/api/v2/otlp"
    headers:
      Authorization: "Api-Token <DYNATRACE_API_TOKEN>"

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [otlp/dynatrace]
    metrics:
      receivers: [otlp]
      exporters: [otlp/dynatrace]
```

---

## 15. AI Agent Example (Observed Pipeline)

```python
from langfuse import Langfuse
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter())
)

langfuse = Langfuse()

with tracer.start_as_current_span("llm_request"):
    trace_id = "req-123"
    langfuse.trace(name="demo", id=trace_id)
    response = "Hello from AI Agent"
    print(response)
```

---

## 16. How to Run (Git Bash)

```bash
git clone <your-repo>
cd hybrid-observability-demo
docker compose pull
docker compose up -d
```

### Access Points

| Component | URL |
|--------|-----|
| Langfuse UI | http://localhost:3000 |
| AI Agent | http://localhost:8080 |
| OTEL Collector | http://localhost:4318 |

---

## 17. Dynatrace Validation Steps

1. Open Dynatrace UI
2. Go to **Distributed Traces**
3. Filter by service name: `ai-agent`
4. Validate:
   - Latency
   - Error rate
   - Trace depth

---

## 18. IBM MCP Gateway (Local Mock)

For demo purposes, we run a **lightweight MCP-like gateway** that:
- Exposes a single AI endpoint
- Forwards requests to the AI Agent
- Is fully observable via Dynatrace

### MCP Gateway (FastAPI – example)

```python
# mcp_gateway.py
from fastapi import FastAPI
import requests

app = FastAPI()

@app.post("/mcp/invoke")
def invoke(prompt: str):
    response = requests.post(
        "http://agent:8080/run",
        json={"prompt": prompt}
    )
    return response.json()
```

### MCP Gateway Dockerfile

```dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install fastapi uvicorn requests opentelemetry-sdk opentelemetry-exporter-otlp
COPY mcp_gateway.py .
CMD ["uvicorn", "mcp_gateway:app", "--host", "0.0.0.0", "--port", "7070"]
```

Expose via Docker Compose:

```yaml
  mcp-gateway:
    build: ./mcp
    ports:
      - "7070:7070"
    environment:
      OTEL_SERVICE_NAME: mcp-gateway
      OTEL_EXPORTER_OTLP_ENDPOINT: http://dynatrace-otel:4317
```

---

## 19. Dynatrace Dashboard (Conceptual)

For demo simplicity, Dynatrace dashboards are created **visually**.
Recommended tiles:

- Service response time (mcp-gateway)
- Error rate (ai-agent)
- Trace count (LLM requests)
- Dependency graph (Gateway → Agent)

> Dynatrace dashboard JSON can be exported later for reuse.

---

## 20. LiteLLM Integration (OpenAI‑compatible & Local LLM)

This demo **does NOT require OpenAI or Azure OpenAI**.
Instead, we use **LiteLLM** as an **OpenAI-compatible LLM Gateway**, supporting:
- Local LLMs (Llama, Mistral, Phi, etc.)
- Remote providers (if needed later)

This aligns perfectly with enterprise and offline demo constraints.

---

### 20.1 LiteLLM Service (Docker)

```yaml
  litellm:
    image: ghcr.io/berriai/litellm:latest
    command: ["--config", "/config/litellm.yaml"]
    volumes:
      - ./litellm/litellm.yaml:/config/litellm.yaml
    ports:
      - "4000:4000"  # OpenAI-compatible endpoint
```

---

### 20.2 LiteLLM Configuration (Local Model)

```yaml
# litellm/litellm.yaml
model_list:
  - model_name: local-llm
    litellm_params:
      model: ollama/llama3
      api_base: http://host.docker.internal:11434

router_settings:
  default_model: local-llm
```

> You may replace `ollama/llama3` with **any local or internal LLM** already supported in your environment.

---

### 20.3 AI Agent → LiteLLM Call (Observed)

```python
import requests
from langfuse import Langfuse
from opentelemetry import trace

langfuse = Langfuse()
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("llm_call"):
    prompt = "Explain hybrid observability"

    langfuse.trace(
        name="litellm-call",
        input=prompt,
        metadata={"provider": "litellm"}
    )

    response = requests.post(
        "http://litellm:4000/v1/chat/completions",
        json={
            "model": "local-llm",
            "messages": [{"role": "user", "content": prompt}]
        }
    ).json()

    print(response)
```

This single call generates:
- **Dynatrace trace span**
- **Langfuse prompt + response record**

---

## 21. IBM MCP Gateway – Fully Local Mode

### Important Clarification

✅ **Yes, IBM MCP Gateway *can* be demoed locally** using:
- A **local containerized control plane**
- OR a **mock-compatible gateway** (recommended for demos)

For architecture and observability demos:
> *Functional equivalence matters more than vendor binaries.*

---

### 21.1 Why Local MCP is Acceptable

- Network-restricted environments
- No external SaaS dependency
- Predictable latency
- Easier trace correlation

Most architecture boards **explicitly prefer local demos**.

---

### 21.2 MCP Gateway Modes

| Mode | Use Case |
|----|----|
| Mock MCP (FastAPI) | Architecture & observability demos |
| LiteLLM + MCP | LLM routing demos |
| Vendor MCP | Production |

---

### 21.3 Observability Still Holds

Even with local MCP:
- Dynatrace observes **gateway health**
- Langfuse observes **AI behavior**
- Correlation remains identical

---

## 22. Failure Injection (Optional but Powerful)

Add artificial latency to AI Agent:

```python
import time
time.sleep(2)
```

This allows you to demonstrate:
- Latency spike in Dynatrace
- Long trace duration in Langfuse

---

## 21. End-to-End Test (Git Bash)

```bash
curl -X POST "http://localhost:7070/mcp/invoke" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Explain hybrid observability"}'
```

Observe:
- Dynatrace → Distributed Traces
- Langfuse → New trace/session

---

## 22. Demo Talk Track (5 Minutes)

1. **Request enters MCP Gateway**
2. **Dynatrace shows latency & dependency map**
3. **Agent executes LLM logic**
4. **Langfuse shows prompt, tokens, response**
5. **Correlation explains root cause**

---

## 23. Final Key Takeaway

> *Traditional observability answers **"Is the system healthy?"***  
> *AI observability answers **"Is the model behaving correctly?"***

Together, Dynatrace + Langfuse deliver **enterprise-grade AI observability**.

---

## 24. Executive-Grade Extensions (Board Demo)

This section elevates the demo from **technical proof** to **executive‑level assurance**, aligned with Enterprise & Capital Markets expectations.

---

## 25. Security & Audit Logging (Who Sent What Prompt)

### Objective (Executive View)

- Full auditability of AI usage
- Regulatory readiness
- Non‑repudiation of AI decisions

### Implementation Model

```mermaid
flowchart LR
    User --> Gateway[Agent Gateway]
    Gateway -->|user_id, role, purpose| Agent
    Agent --> Langfuse
    Agent --> Dynatrace

    Langfuse --> Audit[(Prompt Audit Log)]
```

### Captured Fields

| Field | Purpose |
|---|---|
| user_id | Accountability |
| business_unit | Capital Markets / Enterprise |
| use_case | Trade surveillance, analysis |
| prompt | Full text |
| model | Which LLM |
| timestamp | Audit |

Langfuse acts as the **system of record** for AI behavior.

---

## 26. Multi‑Agent Observability (Agent → Tool → Agent)

### Executive Value

- Explains *complex AI decisions*
- Shows controllability of autonomous agents
- Reduces "black box" perception

### Multi‑Agent Flow

```mermaid
sequenceDiagram
    participant U as User
    participant G as MCP
    participant A1 as Reasoning Agent
    participant T as Tool Agent
    participant A2 as Validation Agent

    U->>G: Request
    G->>A1: Context + Prompt
    A1->>T: Fetch Data
    T-->>A1: Results
    A1->>A2: Validate Output
    A2-->>G: Final Answer

    A1->>Langfuse: Reasoning Trace
    A2->>Langfuse: Validation Trace
```

Each agent step is visible in Langfuse as a **decision graph**.

---

## 27. Dynatrace Executive Dashboard (Importable JSON)

### Recommended Tiles

- AI Request Volume (Gateway)
- P95 Latency (AI Agent)
- Error Rate (LiteLLM)
- Dependency Map (Gateway → Agent → LLM)

### Sample Dashboard JSON (Minimal)

```json
{
  "dashboardMetadata": {
    "name": "AI Observability – Executive View",
    "shared": true
  },
  "tiles": []
}
```

> This dashboard focuses on **risk, stability, and throughput**, not model internals.

---

## 28. Chaos Testing for AI Pipelines

### Executive Rationale

> *“How does the system behave under stress or failure?”*

### Scenarios

| Scenario | What Executives See |
|---|---|
| Slow model | Latency spike & graceful degradation |
| Model failure | Automatic retry / fallback |
| Token explosion | Cost & risk alert |

### Chaos Injection Example

```python
if chaos_mode:
    raise TimeoutError("Simulated LLM timeout")
```

Dynatrace shows impact. Langfuse explains cause.

---

## 29. GitHub‑Ready Demo Repository

### Repository Structure

```text
ai-observability-executive-demo/
├── docker-compose.yml
├── agent/
├── mcp/
├── litellm/
├── otel/
├── dashboards/
│   └── dynatrace-exec.json
├── docs/
│   └── whitepaper.md
└── README.md
```

### README (Executive‑Friendly)

- What problem this solves
- 1‑command startup
- Where to click during demo
- Risk & governance mapping

---

## 30. Executive Demo Script (10 Minutes)

1. **Why AI needs observability** (risk, cost, trust)
2. **Live request through MCP**
3. **Dynatrace: system health**
4. **Langfuse: AI decision transparency**
5. **Failure injection**
6. **Governance & audit assurance**

---

## 31. Final Executive Message

> **Observability is the control plane of enterprise AI.**
>
> This architecture ensures:
> - AI can scale safely
> - Decisions are explainable
> - Risks are measurable
> - Regulators can be satisfied

---

*Author: Babak Emami*

