#!/usr/bin/env python3
"""
Grim Reaper Python Package
Real integration with sh_grim, go_grim, and py_grim core modules
"""

import os
import subprocess
import json
import asyncio
from pathlib import Path
from typing import Dict, List, Optional, Union
import requests

__version__ = "1.0.9"
__author__ = "Bernie Gengel and his beagle Buddy"
__license__ = "BBL"

# Post-install setup
def _run_post_install():
    """Run post-install setup if needed"""
    try:
        from .post_install import setup_scythe
        setup_scythe()
    except ImportError:
        # Post-install script not available, skip
        pass

# Run post-install on first import
_run_post_install()

class GrimReaper:
    """
    Grim Reaper Python interface with real core integration
    No mock files - calls actual sh_grim, go_grim, and py_grim components
    """
    
    def __init__(self, grim_root: Optional[str] = None):
        """Initialize Grim Reaper with portable path discovery"""
        self.grim_root = grim_root or self._find_grim_root()
        self.api_base = "http://localhost:8000"
        
    def _find_grim_root(self) -> str:
        """Find Grim Reaper installation directory"""
        # Check environment variable first
        if os.environ.get('GRIM_ROOT'):
            env_path = os.environ['GRIM_ROOT']
            if self._is_grim_installation(env_path):
                return env_path
        
        # Search up directory tree
        current_dir = Path.cwd()
        for _ in range(10):  # Max depth
            if self._is_grim_installation(str(current_dir)):
                return str(current_dir)
            
            parent = current_dir.parent
            if parent == current_dir:
                break
            current_dir = parent
        
        # Try common installation paths
        possible_paths = [
            os.path.expanduser("~/reaper"),
            os.path.expanduser("~/.reaper"),
            "/root/reaper",
            "/root/.reaper",
            "/usr/local/reaper",
            "/usr/local/share/reaper", 
            "/usr/share/reaper",
            "/opt/reaper",
            "/usr/local/lib/grim-reaper",
            "/usr/lib/grim-reaper",
        ]
        
        for path in possible_paths:
            if self._is_grim_installation(path):
                return path
        
        raise RuntimeError(
            f"Could not find Grim Reaper root directory.\n"
            f"Searched paths: {', '.join(possible_paths)}\n\n"
            f"Please ensure Grim Reaper is properly installed using:\n"
            f"  • curl -fsSL https://get.grim.so | sudo bash\n"
            f"  • wget -qO- https://get.grim.so | sudo bash\n\n"
            f"Or set GRIM_ROOT environment variable:\n"
            f"  export GRIM_ROOT=/path/to/your/grim/installation"
        )
    
    def _is_grim_installation(self, path: str) -> bool:
        """Check if path contains a valid Grim installation"""
        if not os.path.isdir(path):
            return False
        
        # Check for key Grim files
        key_files = [
            "throne/grim_throne.sh",
            "tsk_flask/grim_admin_server.py",
            "sh_grim/backup.sh",
            "go_grim/build/grim-compression"
        ]
        
        return any(os.path.exists(os.path.join(path, key_file)) for key_file in key_files)
    
    def _execute_sh_module(self, module: str, args: List[str] = None) -> str:
        """Execute sh_grim module with proper error handling"""
        args = args or []
        module_path = os.path.join(self.grim_root, "sh_grim", f"{module}.sh")
        
        if not os.path.exists(module_path):
            raise FileNotFoundError(f"Module not found: {module}")
        
        try:
            result = subprocess.run(
                [module_path] + args,
                cwd=self.grim_root,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Module {module} failed: {e.stderr}")
    
    def _execute_go_binary(self, binary: str, args: List[str] = None) -> str:
        """Execute go_grim binary with proper error handling"""
        args = args or []
        binary_path = os.path.join(self.grim_root, "go_grim", "build", binary)
        
        if not os.path.exists(binary_path):
            raise FileNotFoundError(f"Go binary not found: {binary}")
        
        try:
            result = subprocess.run(
                [binary_path] + args,
                cwd=self.grim_root,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Go binary {binary} failed: {e.stderr}")
    
    async def _call_py_api(self, endpoint: str, method: str = "GET", data: Dict = None) -> Dict:
        """Call py_grim FastAPI service"""
        url = f"{self.api_base}{endpoint}"
        
        try:
            if method == "GET":
                response = requests.get(url, timeout=30)
            elif method == "POST":
                response = requests.post(url, json=data, timeout=30)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")
            
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"API call failed: {e}")
    
    # ============================================================================
    # BACKUP OPERATIONS (via sh_grim)
    # ============================================================================
    
    def backup(self, source: str, name: Optional[str] = None, compress: str = "zstd", 
               incremental: bool = False) -> str:
        """Create backup using sh_grim/backup.sh"""
        args = [source]
        
        if name:
            args.extend(["--name", name])
        if compress:
            args.extend(["--compress", compress])
        if incremental:
            args.append("--incremental")
        
        return self._execute_sh_module("backup", args)
    
    def restore(self, backup: str, destination: str, overwrite: bool = False) -> str:
        """Restore from backup using sh_grim/restore.sh"""
        args = [backup, destination]
        
        if overwrite:
            args.append("--overwrite")
        
        return self._execute_sh_module("restore", args)
    
    def list_backups(self) -> str:
        """List available backups"""
        return self._execute_sh_module("backup", ["--list"])
    
    # ============================================================================
    # COMPRESSION OPERATIONS (via go_grim)
    # ============================================================================
    
    def compress(self, file_path: str, algorithm: str = "zstd", level: int = 6, 
                 output: Optional[str] = None) -> str:
        """Compress file using go_grim compression engine"""
        args = []
        
        if algorithm:
            args.extend(["-a", algorithm])
        if level:
            args.extend(["-l", str(level)])
        if output:
            args.extend(["-o", output])
        
        args.append(file_path)
        
        return self._execute_go_binary("grim-compression", args)
    
    def decompress(self, file_path: str, output: Optional[str] = None) -> str:
        """Decompress file using go_grim"""
        args = ["-d"]
        
        if output:
            args.extend(["-o", output])
        args.append(file_path)
        
        return self._execute_go_binary("grim-compression", args)
    
    def benchmark_compression(self, file_path: str) -> str:
        """Get compression benchmarks"""
        return self._execute_go_binary("grim-compression", ["-benchmark", file_path])
    
    # ============================================================================
    # MONITORING OPERATIONS (via sh_grim)
    # ============================================================================
    
    def start_monitoring(self, path: str, interval: int = 5, events: str = "all") -> str:
        """Start monitoring using sh_grim/monitor.sh"""
        args = ["start", path]
        
        if interval:
            args.extend(["--interval", str(interval)])
        if events:
            args.extend(["--events", events])
        
        return self._execute_sh_module("monitor", args)
    
    def stop_monitoring(self) -> str:
        """Stop monitoring"""
        return self._execute_sh_module("monitor", ["stop"])
    
    def get_monitoring_status(self) -> str:
        """Get monitoring status"""
        return self._execute_sh_module("monitor", ["status"])
    
    # ============================================================================
    # SCANNING OPERATIONS (via sh_grim)
    # ============================================================================
    
    def scan(self, path: str, recursive: bool = True, types: Optional[str] = None, 
             output: Optional[str] = None) -> str:
        """Scan directory using sh_grim/scan.sh"""
        args = [path]
        
        if recursive:
            args.append("--recursive")
        if types:
            args.extend(["--types", types])
        if output:
            args.extend(["--output", output])
        
        return self._execute_sh_module("scan", args)
    
    def security_scan(self, path: str, deep: bool = False, report: Optional[str] = None) -> str:
        """Security scan using sh_grim/security.sh"""
        args = [path]
        
        if deep:
            args.append("--deep")
        if report:
            args.extend(["--report", report])
        
        return self._execute_sh_module("security", args)
    
    # ============================================================================
    # SYSTEM OPERATIONS (via sh_grim)
    # ============================================================================
    
    def health_check(self) -> str:
        """System health check using sh_grim/health.sh"""
        return self._execute_sh_module("health", ["check"])
    
    def get_status(self) -> str:
        """Get system status"""
        return self._execute_sh_module("health", ["status"])
    
    def optimize(self, target: str = "all") -> str:
        """Optimize system using sh_grim/blacksmith.sh"""
        return self._execute_sh_module("blacksmith", ["optimize", target])
    
    def heal(self) -> str:
        """Self-healing using sh_grim/healer.sh"""
        return self._execute_sh_module("healer", ["heal"])
    
    # ============================================================================
    # API INTEGRATION (via py_grim FastAPI)
    # ============================================================================
    
    async def get_api_status(self) -> Dict:
        """Get system status via API"""
        return await self._call_py_api("/api/status")
    
    async def get_backup_info(self) -> Dict:
        """Get backup information via API"""
        return await self._call_py_api("/api/backups")
    
    async def start_api_backup(self, source: str, **options) -> Dict:
        """Start backup via API"""
        data = {"source": source, **options}
        return await self._call_py_api("/api/backup", "POST", data)
    
    async def get_monitoring_data(self) -> Dict:
        """Get monitoring data via API"""
        return await self._call_py_api("/api/monitoring")
    
    # ============================================================================
    # UTILITY METHODS
    # ============================================================================
    
    def execute_command(self, command: str, args: List[str] = None) -> str:
        """Execute raw grim command via throne script"""
        throne_path = os.path.join(self.grim_root, "throne", "grim_throne.sh")
        args = args or []
        
        try:
            result = subprocess.run(
                [throne_path, command] + args,
                cwd=self.grim_root,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Command {command} failed: {e.stderr}")
    
    def get_version(self) -> str:
        """Get Grim version and build info"""
        try:
            manifest_path = os.path.join(self.grim_root, "builds", "latest", "manifest.tsk")
            if os.path.exists(manifest_path):
                with open(manifest_path, 'r') as f:
                    return f.read()
        except Exception:
            pass
        
        return self.execute_command("version")
    
    def check_services(self) -> Dict[str, bool]:
        """Check if Grim services are running"""
        services = {
            "api": False,
            "monitoring": False,
            "admin": False
        }
        
        try:
            # Check FastAPI service
            subprocess.run(["pgrep", "-f", "grim_web"], check=True, capture_output=True)
            services["api"] = True
        except subprocess.CalledProcessError:
            pass
        
        try:
            # Check monitoring service
            subprocess.run(["pgrep", "-f", "monitor.sh"], check=True, capture_output=True)
            services["monitoring"] = True
        except subprocess.CalledProcessError:
            pass
        
        try:
            # Check admin server
            subprocess.run(["pgrep", "-f", "grim_admin_server.py"], check=True, capture_output=True)
            services["admin"] = True
        except subprocess.CalledProcessError:
            pass
        
        return services


# Convenience functions for direct use
def backup(source: str, **kwargs) -> str:
    """Quick backup function"""
    grim = GrimReaper()
    return grim.backup(source, **kwargs)

def restore(backup: str, destination: str, **kwargs) -> str:
    """Quick restore function"""
    grim = GrimReaper()
    return grim.restore(backup, destination, **kwargs)

def compress(file_path: str, **kwargs) -> str:
    """Quick compress function"""
    grim = GrimReaper()
    return grim.compress(file_path, **kwargs)

def health_check() -> str:
    """Quick health check function"""
    grim = GrimReaper()
    return grim.health_check()

def scan(path: str, **kwargs) -> str:
    """Quick scan function"""
    grim = GrimReaper()
    return grim.scan(path, **kwargs)

def main():
    """CLI entry point for grim-reaper command"""
    import sys
    import argparse
    
    parser = argparse.ArgumentParser(description="Grim Reaper Python CLI")
    parser.add_argument("command", choices=["backup", "restore", "compress", "health", "scan", "version"], 
                       help="Command to execute")
    parser.add_argument("args", nargs="*", help="Command arguments")
    
    args = parser.parse_args()
    
    try:
        grim = GrimReaper()
        
        if args.command == "backup":
            if not args.args:
                print("Error: backup requires a source path")
                sys.exit(1)
            result = grim.backup(args.args[0])
            print(result)
        elif args.command == "restore":
            if len(args.args) < 2:
                print("Error: restore requires backup path and destination")
                sys.exit(1)
            result = grim.restore(args.args[0], args.args[1])
            print(result)
        elif args.command == "compress":
            if not args.args:
                print("Error: compress requires a file path")
                sys.exit(1)
            result = grim.compress(args.args[0])
            print(result)
        elif args.command == "health":
            result = grim.health_check()
            print(result)
        elif args.command == "scan":
            if not args.args:
                print("Error: scan requires a path")
                sys.exit(1)
            result = grim.scan(args.args[0])
            print(result)
        elif args.command == "version":
            result = grim.get_version()
            print(result)
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)