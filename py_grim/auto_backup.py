#!/usr/bin/env python3
"""
Grim Automatic Backup System - Python Implementation
Monitors file changes and creates intelligent compressed backups
Integrates with Go compression engine for optimal performance
"""

import os
import sys
import time
import json
import signal
import logging
import subprocess
import threading
from pathlib import Path
from typing import Dict, Set, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
import argparse
import fnmatch
import psutil

# Configuration
SCRIPT_DIR = Path(__file__).parent.absolute()
GRAVEYARD_DIR = Path(os.getenv('GRAVEYARD_DIR', '/root/.graveyard'))
MONITOR_DIR = Path(os.getenv('MONITOR_DIR', os.getcwd()))
GO_COMPRESSION_BIN = Path(os.getenv('GO_COMPRESSION_BIN', SCRIPT_DIR.parent / 'go_grim' / 'build' / 'grim-compression'))
BACKUP_INTERVAL = int(os.getenv('BACKUP_INTERVAL', 300))  # 5 minutes
MAX_BACKUPS = int(os.getenv('MAX_BACKUPS', 50))
MIN_FILE_SIZE = int(os.getenv('MIN_FILE_SIZE', 1024))  # 1KB minimum
LOG_FILE = Path(os.getenv('LOG_FILE', '/var/log/grim-auto-backup.log'))
PID_FILE = Path(os.getenv('PID_FILE', '/var/run/grim-auto-backup.pid'))
CONFIG_FILE = Path(os.getenv('CONFIG_FILE', SCRIPT_DIR / 'auto_backup.conf'))

@dataclass
class BackupConfig:
    """Configuration for the backup system"""
    graveyard_dir: Path = GRAVEYARD_DIR
    monitor_dir: Path = MONITOR_DIR
    backup_interval: int = BACKUP_INTERVAL
    max_backups: int = MAX_BACKUPS
    min_file_size: int = MIN_FILE_SIZE
    compression_algorithm: str = 'zstd'
    exclude_patterns: List[str] = None
    include_patterns: List[str] = None
    
    def __post_init__(self):
        if self.exclude_patterns is None:
            self.exclude_patterns = ['*.tmp', '*.log', '*.cache', '.git/*', 'node_modules/*', 'venv/*']
        if self.include_patterns is None:
            self.include_patterns = ['*.py', '*.sh', '*.go', '*.js', '*.php', '*.ts', '*.tsk', '*.pnt']

class AutoBackupSystem:
    """Main automatic backup system"""
    
    def __init__(self, config: BackupConfig):
        self.config = config
        self.file_modifications: Dict[str, int] = {}
        self.file_last_backup: Dict[str, float] = {}
        self.hot_files: Set[str] = set()
        self.running = False
        self.monitor_thread = None
        self.detector_thread = None
        
        # Setup logging
        self.setup_logging()
        
        # Ensure directories exist
        self.ensure_directories()
        
        # Check Go compression binary
        self.check_go_compression()
    
    def setup_logging(self):
        """Setup logging configuration"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s [%(levelname)s] %(message)s',
            handlers=[
                logging.FileHandler(self.config.graveyard_dir / 'auto_backup.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def ensure_directories(self):
        """Ensure necessary directories exist"""
        (self.config.graveyard_dir / 'auto_backups').mkdir(parents=True, exist_ok=True)
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        PID_FILE.parent.mkdir(parents=True, exist_ok=True)
    
    def check_go_compression(self):
        """Check if Go compression binary exists and build if needed"""
        if not GO_COMPRESSION_BIN.exists():
            self.logger.error(f"Go compression binary not found at: {GO_COMPRESSION_BIN}")
            self.build_go_compression()
    
    def build_go_compression(self):
        """Build Go compression engine"""
        go_dir = SCRIPT_DIR.parent / 'go_grim'
        if go_dir.exists():
            try:
                self.logger.info("Building Go compression engine...")
                result = subprocess.run(['make', 'build'], cwd=go_dir, capture_output=True, text=True)
                if result.returncode == 0:
                    self.logger.info("Go compression engine built successfully")
                else:
                    self.logger.error(f"Failed to build Go compression engine: {result.stderr}")
                    sys.exit(1)
            except FileNotFoundError:
                self.logger.error("Make not found. Please install build tools.")
                sys.exit(1)
        else:
            self.logger.error(f"Go grim directory not found: {go_dir}")
            sys.exit(1)
    
    def should_monitor_file(self, file_path: Path) -> bool:
        """Check if file should be monitored"""
        if not file_path.is_file():
            return False
        
        # Check file size
        if file_path.stat().st_size < self.config.min_file_size:
            return False
        
        file_str = str(file_path)
        
        # Check exclude patterns
        for pattern in self.config.exclude_patterns:
            if fnmatch.fnmatch(file_str, pattern) or fnmatch.fnmatch(file_path.name, pattern):
                return False
        
        # Check include patterns
        for pattern in self.config.include_patterns:
            if fnmatch.fnmatch(file_str, pattern) or fnmatch.fnmatch(file_path.name, pattern):
                return True
        
        # If no include patterns specified, monitor all non-excluded files
        return True
    
    def detect_hot_files(self):
        """Detect frequently modified files"""
        current_time = time.time()
        threshold = current_time - 3600  # 1 hour
        
        new_hot_files = set()
        
        for file_path, mod_count in self.file_modifications.items():
            last_backup = self.file_last_backup.get(file_path, 0)
            
            # Consider file "hot" if modified more than 3 times in the last hour
            if mod_count >= 3 and last_backup > threshold:
                new_hot_files.add(file_path)
        
        self.hot_files = new_hot_files
    
    def create_backup(self, source_path: Path) -> bool:
        """Create compressed backup of a file"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = source_path.name
            relative_path = source_path.parent.relative_to(self.config.monitor_dir)
            
            # Create backup directory structure
            backup_dir = self.config.graveyard_dir / 'auto_backups' / relative_path
            backup_dir.mkdir(parents=True, exist_ok=True)
            
            # Generate backup filename
            backup_name = f"{filename}.{timestamp}.{self.config.compression_algorithm}"
            backup_path = backup_dir / backup_name
            
            self.logger.info(f"Creating backup: {source_path} -> {backup_path}")
            
            # Use Go compression engine
            result = subprocess.run([
                str(GO_COMPRESSION_BIN),
                '-input', str(source_path),
                '-algorithm', self.config.compression_algorithm,
                '-output', str(backup_path)
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                self.logger.info(f"Backup created successfully: {backup_path}")
                
                # Update last backup time
                self.file_last_backup[str(source_path)] = time.time()
                
                # Cleanup old backups
                self.cleanup_old_backups(backup_dir)
                
                return True
            else:
                self.logger.error(f"Failed to create backup: {source_path} - {result.stderr}")
                return False
                
        except Exception as e:
            self.logger.error(f"Error creating backup for {source_path}: {e}")
            return False
    
    def cleanup_old_backups(self, backup_dir: Path):
        """Cleanup old backups to maintain limit"""
        try:
            backup_files = list(backup_dir.glob(f"*.{self.config.compression_algorithm}"))
            
            if len(backup_files) > self.config.max_backups:
                self.logger.info(f"Cleaning up old backups in: {backup_dir}")
                
                # Sort by modification time and remove oldest
                backup_files.sort(key=lambda x: x.stat().st_mtime)
                files_to_remove = backup_files[:-self.config.max_backups]
                
                for file_path in files_to_remove:
                    file_path.unlink()
                    self.logger.debug(f"Removed old backup: {file_path}")
                    
        except Exception as e:
            self.logger.error(f"Error cleaning up backups in {backup_dir}: {e}")
    
    def monitor_files(self):
        """Monitor file changes using inotify"""
        try:
            # Check if inotify-tools is available
            if subprocess.run(['which', 'inotifywait'], capture_output=True).returncode != 0:
                self.logger.error("inotifywait not found. Installing inotify-tools...")
                self.install_inotify_tools()
            
            self.logger.info("Starting file monitoring...")
            
            # Start inotifywait process
            process = subprocess.Popen([
                'inotifywait', '-m', '-r', '-e', 'modify,create,move',
                str(self.config.monitor_dir), '--format', '%w%f %e'
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            
            while self.running:
                line = process.stdout.readline()
                if not line:
                    break
                
                try:
                    file_path_str, event = line.strip().split(' ', 1)
                    file_path = Path(file_path_str)
                    
                    if self.should_monitor_file(file_path):
                        file_str = str(file_path)
                        current_time = time.time()
                        
                        # Update modification tracking
                        self.file_modifications[file_str] = self.file_modifications.get(file_str, 0) + 1
                        
                        self.logger.debug(f"File modified: {file_path} ({event}) - count: {self.file_modifications[file_str]}")
                        
                        # Check if backup is needed
                        last_backup = self.file_last_backup.get(file_str, 0)
                        time_since_backup = current_time - last_backup
                        
                        if time_since_backup > self.config.backup_interval or file_str in self.hot_files:
                            self.create_backup(file_path)
                            
                except Exception as e:
                    self.logger.error(f"Error processing file event: {e}")
            
            process.terminate()
            
        except Exception as e:
            self.logger.error(f"Error in file monitoring: {e}")
    
    def install_inotify_tools(self):
        """Install inotify-tools"""
        try:
            if subprocess.run(['which', 'apt-get'], capture_output=True).returncode == 0:
                subprocess.run(['sudo', 'apt-get', 'update'], check=True)
                subprocess.run(['sudo', 'apt-get', 'install', '-y', 'inotify-tools'], check=True)
            elif subprocess.run(['which', 'yum'], capture_output=True).returncode == 0:
                subprocess.run(['sudo', 'yum', 'install', '-y', 'inotify-tools'], check=True)
            else:
                self.logger.error("Cannot install inotify-tools. Please install manually.")
                sys.exit(1)
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to install inotify-tools: {e}")
            sys.exit(1)
    
    def hot_file_detector(self):
        """Periodic hot file detection"""
        while self.running:
            time.sleep(60)  # Check every minute
            self.detect_hot_files()
            
            # Log hot files
            if self.hot_files:
                self.logger.info(f"Hot files detected: {', '.join(self.hot_files)}")
    
    def start(self):
        """Start the auto backup system"""
        if self.running:
            self.logger.warning("Auto backup system is already running")
            return
        
        self.running = True
        
        # Start monitoring thread
        self.monitor_thread = threading.Thread(target=self.monitor_files, daemon=True)
        self.monitor_thread.start()
        
        # Start hot file detector thread
        self.detector_thread = threading.Thread(target=self.hot_file_detector, daemon=True)
        self.detector_thread.start()
        
        # Save PID
        with open(PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
        
        self.logger.info("Auto backup system started")
        
        # Wait for threads
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()
    
    def stop(self):
        """Stop the auto backup system"""
        self.logger.info("Stopping auto backup system...")
        self.running = False
        
        # Remove PID file
        if PID_FILE.exists():
            PID_FILE.unlink()
        
        self.logger.info("Auto backup system stopped")
    
    def status(self):
        """Show system status"""
        print("=== Grim Auto Backup Status ===")
        
        # Check if running
        if PID_FILE.exists():
            try:
                with open(PID_FILE, 'r') as f:
                    pid = int(f.read().strip())
                if psutil.pid_exists(pid):
                    print("✓ Daemon is running")
                else:
                    print("✗ Daemon is not running (stale PID file)")
            except (ValueError, FileNotFoundError):
                print("✗ Daemon is not running")
        else:
            print("✗ Daemon is not running")
        
        print("\nConfiguration:")
        print(f"  Monitor Directory: {self.config.monitor_dir}")
        print(f"  Graveyard Directory: {self.config.graveyard_dir}")
        print(f"  Backup Interval: {self.config.backup_interval} seconds")
        print(f"  Max Backups: {self.config.max_backups}")
        print(f"  Compression: {self.config.compression_algorithm}")
        
        print("\nHot Files:")
        if self.hot_files:
            for file_path in self.hot_files:
                mod_count = self.file_modifications.get(file_path, 0)
                print(f"  - {file_path} ({mod_count} modifications)")
        else:
            print("  None detected")
        
        print("\nRecent Backups:")
        backup_dir = self.config.graveyard_dir / 'auto_backups'
        if backup_dir.exists():
            backup_files = []
            for backup_file in backup_dir.rglob(f"*.{self.config.compression_algorithm}"):
                backup_files.append((backup_file.stat().st_mtime, backup_file))
            
            backup_files.sort(reverse=True)
            for mtime, backup_file in backup_files[:5]:
                date_str = datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M:%S')
                print(f"  - {date_str}: {backup_file}")

def load_config() -> BackupConfig:
    """Load configuration from file"""
    if CONFIG_FILE.exists():
        config_data = {}
        with open(CONFIG_FILE, 'r') as f:
            exec(f.read(), {}, config_data)
        
        return BackupConfig(
            graveyard_dir=Path(config_data.get('GRAVEYARD_DIR', GRAVEYARD_DIR)),
            monitor_dir=Path(config_data.get('MONITOR_DIR', MONITOR_DIR)),
            backup_interval=config_data.get('BACKUP_INTERVAL', BACKUP_INTERVAL),
            max_backups=config_data.get('MAX_BACKUPS', MAX_BACKUPS),
            min_file_size=config_data.get('MIN_FILE_SIZE', MIN_FILE_SIZE),
            compression_algorithm=config_data.get('COMPRESSION_ALGORITHM', 'zstd'),
            exclude_patterns=config_data.get('EXCLUDE_PATTERNS', None),
            include_patterns=config_data.get('INCLUDE_PATTERNS', None)
        )
    else:
        # Create default config
        create_default_config()
        return BackupConfig()

def create_default_config():
    """Create default configuration file"""
    config_content = '''# Grim Auto Backup Configuration
GRAVEYARD_DIR = "/root/.graveyard"
MONITOR_DIR = "."
BACKUP_INTERVAL = 300
MAX_BACKUPS = 50
MIN_FILE_SIZE = 1024
EXCLUDE_PATTERNS = ["*.tmp", "*.log", "*.cache", ".git/*", "node_modules/*", "venv/*"]
INCLUDE_PATTERNS = ["*.py", "*.sh", "*.go", "*.js", "*.php", "*.ts", "*.tsk", "*.pnt"]
COMPRESSION_ALGORITHM = "zstd"
'''
    
    with open(CONFIG_FILE, 'w') as f:
        f.write(config_content)

def health_check() -> bool:
    """Check if daemon is running"""
    if PID_FILE.exists():
        try:
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            if psutil.pid_exists(pid):
                print("Auto backup daemon is running (PID: {pid})")
                return True
        except (ValueError, FileNotFoundError):
            pass
    
    print("Auto backup daemon is not running")
    return False

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Grim Automatic Backup System')
    parser.add_argument('command', choices=['start', 'stop', 'restart', 'status', 'health'],
                       help='Command to execute')
    
    args = parser.parse_args()
    
    if args.command == 'health':
        health_check()
        return
    
    # Load configuration
    config = load_config()
    
    # Create backup system
    backup_system = AutoBackupSystem(config)
    
    if args.command == 'start':
        # Setup signal handlers
        def signal_handler(signum, frame):
            backup_system.stop()
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        backup_system.start()
    
    elif args.command == 'stop':
        if PID_FILE.exists():
            try:
                with open(PID_FILE, 'r') as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGTERM)
                print("Sent stop signal to daemon")
            except (ValueError, FileNotFoundError, ProcessLookupError):
                print("Daemon not running")
        else:
            print("No PID file found")
    
    elif args.command == 'restart':
        if PID_FILE.exists():
            try:
                with open(PID_FILE, 'r') as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGTERM)
                time.sleep(2)
            except (ValueError, FileNotFoundError, ProcessLookupError):
                pass
        
        backup_system.start()
    
    elif args.command == 'status':
        backup_system.status()

if __name__ == '__main__':
    main() 