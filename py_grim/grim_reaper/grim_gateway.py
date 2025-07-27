#!/usr/bin/env python3
"""
Grim Reaper Gateway
Main entry point for the Python package
"""

import sys
import argparse
import subprocess
import os
import shutil
from pathlib import Path

# Global flag to track if dependencies have been checked
_dependencies_checked = False

def check_and_install_dependencies():
    """Check and automatically install dependencies on first import"""
    global _dependencies_checked
    
    if _dependencies_checked:
        return
    
    _dependencies_checked = True
    
    # Only run on first import, not on every command
    if len(sys.argv) > 1 and sys.argv[1] in ['--help', '-h', 'help', '--version']:
        return
    
    print("🗡️  Grim Reaper - Checking dependencies...")
    
    # Check if we're in a proper installation
    grim_root = "/opt/reaper"
    if not os.path.exists(grim_root):
        print("⚠️  GRIM_ROOT not found at /opt/reaper - skipping dependency check")
        return
    
    # Check for install_dependencies.sh
    install_script = os.path.join(grim_root, "install_dependencies.sh")
    if os.path.exists(install_script):
        try:
            print("📦 Running automatic dependency installation...")
            # Run in background to avoid blocking
            result = subprocess.run(
                ['bash', install_script], 
                capture_output=True, 
                text=True,
                timeout=60,  # Reduced timeout to 1 minute
                cwd=grim_root
            )
            
            if result.returncode == 0:
                print("✅ Dependencies installed successfully!")
            else:
                print("⚠️  Some dependencies may need manual installation")
                if result.stderr:
                    print("Error output:", result.stderr)
                    
        except subprocess.TimeoutExpired:
            print("⚠️  Dependency installation timed out - continuing anyway")
        except FileNotFoundError:
            print("⚠️  bash not found - cannot run dependency script")
        except Exception as e:
            print(f"⚠️  Error running dependency script: {e}")
    else:
        print("ℹ️  install_dependencies.sh not found - manual installation may be required")

class GrimGateway:
    """Main gateway for Grim Reaper Python package"""
    
    def __init__(self):
        self.version = "1.0.6"
        self.description = "The Ultimate Backup, Monitoring, and Security System"
        # Set the correct GRIM_ROOT for PyPI installations
        self.grim_root = "/opt/reaper"
        
    def show_banner(self):
        """Display the Grim Reaper banner"""
        banner = f"""
╔══════════════════════════════════════════════════════════════╗
║                    🗡️ GRIM REAPER 🗡️                        ║
║                                                              ║
║  {self.description}                    ║
║  Version: {self.version}                                    ║
║  Python Package - pip install grim-reaper                   ║
║  GRIM_ROOT: {self.grim_root}                                ║
║                                                              ║
║  🚀 Backup • 🔍 Monitor • 🛡️ Security • 🤖 AI              ║
╚══════════════════════════════════════════════════════════════╝
        """
        print(banner)
    
    def check_dependencies(self):
        """Check for required system dependencies"""
        missing_deps = []
        
        # Check for common system tools
        system_tools = [
            'rsync', 'tar', 'gzip', 'bzip2', 'xz', 'openssl',
            'curl', 'wget', 'ssh', 'scp', 'find', 'du', 'df'
        ]
        
        for tool in system_tools:
            if not shutil.which(tool):
                missing_deps.append(f"System tool: {tool}")
        
        # Check for Go runtime
        if not shutil.which('go'):
            missing_deps.append("Go runtime (go)")
        
        # Check for Go binaries
        go_binaries = ['grim-compression']
        for binary in go_binaries:
            go_bin_path = Path(self.grim_root) / "go_grim" / "build" / binary
            if not go_bin_path.exists():
                missing_deps.append(f"Go binary: {binary}")
        
        if missing_deps:
            print("⚠️  Missing Dependencies Detected:")
            for dep in missing_deps:
                print(f"  - {dep}")
            print("\n📋 Installation Instructions:")
            print("  1. Install system tools: sudo apt install rsync tar gzip bzip2 xz-utils openssl curl wget")
            print("  2. Install Go: https://golang.org/doc/install")
            print("  3. Build Go binaries: cd /opt/reaper/go_grim && make build")
            print("  4. Ensure /opt/reaper directory exists and is accessible")
            return False
        
        return True
    
    def show_help(self):
        """Show help information"""
        help_text = """
Available Commands:
  grim backup     - Backup system and files
  grim monitor    - Monitor system health and performance
  grim scan       - Security scanning and analysis
  grim health     - System health check
  grim scythe     - Orchestration and automation
  
Examples:
  grim backup --source /home --dest /backups
  grim monitor --interval 30
  grim scan --path /var/www
  grim health --verbose
  
For more information: https://grim.so
        """
        print(help_text)
    
    def run_command(self, command, args=None):
        """Run a Grim command"""
        try:
            # Check dependencies first
            if not self.check_dependencies():
                return 1
            
            # Set environment variable for GRIM_ROOT
            env = os.environ.copy()
            env['GRIM_ROOT'] = self.grim_root
            
            # Check multiple locations for grim_throne.sh
            possible_paths = [
                Path(self.grim_root) / "grim_throne.sh",  # Primary location
                Path(__file__).parent.parent / "grim_throne.sh",  # Development
                Path("/usr/local/share/grim-reaper/grim_throne.sh"),  # System install
                Path("/usr/share/grim-reaper/grim_throne.sh"),  # System install
                Path(sys.prefix) / "share/grim-reaper/grim_throne.sh",  # Virtual env
            ]
            
            grim_script = None
            for path in possible_paths:
                if path.exists():
                    grim_script = path
                    break
            
            if grim_script:
                cmd = [str(grim_script), command] + (args or [])
                result = subprocess.run(cmd, capture_output=True, text=True, env=env)
                print(result.stdout)
                if result.stderr:
                    print(result.stderr, file=sys.stderr)
                return result.returncode
            else:
                print("❌ Error: grim_throne.sh not found in any expected location")
                print(f"GRIM_ROOT: {self.grim_root}")
                print("Expected locations:")
                for path in possible_paths:
                    print(f"  - {path}")
                return 1
        except Exception as e:
            print(f"❌ Error running command: {e}")
            return 1
    
    def main(self, args=None):
        """Main entry point"""
        if args is None:
            args = sys.argv[1:]
        
        parser = argparse.ArgumentParser(
            description=self.description,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog="""
Examples:
  grim backup --source /home --dest /backups
  grim monitor --interval 30
  grim scan --path /var/www
  grim health --verbose
            """
        )
        
        parser.add_argument(
            "command",
            nargs="?",
            choices=["backup", "monitor", "scan", "health", "scythe", "help", "check-deps"],
            help="Grim command to execute"
        )
        
        parser.add_argument(
            "--version",
            action="version",
            version=f"grim-reaper {self.version}"
        )
        
        parser.add_argument(
            "args",
            nargs=argparse.REMAINDER,
            help="Arguments to pass to the command"
        )
        
        parsed_args = parser.parse_args(args)
        
        if not parsed_args.command:
            self.show_banner()
            self.show_help()
            return 0
        
        if parsed_args.command == "help":
            self.show_banner()
            self.show_help()
            return 0
        
        if parsed_args.command == "check-deps":
            self.show_banner()
            if self.check_dependencies():
                print("✅ All dependencies are available")
                return 0
            else:
                return 1
        
        # Run the command
        return self.run_command(parsed_args.command, parsed_args.args)

def main():
    """Main function for console script entry point"""
    # Run automatic dependency check on first import
    check_and_install_dependencies()
    
    gateway = GrimGateway()
    sys.exit(gateway.main())

if __name__ == "__main__":
    main() 