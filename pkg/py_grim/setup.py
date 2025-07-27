#!/usr/bin/env python3
"""
Grim Reaper Python Package
The Ultimate Backup, Monitoring, and Security System
"""

from setuptools import setup, find_packages, Command
import os
import subprocess
import sys

# Read the README file
def read_readme():
    with open("README.md", "r", encoding="utf-8") as fh:
        return fh.read()

# Read requirements
def read_requirements():
    """Read requirements from requirements.txt"""
    try:
        with open("requirements.txt") as f:
            return [line.strip() for line in f if line.strip() and not line.startswith("#")]
    except FileNotFoundError:
        # Return basic requirements if file doesn't exist
        return [
            "requests>=2.25.0",
            "aiohttp>=3.8.0", 
            "click>=8.0.0",
            "pyyaml>=6.0",
            "psutil>=5.8.0",
            "pathlib>=1.0.0",
            "typing-extensions>=4.0.0",
        ]

class InstallDependencies(Command):
    """Custom command to install system dependencies"""
    description = "Install system dependencies for Grim Reaper"
    user_options = []
    
    def initialize_options(self):
        pass
    
    def finalize_options(self):
        pass
    
    def run(self):
        print("Installing Grim Reaper system dependencies...")
        
        # Get the installation directory
        install_dir = os.path.join(sys.prefix, 'share', 'grim-reaper')
        
        # Run the dependency installation script
        install_script = os.path.join(install_dir, 'install_dependencies.sh')
        if os.path.exists(install_script):
            try:
                subprocess.run(['bash', install_script], check=True)
                print("✅ System dependencies installed successfully!")
            except subprocess.CalledProcessError as e:
                print(f"⚠️  Warning: Some dependencies may not have installed correctly: {e}")
        else:
            print("⚠️  Warning: install_dependencies.sh not found")

class SetupScythe(Command):
    """Custom command to setup .scythe directory structure"""
    description = "Setup .scythe directory structure for Grim Reaper"
    user_options = []
    
    def initialize_options(self):
        pass
    
    def finalize_options(self):
        pass
    
    def run(self):
        print("🗡️  Setting up .scythe directory structure...")
        
        # Detect GRIM_ROOT dynamically
        grim_root = self.detect_grim_root()
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
        
        # Try to run the universal setup script if available
        setup_script = os.path.join(grim_root, 'scripts', 'setup_scythe_dirs.sh')
        if os.path.exists(setup_script):
            try:
                subprocess.run(['bash', setup_script, 'setup', grim_root, 'auto'], check=True)
                print("✅ Initialized scythe database")
            except subprocess.CalledProcessError:
                print("⚠️  Could not initialize scythe database - basic structure created")
        
        print(f"✅ .scythe directory structure created at: {scythe_dir}")
        
        # Make throne script executable
        throne_script = os.path.join(os.path.dirname(__file__), 'grim_throne.sh')
        if os.path.exists(throne_script):
            try:
                os.chmod(throne_script, 0o755)
                print("✅ Made grim_throne.sh executable")
            except Exception as e:
                print(f"⚠️  Could not make throne script executable: {e}")
    
    def detect_grim_root(self):
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

setup(
    name="grim-reaper",
    version="1.0.36",
    author="Bernie Gengel and his beagle Buddy", 
    author_email="rip@grim.so",
    description="Grim: Unified Data Protection Ecosystem. When data death comes knocking, Grim ensures resurrection is just a command away. License management, auto backups, highly compressed backups, multi-algorithm compression, content-based deduplication, smart storage tiering save up to 60% space, military-grade encryption, license protection, security surveillance, and automated threat response.",
    long_description=read_readme(),
    long_description_content_type="text/markdown",
    url="https://grim.so",
    project_urls={
        "Bug Reports": "https://github.com/cyber-boost/grim/issues",
        "Source": "https://github.com/cyber-boost/grim/tree/main",
        "Documentation": "https://grim.so",
    },
    packages=find_packages(include=["grim_reaper*"]),
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "Intended Audience :: System Administrators",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: System :: Systems Administration",
        "Topic :: System :: Monitoring",
        "Topic :: System :: Archiving :: Backup",
        "Topic :: Security",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    python_requires=">=3.8",
    # Dependencies and license are now handled in pyproject.toml
    entry_points={
        "console_scripts": [
            "grim=grim_reaper:main",
        ],
    },
    include_package_data=True,
    package_data={
        "": ["*.txt", "*.md", "*.sh"],
        "grim_reaper": ["*.py"],
    },
    cmdclass={
        'install_deps': InstallDependencies,
        'setup_scythe': SetupScythe,
    },
    # Post-install hook
    data_files=[
        # ('grim_reaper', ['grim_reaper/post_install.py']),  # File doesn't exist
    ],
    zip_safe=False,
    keywords=[
        "grim",
        "backup",
        "monitoring", 
        "security",
        "cli",
        "orchestration",
        "system-management",
        "compression",
        "encryption",
        "ai",
        "machine-learning",
        "grim-reaper",
    ],
    platforms=["any"],
)

# Post-install hook for scythe setup
def run_post_install():
    """Run post-installation tasks"""
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
        throne_script = os.path.join(os.path.dirname(__file__), 'grim_throne.sh')
        if os.path.exists(throne_script):
            try:
                os.chmod(throne_script, 0o755)
                print("✅ Made grim_throne.sh executable")
            except Exception as e:
                print(f"⚠️  Could not make throne script executable: {e}")
        
        print(f"✅ .scythe directory structure created at: {scythe_dir}")
        
    except Exception as e:
        print(f"⚠️  Warning: Could not setup .scythe directory structure: {e}")
        print("💡 You can manually run: python -c 'from grim_reaper import GrimReaper; GrimReaper()._setup_scythe()'")

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

# Run post-install hook
if __name__ == "__main__":
    run_post_install() 