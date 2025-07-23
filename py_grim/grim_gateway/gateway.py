#!/usr/bin/env python3
"""
Grim API Gateway

Unified API layer for Python and Go components with routing, load balancing,
authentication, rate limiting, and comprehensive monitoring.
"""

import asyncio
import json
import logging
import time
from contextlib import asynccontextmanager
from typing import Dict, List, Optional, Any, Callable
from pathlib import Path
import subprocess
import aiofiles
import httpx
from fastapi import FastAPI, Request, Response, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field
import uvicorn
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import redis.asyncio as redis
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import os

# Add the project root to the path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from grim_core.config import Config
from grim_core.logger import Logger
from grim_core.database import DatabaseManager

# Metrics
REQUEST_COUNT = Counter('gateway_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('gateway_request_duration_seconds', 'Request duration', ['method', 'endpoint'])
ACTIVE_CONNECTIONS = Gauge('gateway_active_connections', 'Active connections')
COMPRESSION_OPERATIONS = Counter('gateway_compression_operations_total', 'Compression operations', ['algorithm', 'operation'])
BACKUP_OPERATIONS = Counter('gateway_backup_operations_total', 'Backup operations', ['operation', 'status'])

class GatewayConfig(BaseModel):
    """Gateway configuration"""
    host: str = Field(default="0.0.0.0", description="Gateway host")
    port: int = Field(default=8000, description="Gateway port")
    workers: int = Field(default=4, description="Number of workers")
    max_connections: int = Field(default=1000, description="Maximum connections")
    rate_limit: int = Field(default=100, description="Requests per minute")
    timeout: int = Field(default=30, description="Request timeout in seconds")
    enable_cors: bool = Field(default=True, description="Enable CORS")
    enable_auth: bool = Field(default=True, description="Enable authentication")
    enable_monitoring: bool = Field(default=True, description="Enable monitoring")

class ServiceEndpoint(BaseModel):
    """Service endpoint configuration"""
    name: str
    path: str
    target: str
    methods: List[str] = ["GET", "POST", "PUT", "DELETE"]
    timeout: int = 30
    retries: int = 3
    rate_limit: Optional[int] = None
    auth_required: bool = True

class GatewayService:
    """Main gateway service"""
    
    def __init__(self, config: Optional[GatewayConfig] = None):
        self.config = config or GatewayConfig()
        self.logger = Logger("gateway")
        self.db_manager = DatabaseManager(Config())
        
        # Initialize Redis for rate limiting and caching
        self.redis_client = None
        
        # Service registry
        self.services: Dict[str, ServiceEndpoint] = {}
        
        # HTTP client for proxying requests
        self.http_client = None
        
        # Rate limiter
        self.limiter = Limiter(key_func=get_remote_address)
        
        # Initialize FastAPI app
        self.app = self._create_app()
        
        self.logger.info(f"Gateway initialized with config: {self.config}")
    
    def _create_app(self) -> FastAPI:
        """Create and configure FastAPI application"""
        app = FastAPI(
            title="Grim API Gateway",
            description="Unified API gateway for Python and Go components",
            version="1.0.0",
            docs_url="/docs" if self.config.enable_monitoring else None,
            redoc_url="/redoc" if self.config.enable_monitoring else None
        )
        
        # Add middleware
        if self.config.enable_cors:
            app.add_middleware(
                CORSMiddleware,
                allow_origins=["*"],
                allow_credentials=True,
                allow_methods=["*"],
                allow_headers=["*"],
            )
        
        app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*"])
        
        # Add rate limiting
        app.state.limiter = self.limiter
        app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
        
        # Register routes
        self._register_routes(app)
        
        return app
    
    def _register_routes(self, app: FastAPI):
        """Register API routes"""
        
        @app.on_event("startup")
        async def startup_event():
            """Initialize services on startup"""
            await self._initialize_services()
        
        @app.on_event("shutdown")
        async def shutdown_event():
            """Cleanup on shutdown"""
            await self._cleanup()
        
        # Health check
        @app.get("/health")
        async def health_check():
            """Gateway health check"""
            return {
                "status": "healthy",
                "timestamp": time.time(),
                "services": len(self.services),
                "active_connections": ACTIVE_CONNECTIONS._value.get()
            }
        
        # Metrics endpoint
        @app.get("/metrics")
        async def metrics():
            """Prometheus metrics"""
            return Response(
                content=generate_latest(),
                media_type=CONTENT_TYPE_LATEST
            )
        
        # Service discovery
        @app.get("/services")
        async def list_services():
            """List registered services"""
            return {
                "services": [
                    {
                        "name": service.name,
                        "path": service.path,
                        "target": service.target,
                        "methods": service.methods
                    }
                    for service in self.services.values()
                ]
            }
        
        # Dynamic routing for all services
        @app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
        async def proxy_request(
            request: Request,
            path: str,
            response: Response
        ):
            """Proxy requests to appropriate services"""
            return await self._handle_proxy_request(request, path, response)
        
        # Compression API
        @app.post("/api/v1/compress")
        async def compress_data(request: Request):
            """Compress data using Go compression engine"""
            return await self._handle_compression(request, "compress")
        
        @app.post("/api/v1/decompress")
        async def decompress_data(request: Request):
            """Decompress data using Go compression engine"""
            return await self._handle_compression(request, "decompress")
        
        @app.post("/api/v1/compress/benchmark")
        async def benchmark_compression(request: Request):
            """Run compression benchmarks"""
            return await self._handle_compression_benchmark(request)
        
        # Backup API
        @app.post("/api/v1/backup/create")
        async def create_backup(request: Request):
            """Create backup using Python backup system"""
            return await self._handle_backup(request, "create")
        
        @app.post("/api/v1/backup/restore")
        async def restore_backup(request: Request):
            """Restore backup using Python backup system"""
            return await self._handle_backup(request, "restore")
        
        @app.get("/api/v1/backup/list")
        async def list_backups():
            """List available backups"""
            return await self._handle_backup_list()
    
    async def _initialize_services(self):
        """Initialize gateway services"""
        try:
            # Initialize Redis
            self.redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
            await self.redis_client.ping()
            self.logger.info("Redis connection established")
        except Exception as e:
            self.logger.warning(f"Redis not available: {e}")
            self.redis_client = None
        
        # Initialize HTTP client
        self.http_client = httpx.AsyncClient(
            timeout=self.config.timeout,
            limits=httpx.Limits(max_connections=self.config.max_connections)
        )
        
        # Register services
        self._register_service_endpoints()
        
        self.logger.info(f"Gateway services initialized: {len(self.services)} services registered")
    
    def _register_service_endpoints(self):
        """Register service endpoints"""
        # Python services
        self.services["python_web"] = ServiceEndpoint(
            name="python_web",
            path="/python",
            target="http://localhost:8001",
            methods=["GET", "POST", "PUT", "DELETE"]
        )
        
        self.services["python_backup"] = ServiceEndpoint(
            name="python_backup",
            path="/backup",
            target="http://localhost:8002",
            methods=["GET", "POST"]
        )
        
        # Go services
        self.services["go_compression"] = ServiceEndpoint(
            name="go_compression",
            path="/compression",
            target="http://localhost:8003",
            methods=["GET", "POST"]
        )
        
        self.services["go_deduplication"] = ServiceEndpoint(
            name="go_deduplication",
            path="/deduplication",
            target="http://localhost:8004",
            methods=["GET", "POST"]
        )
    
    async def _cleanup(self):
        """Cleanup resources"""
        if self.http_client:
            await self.http_client.aclose()
        
        if self.redis_client:
            await self.redis_client.close()
        
        self.logger.info("Gateway cleanup completed")
    
    async def _handle_proxy_request(self, request: Request, path: str, response: Response):
        """Handle proxy requests to services"""
        start_time = time.time()
        
        try:
            # Find matching service
            service = self._find_service(path)
            if not service:
                raise HTTPException(status_code=404, detail="Service not found")
            
            # Check rate limiting
            if service.rate_limit:
                await self._check_rate_limit(request, service)
            
            # Check authentication
            if service.auth_required and self.config.enable_auth:
                await self._check_authentication(request)
            
            # Proxy request
            result = await self._proxy_to_service(request, service)
            
            # Update metrics
            duration = time.time() - start_time
            REQUEST_DURATION.labels(method=request.method, endpoint=path).observe(duration)
            REQUEST_COUNT.labels(method=request.method, endpoint=path, status=200).inc()
            
            return result
            
        except Exception as e:
            # Update error metrics
            duration = time.time() - start_time
            REQUEST_DURATION.labels(method=request.method, endpoint=path).observe(duration)
            REQUEST_COUNT.labels(method=request.method, endpoint=path, status=500).inc()
            
            self.logger.error(f"Proxy request failed: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    def _find_service(self, path: str) -> Optional[ServiceEndpoint]:
        """Find service for given path"""
        for service in self.services.values():
            if path.startswith(service.path):
                return service
        return None
    
    async def _check_rate_limit(self, request: Request, service: ServiceEndpoint):
        """Check rate limiting"""
        if not self.redis_client:
            return
        
        client_ip = get_remote_address(request)
        key = f"rate_limit:{service.name}:{client_ip}"
        
        current = await self.redis_client.get(key)
        if current and int(current) >= service.rate_limit:
            raise HTTPException(status_code=429, detail="Rate limit exceeded")
        
        pipe = self.redis_client.pipeline()
        pipe.incr(key)
        pipe.expire(key, 60)  # 1 minute window
        await pipe.execute()
    
    async def _check_authentication(self, request: Request):
        """Check authentication"""
        # Simple API key authentication
        api_key = request.headers.get("X-API-Key")
        
        # Validate API key from environment variable
        expected_api_key = os.getenv('GRIM_API_KEY')
        if not expected_api_key:
            raise HTTPException(status_code=500, detail="API key not configured")
            
        if api_key != expected_api_key:
            raise HTTPException(status_code=401, detail="Invalid API key")
    
    async def _proxy_to_service(self, request: Request, service: ServiceEndpoint):
        """Proxy request to service"""
        # Build target URL
        target_url = f"{service.target}{request.url.path}"
        
        # Prepare headers
        headers = dict(request.headers)
        headers.pop("host", None)  # Remove host header
        
        # Prepare body
        body = await request.body()
        
        # Make request
        async with self.http_client.stream(
            method=request.method,
            url=target_url,
            headers=headers,
            content=body,
            params=request.query_params
        ) as response:
            # Stream response
            async def generate():
                async for chunk in response.aiter_bytes():
                    yield chunk
            
            return StreamingResponse(
                generate(),
                status_code=response.status_code,
                headers=dict(response.headers)
            )
    
    async def _handle_compression(self, request: Request, operation: str):
        """Handle compression operations using Go engine"""
        try:
            # Get request data
            data = await request.json()
            algorithm = data.get("algorithm", "zstd")
            input_data = data.get("data")
            
            if not input_data:
                raise HTTPException(status_code=400, detail="Data required")
            
            # Create temporary file
            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
                f.write(input_data)
                input_file = f.name
            
            # Run Go compression command
            go_bin = Path("/opt/grim/go_grim/build/grim-compression")
            if not go_bin.exists():
                raise HTTPException(status_code=500, detail="Go compression binary not found")
            
            output_file = f"{input_file}.{algorithm}"
            
            cmd = [
                str(go_bin),
                "-input", input_file,
                "-algorithm", algorithm,
                "-output", output_file
            ]
            
            if operation == "decompress":
                cmd.append("-decompress")
            
            cmd.append("-json")
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            # Parse result
            compression_result = json.loads(result.stdout)
            
            # Read output file
            with open(output_file, 'rb') as f:
                output_data = f.read()
            
            # Cleanup
            Path(input_file).unlink(missing_ok=True)
            Path(output_file).unlink(missing_ok=True)
            
            # Update metrics
            COMPRESSION_OPERATIONS.labels(algorithm=algorithm, operation=operation).inc()
            
            return {
                "operation": operation,
                "algorithm": algorithm,
                "result": compression_result,
                "output_data": output_data.decode('utf-8') if operation == "decompress" else output_data.hex()
            }
            
        except Exception as e:
            self.logger.error(f"Compression operation failed: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def _handle_compression_benchmark(self, request: Request):
        """Handle compression benchmarking"""
        try:
            data = await request.json()
            iterations = data.get("iterations", 3)
            
            go_bin = Path("/opt/grim/go_grim/build/grim-compression")
            if not go_bin.exists():
                raise HTTPException(status_code=500, detail="Go compression binary not found")
            
            cmd = [
                str(go_bin),
                "-benchmark",
                "-iterations", str(iterations),
                "-json"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            benchmark_results = json.loads(result.stdout)
            
            return {
                "benchmark_results": benchmark_results,
                "iterations": iterations
            }
            
        except Exception as e:
            self.logger.error(f"Compression benchmark failed: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def _handle_backup(self, request: Request, operation: str):
        """Handle backup operations using Python system"""
        try:
            data = await request.json()
            
            if operation == "create":
                files = data.get("files", [])
                if not files:
                    raise HTTPException(status_code=400, detail="Files required")
                
                # Import backup manager
                from grim_backup import BackupManager
                backup_manager = BackupManager(Config())
                
                backup_path = backup_manager.create_backup(files)
                
                BACKUP_OPERATIONS.labels(operation="create", status="success").inc()
                
                return {
                    "operation": "create",
                    "backup_path": str(backup_path),
                    "size": backup_path.stat().st_size
                }
            
            elif operation == "restore":
                backup_path = data.get("backup_path")
                restore_dir = data.get("restore_dir")
                
                if not backup_path or not restore_dir:
                    raise HTTPException(status_code=400, detail="Backup path and restore directory required")
                
                # Import backup manager
                from grim_backup import BackupManager
                backup_manager = BackupManager(Config())
                
                backup_manager.restore_backup(backup_path, restore_dir)
                
                BACKUP_OPERATIONS.labels(operation="restore", status="success").inc()
                
                return {
                    "operation": "restore",
                    "backup_path": backup_path,
                    "restore_dir": restore_dir
                }
            
        except Exception as e:
            self.logger.error(f"Backup operation failed: {e}")
            BACKUP_OPERATIONS.labels(operation=operation, status="error").inc()
            raise HTTPException(status_code=500, detail=str(e))
    
    async def _handle_backup_list(self):
        """List available backups"""
        try:
            # Query database for backups
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT filename, size, created_at FROM backups ORDER BY created_at DESC")
                backups = cursor.fetchall()
            
            return {
                "backups": [
                    {
                        "filename": backup[0],
                        "size": backup[1],
                        "created_at": backup[2]
                    }
                    for backup in backups
                ]
            }
            
        except Exception as e:
            self.logger.error(f"Backup list failed: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    def run(self):
        """Run the gateway server"""
        uvicorn.run(
            self.app,
            host=self.config.host,
            port=self.config.port,
            workers=self.config.workers,
            log_level="info"
        )

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grim API Gateway")
    parser.add_argument("--host", default="0.0.0.0", help="Gateway host")
    parser.add_argument("--port", type=int, default=8000, help="Gateway port")
    parser.add_argument("--workers", type=int, default=4, help="Number of workers")
    parser.add_argument("--config", help="Configuration file path")
    
    args = parser.parse_args()
    
    # Load configuration
    config = GatewayConfig(
        host=args.host,
        port=args.port,
        workers=args.workers
    )
    
    # Create and run gateway
    gateway = GatewayService(config)
    gateway.run()

if __name__ == "__main__":
    main() 