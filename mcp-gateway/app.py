"""
IBM MCP Context Forge Gateway (Mock Implementation)

This is a lightweight mock of the IBM MCP Gateway that:
- Exposes AI endpoints for orchestrating LLM calls
- Maintains an MCP Server registry
- Forwards requests to AI Agents and LiteLLM
- Is fully observable via Dynatrace (OTEL) and Langfuse
"""

import os
import uuid
import time
import logging
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException, Request, Depends, Header
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

from mcp_registry import MCPRegistry

# ===========================================
# Configuration
# ===========================================

LITELLM_URL = os.getenv("LITELLM_URL", "http://litellm:4000")
AGENT_URL = os.getenv("AGENT_URL", "http://agent:8080")
MCP_GATEWAY_SECRET = os.getenv("MCP_GATEWAY_SECRET", "mcp-secret")
OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://dynatrace-otel:4317")
SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "mcp-gateway")

# Langfuse configuration
LANGFUSE_PUBLIC_KEY = os.getenv("LANGFUSE_PUBLIC_KEY", "")
LANGFUSE_SECRET_KEY = os.getenv("LANGFUSE_SECRET_KEY", "")
LANGFUSE_HOST = os.getenv("LANGFUSE_HOST", "http://langfuse-web:3000")

# ===========================================
# Logging Setup
# ===========================================

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ===========================================
# OpenTelemetry Setup
# ===========================================

resource = Resource.create({"service.name": SERVICE_NAME})
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
# MCP Registry
# ===========================================

mcp_registry = MCPRegistry()

# ===========================================
# Request/Response Models
# ===========================================

class InvokeRequest(BaseModel):
    prompt: str
    model: Optional[str] = "llama-3.1-8b-instant"
    mcp_servers: Optional[List[str]] = None
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

class InvokeResponse(BaseModel):
    request_id: str
    response: str
    model: str
    tokens_used: Optional[int] = None
    mcp_tools_used: Optional[List[str]] = None
    latency_ms: float

class MCPServerConfig(BaseModel):
    name: str
    url: str
    capabilities: List[str]
    description: Optional[str] = None
    auth_token: Optional[str] = None

class HealthResponse(BaseModel):
    status: str
    version: str
    services: Dict[str, str]

# ===========================================
# FastAPI App
# ===========================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup/shutdown"""
    logger.info("MCP Gateway starting up...")
    yield
    logger.info("MCP Gateway shutting down...")
    if langfuse:
        langfuse.flush()

app = FastAPI(
    title="IBM MCP Context Forge Gateway (Mock)",
    description="Centralized AI Gateway with MCP Server Registry",
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
    """Health check endpoint for observability"""
    services = {}
    
    async with httpx.AsyncClient(timeout=5.0) as client:
        # Check LiteLLM
        try:
            resp = await client.get(f"{LITELLM_URL}/health")
            services["litellm"] = "healthy" if resp.status_code == 200 else "unhealthy"
        except Exception:
            services["litellm"] = "unavailable"
        
        # Check Agent
        try:
            resp = await client.get(f"{AGENT_URL}/health")
            services["agent"] = "healthy" if resp.status_code == 200 else "unhealthy"
        except Exception:
            services["agent"] = "unavailable"
    
    services["mcp_registry"] = f"{len(mcp_registry.list_servers())} servers registered"
    
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        services=services
    )


@app.post("/mcp/invoke", response_model=InvokeResponse)
async def invoke(request: InvokeRequest, x_request_id: Optional[str] = Header(None)):
    """
    Main AI invocation endpoint.
    
    - Routes requests through the MCP Gateway
    - Optionally uses registered MCP servers for tool calls
    - Dual observability: OTEL traces to Dynatrace, LLM events to Langfuse
    """
    request_id = x_request_id or str(uuid.uuid4())
    start_time = time.time()
    
    with tracer.start_as_current_span("mcp_invoke") as span:
        span.set_attribute("request_id", request_id)
        span.set_attribute("model", request.model)
        span.set_attribute("prompt_length", len(request.prompt))
        
        if request.user_id:
            span.set_attribute("user_id", request.user_id)
        
        # Start Langfuse trace
        langfuse_trace = None
        if langfuse:
            try:
                langfuse_trace = langfuse.trace(
                    id=request_id,
                    name="mcp_gateway_invoke",
                    input={"prompt": request.prompt, "model": request.model},
                    metadata={
                        "session_id": request.session_id,
                        "user_id": request.user_id,
                        "mcp_servers": request.mcp_servers,
                        **(request.metadata or {})
                    }
                )
            except Exception as e:
                logger.warning(f"Failed to create Langfuse trace: {e}")
        
        mcp_tools_used = []
        
        # Process MCP server requests if specified
        if request.mcp_servers:
            with tracer.start_as_current_span("mcp_tool_calls"):
                for server_name in request.mcp_servers:
                    server = mcp_registry.get_server(server_name)
                    if server:
                        span.set_attribute(f"mcp_server.{server_name}", server.url)
                        mcp_tools_used.append(server_name)
                        
                        if langfuse_trace:
                            langfuse_trace.span(
                                name=f"mcp_call_{server_name}",
                                input={"capabilities": server.capabilities}
                            )
        
        # Call LiteLLM for LLM completion
        try:
            with tracer.start_as_current_span("litellm_completion") as llm_span:
                llm_span.set_attribute("model", request.model)
                
                headers = {"Content-Type": "application/json"}
                inject(headers)  # Inject trace context
                
                async with httpx.AsyncClient(timeout=120.0) as client:
                    response = await client.post(
                        f"{LITELLM_URL}/v1/chat/completions",
                        json={
                            "model": request.model,
                            "messages": [{"role": "user", "content": request.prompt}]
                        },
                        headers=headers
                    )
                    response.raise_for_status()
                    result = response.json()
                
                llm_response = result["choices"][0]["message"]["content"]
                tokens_used = result.get("usage", {}).get("total_tokens")
                
                llm_span.set_attribute("tokens_used", tokens_used or 0)
                llm_span.set_attribute("response_length", len(llm_response))
                
                if langfuse_trace:
                    langfuse_trace.generation(
                        name="llm_completion",
                        model=request.model,
                        input=request.prompt,
                        output=llm_response,
                        usage={
                            "input": result.get("usage", {}).get("prompt_tokens", 0),
                            "output": result.get("usage", {}).get("completion_tokens", 0)
                        }
                    )
        
        except httpx.HTTPError as e:
            span.set_attribute("error", True)
            span.set_attribute("error.message", str(e))
            
            if langfuse_trace:
                langfuse_trace.update(output={"error": str(e)}, status_message="error")
            
            raise HTTPException(status_code=502, detail=f"LiteLLM error: {str(e)}")
        
        latency_ms = (time.time() - start_time) * 1000
        span.set_attribute("latency_ms", latency_ms)
        
        # Finalize Langfuse trace
        if langfuse_trace:
            langfuse_trace.update(
                output={"response": llm_response},
                status_message="success"
            )
        
        return InvokeResponse(
            request_id=request_id,
            response=llm_response,
            model=request.model,
            tokens_used=tokens_used,
            mcp_tools_used=mcp_tools_used if mcp_tools_used else None,
            latency_ms=latency_ms
        )


# ===========================================
# MCP Registry Endpoints
# ===========================================

@app.post("/mcp/registry/add")
async def add_mcp_server(config: MCPServerConfig):
    """Register a new MCP server in the registry"""
    with tracer.start_as_current_span("mcp_registry_add") as span:
        span.set_attribute("server_name", config.name)
        span.set_attribute("server_url", config.url)
        
        mcp_registry.add_server(
            name=config.name,
            url=config.url,
            capabilities=config.capabilities,
            description=config.description,
            auth_token=config.auth_token
        )
        
        logger.info(f"Registered MCP server: {config.name} at {config.url}")
        
        return {"status": "registered", "name": config.name}


@app.delete("/mcp/registry/remove/{name}")
async def remove_mcp_server(name: str):
    """Remove an MCP server from the registry"""
    with tracer.start_as_current_span("mcp_registry_remove") as span:
        span.set_attribute("server_name", name)
        
        if mcp_registry.remove_server(name):
            return {"status": "removed", "name": name}
        else:
            raise HTTPException(status_code=404, detail=f"MCP server '{name}' not found")


@app.get("/mcp/registry/list")
async def list_mcp_servers():
    """List all registered MCP servers"""
    servers = mcp_registry.list_servers()
    return {
        "count": len(servers),
        "servers": [
            {
                "name": s.name,
                "url": s.url,
                "capabilities": s.capabilities,
                "description": s.description
            }
            for s in servers
        ]
    }


@app.get("/mcp/registry/{name}")
async def get_mcp_server(name: str):
    """Get details of a specific MCP server"""
    server = mcp_registry.get_server(name)
    if not server:
        raise HTTPException(status_code=404, detail=f"MCP server '{name}' not found")
    
    return {
        "name": server.name,
        "url": server.url,
        "capabilities": server.capabilities,
        "description": server.description
    }


# ===========================================
# Agent Routing Endpoint
# ===========================================

@app.post("/mcp/agent/run")
async def run_agent(request: InvokeRequest, x_request_id: Optional[str] = Header(None)):
    """
    Route request to AI Agent for complex multi-step processing.
    The agent handles tool calls, reasoning chains, and validation.
    """
    request_id = x_request_id or str(uuid.uuid4())
    
    with tracer.start_as_current_span("agent_run") as span:
        span.set_attribute("request_id", request_id)
        
        headers = {
            "Content-Type": "application/json",
            "X-Request-ID": request_id
        }
        inject(headers)
        
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                f"{AGENT_URL}/run",
                json=request.model_dump(),
                headers=headers
            )
            response.raise_for_status()
            return response.json()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7070)
