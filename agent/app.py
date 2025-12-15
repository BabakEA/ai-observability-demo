"""
AI Agent with Dual Observability

This agent demonstrates:
- OpenTelemetry traces to Dynatrace (infrastructure/APM)
- Langfuse integration for AI/LLM observability
- Multi-step reasoning with tool calls
- Chaos testing support
"""

import os
import uuid
import time
import logging
import asyncio
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# OpenTelemetry imports
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.propagate import inject

# Langfuse imports
from langfuse import Langfuse
from langfuse.decorators import observe, langfuse_context

# ===========================================
# Configuration
# ===========================================

LITELLM_URL = os.getenv("LITELLM_URL", "http://litellm:4000")
OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://dynatrace-otel:4317")
SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "ai-agent")

# Langfuse configuration
LANGFUSE_PUBLIC_KEY = os.getenv("LANGFUSE_PUBLIC_KEY", "")
LANGFUSE_SECRET_KEY = os.getenv("LANGFUSE_SECRET_KEY", "")
LANGFUSE_HOST = os.getenv("LANGFUSE_HOST", "http://langfuse-web:3000")

# Chaos testing
CHAOS_MODE = os.getenv("AGENT_CHAOS_MODE", "false").lower() == "true"
CHAOS_LATENCY_MS = int(os.getenv("AGENT_LATENCY_MS", "0"))

# ===========================================
# Logging Setup
# ===========================================

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ===========================================
# OpenTelemetry Setup
# ===========================================

resource = Resource.create({
    "service.name": SERVICE_NAME,
    "service.version": "1.0.0",
    "deployment.environment": "demo"
})
provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True))
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

# Instrument HTTPX for outgoing requests
HTTPXClientInstrumentor().instrument()

# ===========================================
# Langfuse Setup
# ===========================================

langfuse = None
if LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY:
    try:
        langfuse = Langfuse(
            public_key=LANGFUSE_PUBLIC_KEY,
            secret_key=LANGFUSE_SECRET_KEY,
            host=LANGFUSE_HOST
        )
        logger.info("Langfuse client initialized successfully")
    except Exception as e:
        logger.warning(f"Failed to initialize Langfuse: {e}")

# ===========================================
# Agent State
# ===========================================

class AgentConfig:
    chaos_mode: bool = CHAOS_MODE
    latency_ms: int = CHAOS_LATENCY_MS

agent_config = AgentConfig()

# ===========================================
# Request/Response Models
# ===========================================

class AgentRequest(BaseModel):
    prompt: str
    model: Optional[str] = "llama-3.1-8b-instant"
    mcp_servers: Optional[List[str]] = None
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    max_steps: Optional[int] = 5

class AgentResponse(BaseModel):
    request_id: str
    response: str
    model: str
    steps: List[Dict[str, Any]]
    total_tokens: int
    latency_ms: float

class ConfigUpdate(BaseModel):
    chaos_mode: Optional[bool] = None
    latency_ms: Optional[int] = None

class HealthResponse(BaseModel):
    status: str
    version: str
    chaos_mode: bool
    latency_ms: int

# ===========================================
# Agent Logic
# ===========================================

class ReasoningAgent:
    """
    Multi-step reasoning agent with observability.
    
    This agent:
    1. Analyzes the prompt
    2. Determines if tools are needed
    3. Executes reasoning steps
    4. Generates final response
    """
    
    def __init__(self, langfuse_client: Optional[Langfuse] = None):
        self.langfuse = langfuse_client
        self.http_client = httpx.AsyncClient(timeout=120.0)
    
    async def analyze_prompt(self, prompt: str) -> Dict[str, Any]:
        """Analyze the prompt to determine required steps"""
        with tracer.start_as_current_span("analyze_prompt") as span:
            span.set_attribute("prompt_length", len(prompt))
            
            # Simple analysis - in production, this would be more sophisticated
            requires_tools = any(keyword in prompt.lower() for keyword in [
                "calculate", "weather", "time", "search", "lookup"
            ])
            
            complexity = "simple" if len(prompt) < 100 else "complex"
            
            analysis = {
                "requires_tools": requires_tools,
                "complexity": complexity,
                "suggested_steps": 1 if not requires_tools else 3
            }
            
            span.set_attribute("requires_tools", requires_tools)
            span.set_attribute("complexity", complexity)
            
            return analysis
    
    async def call_llm(
        self,
        messages: List[Dict[str, str]],
        model: str,
        trace_id: str
    ) -> Dict[str, Any]:
        """Call LiteLLM with observability"""
        with tracer.start_as_current_span("llm_call") as span:
            span.set_attribute("model", model)
            span.set_attribute("message_count", len(messages))
            
            headers = {"Content-Type": "application/json"}
            inject(headers)
            
            response = await self.http_client.post(
                f"{LITELLM_URL}/v1/chat/completions",
                json={"model": model, "messages": messages},
                headers=headers
            )
            response.raise_for_status()
            result = response.json()
            
            content = result["choices"][0]["message"]["content"]
            usage = result.get("usage", {})
            
            span.set_attribute("response_length", len(content))
            span.set_attribute("prompt_tokens", usage.get("prompt_tokens", 0))
            span.set_attribute("completion_tokens", usage.get("completion_tokens", 0))
            
            return {
                "content": content,
                "usage": usage
            }
    
    async def run(self, request: AgentRequest, request_id: str) -> AgentResponse:
        """Execute the full agent pipeline"""
        start_time = time.time()
        steps = []
        total_tokens = 0
        
        with tracer.start_as_current_span("agent_run") as span:
            span.set_attribute("request_id", request_id)
            span.set_attribute("model", request.model)
            
            # Create Langfuse trace
            langfuse_trace = None
            if self.langfuse:
                try:
                    langfuse_trace = self.langfuse.trace(
                        id=request_id,
                        name="agent_pipeline",
                        input={"prompt": request.prompt},
                        metadata={
                            "model": request.model,
                            "session_id": request.session_id,
                            "user_id": request.user_id
                        }
                    )
                except Exception as e:
                    logger.warning(f"Langfuse trace creation failed: {e}")
            
            # Apply chaos testing if enabled
            if agent_config.chaos_mode and agent_config.latency_ms > 0:
                with tracer.start_as_current_span("chaos_delay"):
                    await asyncio.sleep(agent_config.latency_ms / 1000)
                    span.set_attribute("chaos_delay_ms", agent_config.latency_ms)
            
            # Step 1: Analyze
            analysis = await self.analyze_prompt(request.prompt)
            steps.append({
                "step": 1,
                "name": "analyze",
                "result": analysis
            })
            
            if langfuse_trace:
                langfuse_trace.span(
                    name="analyze_prompt",
                    input={"prompt": request.prompt},
                    output=analysis
                )
            
            # Step 2: Reasoning (if complex)
            messages = [{"role": "user", "content": request.prompt}]
            
            if analysis["complexity"] == "complex":
                with tracer.start_as_current_span("reasoning_step"):
                    reasoning_prompt = f"Think step by step about how to answer: {request.prompt}"
                    reasoning_result = await self.call_llm(
                        [{"role": "user", "content": reasoning_prompt}],
                        request.model,
                        request_id
                    )
                    total_tokens += reasoning_result["usage"].get("total_tokens", 0)
                    
                    steps.append({
                        "step": 2,
                        "name": "reasoning",
                        "result": reasoning_result["content"][:200] + "..."
                    })
                    
                    if langfuse_trace:
                        langfuse_trace.generation(
                            name="reasoning",
                            model=request.model,
                            input=reasoning_prompt,
                            output=reasoning_result["content"],
                            usage=reasoning_result["usage"]
                        )
            
            # Step 3: Final response
            with tracer.start_as_current_span("final_response"):
                final_result = await self.call_llm(messages, request.model, request_id)
                total_tokens += final_result["usage"].get("total_tokens", 0)
                
                steps.append({
                    "step": len(steps) + 1,
                    "name": "final_response",
                    "result": "generated"
                })
                
                if langfuse_trace:
                    langfuse_trace.generation(
                        name="final_response",
                        model=request.model,
                        input=request.prompt,
                        output=final_result["content"],
                        usage=final_result["usage"]
                    )
            
            latency_ms = (time.time() - start_time) * 1000
            span.set_attribute("latency_ms", latency_ms)
            span.set_attribute("total_tokens", total_tokens)
            span.set_attribute("step_count", len(steps))
            
            if langfuse_trace:
                langfuse_trace.update(
                    output={"response": final_result["content"]},
                    status_message="success"
                )
            
            return AgentResponse(
                request_id=request_id,
                response=final_result["content"],
                model=request.model,
                steps=steps,
                total_tokens=total_tokens,
                latency_ms=latency_ms
            )


# ===========================================
# FastAPI App
# ===========================================

agent = ReasoningAgent(langfuse)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager"""
    logger.info("AI Agent starting up...")
    yield
    logger.info("AI Agent shutting down...")
    await agent.http_client.aclose()
    if langfuse:
        langfuse.flush()

app = FastAPI(
    title="AI Agent with Dual Observability",
    description="Demo agent with Dynatrace + Langfuse observability",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Instrument FastAPI
FastAPIInstrumentor.instrument_app(app)

# ===========================================
# Endpoints
# ===========================================

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        chaos_mode=agent_config.chaos_mode,
        latency_ms=agent_config.latency_ms
    )


@app.post("/run", response_model=AgentResponse)
async def run_agent(
    request: AgentRequest,
    x_request_id: Optional[str] = Header(None)
):
    """
    Execute the AI agent pipeline.
    
    This endpoint:
    1. Analyzes the prompt
    2. Performs reasoning if needed
    3. Generates the final response
    
    All steps are observable in both Dynatrace and Langfuse.
    """
    request_id = x_request_id or str(uuid.uuid4())
    
    try:
        result = await agent.run(request, request_id)
        return result
    except httpx.HTTPError as e:
        raise HTTPException(status_code=502, detail=f"LLM service error: {str(e)}")
    except Exception as e:
        logger.error(f"Agent error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/config")
async def update_config(config: ConfigUpdate):
    """
    Update agent configuration.
    Used for chaos testing and demonstrations.
    """
    if config.chaos_mode is not None:
        agent_config.chaos_mode = config.chaos_mode
        logger.info(f"Chaos mode set to: {config.chaos_mode}")
    
    if config.latency_ms is not None:
        agent_config.latency_ms = config.latency_ms
        logger.info(f"Chaos latency set to: {config.latency_ms}ms")
    
    return {
        "status": "updated",
        "chaos_mode": agent_config.chaos_mode,
        "latency_ms": agent_config.latency_ms
    }


@app.get("/config")
async def get_config():
    """Get current agent configuration"""
    return {
        "chaos_mode": agent_config.chaos_mode,
        "latency_ms": agent_config.latency_ms
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
