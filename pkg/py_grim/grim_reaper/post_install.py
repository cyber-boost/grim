#!/usr/bin/env python3
"""
Post-install script for Grim Reaper Python package
Sets up .scythe directory structure and makes throne script executable
"""

import os
import subprocess
import sys

def detect_grim_root():
    """Detect GRIM_ROOT dynamically with improved logic"""
    # Priority order for GRIM_ROOT detection
    if 'GRIM_ROOT' in os.environ:
        grim_root = os.environ['GRIM_ROOT']
        if os.path.exists(grim_root):
            return grim_root
    
    # Check for existing installation in common paths
    possible_paths = [
        "/root",
        os.path.expanduser("~"),
        os.path.join(os.path.expanduser('~'), '.graveyard', 'reaper'),
        os.path.join(os.path.expanduser('~'), '.graveyard'),
        '/root/.graveyard/reaper',
        '/root/.graveyard',
        '/opt/reaper',
        '/usr/local/reaper',
        os.path.expanduser('~/.reaper'),
        '/root/reaper'
    ]
    
    for path in possible_paths:
        if os.path.exists(path) and _is_grim_installation(path):
            return path
    
    # Default fallback - use home directory
    return os.path.expanduser('~')

def _is_grim_installation(path: str) -> bool:
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

def setup_environment_variables(grim_root):
    """Setup required environment variables"""
    # Set environment variables if not already set
    if not os.environ.get('GRIM_ROOT'):
        os.environ['GRIM_ROOT'] = grim_root
        
    if not os.environ.get('GRIM_LICENSE'):
        os.environ['GRIM_LICENSE'] = "FREE"
        
    if not os.environ.get('GRIM_REAPER'):
        os.environ['GRIM_REAPER'] = "FALSE"
    
    # Try to persist environment variables to shell profile
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
            f'export GRIM_ROOT="{grim_root}"',
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

def setup_scythe():
    """Setup .scythe directory structure"""
    try:
        print("🗡️  Setting up .scythe directory structure...")
        
        # Detect GRIM_ROOT dynamically
        grim_root = detect_grim_root()
        
        # Setup environment variables
        setup_environment_variables(grim_root)
        
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
  version: "1.0.6"
  install_date: {subprocess.run(['date', '-Iseconds'], capture_output=True, text=True).stdout.strip()}
  grim_root: "{grim_root}"
  
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
  
environment:
  grim_root: "{grim_root}"
  grim_license: "FREE"
  grim_reaper: "FALSE"
"""
            with open(config_file, 'w') as f:
                f.write(config_content)
            print("✅ Created scythe configuration")
        
        # Make throne script executable if found
        throne_scripts = [
            os.path.join(os.path.dirname(__file__), '..', 'grim_throne.sh'),
            os.path.join(grim_root, 'throne', 'grim_throne.sh'),
            os.path.join(grim_root, 'grim_throne.sh'),
            os.path.join(grim_root, 'reaper.sh'),
        ]
        
        for throne_script in throne_scripts:
            if os.path.exists(throne_script):
                try:
                    os.chmod(throne_script, 0o755)
                    print(f"✅ Made {os.path.basename(throne_script)} executable")
                    break
                except Exception as e:
                    print(f"⚠️  Could not make {throne_script} executable: {e}")
        
        # Try to run the universal setup script if available
        setup_script = os.path.join(grim_root, 'scripts', 'setup_scythe_dirs.sh')
        if os.path.exists(setup_script):
            try:
                subprocess.run(['bash', setup_script, 'setup', grim_root, 'auto'], check=True)
                print("✅ Initialized scythe database")
            except subprocess.CalledProcessError:
                print("⚠️  Could not initialize scythe database - basic structure created")
        
        print(f"✅ .scythe directory structure created at: {scythe_dir}")
        print(f"🗡️  GRIM_ROOT set to: {grim_root}")
        print(f"🔑 GRIM_LICENSE set to: {os.environ.get('GRIM_LICENSE', 'FREE')}")
        print(f"⚡ GRIM_REAPER set to: {os.environ.get('GRIM_REAPER', 'FALSE')}")
        
        return True
        
    except Exception as e:
        print(f"⚠️  Warning: Could not setup .scythe directory structure: {e}")
        return False

if __name__ == "__main__":
    success = setup_scythe()
    sys.exit(0 if success else 1) 