"""
MCP Server Registry

Manages the registration and discovery of MCP (Model Context Protocol) servers.
These servers provide tools and capabilities that AI agents can use.
"""

import threading
from typing import List, Optional, Dict, Any
from dataclasses import dataclass, field
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


@dataclass
class MCPServer:
    """Represents a registered MCP server"""
    name: str
    url: str
    capabilities: List[str]
    description: Optional[str] = None
    auth_token: Optional[str] = None
    registered_at: datetime = field(default_factory=datetime.now)
    last_health_check: Optional[datetime] = None
    is_healthy: bool = True
    metadata: Dict[str, Any] = field(default_factory=dict)


class MCPRegistry:
    """
    Thread-safe registry for MCP servers.
    
    Features:
    - Add/remove/list MCP servers
    - Capability-based discovery
    - Health tracking
    """
    
    def __init__(self):
        self._servers: Dict[str, MCPServer] = {}
        self._lock = threading.RLock()
        
        # Pre-register some demo MCP servers
        self._register_demo_servers()
    
    def _register_demo_servers(self):
        """Register demo MCP servers for testing"""
        demo_servers = [
            MCPServer(
                name="calculator-mcp",
                url="http://calculator-mcp:8000",
                capabilities=["calculate", "math_expression"],
                description="Mathematical calculations and expressions"
            ),
            MCPServer(
                name="datetime-mcp",
                url="http://datetime-mcp:8000",
                capabilities=["get_current_time", "format_date", "timezone_convert"],
                description="Date and time utilities"
            ),
            MCPServer(
                name="weather-mcp",
                url="http://weather-mcp:8000",
                capabilities=["get_weather", "get_forecast"],
                description="Weather information service"
            )
        ]
        
        for server in demo_servers:
            self._servers[server.name] = server
        
        logger.info(f"Registered {len(demo_servers)} demo MCP servers")
    
    def add_server(
        self,
        name: str,
        url: str,
        capabilities: List[str],
        description: Optional[str] = None,
        auth_token: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ) -> MCPServer:
        """
        Register a new MCP server.
        
        Args:
            name: Unique identifier for the server
            url: Base URL of the MCP server
            capabilities: List of tool/capability names
            description: Human-readable description
            auth_token: Optional authentication token
            metadata: Additional metadata
            
        Returns:
            The registered MCPServer instance
        """
        with self._lock:
            server = MCPServer(
                name=name,
                url=url,
                capabilities=capabilities,
                description=description,
                auth_token=auth_token,
                metadata=metadata or {}
            )
            self._servers[name] = server
            logger.info(f"Registered MCP server: {name} with capabilities: {capabilities}")
            return server
    
    def remove_server(self, name: str) -> bool:
        """
        Remove an MCP server from the registry.
        
        Args:
            name: Name of the server to remove
            
        Returns:
            True if removed, False if not found
        """
        with self._lock:
            if name in self._servers:
                del self._servers[name]
                logger.info(f"Removed MCP server: {name}")
                return True
            return False
    
    def get_server(self, name: str) -> Optional[MCPServer]:
        """
        Get an MCP server by name.
        
        Args:
            name: Name of the server
            
        Returns:
            MCPServer if found, None otherwise
        """
        with self._lock:
            return self._servers.get(name)
    
    def list_servers(self) -> List[MCPServer]:
        """
        List all registered MCP servers.
        
        Returns:
            List of all MCPServer instances
        """
        with self._lock:
            return list(self._servers.values())
    
    def find_by_capability(self, capability: str) -> List[MCPServer]:
        """
        Find servers that provide a specific capability.
        
        Args:
            capability: The capability to search for
            
        Returns:
            List of servers with the capability
        """
        with self._lock:
            return [
                server for server in self._servers.values()
                if capability in server.capabilities
            ]
    
    def update_health(self, name: str, is_healthy: bool) -> bool:
        """
        Update the health status of an MCP server.
        
        Args:
            name: Name of the server
            is_healthy: Current health status
            
        Returns:
            True if updated, False if server not found
        """
        with self._lock:
            server = self._servers.get(name)
            if server:
                server.is_healthy = is_healthy
                server.last_health_check = datetime.now()
                return True
            return False
    
    def get_healthy_servers(self) -> List[MCPServer]:
        """
        Get all healthy MCP servers.
        
        Returns:
            List of healthy MCPServer instances
        """
        with self._lock:
            return [s for s in self._servers.values() if s.is_healthy]
    
    def to_dict(self) -> Dict[str, Any]:
        """Export registry as dictionary for serialization"""
        with self._lock:
            return {
                "servers": {
                    name: {
                        "url": s.url,
                        "capabilities": s.capabilities,
                        "description": s.description,
                        "is_healthy": s.is_healthy,
                        "registered_at": s.registered_at.isoformat()
                    }
                    for name, s in self._servers.items()
                }
            }
