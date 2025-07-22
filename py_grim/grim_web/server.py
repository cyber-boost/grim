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

from grim_core.config import get_config
from grim_core.logger import init_logger, get_logger, log_event, log_metric

class GrimServer:
    """Production-ready server for Grim web application"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config = get_config(config_path)
        self.server: Optional[Server] = None
        self.should_exit = False
        
        # Initialize logging
        init_logger("./logs", self.config.get_log_level())
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
            self.logger.info("Starting Grim Web Server")
            log_event('server_startup', {
                'host': self.config.web.host,
                'port': self.config.web.port,
                'workers': self.config.web.workers
            })
            
            # Create server configuration
            config = Config(
                app="grim_web.app:app",
                host=self.config.web.host,
                port=self.config.web.port,
                workers=self.config.web.workers,
                reload=self.config.web.reload,
                access_log=self.config.web.access_log,
                log_level=self.config.logging.level.lower(),
                loop="asyncio"
            )
            
            # Create and start server
            self.server = Server(config=config)
            await self.server.serve()
            
        except Exception as e:
            self.logger.error(f"Failed to start server: {e}")
            log_event('server_startup_failed', {'error': str(e)})
            raise
    
    async def stop_server(self):
        """Stop the web server gracefully"""
        if self.server:
            self.logger.info("Stopping Grim Web Server")
            await self.server.shutdown()
            log_event('server_shutdown', {})
    
    def run(self):
        """Run the server in the main thread"""
        try:
            # Start the event loop
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            # Run the server
            loop.run_until_complete(self.start_server())
            
        except KeyboardInterrupt:
            self.logger.info("Received keyboard interrupt")
        except Exception as e:
            self.logger.error(f"Server error: {e}")
            sys.exit(1)
        finally:
            # Cleanup
            if loop.is_running():
                loop.run_until_complete(self.stop_server())
            loop.close()

class DevelopmentServer:
    """Development server with hot reload"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config = get_config(config_path)
        
        # Initialize logging
        init_logger("./logs", self.config.get_log_level())
        self.logger = get_logger('dev_server')
    
    def run(self):
        """Run the development server"""
        self.logger.info("Starting Grim Development Server")
        log_event('dev_server_startup', {
            'host': self.config.web.host,
            'port': self.config.web.port,
            'reload': True
        })
        
        uvicorn.run(
            "grim_web.app:app",
            host=self.config.web.host,
            port=self.config.web.port,
            reload=True,
            log_level=self.config.logging.level.lower(),
            access_log=self.config.web.access_log
        )

def main():
    """Main entry point for the server"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grim Web Server")
    parser.add_argument('--config', help='Configuration file path')
    parser.add_argument('--dev', action='store_true', help='Run in development mode')
    parser.add_argument('--host', help='Host to bind to')
    parser.add_argument('--port', type=int, help='Port to bind to')
    parser.add_argument('--workers', type=int, help='Number of worker processes')
    parser.add_argument('--reload', action='store_true', help='Enable auto-reload')
    
    args = parser.parse_args()
    
    # Override config with command line arguments
    if args.host or args.port or args.workers or args.reload:
        config = get_config(args.config)
        if args.host:
            config.web.host = args.host
        if args.port:
            config.web.port = args.port
        if args.workers:
            config.web.workers = args.workers
        if args.reload:
            config.web.reload = args.reload
    
    if args.dev:
        # Run development server
        server = DevelopmentServer(args.config)
        server.run()
    else:
        # Run production server
        server = GrimServer(args.config)
        server.run()

if __name__ == "__main__":
    main() 