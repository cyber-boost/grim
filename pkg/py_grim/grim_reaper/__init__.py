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

__version__ = "1.0.36"
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
        self._setup_environment()
        
    def _setup_environment(self):
        """Setup required environment variables"""
        # Set GRIM_ROOT if not already set
        if not os.environ.get('GRIM_ROOT'):
            os.environ['GRIM_ROOT'] = self.grim_root
            
        # Set GRIM_LICENSE to FREE if not already set
        if not os.environ.get('GRIM_LICENSE'):
            os.environ['GRIM_LICENSE'] = "FREE"
            
        # Set GRIM_REAPER to FALSE if not already set (normal install)
        if not os.environ.get('GRIM_REAPER'):
            os.environ['GRIM_REAPER'] = "FALSE"
            
        # Try to add environment variables to user's shell profile
        self._persist_environment_variables()
        
    def _persist_environment_variables(self):
        """Persist environment variables to shell profile"""
        try:
            # Determine shell profile file
            home_dir = os.path.expanduser("~")
            profile_files = [
                os.path.join(home_dir, ".bashrc"),
                os.path.join(home_dir, ".zshrc"),
                os.path.join(home_dir, ".profile")
            ]
            
            # Find the first existing profile file
            profile_file = None
            for pf in profile_files:
                if os.path.exists(pf):
                    profile_file = pf
                    break
            
            if not profile_file:
                # Create .bashrc if no profile exists
                profile_file = os.path.join(home_dir, ".bashrc")
            
            # Check if our exports already exist
            env_exports = [
                f'export GRIM_ROOT="{self.grim_root}"',
                'export GRIM_LICENSE="FREE"',
                'export GRIM_REAPER="FALSE"'
            ]
            
            existing_content = ""
            if os.path.exists(profile_file):
                with open(profile_file, 'r') as f:
                    existing_content = f.read()
            
            # Add exports if they don't exist
            content_to_add = []
            for export in env_exports:
                if export not in existing_content:
                    content_to_add.append(export)
            
            if content_to_add:
                with open(profile_file, 'a') as f:
                    f.write("\n# Grim Reaper Environment Variables\n")
                    for export in content_to_add:
                        f.write(f"{export}\n")
                
                print(f"✅ Environment variables added to {profile_file}")
                
        except Exception as e:
            # Don't fail installation if we can't persist env vars
            print(f"⚠️  Could not persist environment variables: {e}")
        
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
            "/root",
            os.path.expanduser("~"),
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
        
        # Determine install location with proper permissions
        install_dir = self._determine_install_location()
        
        try:
            print(f"🗡️  Grim Reaper not found. Installing to {install_dir}...")
            self._install_grim_core(install_dir)
            return install_dir
        except Exception as install_error:
            raise RuntimeError(
                f"Could not find Grim Reaper root directory.\n"
                f"Searched paths: {', '.join(possible_paths)}\n"
                f"Auto-installation failed: {install_error}\n\n"
                f"Please ensure Grim Reaper is properly installed using:\n"
                f"  • curl -fsSL https://get.grim.so | sudo bash\n"
                f"  • wget -qO- https://get.grim.so | sudo bash\n\n"
                f"Or set GRIM_ROOT environment variable:\n"
                f"  export GRIM_ROOT=/path/to/your/grim/installation\n\n"
                f"If you get permission errors, try:\n"
                f"  chmod +x ./install.sh && ./install.sh"
            )
    
    def _determine_install_location(self) -> str:
        """Determine the best installation location based on permissions"""
        # Try /root first
        if os.access("/root", os.W_OK):
            return "/root"
        
        # Try user home directory
        home_dir = os.path.expanduser("~")
        if os.access(home_dir, os.W_OK):
            return home_dir
            
        # Try local directory
        current_dir = os.getcwd()
        if os.access(current_dir, os.W_OK):
            return current_dir
            
        # Fallback to /tmp (less ideal but works)
        return "/tmp/grim_install"
    
    def _is_grim_installation(self, path: str) -> bool:
        """Check if path contains a valid Grim installation"""
        if not os.path.isdir(path):
            return False
        
        # Check for key Grim files in various possible structures
        key_files = [
            # Direct structure
            "throne/grim_throne.sh",
            "tsk_flask/grim_admin_server.py",
            "sh_grim/backup.sh",
            "go_grim/build/grim-compression",
            # Reaper structure
            "reaper/throne/grim_throne.sh",
            "reaper/tsk_flask/grim_admin_server.py",
            "reaper/sh_grim/backup.sh",
            "reaper/go_grim/build/grim-compression",
            # Main source structure
            "grim_throne.sh",
            "reaper.sh",
            ".rip/config.tsk",
            "auto_backups/",
        ]
        
        return any(os.path.exists(os.path.join(path, key_file)) for key_file in key_files)
    
    def _install_grim_core(self, install_dir: str) -> None:
        """Install Grim Reaper core system from latest.tar.gz"""
        import tarfile
        import tempfile
        import shutil
        
        print("📥 Downloading Grim Reaper from get.grim.so...")
        
        # Download latest.tar.gz
        download_url = "https://get.grim.so/latest.tar.gz"
        try:
            response = requests.get(download_url, stream=True, timeout=60)
            response.raise_for_status()
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"Failed to download Grim Reaper: {e}")
        
        # Create installation directory
        os.makedirs(install_dir, exist_ok=True)
        
        # Save to temp file
        with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as temp_file:
            for chunk in response.iter_content(chunk_size=8192):
                temp_file.write(chunk)
            temp_path = temp_file.name
        
        print("✅ Download complete")
        print("📦 Extracting Grim Reaper...")
        
        try:
            # Extract tarball with strip=2 to handle graveyard/reaper/ prefix
            with tarfile.open(temp_path, 'r:gz') as tar:
                # Get all members and strip the first 2 path components
                members = []
                for member in tar.getmembers():
                    # Split path and remove first 2 components (graveyard/reaper/)
                    path_parts = member.name.split('/')
                    if len(path_parts) > 2:
                        member.name = '/'.join(path_parts[2:])
                        members.append(member)
                    elif len(path_parts) == 2 and path_parts[0] in ['graveyard'] and path_parts[1] in ['reaper']:
                        # Skip empty graveyard/reaper directories
                        continue
                    elif len(path_parts) == 1 and path_parts[0] in ['graveyard']:
                        # Skip graveyard directory
                        continue
                
                # Extract with modified paths
                if members:
                    tar.extractall(install_dir, members=members)
                else:
                    # Fallback: extract everything without path modification
                    tar.extractall(install_dir)
            
            print("✅ Extraction complete")
            
            # Make scripts executable
            print("🔧 Making scripts executable...")
            script_dirs = ['throne', 'sh_grim', 'scripts', '.rip', 'auto_backups']
            for script_dir in script_dirs:
                script_path = os.path.join(install_dir, script_dir)
                if os.path.exists(script_path):
                    for root, dirs, files in os.walk(script_path):
                        for file in files:
                            if file.endswith('.sh') or file == 'reaper' or file == 'grim_throne.sh':
                                file_path = os.path.join(root, file)
                                try:
                                    os.chmod(file_path, 0o755)
                                except:
                                    pass  # Skip if chmod fails
            
            # Make main executables executable
            main_executables = [
                'reaper.sh',
                'grim_throne.sh', 
                'install.sh'
            ]
            for executable in main_executables:
                exe_path = os.path.join(install_dir, executable)
                if os.path.exists(exe_path):
                    try:
                        os.chmod(exe_path, 0o755)
                    except:
                        pass
            
            print("✅ Scripts made executable")
            
            # Check if GRIM_REAPER environment variable indicates update mode
            if os.environ.get('GRIM_REAPER') == 'TRUE':
                print("🔄 GRIM_REAPER=TRUE detected - performing update mode")
                self._handle_reaper_update(install_dir)
            
            print(f"✅ Grim Reaper installation complete at: {install_dir}")
            
        finally:
            # Clean up temp file
            try:
                os.unlink(temp_path)
            except:
                pass
    
    def _handle_reaper_update(self, install_dir: str):
        """Handle GRIM_REAPER=TRUE update mode - extract and overwrite except sensitive data"""
        print("⚠️  Update mode: Preserving sensitive data (DB files, license, keys)")
        
        # Sensitive files to preserve
        sensitive_patterns = [
            "*.db",
            "*.key", 
            "*.pem",
            "*.crt",
            "license*",
            "*.license",
            ".rip/config.tsk",
            "auto_backups_encrypted/",
            "database/",
            "keys/",
            "ssl/",
        ]
        
        # Create backup of sensitive files
        import glob
        preserved_files = {}
        
        for pattern in sensitive_patterns:
            for file_path in glob.glob(os.path.join(install_dir, "**", pattern), recursive=True):
                if os.path.exists(file_path):
                    with open(file_path, 'rb') as f:
                        preserved_files[file_path] = f.read()
        
        print(f"🔒 Preserved {len(preserved_files)} sensitive files")
        
        # Restore preserved files after extraction
        for file_path, content in preserved_files.items():
            try:
                os.makedirs(os.path.dirname(file_path), exist_ok=True)
                with open(file_path, 'wb') as f:
                    f.write(content)
            except Exception as e:
                print(f"⚠️  Could not restore {file_path}: {e}")
        
        # Try to read version from manifest.tsk
        try:
            manifest_path = os.path.join(install_dir, "manifest.tsk")
            if os.path.exists(manifest_path):
                with open(manifest_path, 'r') as f:
                    for line in f:
                        if 'version' in line.lower():
                            version = line.split('=', 1)[-1].strip().strip('"\'')
                            os.environ['GRIM_VERSION'] = version
                            print(f"📋 Set GRIM_VERSION={version}")
                            break
        except Exception as e:
            print(f"⚠️  Could not read version from manifest.tsk: {e}")
    
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
    
    def install_core(self, install_dir: Optional[str] = None) -> str:
        """Manually install Grim Reaper core system"""
        if install_dir is None:
            install_dir = os.path.expanduser("~/reaper")
        
        self._install_grim_core(install_dir)
        return install_dir
    
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
    parser.add_argument("command", choices=["backup", "restore", "compress", "health", "scan", "version", "install"], 
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
        elif args.command == "install":
            install_dir = args.args[0] if args.args else None
            result = grim.install_core(install_dir)
            print(f"✅ Grim Reaper installed to: {result}")
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)