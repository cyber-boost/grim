#!/usr/bin/env python3
"""
Production Server for Grim Web Application
High-performance server with advanced features and monitoring
"""

import asyncio
import signal
import sys
import time
from pathlib import Path
from typing import Optional
import uvicorn
from uvicorn.config import Config
from uvicorn.server import Server
import argparse
import os

# Add the GRIM_ROOT to the path
grim_root = os.environ.get('GRIM_ROOT', str(Path(__file__).parent.parent.parent))
sys.path.insert(0, grim_root)

from py_grim.grim_core.config import get_config
from py_grim.grim_core.logger import init_logger, get_logger, log_event, log_metric

class GrimServer:
    """Production-ready server for Grim web application"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config = get_config(config_path)
        self.server: Optional[Server] = None
        self.should_exit = False
        
        # Initialize logging
        init_logger("INFO", "./logs/server.log")
        self.logger = get_logger('server')
        
        # Setup signal handlers
        self._setup_signal_handlers()
    
    def _setup_signal_handlers(self):
        """Setup signal handlers for graceful shutdown"""
        for sig in (signal.SIGTERM, signal.SIGINT):
            signal.signal(sig, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, initiating graceful shutdown")
        self.should_exit = True
        
        if self.server:
            asyncio.create_task(self.server.shutdown())
    
    async def start_server(self):
        """Start the web server"""
        try:
            from py_grim.grim_web.app import app
            
            # Configure server
            config = Config(
                app=app,
                host=self.config.web.host,
                port=self.config.web.port,
                workers=self.config.web.workers,
                access_log=self.config.web.access_log,
                reload=self.config.web.reload
            )
            
            self.server = Server(config)
            
            self.logger.info(f"Starting Grim Web Server on {self.config.web.host}:{self.config.web.port}")
            log_event('server_startup', {
                'host': self.config.web.host,
                'port': self.config.web.port,
                'workers': self.config.web.workers
            })
            
            await self.server.serve()
            
        except Exception as e:
            self.logger.error(f"Server startup failed: {e}")
            raise
    
    def run(self):
        """Run the server"""
        try:
            asyncio.run(self.start_server())
        except KeyboardInterrupt:
            self.logger.info("Server stopped by user")
        except Exception as e:
            self.logger.error(f"Server error: {e}")
            sys.exit(1)


class DevelopmentServer:
    """Development server with hot reload"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config = get_config(config_path)
        
        # Initialize logging
        init_logger("INFO", "./logs/server.log")
        self.logger = get_logger('dev_server')
    
    def run(self, host="127.0.0.1", port=8000, reload=True):
        """Run the development server"""
        self.logger.info("Starting Grim Development Server")
        log_event('dev_server_startup', {
            'host': host,
            'port': port,
            'reload': reload
        })
        
        try:
            from py_grim.grim_web.app import app
            uvicorn.run(
                app,
                host=host,
                port=port,
                reload=reload,
                access_log=True,
                log_level="info"
            )
        except Exception as e:
            self.logger.error(f"Development server error: {e}")
            sys.exit(1)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Grim Web Server")
    parser.add_argument("--config", help="Configuration file path")
    parser.add_argument("--dev", action="store_true", help="Run in development mode")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8000, help="Port to bind to")
    parser.add_argument("--workers", type=int, default=1, help="Number of worker processes")
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload")
    
    args = parser.parse_args()
    
    # Ensure logs directory exists
    os.makedirs("./logs", exist_ok=True)
    
    if args.dev:
        server = DevelopmentServer(args.config)
        server.run(host=args.host, port=args.port, reload=args.reload)
    else:
        server = GrimServer(args.config)
        # Override config with command line args
        server.config.web.host = args.host
        server.config.web.port = args.port
        server.config.web.workers = args.workers
        server.config.web.reload = args.reload
        server.run()


if __name__ == "__main__":
    main() 