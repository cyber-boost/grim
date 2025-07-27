#!/usr/bin/env python3
"""
Post-install script for Grim Reaper Python package
Sets up .scythe directory structure and makes throne script executable
"""

import os
import subprocess
import sys

def detect_grim_root():
    """Detect GRIM_ROOT dynamically"""
    # Priority order for GRIM_ROOT detection
    if 'GRIM_ROOT' in os.environ:
        return os.environ['GRIM_ROOT']
    
    # Check for existing installation
    possible_paths = [
        os.path.join(os.path.expanduser('~'), '.graveyard', 'reaper'),
        os.path.join(os.path.expanduser('~'), '.graveyard'),
        '/root/.graveyard/reaper',
        '/root/.graveyard'
    ]
    
    for path in possible_paths:
        if os.path.exists(path):
            return path
    
    # Default fallback
    return os.path.join(os.path.expanduser('~'), '.graveyard')

def setup_scythe():
    """Setup .scythe directory structure"""
    try:
        print("🗡️  Setting up .scythe directory structure...")
        
        # Detect GRIM_ROOT dynamically
        grim_root = detect_grim_root()
        scythe_dir = os.path.join(grim_root, '.graveyard', '.rip', '.scythe')
        
        # Create directory structure
        directories = ['config', 'db', 'logs', 'run', 'integrations']
        for dir_name in directories:
            dir_path = os.path.join(scythe_dir, dir_name)
            os.makedirs(dir_path, exist_ok=True)
        
        # Create subdirectories
        subdirs = [
            os.path.join(scythe_dir, 'logs', 'orchestration'),
            os.path.join(scythe_dir, 'logs', 'components'),
            os.path.join(scythe_dir, 'logs', 'integrations'),
            os.path.join(scythe_dir, 'logs', 'security'),
            os.path.join(scythe_dir, 'integrations', 'discovered'),
            os.path.join(scythe_dir, 'integrations', 'configs'),
            os.path.join(scythe_dir, 'integrations', 'scripts'),
        ]
        for subdir in subdirs:
            os.makedirs(subdir, exist_ok=True)
        
        # Create configuration file
        config_file = os.path.join(scythe_dir, 'config', 'scythe.yaml')
        if not os.path.exists(config_file):
            config_content = f"""# Scythe Configuration
# Central orchestrator settings for Grim Reaper System

scythe:
  version: "1.0.5"
  install_date: {subprocess.run(['date', '-Iseconds'], capture_output=True, text=True).stdout.strip()}
  
database:
  path: "../db/scythe.db"
  auto_backup: true
  backup_interval: "24h"
  
logging:
  level: "info"
  path: "../logs"
  max_size: "100MB"
  max_files: 10
  
orchestration:
  enabled: true
  heartbeat_interval: "30s"
  max_concurrent_jobs: 5
  
integrations:
  enabled: true
  scan_interval: "5m"
  auto_discover: true
  
security:
  encryption: true
  key_rotation: "30d"
  audit_logs: true
"""
            with open(config_file, 'w') as f:
                f.write(config_content)
            print("✅ Created scythe configuration")
        
        # Make throne script executable
        throne_script = os.path.join(os.path.dirname(__file__), '..', 'grim_throne.sh')
        if os.path.exists(throne_script):
            try:
                os.chmod(throne_script, 0o755)
                print("✅ Made grim_throne.sh executable")
            except Exception as e:
                print(f"⚠️  Could not make throne script executable: {e}")
        
        print(f"✅ .scythe directory structure created at: {scythe_dir}")
        return True
        
    except Exception as e:
        print(f"⚠️  Warning: Could not setup .scythe directory structure: {e}")
        return False

if __name__ == "__main__":
    success = setup_scythe()
    sys.exit(0 if success else 1) 