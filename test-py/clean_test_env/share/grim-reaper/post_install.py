#!/usr/bin/env python3
"""
Post-install script for Grim Reaper
Automatically installs system dependencies after pip installation
"""

import os
import sys
import subprocess
import platform

def install_dependencies():
    """Install system dependencies for Grim Reaper"""
    print("🗡️  Grim Reaper - Installing system dependencies...")
    
    # Get the installation directory
    if hasattr(sys, 'real_prefix'):  # virtualenv
        install_dir = os.path.join(sys.real_prefix, 'share', 'grim-reaper')
    else:  # system or venv
        install_dir = os.path.join(sys.prefix, 'share', 'grim-reaper')
    
    # Run the dependency installation script
    install_script = os.path.join(install_dir, 'install_dependencies.sh')
    
    if os.path.exists(install_script):
        try:
            print("📦 Running dependency installation script...")
            result = subprocess.run(
                ['bash', install_script], 
                capture_output=True, 
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            if result.returncode == 0:
                print("✅ System dependencies installed successfully!")
                if result.stdout:
                    print(result.stdout)
            else:
                print("⚠️  Some dependencies may not have installed correctly:")
                if result.stderr:
                    print(result.stderr)
                    
        except subprocess.TimeoutExpired:
            print("⚠️  Dependency installation timed out (5 minutes)")
        except FileNotFoundError:
            print("⚠️  bash not found - cannot run dependency script")
        except Exception as e:
            print(f"⚠️  Error running dependency script: {e}")
    else:
        print("⚠️  install_dependencies.sh not found at:", install_script)
    
    print("🎉 Grim Reaper installation complete!")
    print("💡 Run 'grim --help' to see available commands")

if __name__ == "__main__":
    install_dependencies() 