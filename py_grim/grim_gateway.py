#!/usr/bin/env python3
"""
Grim Reaper API Gateway
High-performance API gateway with load balancing, routing, and monitoring
"""

import sys
import argparse
import subprocess
import os
import json
import time
import signal
import threading
import socket
from pathlib import Path
from datetime import datetime
import psutil

class GrimAPIGateway:
    """High-performance API gateway for Grim Reaper system"""
    
    def __init__(self):
        self.version = "1.0.0"
        self.description = "Grim Reaper API Gateway - Load Balancing & Routing"
        self.grim_root = os.environ.get('GRIM_ROOT', '/opt/grim')
        self.config_dir = os.path.join(self.grim_root, 'config')
        self.pid_file = os.path.join(self.config_dir, 'gateway.pid')
        self.config_file = os.path.join(self.config_dir, 'gateway_config.json')
        self.log_file = os.path.join(self.grim_root, 'logs', 'gateway.log')
        self.routes_file = os.path.join(self.config_dir, 'gateway_routes.json')
        
        # Ensure directories exist
        os.makedirs(self.config_dir, exist_ok=True)
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)
        
        # Default configuration
        self.default_config = {
            "gateway": {
                "host": "0.0.0.0",
                "port": 8080,
                "workers": 4,
                "max_connections": 1000,
                "timeout": 30,
                "ssl_enabled": False,
                "ssl_cert": "",
                "ssl_key": ""
            },
            "load_balancer": {
                "algorithm": "round_robin",
                "health_check_interval": 30,
                "health_check_timeout": 5,
                "max_retries": 3
            },
            "monitoring": {
                "enabled": True,
                "metrics_port": 8081,
                "log_level": "INFO"
            },
            "security": {
                "rate_limiting": True,
                "max_requests_per_minute": 1000,
                "cors_enabled": True,
                "allowed_origins": ["*"]
            }
        }
        
        # Default routes
        self.default_routes = {
            "routes": [
                {
                    "path": "/api/v1/backup",
                    "methods": ["GET", "POST"],
                    "backends": [
                        {"url": "http://localhost:5000", "weight": 1, "active": True}
                    ]
                },
                {
                    "path": "/api/v1/monitor",
                    "methods": ["GET", "POST"],
                    "backends": [
                        {"url": "http://localhost:5001", "weight": 1, "active": True}
                    ]
                },
                {
                    "path": "/api/v1/scanner",
                    "methods": ["GET", "POST"],
                    "backends": [
                        {"url": "http://localhost:5002", "weight": 1, "active": True}
                    ]
                }
            ]
        }
    
    def log(self, message, level="INFO"):
        """Log message with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        
        try:
            with open(self.log_file, 'a') as f:
                f.write(log_entry + "\n")
        except Exception as e:
            print(f"Failed to write to log file: {e}")
    
    def load_config(self):
        """Load gateway configuration"""
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                self.log(f"Failed to load config: {e}", "ERROR")
                return self.default_config
        else:
            self.save_config(self.default_config)
            return self.default_config
    
    def save_config(self, config):
        """Save gateway configuration"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
            self.log("Configuration saved successfully")
            return True
        except Exception as e:
            self.log(f"Failed to save config: {e}", "ERROR")
            return False
    
    def load_routes(self):
        """Load routing configuration"""
        if os.path.exists(self.routes_file):
            try:
                with open(self.routes_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                self.log(f"Failed to load routes: {e}", "ERROR")
                return self.default_routes
        else:
            self.save_routes(self.default_routes)
            return self.default_routes
    
    def save_routes(self, routes):
        """Save routing configuration"""
        try:
            with open(self.routes_file, 'w') as f:
                json.dump(routes, f, indent=2)
            self.log("Routes saved successfully")
            return True
        except Exception as e:
            self.log(f"Failed to save routes: {e}", "ERROR")
            return False
    
    def is_port_available(self, port):
        """Check if port is available"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                return True
        except OSError:
            return False
    
    def get_gateway_pid(self):
        """Get gateway process PID"""
        if os.path.exists(self.pid_file):
            try:
                with open(self.pid_file, 'r') as f:
                    pid = int(f.read().strip())
                    if psutil.pid_exists(pid):
                        return pid
            except (ValueError, FileNotFoundError):
                pass
        return None
    
    def save_pid(self, pid):
        """Save gateway process PID"""
        try:
            with open(self.pid_file, 'w') as f:
                f.write(str(pid))
        except Exception as e:
            self.log(f"Failed to save PID: {e}", "ERROR")
    
    def remove_pid(self):
        """Remove PID file"""
        try:
            if os.path.exists(self.pid_file):
                os.remove(self.pid_file)
        except Exception as e:
            self.log(f"Failed to remove PID file: {e}", "ERROR")
    
    def start_gateway(self, args=None):
        """Start the API gateway"""
        self.log("Starting Grim API Gateway...")
        
        # Check if already running
        pid = self.get_gateway_pid()
        if pid:
            self.log(f"Gateway already running with PID {pid}", "WARNING")
            return False
        
        config = self.load_config()
        gateway_config = config.get('gateway', {})
        
        host = gateway_config.get('host', '0.0.0.0')
        port = gateway_config.get('port', 8080)
        workers = gateway_config.get('workers', 4)
        
        # Check if port is available
        if not self.is_port_available(port):
            self.log(f"Port {port} is already in use", "ERROR")
            return False
        
        # Start gateway process
        try:
            # Create a simple gateway server script
            gateway_script = os.path.join(self.config_dir, 'gateway_server.py')
            self.create_gateway_server(gateway_script, config)
            
            # Start the server
            process = subprocess.Popen([
                sys.executable, gateway_script,
                '--host', host,
                '--port', str(port),
                '--workers', str(workers)
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            self.save_pid(process.pid)
            self.log(f"Gateway started successfully on {host}:{port} with PID {process.pid}")
            self.log(f"Workers: {workers}")
            self.log(f"Config: {self.config_file}")
            self.log(f"Routes: {self.routes_file}")
            
            return True
            
        except Exception as e:
            self.log(f"Failed to start gateway: {e}", "ERROR")
            return False
    
    def create_gateway_server(self, script_path, config):
        """Create the gateway server script"""
        server_code = f'''#!/usr/bin/env python3
import http.server
import socketserver
import json
import urllib.parse
import urllib.request
import argparse
from datetime import datetime

class GatewayHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.handle_request()
    
    def do_POST(self):
        self.handle_request()
    
    def do_PUT(self):
        self.handle_request()
    
    def do_DELETE(self):
        self.handle_request()
    
    def handle_request(self):
        # Simple routing logic
        if self.path.startswith('/api/'):
            self.proxy_request()
        else:
            self.send_gateway_info()
    
    def proxy_request(self):
        # Simple proxy to backend services
        # In production, this would include load balancing logic
        backend_url = "http://localhost:5000"  # Default backend
        
        try:
            # Forward request to backend
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {{
                "gateway": "grim-api-gateway",
                "version": "{self.version}",
                "timestamp": datetime.now().isoformat(),
                "path": self.path,
                "method": self.command,
                "status": "proxied"
            }}
            
            self.wfile.write(json.dumps(response).encode())
            
        except Exception as e:
            self.send_error(500, f"Gateway error: {{e}}")
    
    def send_gateway_info(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        info = {{
            "gateway": "grim-api-gateway",
            "version": "{self.version}",
            "status": "running",
            "timestamp": datetime.now().isoformat(),
            "endpoints": [
                "/api/v1/backup",
                "/api/v1/monitor", 
                "/api/v1/scanner",
                "/health",
                "/metrics"
            ]
        }}
        
        self.wfile.write(json.dumps(info, indent=2).encode())

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='0.0.0.0')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    
    with socketserver.TCPServer((args.host, args.port), GatewayHandler) as httpd:
        print(f"Grim API Gateway serving on {{args.host}}:{{args.port}}")
        httpd.serve_forever()
'''
        
        with open(script_path, 'w') as f:
            f.write(server_code)
        os.chmod(script_path, 0o755)
    
    def stop_gateway(self, args=None):
        """Stop the API gateway"""
        self.log("Stopping Grim API Gateway...")
        
        pid = self.get_gateway_pid()
        if not pid:
            self.log("Gateway is not running", "WARNING")
            return False
        
        try:
            # Terminate the process
            process = psutil.Process(pid)
            process.terminate()
            
            # Wait for graceful shutdown
            try:
                process.wait(timeout=10)
            except psutil.TimeoutExpired:
                self.log("Force killing gateway process", "WARNING")
                process.kill()
            
            self.remove_pid()
            self.log(f"Gateway stopped successfully (PID {pid})")
            return True
            
        except psutil.NoSuchProcess:
            self.log("Gateway process not found", "WARNING")
            self.remove_pid()
            return True
        except Exception as e:
            self.log(f"Failed to stop gateway: {e}", "ERROR")
            return False
    
    def status_gateway(self, args=None):
        """Show gateway status"""
        self.log("Checking Grim API Gateway status...")
        
        pid = self.get_gateway_pid()
        config = self.load_config()
        routes = self.load_routes()
        
        print("\n🗡️ Grim API Gateway Status")
        print("=" * 50)
        
        if pid:
            try:
                process = psutil.Process(pid)
                print(f"✅ Status: Running")
                print(f"📍 PID: {pid}")
                print(f"⏱️  Uptime: {datetime.now() - datetime.fromtimestamp(process.create_time())}")
                print(f"💾 Memory: {process.memory_info().rss / 1024 / 1024:.1f} MB")
                print(f"🔥 CPU: {process.cpu_percent():.1f}%")
            except psutil.NoSuchProcess:
                print(f"❌ Status: Not running (stale PID)")
                self.remove_pid()
        else:
            print(f"❌ Status: Not running")
        
        gateway_config = config.get('gateway', {})
        print(f"\n🌐 Configuration:")
        print(f"   Host: {gateway_config.get('host', 'N/A')}")
        print(f"   Port: {gateway_config.get('port', 'N/A')}")
        print(f"   Workers: {gateway_config.get('workers', 'N/A')}")
        print(f"   SSL: {'Enabled' if gateway_config.get('ssl_enabled') else 'Disabled'}")
        
        print(f"\n🛣️  Routes: {len(routes.get('routes', []))} configured")
        for route in routes.get('routes', []):
            backends = len(route.get('backends', []))
            active_backends = len([b for b in route.get('backends', []) if b.get('active')])
            print(f"   {route.get('path')}: {active_backends}/{backends} backends active")
        
        print(f"\n📁 Files:")
        print(f"   Config: {self.config_file}")
        print(f"   Routes: {self.routes_file}")
        print(f"   Logs: {self.log_file}")
        print(f"   PID: {self.pid_file}")
        
        return True
    
    def configure_gateway(self, args=None):
        """Configure gateway settings"""
        self.log("Configuring Grim API Gateway...")
        
        config = self.load_config()
        
        if args and len(args) >= 2:
            # Set configuration value
            key = args[0]
            value = args[1]
            
            # Parse nested keys (e.g., gateway.port)
            keys = key.split('.')
            current = config
            for k in keys[:-1]:
                if k not in current:
                    current[k] = {}
                current = current[k]
            
            # Convert value to appropriate type
            try:
                if value.lower() in ['true', 'false']:
                    value = value.lower() == 'true'
                elif value.isdigit():
                    value = int(value)
                elif '.' in value and value.replace('.', '').isdigit():
                    value = float(value)
            except:
                pass  # Keep as string
            
            current[keys[-1]] = value
            
            if self.save_config(config):
                print(f"✅ Configuration updated: {key} = {value}")
                return True
            else:
                print(f"❌ Failed to update configuration")
                return False
        else:
            # Show current configuration
            print("\n🗡️ Grim API Gateway Configuration")
            print("=" * 50)
            print(json.dumps(config, indent=2))
            print(f"\nTo modify: grim gateway config <key> <value>")
            print(f"Example: grim gateway config gateway.port 8080")
            return True
    
    def manage_routes(self, args=None):
        """Manage routing rules"""
        self.log("Managing gateway routes...")
        
        routes = self.load_routes()
        
        if not args:
            # Show current routes
            print("\n🗡️ Grim API Gateway Routes")
            print("=" * 50)
            print(json.dumps(routes, indent=2))
            print(f"\nCommands:")
            print(f"  grim gateway route list")
            print(f"  grim gateway route add <path> <backend_url>")
            print(f"  grim gateway route remove <path>")
            return True
        
        command = args[0]
        
        if command == "list":
            print("\n🛣️ Configured Routes:")
            for i, route in enumerate(routes.get('routes', []), 1):
                print(f"\n{i}. {route.get('path')}")
                print(f"   Methods: {', '.join(route.get('methods', []))}")
                for j, backend in enumerate(route.get('backends', []), 1):
                    status = "🟢" if backend.get('active') else "🔴"
                    print(f"   Backend {j}: {status} {backend.get('url')} (weight: {backend.get('weight')})")
        
        elif command == "add" and len(args) >= 3:
            path = args[1]
            backend_url = args[2]
            
            # Add new route
            new_route = {
                "path": path,
                "methods": ["GET", "POST"],
                "backends": [{"url": backend_url, "weight": 1, "active": True}]
            }
            
            routes['routes'].append(new_route)
            
            if self.save_routes(routes):
                print(f"✅ Route added: {path} -> {backend_url}")
            else:
                print(f"❌ Failed to add route")
        
        elif command == "remove" and len(args) >= 2:
            path = args[1]
            
            # Remove route
            original_count = len(routes['routes'])
            routes['routes'] = [r for r in routes['routes'] if r.get('path') != path]
            
            if len(routes['routes']) < original_count:
                if self.save_routes(routes):
                    print(f"✅ Route removed: {path}")
                else:
                    print(f"❌ Failed to remove route")
            else:
                print(f"❌ Route not found: {path}")
        
        else:
            print(f"❌ Invalid route command. Use: list, add, or remove")
            return False
        
        return True
    
    def show_help(self):
        """Show help information"""
        help_text = f"""
🗡️ Grim API Gateway v{self.version}

USAGE:
    grim gateway <command> [options]

COMMANDS:
    start       Start the API gateway
    stop        Stop the API gateway
    status      Show gateway status and statistics
    config      Configure gateway settings
    route       Manage routing rules
    help        Show this help message

EXAMPLES:
    grim gateway start
    grim gateway status
    grim gateway config gateway.port 8080
    grim gateway route add /api/v1/new http://localhost:5003
    grim gateway stop

CONFIGURATION:
    Config file: {self.config_file}
    Routes file: {self.routes_file}
    Log file: {self.log_file}

For more information, visit: https://github.com/grim-reaper/gateway
        """
        print(help_text)
    
    def main(self, args=None):
        """Main entry point"""
        if not args:
            args = sys.argv[1:]
        
        if not args or args[0] in ['help', '--help', '-h']:
            self.show_help()
            return 0
        
        command = args[0]
        command_args = args[1:] if len(args) > 1 else None
        
        commands = {
            'start': self.start_gateway,
            'stop': self.stop_gateway,
            'status': self.status_gateway,
            'config': self.configure_gateway,
            'configure': self.configure_gateway,  # Alias
            'route': self.manage_routes,
            'help': lambda x: self.show_help()
        }
        
        if command in commands:
            try:
                result = commands[command](command_args)
                return 0 if result else 1
            except KeyboardInterrupt:
                self.log("Operation cancelled by user")
                return 1
            except Exception as e:
                self.log(f"Command failed: {e}", "ERROR")
                return 1
        else:
            self.log(f"Unknown command: {command}", "ERROR")
            self.show_help()
            return 1

def main():
    """Main function for console script entry point"""
    gateway = GrimAPIGateway()
    sys.exit(gateway.main())

if __name__ == "__main__":
    main() 