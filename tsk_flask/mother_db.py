#!/usr/bin/env python3
"""
Mother Database Integration for Grim Reaper
Handles error tracking, installation registration, and API key management
"""

import os
import json
import uuid
import hashlib
import requests
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, asdict
from pathlib import Path

logger = logging.getLogger(__name__)

@dataclass
class Installation:
    """Installation data model"""
    install_id: str
    api_key: str
    version: str
    os: str
    hostname: str
    ip_address: str
    created_at: datetime
    last_seen: datetime
    is_active: bool = True
    error_count: int = 0
    last_error: Optional[datetime] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}

@dataclass
class ErrorReport:
    """Error report data model"""
    error_id: str
    install_id: str
    error_type: str
    message: str
    severity: str
    stack_trace: Optional[str] = None
    context: Dict[str, Any] = None
    timestamp: datetime = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()
        if self.context is None:
            self.context = {}

class MotherDBClient:
    """Client for interacting with the mother database"""
    
    def __init__(self, base_url: str = "https://rp.grim.so", api_key: str = None):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'GrimReaper/1.0'
        })
        
        if api_key:
            self.session.headers['Authorization'] = f'Bearer {api_key}'
    
    def create_child(self, install_data: Dict[str, Any]) -> Dict[str, Any]:
        """Register a new installation with the mother database"""
        try:
            response = self.session.post(
                f"{self.base_url}/create_child",
                json=install_data,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to create child installation: {e}")
            raise
    
    def cry_to_mom(self, error_data: Dict[str, Any]) -> Dict[str, Any]:
        """Send error report to mother database"""
        try:
            response = self.session.post(
                f"{self.base_url}/cry_to_mom",
                json=error_data,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to send error report: {e}")
            raise
    
    def get_installation_status(self, install_id: str) -> Dict[str, Any]:
        """Get installation status from mother database"""
        try:
            response = self.session.get(
                f"{self.base_url}/status/{install_id}",
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get installation status: {e}")
            raise
    
    def update_installation(self, install_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update installation data in mother database"""
        try:
            response = self.session.put(
                f"{self.base_url}/update/{install_id}",
                json=update_data,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to update installation: {e}")
            raise

class LocalMotherDB:
    """Local mother database for development and testing"""
    
    def __init__(self, data_dir: str = "/opt/reaper/mother_db"):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        
        self.installations_file = self.data_dir / "installations.json"
        self.errors_file = self.data_dir / "errors.json"
        self.api_keys_file = self.data_dir / "api_keys.json"
        
        self._load_data()
    
    def _load_data(self):
        """Load data from JSON files"""
        # Load installations
        if self.installations_file.exists():
            with open(self.installations_file, 'r') as f:
                self.installations = json.load(f)
        else:
            self.installations = {}
        
        # Load errors
        if self.errors_file.exists():
            with open(self.errors_file, 'r') as f:
                self.errors = json.load(f)
        else:
            self.errors = {}
        
        # Load API keys
        if self.api_keys_file.exists():
            with open(self.api_keys_file, 'r') as f:
                self.api_keys = json.load(f)
        else:
            self.api_keys = {}
    
    def _save_data(self):
        """Save data to JSON files"""
        # Save installations
        with open(self.installations_file, 'w') as f:
            json.dump(self.installations, f, indent=2, default=str)
        
        # Save errors
        with open(self.errors_file, 'w') as f:
            json.dump(self.errors, f, indent=2, default=str)
        
        # Save API keys
        with open(self.api_keys_file, 'w') as f:
            json.dump(self.api_keys, f, indent=2, default=str)
    
    def create_child(self, install_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new child installation"""
        install_id = install_data.get('install_id') or str(uuid.uuid4())
        api_key = self._generate_api_key()
        
        installation = {
            'install_id': install_id,
            'api_key': api_key,
            'version': install_data.get('version', '1.0.0'),
            'os': install_data.get('os', 'unknown'),
            'hostname': install_data.get('hostname', 'unknown'),
            'ip_address': install_data.get('ip_address', 'unknown'),
            'created_at': datetime.now().isoformat(),
            'last_seen': datetime.now().isoformat(),
            'is_active': True,
            'error_count': 0,
            'last_error': None,
            'metadata': install_data.get('metadata', {})
        }
        
        self.installations[install_id] = installation
        self.api_keys[api_key] = install_id
        self._save_data()
        
        logger.info(f"Created child installation: {install_id}")
        return {
            'success': True,
            'install_id': install_id,
            'api_key': api_key,
            'message': 'Installation registered successfully'
        }
    
    def cry_to_mom(self, error_data: Dict[str, Any]) -> Dict[str, Any]:
        """Record an error report"""
        # Handle both 'install_id' and 'installation_id' field names
        install_id = error_data.get('install_id') or error_data.get('installation_id')
        if not install_id or install_id not in self.installations:
            return {
                'success': False,
                'error': 'Invalid installation ID'
            }
        
        error_id = str(uuid.uuid4())
        error_report = {
            'error_id': error_id,
            'install_id': install_id,
            'error_type': error_data.get('error_type', 'unknown'),
            'message': error_data.get('message', ''),
            'severity': error_data.get('severity', 'medium'),
            'stack_trace': error_data.get('stack_trace'),
            'context': error_data.get('context', {}),
            'timestamp': datetime.now().isoformat()
        }
        
        self.errors[error_id] = error_report
        
        # Update installation error count
        self.installations[install_id]['error_count'] += 1
        self.installations[install_id]['last_error'] = datetime.now().isoformat()
        self.installations[install_id]['last_seen'] = datetime.now().isoformat()
        
        self._save_data()
        
        logger.info(f"Recorded error {error_id} for installation {install_id}")
        return {
            'success': True,
            'error_id': error_id,
            'message': 'Error reported successfully'
        }
    
    def get_installation_status(self, install_id: str) -> Dict[str, Any]:
        """Get installation status"""
        if install_id not in self.installations:
            return {
                'success': False,
                'error': 'Installation not found'
            }
        
        installation = self.installations[install_id]
        
        # Get recent errors for this installation
        recent_errors = [
            error for error in self.errors.values()
            if error['install_id'] == install_id
        ]
        
        return {
            'success': True,
            'installation': installation,
            'recent_errors': recent_errors[-10:],  # Last 10 errors
            'total_errors': len(recent_errors)
        }
    
    def update_installation(self, install_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update installation data"""
        if install_id not in self.installations:
            return {
                'success': False,
                'error': 'Installation not found'
            }
        
        self.installations[install_id].update(update_data)
        self.installations[install_id]['last_seen'] = datetime.now().isoformat()
        self._save_data()
        
        return {
            'success': True,
            'message': 'Installation updated successfully'
        }
    
    def get_all_installations(self) -> List[Dict[str, Any]]:
        """Get all installations"""
        return list(self.installations.values())
    
    def get_all_errors(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Get all errors, optionally limited"""
        errors = list(self.errors.values())
        errors.sort(key=lambda x: x['timestamp'], reverse=True)
        return errors[:limit]
    
    def get_stats(self) -> Dict[str, Any]:
        """Get database statistics"""
        total_installations = len(self.installations)
        active_installations = len([i for i in self.installations.values() if i['is_active']])
        total_errors = len(self.errors)
        
        # Error counts by severity
        error_severities = {}
        for error in self.errors.values():
            severity = error['severity']
            error_severities[severity] = error_severities.get(severity, 0) + 1
        
        # Calculate error rate
        error_rate = 0.0
        if total_installations > 0:
            error_rate = round(total_errors / total_installations, 2)
        
        return {
            'total_installations': total_installations,
            'active_installations': active_installations,
            'total_errors': total_errors,
            'error_rate': error_rate,
            'error_severities': error_severities
        }
    
    def _generate_api_key(self) -> str:
        """Generate a unique API key"""
        while True:
            api_key = hashlib.sha256(uuid.uuid4().bytes).hexdigest()[:32]
            if api_key not in self.api_keys:
                return api_key

class ErrorTracker:
    """Local error tracking system"""
    
    def __init__(self, log_file: str = "/tmp/grim-error.log"):
        self.log_file = log_file
        self.mother_db = None
        self.install_id = None
        self.api_key = None
        
        # Ensure log directory exists
        log_path = Path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)
    
    def initialize(self, mother_db_url: str = None, install_id: str = None, api_key: str = None):
        """Initialize the error tracker"""
        self.install_id = install_id
        self.api_key = api_key
        
        if mother_db_url:
            self.mother_db = MotherDBClient(mother_db_url, api_key)
        else:
            self.mother_db = LocalMotherDB()
        
        # If no install_id provided, try to load from local storage
        if not self.install_id:
            self.install_id = self._load_install_id()
        
        logger.info(f"Error tracker initialized for installation: {self.install_id}")
    
    def _load_install_id(self) -> Optional[str]:
        """Load installation ID from local storage"""
        install_file = Path("/opt/reaper/.install_id")
        if install_file.exists():
            return install_file.read_text().strip()
        return None
    
    def _save_install_id(self, install_id: str):
        """Save installation ID to local storage"""
        install_file = Path("/opt/reaper/.install_id")
        install_file.parent.mkdir(parents=True, exist_ok=True)
        install_file.write_text(install_id)
    
    def _save_api_key(self, api_key: str):
        """Save API key to local storage"""
        api_key_file = Path("/opt/reaper/.api_key")
        api_key_file.parent.mkdir(parents=True, exist_ok=True)
        api_key_file.write_text(api_key)
    
    def register_installation(self, version: str = "1.0.0", os: str = None, hostname: str = None) -> bool:
        """Register this installation with the mother database"""
        try:
            if not os:
                import platform
                os = platform.system().lower()
            
            if not hostname:
                import socket
                hostname = socket.gethostname()
            
            install_data = {
                'install_id': self.install_id,
                'version': version,
                'os': os,
                'hostname': hostname,
                'ip_address': self._get_ip_address(),
                'metadata': {
                    'python_version': platform.python_version(),
                    'architecture': platform.machine()
                }
            }
            
            result = self.mother_db.create_child(install_data)
            
            if result.get('success'):
                self.install_id = result['install_id']
                self.api_key = result['api_key']
                
                # Save to local storage
                self._save_install_id(self.install_id)
                self._save_api_key(self.api_key)
                
                logger.info(f"Installation registered successfully: {self.install_id}")
                return True
            else:
                logger.error(f"Failed to register installation: {result.get('error')}")
                return False
                
        except Exception as e:
            logger.error(f"Error registering installation: {e}")
            return False
    
    def _get_ip_address(self) -> str:
        """Get local IP address"""
        try:
            import socket
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return "unknown"
    
    def log_error(self, error_type: str, message: str, severity: str = "medium", 
                  stack_trace: str = None, context: Dict[str, Any] = None):
        """Log an error locally and optionally send to mother database"""
        timestamp = datetime.now().isoformat()
        
        # Log locally
        log_entry = f"[{timestamp}] {severity.upper()}: {error_type} - {message}"
        if context:
            log_entry += f" - {json.dumps(context)}"
        
        with open(self.log_file, 'a') as f:
            f.write(log_entry + '\n')
        
        # Send to mother database if available
        if self.mother_db and self.install_id:
            try:
                error_data = {
                    'install_id': self.install_id,
                    'error_type': error_type,
                    'message': message,
                    'severity': severity,
                    'stack_trace': stack_trace,
                    'context': context or {}
                }
                
                self.mother_db.cry_to_mom(error_data)
                
            except Exception as e:
                logger.error(f"Failed to send error to mother database: {e}")
    
    def get_local_errors(self, lines: int = 100) -> List[str]:
        """Get recent local error log entries"""
        try:
            with open(self.log_file, 'r') as f:
                return f.readlines()[-lines:]
        except FileNotFoundError:
            return []

# Global error tracker instance
error_tracker = ErrorTracker()

def get_error_tracker() -> ErrorTracker:
    """Get the global error tracker instance"""
    return error_tracker

def init_error_tracker(mother_db_url: str = None, install_id: str = None, api_key: str = None):
    """Initialize the global error tracker"""
    error_tracker.initialize(mother_db_url, install_id, api_key)
    
    # Auto-register if no installation ID
    if not error_tracker.install_id:
        error_tracker.register_installation()

def log_error(error_type: str, message: str, severity: str = "medium", 
              stack_trace: str = None, context: Dict[str, Any] = None):
    """Log an error using the global error tracker"""
    error_tracker.log_error(error_type, message, severity, stack_trace, context) 