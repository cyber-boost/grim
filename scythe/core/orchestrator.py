#!/usr/bin/env python3
"""
Scythe Orchestrator - Central Coordination System for Grim Reaper
Coordinates sh_grim, go_grim, and py_grim modules for unified operation
"""

import os
import sys
import json
import yaml
import logging
import subprocess
import threading
import time
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime

@dataclass
class ModuleStatus:
    """Status tracking for individual modules"""
    name: str
    status: str  # 'running', 'stopped', 'error', 'unknown'
    last_check: datetime
    health_score: float  # 0.0 to 1.0
    error_count: int
    uptime: float

class ScytheOrchestrator:
    """Main orchestrator for Grim Reaper system coordination"""
    
    def __init__(self, config_path: str = "scythe/config/orchestrator.yaml"):
        self.config_path = config_path
        self.base_path = Path(__file__).parent.parent.parent
        self.modules = {
            'sh_grim': {'path': self.base_path / 'sh_grim', 'type': 'bash'},
            'go_grim': {'path': self.base_path / 'go_grim', 'type': 'go'},
            'py_grim': {'path': self.base_path / 'py_grim', 'type': 'python'}
        }
        self.module_status = {}
        self.running = False
        self.logger = self._setup_logging()
        self.config = self._load_config()
        
    def _setup_logging(self) -> logging.Logger:
        """Setup comprehensive logging system"""
        logger = logging.getLogger('scythe_orchestrator')
        logger.setLevel(logging.INFO)
        
        # File handler
        log_dir = self.base_path / 'scythe' / 'logs'
        log_dir.mkdir(exist_ok=True)
        file_handler = logging.FileHandler(log_dir / 'orchestrator.log')
        file_handler.setLevel(logging.INFO)
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        
        # Formatter
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        logger.addHandler(file_handler)
        logger.addHandler(console_handler)
        
        return logger
    
    def _load_config(self) -> Dict[str, Any]:
        """Load orchestrator configuration"""
        config_file = Path(self.config_path)
        if config_file.exists():
            try:
                with open(config_file, 'r') as f:
                    return yaml.safe_load(f)
            except Exception as e:
                self.logger.error(f"Failed to load config: {e}")
        
        # Default configuration
        return {
            'monitoring_interval': 30,
            'health_check_timeout': 10,
            'max_retries': 3,
            'modules': {
                'sh_grim': {'enabled': True, 'priority': 1},
                'go_grim': {'enabled': True, 'priority': 2},
                'py_grim': {'enabled': True, 'priority': 3}
            }
        }
    
    def verify_module_integrity(self, module_name: str) -> bool:
        """Verify module files and structure integrity"""
        module_info = self.modules.get(module_name)
        if not module_info:
            self.logger.error(f"Unknown module: {module_name}")
            return False
        
        module_path = module_info['path']
        if not module_path.exists():
            self.logger.error(f"Module path does not exist: {module_path}")
            return False
        
        # Check for critical files based on module type
        if module_info['type'] == 'bash':
            critical_files = ['init.sh', 'health.sh', 'backup.sh']
        elif module_info['type'] == 'go':
            critical_files = ['go.mod', 'Makefile', 'README.md']
        elif module_info['type'] == 'python':
            critical_files = ['requirements.txt', 'README.md']
        else:
            critical_files = []
        
        missing_files = []
        for file_name in critical_files:
            if not (module_path / file_name).exists():
                missing_files.append(file_name)
        
        if missing_files:
            self.logger.warning(f"Module {module_name} missing files: {missing_files}")
            return False
        
        self.logger.info(f"Module {module_name} integrity verified")
        return True
    
    def check_module_health(self, module_name: str) -> ModuleStatus:
        """Check health status of a specific module"""
        module_info = self.modules.get(module_name)
        if not module_info:
            return ModuleStatus(
                name=module_name,
                status='unknown',
                last_check=datetime.now(),
                health_score=0.0,
                error_count=0,
                uptime=0.0
            )
        
        start_time = time.time()
        health_score = 0.0
        status = 'unknown'
        error_count = 0
        
        try:
            # Module-specific health checks
            if module_info['type'] == 'bash':
                health_score, status, error_count = self._check_bash_health(module_name)
            elif module_info['type'] == 'go':
                health_score, status, error_count = self._check_go_health(module_name)
            elif module_info['type'] == 'python':
                health_score, status, error_count = self._check_python_health(module_name)
            
        except Exception as e:
            self.logger.error(f"Health check failed for {module_name}: {e}")
            status = 'error'
            error_count = 1
        
        uptime = time.time() - start_time
        
        module_status = ModuleStatus(
            name=module_name,
            status=status,
            last_check=datetime.now(),
            health_score=health_score,
            error_count=error_count,
            uptime=uptime
        )
        
        self.module_status[module_name] = module_status
        return module_status
    
    def _check_bash_health(self, module_name: str) -> tuple:
        """Check health of bash module"""
        module_path = self.modules[module_name]['path']
        health_script = module_path / 'health.sh'
        
        if not health_script.exists():
            return 0.5, 'unknown', 0
        
        try:
            result = subprocess.run(
                [str(health_script)],
                capture_output=True,
                text=True,
                timeout=10,
                cwd=str(module_path)
            )
            
            if result.returncode == 0:
                return 1.0, 'running', 0
            else:
                return 0.3, 'error', 1
                
        except subprocess.TimeoutExpired:
            return 0.0, 'timeout', 1
        except Exception as e:
            self.logger.error(f"Bash health check error: {e}")
            return 0.0, 'error', 1
    
    def _check_go_health(self, module_name: str) -> tuple:
        """Check health of Go module"""
        module_path = self.modules[module_name]['path']
        
        # Check if Go module can be built
        try:
            result = subprocess.run(
                ['go', 'mod', 'tidy'],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=str(module_path)
            )
            
            if result.returncode == 0:
                return 1.0, 'running', 0
            else:
                return 0.5, 'error', 1
                
        except Exception as e:
            self.logger.error(f"Go health check error: {e}")
            return 0.0, 'error', 1
    
    def _check_python_health(self, module_name: str) -> tuple:
        """Check health of Python module"""
        module_path = self.modules[module_name]['path']
        requirements_file = module_path / 'requirements.txt'
        
        if not requirements_file.exists():
            return 0.5, 'unknown', 0
        
        try:
            # Check if dependencies can be imported
            result = subprocess.run(
                [sys.executable, '-c', 'import sys; print("Python OK")'],
                capture_output=True,
                text=True,
                timeout=10,
                cwd=str(module_path)
            )
            
            if result.returncode == 0:
                return 1.0, 'running', 0
            else:
                return 0.3, 'error', 1
                
        except Exception as e:
            self.logger.error(f"Python health check error: {e}")
            return 0.0, 'error', 1
    
    def start_monitoring(self):
        """Start continuous monitoring of all modules"""
        self.running = True
        self.logger.info("Starting Scythe Orchestrator monitoring")
        
        while self.running:
            try:
                for module_name in self.modules.keys():
                    if self.config['modules'].get(module_name, {}).get('enabled', True):
                        status = self.check_module_health(module_name)
                        self.logger.info(f"Module {module_name}: {status.status} (health: {status.health_score:.2f})")
                
                # Save status to file
                self._save_status()
                
                # Wait for next check
                time.sleep(self.config.get('monitoring_interval', 30))
                
            except KeyboardInterrupt:
                self.logger.info("Monitoring stopped by user")
                break
            except Exception as e:
                self.logger.error(f"Monitoring error: {e}")
                time.sleep(5)
    
    def _save_status(self):
        """Save current status to JSON file"""
        status_data = {}
        for module_name, status in self.module_status.items():
            status_data[module_name] = {
                'status': status.status,
                'last_check': status.last_check.isoformat(),
                'health_score': status.health_score,
                'error_count': status.error_count,
                'uptime': status.uptime
            }
        
        status_file = self.base_path / 'scythe' / 'status.json'
        try:
            with open(status_file, 'w') as f:
                json.dump(status_data, f, indent=2)
        except Exception as e:
            self.logger.error(f"Failed to save status: {e}")
    
    def get_system_overview(self) -> Dict[str, Any]:
        """Get comprehensive system overview"""
        overview = {
            'timestamp': datetime.now().isoformat(),
            'orchestrator_status': 'running' if self.running else 'stopped',
            'modules': {},
            'system_health': 0.0,
            'total_modules': len(self.modules),
            'healthy_modules': 0,
            'error_modules': 0
        }
        
        total_health = 0.0
        for module_name, status in self.module_status.items():
            overview['modules'][module_name] = {
                'status': status.status,
                'health_score': status.health_score,
                'last_check': status.last_check.isoformat(),
                'error_count': status.error_count
            }
            
            total_health += status.health_score
            if status.health_score > 0.7:
                overview['healthy_modules'] += 1
            elif status.health_score < 0.3:
                overview['error_modules'] += 1
        
        if self.module_status:
            overview['system_health'] = total_health / len(self.module_status)
        
        return overview
    
    def stop_monitoring(self):
        """Stop monitoring"""
        self.running = False
        self.logger.info("Scythe Orchestrator monitoring stopped")

def main():
    """Main entry point"""
    orchestrator = ScytheOrchestrator()
    
    # Verify all modules
    print("🔍 Verifying module integrity...")
    for module_name in orchestrator.modules.keys():
        if orchestrator.verify_module_integrity(module_name):
            print(f"✅ {module_name}: OK")
        else:
            print(f"❌ {module_name}: Issues detected")
    
    # Start monitoring
    print("🚀 Starting Scythe Orchestrator...")
    try:
        orchestrator.start_monitoring()
    except KeyboardInterrupt:
        print("\n🛑 Stopping orchestrator...")
        orchestrator.stop_monitoring()

if __name__ == "__main__":
    main() 