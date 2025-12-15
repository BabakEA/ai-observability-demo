# Langfuse Dashboard Setup Guide

This document describes how to set up and use the Langfuse dashboard for AI/LLM observability.

## Initial Setup

### 1. Access Langfuse

Open http://localhost:3000 in your browser.

### 2. Create Account

On first access:
1. Click "Sign Up"
2. Enter your details:
   - Email: admin@demo.local
   - Password: (your choice)
3. Create your organization and project

### 3. Get API Keys

1. Go to **Settings** → **API Keys**
2. Copy the **Public Key** and **Secret Key**
3. Update your `.env` file:
   ```
   LANGFUSE_INIT_PROJECT_PUBLIC_KEY=pk-lf-xxx
   LANGFUSE_INIT_PROJECT_SECRET_KEY=sk-lf-xxx
   ```
4. Restart the services: `docker compose restart`

## Key Dashboard Views

### Traces View

**Path:** Dashboard → Traces

Shows all AI/LLM interactions:
- Request/response pairs
- Token usage
- Latency
- Model versions
- Error states

**Filters:**
- By model
- By user
- By time range
- By status

### Sessions View

**Path:** Dashboard → Sessions

Groups traces by session for multi-turn conversations:
- Session timeline
- Total token usage per session
- User journey analysis

### Generations View

**Path:** Dashboard → Generations

Detailed view of LLM generations:
- Prompt text
- Response text
- Token counts (input/output)
- Model used
- Latency breakdown

### Scores & Evaluations

**Path:** Dashboard → Scores

Quality metrics and evaluations:
- Manual feedback scores
- Automated evaluation results
- Quality trends over time

## Key Metrics to Monitor

### 1. Token Usage

Track token consumption to manage costs:
- Total tokens per request
- Average tokens per session
- Token trends over time

### 2. Latency

Monitor response times:
- P50/P95/P99 latencies
- Latency by model
- Latency by prompt complexity

### 3. Error Rates

Track failures:
- LLM API errors
- Timeout rates
- Retry patterns

### 4. Model Comparison

Compare model performance:
- Quality scores by model
- Latency by model
- Cost efficiency

## Correlation with Dynatrace

### Using Request IDs

All traces include a `request_id` that appears in both:
- Langfuse traces (as trace ID)
- Dynatrace distributed traces (as custom attribute)

### Workflow

1. **Issue detected in Dynatrace:**
   - High latency spike
   - Error rate increase

2. **Find request_id in Dynatrace:**
   - Go to Distributed Traces
   - Find the problematic trace
   - Copy the request_id attribute

3. **Search in Langfuse:**
   - Go to Traces
   - Search by request_id
   - Analyze prompt/response

4. **Root cause:**
   - Long prompt? → Token limit issue
   - Complex reasoning? → Model capability
   - Tool failures? → MCP server issue

## Dashboards for Different Roles

### Executive Dashboard

Focus on:
- Total AI requests
- Error rate trend
- Cost (token usage)
- System availability

### Developer Dashboard

Focus on:
- Individual trace analysis
- Prompt debugging
- Model comparison
- Error details

### Operations Dashboard

Focus on:
- Real-time request volume
- Latency alerts
- Capacity planning
- Resource utilization

## Alerting (Custom)

Langfuse doesn't have built-in alerting, but you can:

1. **Export to webhook:**
   - Use Langfuse API to poll for anomalies
   - Send to Slack/Teams

2. **Integrate with Dynatrace:**
   - Send custom metrics from Langfuse data
   - Use Dynatrace alerting

### Example Alert Script

```python
import requests
from langfuse import Langfuse

langfuse = Langfuse()

# Get recent traces with high latency
traces = langfuse.get_traces(
    filter={"latency_ms": {"gt": 5000}}
)

if len(traces) > 10:
    # Send alert
    requests.post(
        "https://hooks.slack.com/services/...",
        json={"text": f"⚠️ {len(traces)} slow AI requests detected"}
    )
```

## Best Practices

### 1. Structured Metadata

Always include:
- `user_id` for accountability
- `session_id` for conversation tracking
- `model` for performance comparison
- `use_case` for business analytics

### 2. Trace Naming

Use consistent trace names:
- `mcp_gateway_invoke` for gateway calls
- `agent_pipeline` for agent processing
- `llm_completion` for direct LLM calls

### 3. Error Tracking

Log errors with context:
- Error type
- Input that caused error
- Stack trace
- Retry count

### 4. Regular Analysis

Weekly review:
- Token usage trends
- Quality score distribution
- Top error patterns
- Model performance comparison

## Integration with CI/CD

### Prompt Testing

Use Langfuse datasets for regression testing:

```python
from langfuse import Langfuse

langfuse = Langfuse()

# Load test dataset
dataset = langfuse.get_dataset("regression-tests")

for item in dataset.items:
    # Run your LLM
    result = call_llm(item.input)
    
    # Log result for comparison
    langfuse.score(
        trace_id=result.trace_id,
        name="regression-test",
        value=compare(result.output, item.expected_output)
    )
```

## Resources

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse Python SDK](https://langfuse.com/docs/sdk/python)
- [Self-Hosting Guide](https://langfuse.com/docs/deployment/self-host)
