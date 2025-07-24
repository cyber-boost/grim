#!/usr/bin/env python3
"""
Grim Command Executor
Secure command execution for Grim admin web interface
Handles backups, logs, licenses, and system operations
"""

import os
import sys
import json
import subprocess
import asyncio
import logging
import time
import hashlib
import hmac
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime
import threading
import queue

# Import TuskLang performance engine
from performance_engine import render_turbo_template

@dataclass
class CommandResult:
    """Result of command execution"""
    success: bool
    command: str
    output: str
    error: str
    return_code: int
    execution_time: float
    timestamp: datetime
    command_id: str

class GrimExecutor:
    """Secure command executor for Grim admin operations"""
    
    def __init__(self, base_path: str = "/opt/reaper"):
        self.base_path = Path(base_path)
        self.logger = self._setup_logging()
        self.command_queue = queue.Queue()
        self.running_commands = {}
        self.command_history = []
        self.max_history = 1000
        
        # Security settings
        self.allowed_commands = {
            # Backup operations
            'backup': {
                'grim': 'grim backup',
                'scythe': 'python3 scythe/scythe.py backup',
                'sh_grim': './sh_grim/backup.sh',
                'go_grim': './go_grim/build/grim-compression'
            },
            # License operations
            'license': {
                'status': './sh_grim/scythe.sh status',
                'check': './sh_grim/scythe.sh check',
                'report': './sh_grim/scythe.sh report summary',
                'validate': './sh_grim/scythe.sh validate'
            },
            # System operations
            'system': {
                'health': 'python3 scythe/scythe.py health',
                'status': 'python3 scythe/scythe.py status',
                'logs': 'tail -n 100',
                'processes': 'ps aux | grep grim'
            },
            # Log operations
            'logs': {
                'view': 'tail -n',
                'search': 'grep -r',
                'clear': 'echo "" >',
                'archive': 'tar -czf'
            },
            # File operations
            'files': {
                'list': 'ls -la',
                'copy': 'cp',
                'move': 'mv',
                'delete': 'rm',
                'chmod': 'chmod'
            }
        }
        
        # Start command processor
        self.start_command_processor()
        
        self.logger.info("Grim Executor initialized")
    
    def _setup_logging(self) -> logging.Logger:
        """Setup logging for command execution"""
        logger = logging.getLogger('grim_executor')
        logger.setLevel(logging.INFO)
        
        # Create logs directory
        log_dir = self.base_path / 'logs'
        log_dir.mkdir(exist_ok=True)
        
        # File handler
        file_handler = logging.FileHandler(log_dir / 'executor.log')
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
    
    def start_command_processor(self):
        """Start background command processor"""
        def processor():
            while True:
                try:
                    command_data = self.command_queue.get(timeout=1)
                    if command_data is None:  # Shutdown signal
                        break
                    
                    command_id, command_type, command_args = command_data
                    result = self._execute_command_safe(command_type, command_args)
                    self.running_commands[command_id] = result
                    
                except queue.Empty:
                    continue
                except Exception as e:
                    self.logger.error(f"Command processor error: {e}")
        
        self.processor_thread = threading.Thread(target=processor, daemon=True)
        self.processor_thread.start()
    
    def _execute_command_safe(self, command_type: str, command_args: Dict[str, Any]) -> CommandResult:
        """Execute command with safety checks"""
        start_time = time.time()
        command_id = hashlib.md5(f"{command_type}_{time.time()}".encode()).hexdigest()[:8]
        
        try:
            # Validate command type
            if command_type not in self.allowed_commands:
                return CommandResult(
                    success=False,
                    command=command_type,
                    output="",
                    error=f"Command type '{command_type}' not allowed",
                    return_code=1,
                    execution_time=time.time() - start_time,
                    timestamp=datetime.now(),
                    command_id=command_id
                )
            
            # Build command based on type
            if command_type == 'backup':
                result = self._execute_backup_command(command_args)
            elif command_type == 'license':
                result = self._execute_license_command(command_args)
            elif command_type == 'system':
                result = self._execute_system_command(command_args)
            elif command_type == 'logs':
                result = self._execute_logs_command(command_args)
            elif command_type == 'files':
                result = self._execute_files_command(command_args)
            else:
                result = self._execute_custom_command(command_args)
            
            # Add to history
            self.command_history.append(result)
            if len(self.command_history) > self.max_history:
                self.command_history.pop(0)
            
            return result
            
        except Exception as e:
            result = CommandResult(
                success=False,
                command=command_type,
                output="",
                error=str(e),
                return_code=1,
                execution_time=time.time() - start_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
            self.logger.error(f"Command execution failed: {e}")
            return result
    
    def _execute_backup_command(self, args: Dict[str, Any]) -> CommandResult:
        """Execute backup operations"""
        start_time = time.time()
        command_id = hashlib.md5(f"backup_{time.time()}".encode()).hexdigest()[:8]
        
        backup_type = args.get('type', 'grim')
        source_path = args.get('source', '')
        backup_name = args.get('name', f'backup_{int(time.time())}')
        
        if backup_type == 'grim':
            cmd = ['grim', 'backup', source_path, '--name', backup_name]
        elif backup_type == 'scythe':
            cmd = ['python3', 'scythe/scythe.py', 'backup', source_path, '--name', backup_name]
        elif backup_type == 'sh_grim':
            cmd = ['./sh_grim/backup.sh', source_path, backup_name]
        else:
            return CommandResult(
                success=False,
                command=f"backup {backup_type}",
                output="",
                error=f"Unknown backup type: {backup_type}",
                return_code=1,
                execution_time=time.time() - start_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
        
        return self._run_subprocess(cmd, command_id, f"backup {backup_type}")
    
    def _execute_license_command(self, args: Dict[str, Any]) -> CommandResult:
        """Execute license operations"""
        start_time = time.time()
        command_id = hashlib.md5(f"license_{time.time()}".encode()).hexdigest()[:8]
        
        license_action = args.get('action', 'status')
        
        if license_action == 'status':
            cmd = ['./sh_grim/scythe.sh', 'status']
        elif license_action == 'check':
            cmd = ['./sh_grim/scythe.sh', 'check']
        elif license_action == 'report':
            cmd = ['./sh_grim/scythe.sh', 'report', 'summary']
        elif license_action == 'validate':
            license_key = args.get('key', '')
            cmd = ['./sh_grim/scythe.sh', 'validate', license_key]
        else:
            return CommandResult(
                success=False,
                command=f"license {license_action}",
                output="",
                error=f"Unknown license action: {license_action}",
                return_code=1,
                execution_time=time.time() - start_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
        
        return self._run_subprocess(cmd, command_id, f"license {license_action}")
    
    def _execute_system_command(self, args: Dict[str, Any]) -> CommandResult:
        """Execute system operations"""
        start_time = time.time()
        command_id = hashlib.md5(f"system_{time.time()}".encode()).hexdigest()[:8]
        
        system_action = args.get('action', 'status')
        
        if system_action == 'health':
            cmd = ['python3', 'scythe/scythe.py', 'health']
        elif system_action == 'status':
            cmd = ['python3', 'scythe/scythe.py', 'status']
        elif system_action == 'logs':
            log_file = args.get('file', 'scythe/logs/orchestrator.log')
            lines = args.get('lines', '100')
            cmd = ['tail', '-n', lines, log_file]
        elif system_action == 'processes':
            cmd = ['ps', 'aux', '|', 'grep', 'grim']
        else:
            return CommandResult(
                success=False,
                command=f"system {system_action}",
                output="",
                error=f"Unknown system action: {system_action}",
                return_code=1,
                execution_time=time.time() - start_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
        
        return self._run_subprocess(cmd, command_id, f"system {system_action}")
    
    def _execute_logs_command(self, args: Dict[str, Any]) -> CommandResult:
        """Execute log operations"""
        start_time = time.time()
        command_id = hashlib.md5(f"logs_{time.time()}".encode()).hexdigest()[:8]
        
        log_action = args.get('action', 'view')
        log_file = args.get('file', 'scythe/logs/orchestrator.log')
        
        if log_action == 'view':
            lines = args.get('lines', '100')
            cmd = ['tail', '-n', lines, log_file]
        elif log_action == 'search':
            search_term = args.get('term', '')
            cmd = ['grep', '-r', search_term, log_file]
        elif log_action == 'clear':
            cmd = ['echo', '""', '>', log_file]
        elif log_action == 'archive':
            archive_name = args.get('archive', f'logs_{int(time.time())}.tar.gz')
            cmd = ['tar', '-czf', archive_name, log_file]
        else:
            return CommandResult(
                success=False,
                command=f"logs {log_action}",
                output="",
                error=f"Unknown log action: {log_action}",
                return_code=1,
                execution_time=time.time() - start_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
        
        return self._run_subprocess(cmd, command_id, f"logs {log_action}")
    
    def _execute_files_command(self, args: Dict[str, Any]) -> CommandResult:
        """Execute file operations"""
        start_time = time.time()
        command_id = hashlib.md5(f"files_{time.time()}".encode()).hexdigest()[:8]
        
        file_action = args.get('action', 'list')
        file_path = args.get('path', '.')
        
        if file_action == 'list':
            cmd = ['ls', '-la', file_path]
        elif file_action == 'copy':
            source = args.get('source', '')
            dest = args.get('dest', '')
            cmd = ['cp', source, dest]
        elif file_action == 'move':
            source = args.get('source', '')
            dest = args.get('dest', '')
            cmd = ['mv', source, dest]
        elif file_action == 'delete':
            cmd = ['rm', '-rf', file_path]
        elif file_action == 'chmod':
            mode = args.get('mode', '755')
            cmd = ['chmod', mode, file_path]
        else:
            return CommandResult(
                success=False,
                command=f"files {file_action}",
                output="",
                error=f"Unknown file action: {file_action}",
                return_code=1,
                execution_time=time.time() - start_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
        
        return self._run_subprocess(cmd, command_id, f"files {file_action}")
    
    def _execute_custom_command(self, args: Dict[str, Any]) -> CommandResult:
        """Execute custom commands (with restrictions)"""
        start_time = time.time()
        command_id = hashlib.md5(f"custom_{time.time()}".encode()).hexdigest()[:8]
        
        command = args.get('command', '')
        
        # Security check - only allow safe commands
        dangerous_patterns = ['rm -rf /', 'dd if=', 'mkfs', 'fdisk', 'shutdown', 'reboot']
        for pattern in dangerous_patterns:
            if pattern in command.lower():
                return CommandResult(
                    success=False,
                    command=command,
                    output="",
                    error=f"Dangerous command blocked: {pattern}",
                    return_code=1,
                    execution_time=time.time() - start_time,
                    timestamp=datetime.now(),
                    command_id=command_id
                )
        
        # Split command into list
        cmd = command.split()
        return self._run_subprocess(cmd, command_id, command)
    
    def _run_subprocess(self, cmd: List[str], command_id: str, command_str: str) -> CommandResult:
        """Run subprocess with timeout and capture output"""
        start_time = time.time()
        
        try:
            # Change to base directory
            os.chdir(self.base_path)
            
            # Run command with timeout
            process = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300,  # 5 minute timeout
                cwd=self.base_path
            )
            
            execution_time = time.time() - start_time
            
            return CommandResult(
                success=process.returncode == 0,
                command=command_str,
                output=process.stdout,
                error=process.stderr,
                return_code=process.returncode,
                execution_time=execution_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
            
        except subprocess.TimeoutExpired:
            return CommandResult(
                success=False,
                command=command_str,
                output="",
                error="Command timed out after 5 minutes",
                return_code=1,
                execution_time=time.time() - start_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
        except Exception as e:
            return CommandResult(
                success=False,
                command=command_str,
                output="",
                error=str(e),
                return_code=1,
                execution_time=time.time() - start_time,
                timestamp=datetime.now(),
                command_id=command_id
            )
    
    async def execute_command_async(self, command_type: str, command_args: Dict[str, Any]) -> str:
        """Execute command asynchronously and return command ID"""
        command_id = hashlib.md5(f"{command_type}_{time.time()}".encode()).hexdigest()[:8]
        
        # Add to queue for processing
        self.command_queue.put((command_id, command_type, command_args))
        
        return command_id
    
    def get_command_result(self, command_id: str) -> Optional[CommandResult]:
        """Get result of a specific command"""
        return self.running_commands.get(command_id)
    
    def get_command_history(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Get command execution history"""
        history = []
        for result in self.command_history[-limit:]:
            history.append({
                'command_id': result.command_id,
                'command': result.command,
                'success': result.success,
                'return_code': result.return_code,
                'execution_time': result.execution_time,
                'timestamp': result.timestamp.isoformat(),
                'output_preview': result.output[:200] + '...' if len(result.output) > 200 else result.output
            })
        return history
    
    def get_system_status(self) -> Dict[str, Any]:
        """Get current system status"""
        return {
            'executor_status': 'running',
            'queue_size': self.command_queue.qsize(),
            'running_commands': len(self.running_commands),
            'command_history_size': len(self.command_history),
            'base_path': str(self.base_path),
            'timestamp': datetime.now().isoformat()
        }

# Global executor instance
grim_executor = GrimExecutor()

def main():
    """Test the executor"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grim Command Executor')
    parser.add_argument('--test', action='store_true', help='Run test commands')
    parser.add_argument('--command', help='Command type to execute')
    parser.add_argument('--args', help='Command arguments as JSON')
    
    args = parser.parse_args()
    
    if args.test:
        # Test various commands
        test_commands = [
            ('system', {'action': 'health'}),
            ('license', {'action': 'status'}),
            ('logs', {'action': 'view', 'file': 'scythe/logs/orchestrator.log', 'lines': '10'})
        ]
        
        for cmd_type, cmd_args in test_commands:
            print(f"\nTesting {cmd_type} command...")
            result = grim_executor._execute_command_safe(cmd_type, cmd_args)
            print(f"Success: {result.success}")
            print(f"Output: {result.output[:200]}...")
            print(f"Error: {result.error}")
    
    elif args.command and args.args:
        # Execute specific command
        cmd_args = json.loads(args.args)
        result = grim_executor._execute_command_safe(args.command, cmd_args)
        print(json.dumps({
            'success': result.success,
            'output': result.output,
            'error': result.error,
            'return_code': result.return_code,
            'execution_time': result.execution_time
        }, indent=2))
    
    else:
        print("Grim Executor ready for web interface integration")

if __name__ == '__main__':
    main() 