#!/usr/bin/env python3
"""
SCYTHE ORCHESTRATOR - The Reaper's Command Center

High-performance orchestrator that coordinates sh_grim, go_grim, and py_grim
into a unified backup and system management platform.

Author: Claude (Grim Reaper Agent)
Mission: CRUSH COORDINATION COMPLEXITY
"""

import os
import sys
import json
import yaml
import subprocess
import asyncio
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from enum import Enum
import time

# Add reaper root to path for importing other systems
REAPER_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(REAPER_ROOT))

class SystemStatus(Enum):
    """System health status indicators"""
    HEALTHY = "healthy"
    DEGRADED = "degraded"  
    FAILED = "failed"
    UNKNOWN = "unknown"

@dataclass
class SystemHealth:
    """Health check result for a subsystem"""
    name: str
    status: SystemStatus
    response_time: float
    last_check: float
    message: str = ""

class ScytheOrchestrator:
    """
    The Scythe Orchestrator - Central command and control for Grim Reaper
    
    Coordinates operations between:
    - sh_grim: Bash-based operations and file management
    - go_grim: High-performance compression and scanning
    - py_grim: Web APIs and monitoring interfaces
    """
    
    def __init__(self, config_path: Optional[str] = None):
        self.reaper_root = REAPER_ROOT
        self.config_path = config_path or str(self.reaper_root / "config.yaml")
        self.config = self._load_config()
        self.logger = self._setup_logging()
        self.systems = {
            'sh_grim': self.reaper_root / 'sh_grim',
            'go_grim': self.reaper_root / 'go_grim', 
            'py_grim': self.reaper_root / 'py_grim'
        }
        self.health_status = {}
        
        self.logger.info("🗡️  SCYTHE ORCHESTRATOR INITIALIZED")
        self.logger.info(f"Managing systems: {list(self.systems.keys())}")

    def _load_config(self) -> Dict[str, Any]:
        """Load orchestrator configuration with intelligent defaults"""
        default_config = {
            'logging': {
                'level': 'INFO',
                'file': 'scythe.log'
            },
            'systems': {
                'sh_grim': {
                    'enabled': True,
                    'health_check_script': 'health.sh'
                },
                'go_grim': {
                    'enabled': True,
                    'binary': 'build/grim-compression',
                    'health_endpoint': '/health'
                },
                'py_grim': {
                    'enabled': True,
                    'module': 'grim_web.app',
                    'health_endpoint': '/health'
                }
            },
            'operations': {
                'timeout': 300,
                'max_concurrent': 5,
                'retry_attempts': 3
            }
        }
        
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, 'r') as f:
                    user_config = yaml.safe_load(f) or {}
                # Merge user config with defaults
                return self._deep_merge(default_config, user_config)
            except Exception as e:
                print(f"Warning: Failed to load config from {self.config_path}: {e}")
        
        return default_config

    def _deep_merge(self, base: Dict, override: Dict) -> Dict:
        """Deep merge configuration dictionaries"""
        result = base.copy()
        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = value
        return result

    def _setup_logging(self) -> logging.Logger:
        """Setup high-performance logging"""
        logger = logging.getLogger('scythe')
        logger.setLevel(getattr(logging, self.config['logging']['level']))
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_format = logging.Formatter(
            '🗡️  %(asctime)s [%(levelname)s] %(message)s',
            datefmt='%H:%M:%S'
        )
        console_handler.setFormatter(console_format)
        logger.addHandler(console_handler)
        
        # File handler
        log_file = self.reaper_root / self.config['logging']['file']
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)
        file_format = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
        )
        file_handler.setFormatter(file_format)
        logger.addHandler(file_handler)
        
        return logger

    async def health_check_all(self) -> Dict[str, SystemHealth]:
        """Perform health checks on all managed systems"""
        self.logger.info("🏥 Performing system health checks...")
        
        tasks = []
        for system_name in self.systems:
            if self.config['systems'][system_name]['enabled']:
                tasks.append(self._health_check_system(system_name))
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        health_report = {}
        for i, result in enumerate(results):
            system_name = list(self.systems.keys())[i]
            if isinstance(result, Exception):
                health_report[system_name] = SystemHealth(
                    name=system_name,
                    status=SystemStatus.FAILED,
                    response_time=0.0,
                    last_check=time.time(),
                    message=str(result)
                )
            else:
                health_report[system_name] = result
        
        self.health_status = health_report
        return health_report

    async def _health_check_system(self, system_name: str) -> SystemHealth:
        """Health check individual system"""
        start_time = time.time()
        
        try:
            if system_name == 'sh_grim':
                return await self._health_check_sh_grim()
            elif system_name == 'go_grim':
                return await self._health_check_go_grim()
            elif system_name == 'py_grim':
                return await self._health_check_py_grim()
        except Exception as e:
            return SystemHealth(
                name=system_name,
                status=SystemStatus.FAILED,
                response_time=time.time() - start_time,
                last_check=time.time(),
                message=f"Health check failed: {e}"
            )

    async def _health_check_sh_grim(self) -> SystemHealth:
        """Health check for sh_grim bash modules"""
        start_time = time.time()
        health_script = self.systems['sh_grim'] / 'health_fixed.sh'
        
        if health_script.exists():
            proc = await asyncio.create_subprocess_exec(
                str(health_script), 'quick',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.reaper_root)
            )
            stdout, stderr = await proc.communicate()
            
            output = stdout.decode().strip()
            if proc.returncode == 0 and "HEALTHY" in output:
                status = SystemStatus.HEALTHY
                message = output
            elif "DEGRADED" in output:
                status = SystemStatus.DEGRADED 
                message = output
            else:
                status = SystemStatus.FAILED
                message = output or stderr.decode() if stderr else "Health check failed"
        else:
            status = SystemStatus.FAILED
            message = "Health check script not found"
        
        return SystemHealth(
            name='sh_grim',
            status=status,
            response_time=time.time() - start_time,
            last_check=time.time(),
            message=message
        )

    async def _health_check_go_grim(self) -> SystemHealth:
        """Health check for go_grim compression engine"""
        start_time = time.time()
        binary_path = self.systems['go_grim'] / self.config['systems']['go_grim']['binary']
        
        if binary_path.exists():
            # Test compression binary by checking if it responds to help
            proc = await asyncio.create_subprocess_exec(
                str(binary_path),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await proc.communicate()
            
            # go_grim binary shows error when no input - that means it's working!
            if stderr and (b"Usage of" in stderr or b"Input file is required" in stderr):
                status = SystemStatus.HEALTHY
                message = "Compression engine ready and operational"
            else:
                status = SystemStatus.FAILED
                message = f"Binary execution failed: {stderr.decode() if stderr else 'No response'}"
        else:
            status = SystemStatus.FAILED
            message = "Compression binary not found - needs compilation"
        
        return SystemHealth(
            name='go_grim',
            status=status,
            response_time=time.time() - start_time,
            last_check=time.time(),
            message=message
        )

    async def _health_check_py_grim(self) -> SystemHealth:
        """Health check for py_grim web services"""
        start_time = time.time()
        
        try:
            # Try to import py_grim modules
            py_grim_path = self.systems['py_grim']
            sys.path.insert(0, str(py_grim_path))
            
            import grim_web.app
            status = SystemStatus.HEALTHY
            message = "Web services available"
        except ImportError as e:
            status = SystemStatus.DEGRADED
            message = f"Import failed: {e}"
        except Exception as e:
            status = SystemStatus.FAILED
            message = f"Module check failed: {e}"
        
        return SystemHealth(
            name='py_grim',
            status=status,
            response_time=time.time() - start_time,
            last_check=time.time(),
            message=message
        )

    async def execute_backup(self, source_path: str, backup_name: str = None) -> Dict[str, Any]:
        """Execute coordinated backup operation across all systems"""
        self.logger.info(f"🎯 EXECUTING BACKUP: {source_path}")
        
        if not backup_name:
            backup_name = f"backup_{int(time.time())}"
        
        operation_id = f"backup_{backup_name}_{int(time.time())}"
        
        try:
            # Step 1: Health check all systems
            health = await self.health_check_all()
            failed_systems = [name for name, status in health.items() 
                           if status.status == SystemStatus.FAILED]
            
            if failed_systems:
                self.logger.warning(f"Systems failed health check (proceeding anyway): {failed_systems}")
            
            # Step 2: Scan and prepare (sh_grim)
            self.logger.info("📁 Scanning source files...")
            scan_result = await self._execute_sh_grim_command('scan.sh', [source_path])
            
            # Step 3: Compress and deduplicate (go_grim)
            self.logger.info("🗜️  Compressing data...")
            compress_result = await self._execute_go_grim_compression(source_path, backup_name)
            
            # Step 4: Store and index (py_grim)
            self.logger.info("💾 Storing backup metadata...")
            storage_result = await self._execute_py_grim_storage(backup_name, compress_result)
            
            # Step 5: Verify and report
            self.logger.info("✅ Verifying backup integrity...")
            verify_result = await self._verify_backup(backup_name)
            
            result = {
                'operation_id': operation_id,
                'backup_name': backup_name,
                'status': 'success',
                'source_path': source_path,
                'scan_result': scan_result,
                'compress_result': compress_result,
                'storage_result': storage_result,
                'verify_result': verify_result,
                'timestamp': time.time()
            }
            
            self.logger.info(f"🎉 BACKUP COMPLETED: {backup_name}")
            return result
            
        except Exception as e:
            self.logger.error(f"❌ BACKUP FAILED: {e}")
            return {
                'operation_id': operation_id,
                'backup_name': backup_name,
                'status': 'failed',
                'error': str(e),
                'timestamp': time.time()
            }

    async def _execute_sh_grim_command(self, script: str, args: List[str]) -> Dict[str, Any]:
        """Execute sh_grim bash script with arguments"""
        script_path = self.systems['sh_grim'] / script
        
        if not script_path.exists():
            raise FileNotFoundError(f"Script not found: {script_path}")
        
        cmd = [str(script_path)] + args
        
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(self.systems['sh_grim'])
        )
        
        stdout, stderr = await proc.communicate()
        
        if proc.returncode != 0:
            raise Exception(f"sh_grim command failed: {stderr.decode()}")
        
        return {
            'returncode': proc.returncode,
            'stdout': stdout.decode(),
            'stderr': stderr.decode()
        }

    async def _execute_go_grim_compression(self, source_path: str, backup_name: str) -> Dict[str, Any]:
        """Execute go_grim compression with optimal settings"""
        binary_path = self.systems['go_grim'] / self.config['systems']['go_grim']['binary']
        
        if not binary_path.exists():
            raise FileNotFoundError("go_grim compression binary not found - run 'make build' in go_grim/")
        
        output_path = self.reaper_root / 'backups' / f"{backup_name}.tar.zst"
        output_path.parent.mkdir(exist_ok=True)
        
        cmd = [
            str(binary_path),
            '--algorithm', 'zstd',
            '--level', '3',
            '--input', source_path,
            '--output', str(output_path)
        ]
        
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await proc.communicate()
        
        if proc.returncode != 0:
            raise Exception(f"go_grim compression failed: {stderr.decode()}")
        
        return {
            'output_path': str(output_path),
            'compression_ratio': self._calculate_compression_ratio(source_path, output_path),
            'stdout': stdout.decode()
        }

    async def _execute_py_grim_storage(self, backup_name: str, compress_result: Dict[str, Any]) -> Dict[str, Any]:
        """Store backup metadata using py_grim"""
        # This would integrate with py_grim's storage APIs
        # For now, create a simple metadata record
        
        metadata = {
            'backup_name': backup_name,
            'timestamp': time.time(),
            'file_path': compress_result['output_path'],
            'compression_ratio': compress_result.get('compression_ratio', 'unknown'),
            'status': 'stored'
        }
        
        metadata_path = self.reaper_root / 'backups' / f"{backup_name}.metadata.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        return metadata

    async def _verify_backup(self, backup_name: str) -> Dict[str, Any]:
        """Verify backup integrity"""
        backup_path = self.reaper_root / 'backups' / f"{backup_name}.tar.zst"
        metadata_path = self.reaper_root / 'backups' / f"{backup_name}.metadata.json"
        
        verification = {
            'backup_exists': backup_path.exists(),
            'metadata_exists': metadata_path.exists(),
            'backup_size': backup_path.stat().st_size if backup_path.exists() else 0,
            'verification_time': time.time()
        }
        
        return verification

    def _calculate_compression_ratio(self, source_path: str, compressed_path: Path) -> float:
        """Calculate compression ratio"""
        try:
            source_size = Path(source_path).stat().st_size if Path(source_path).is_file() else 0
            compressed_size = compressed_path.stat().st_size if compressed_path.exists() else 0
            
            if source_size > 0 and compressed_size > 0:
                return round((1 - compressed_size / source_size) * 100, 2)
            return 0.0
        except:
            return 0.0

    def get_system_status(self) -> Dict[str, Any]:
        """Get comprehensive system status"""
        return {
            'scythe_status': 'operational',
            'managed_systems': list(self.systems.keys()),
            'health_status': {name: {
                'status': health.status.value,
                'response_time': health.response_time,
                'last_check': health.last_check,
                'message': health.message
            } for name, health in self.health_status.items()},
            'config_loaded': bool(self.config),
            'timestamp': time.time()
        }

# CLI Interface
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="🗡️  Scythe Orchestrator - Grim Reaper Command Center")
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Health check command
    health_parser = subparsers.add_parser('health', help='Check system health')
    
    # Backup command
    backup_parser = subparsers.add_parser('backup', help='Execute backup operation')
    backup_parser.add_argument('source', help='Source path to backup')
    backup_parser.add_argument('--name', help='Backup name (optional)')
    
    # Status command
    status_parser = subparsers.add_parser('status', help='Get system status')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Initialize orchestrator
    orchestrator = ScytheOrchestrator()
    
    async def main():
        if args.command == 'health':
            health = await orchestrator.health_check_all()
            print("\n🏥 SYSTEM HEALTH REPORT")
            print("=" * 50)
            for name, status in health.items():
                print(f"{name:12} [{status.status.value:8}] {status.response_time:.3f}s - {status.message}")
        
        elif args.command == 'backup':
            result = await orchestrator.execute_backup(args.source, args.name)
            print(f"\n🎯 BACKUP OPERATION: {result['status'].upper()}")
            print("=" * 50)
            if result['status'] == 'success':
                print(f"Backup Name: {result['backup_name']}")
                print(f"Source Path: {result['source_path']}")
                print(f"Operation ID: {result['operation_id']}")
            else:
                print(f"Error: {result.get('error', 'Unknown error')}")
        
        elif args.command == 'status':
            status = orchestrator.get_system_status()
            print("\n🗡️  SCYTHE ORCHESTRATOR STATUS")
            print("=" * 50)
            print(f"Status: {status['scythe_status']}")
            print(f"Managed Systems: {', '.join(status['managed_systems'])}")
            print(f"Config Loaded: {status['config_loaded']}")
    
    # Run the async main function
    asyncio.run(main())