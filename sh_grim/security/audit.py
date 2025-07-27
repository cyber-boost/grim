#!/usr/bin/env python3
"""
Grimm Security Audit Module
Comprehensive security auditing and logging for backup system activities
"""

import os
import sys
import json
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional, Union
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
import hashlib
import hmac
import secrets
from enum import Enum
import threading
import queue

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AuditLevel(Enum):
    """Audit log levels"""
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"

class AuditCategory(Enum):
    """Audit event categories"""
    AUTHENTICATION = "authentication"
    AUTHORIZATION = "authorization"
    BACKUP = "backup"
    RESTORE = "restore"
    CONFIGURATION = "configuration"
    SECURITY = "security"
    SYSTEM = "system"
    USER = "user"
    DATA = "data"
    NETWORK = "network"

@dataclass
class AuditEvent:
    """Audit event data structure"""
    event_id: str
    timestamp: datetime
    level: AuditLevel
    category: AuditCategory
    user_id: Optional[str]
    username: Optional[str]
    ip_address: Optional[str]
    user_agent: Optional[str]
    action: str
    resource: str
    details: Dict[str, Any]
    result: str
    session_id: Optional[str]
    checksum: str

@dataclass
class AuditConfig:
    """Audit configuration data structure"""
    enabled: bool
    log_file: str
    max_file_size: int
    max_files: int
    retention_days: int
    compression: bool
    encryption: bool
    real_time: bool
    syslog: bool
    syslog_host: str
    syslog_port: int
    syslog_facility: str

class AuditManager:
    """Main audit management class"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.audit_config = self._load_audit_config()
        self.audit_queue = queue.Queue()
        self.audit_thread = None
        self.running = False
        
        # Initialize audit system
        self._initialize_audit_system()
        
        # Start audit processing thread
        if self.audit_config.real_time:
            self._start_audit_thread()
        
        logger.info("Audit manager initialized")
    
    def _load_audit_config(self) -> AuditConfig:
        """Load audit configuration"""
        return AuditConfig(
            enabled=self.config.get('audit_enabled', True),
            log_file=self.config.get('audit_log_file', 'audit.log'),
            max_file_size=self.config.get('audit_max_file_size', 10 * 1024 * 1024),  # 10MB
            max_files=self.config.get('audit_max_files', 10),
            retention_days=self.config.get('audit_retention_days', 90),
            compression=self.config.get('audit_compression', True),
            encryption=self.config.get('audit_encryption', False),
            real_time=self.config.get('audit_real_time', True),
            syslog=self.config.get('audit_syslog', False),
            syslog_host=self.config.get('audit_syslog_host', 'localhost'),
            syslog_port=self.config.get('audit_syslog_port', 514),
            syslog_facility=self.config.get('audit_syslog_facility', 'local0')
        )
    
    def _initialize_audit_system(self):
        """Initialize audit system"""
        # Create audit log directory
        log_dir = Path(self.audit_config.log_file).parent
        log_dir.mkdir(parents=True, exist_ok=True)
        
        # Create initial audit log entry
        self._log_system_event(
            AuditLevel.INFO,
            AuditCategory.SYSTEM,
            "audit_system_started",
            "Audit system initialized",
            {"config": asdict(self.audit_config)}
        )
    
    def _start_audit_thread(self):
        """Start audit processing thread"""
        if self.audit_thread and self.audit_thread.is_alive():
            return
        
        self.running = True
        self.audit_thread = threading.Thread(target=self._audit_processing_loop, daemon=True)
        self.audit_thread.start()
        logger.info("Audit processing thread started")
    
    def _audit_processing_loop(self):
        """Audit event processing loop"""
        while self.running:
            try:
                # Get event from queue with timeout
                event = self.audit_queue.get(timeout=1)
                self._process_audit_event(event)
            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"Error processing audit event: {e}")
    
    def _process_audit_event(self, event: AuditEvent):
        """Process individual audit event"""
        try:
            # Write to log file
            self._write_audit_log(event)
            
            # Send to syslog if configured
            if self.audit_config.syslog:
                self._send_to_syslog(event)
            
            # Check for security alerts
            self._check_security_alerts(event)
            
        except Exception as e:
            logger.error(f"Error processing audit event: {e}")
    
    def log_event(self, level: AuditLevel, category: AuditCategory, action: str, 
                 resource: str, details: Dict[str, Any], user_id: str = None,
                 username: str = None, ip_address: str = None, user_agent: str = None,
                 session_id: str = None, result: str = "success") -> str:
        """Log an audit event"""
        if not self.audit_config.enabled:
            return ""
        
        # Create audit event
        event = AuditEvent(
            event_id=self._generate_event_id(),
            timestamp=datetime.now(),
            level=level,
            category=category,
            user_id=user_id,
            username=username,
            ip_address=ip_address,
            user_agent=user_agent,
            action=action,
            resource=resource,
            details=details,
            result=result,
            session_id=session_id,
            checksum=""
        )
        
        # Calculate checksum
        event.checksum = self._calculate_event_checksum(event)
        
        # Add to queue for processing
        if self.audit_config.real_time:
            self.audit_queue.put(event)
        else:
            self._process_audit_event(event)
        
        return event.event_id
    
    def log_authentication_event(self, action: str, username: str, ip_address: str = None,
                               user_agent: str = None, result: str = "success", 
                               details: Dict[str, Any] = None) -> str:
        """Log authentication event"""
        return self.log_event(
            level=AuditLevel.INFO if result == "success" else AuditLevel.WARNING,
            category=AuditCategory.AUTHENTICATION,
            action=action,
            resource=f"user:{username}",
            details=details or {},
            username=username,
            ip_address=ip_address,
            user_agent=user_agent,
            result=result
        )
    
    def log_authorization_event(self, action: str, user_id: str, username: str,
                              resource: str, permission: str, result: str = "success",
                              details: Dict[str, Any] = None) -> str:
        """Log authorization event"""
        return self.log_event(
            level=AuditLevel.INFO if result == "success" else AuditLevel.WARNING,
            category=AuditCategory.AUTHORIZATION,
            action=action,
            resource=resource,
            details={
                "permission": permission,
                **(details or {})
            },
            user_id=user_id,
            username=username,
            result=result
        )
    
    def log_backup_event(self, action: str, user_id: str, username: str,
                        backup_id: str, source_path: str, result: str = "success",
                        details: Dict[str, Any] = None) -> str:
        """Log backup event"""
        return self.log_event(
            level=AuditLevel.INFO if result == "success" else AuditLevel.ERROR,
            category=AuditCategory.BACKUP,
            action=action,
            resource=f"backup:{backup_id}",
            details={
                "source_path": source_path,
                "backup_id": backup_id,
                **(details or {})
            },
            user_id=user_id,
            username=username,
            result=result
        )
    
    def log_restore_event(self, action: str, user_id: str, username: str,
                         backup_id: str, target_path: str, result: str = "success",
                         details: Dict[str, Any] = None) -> str:
        """Log restore event"""
        return self.log_event(
            level=AuditLevel.INFO if result == "success" else AuditLevel.ERROR,
            category=AuditCategory.RESTORE,
            action=action,
            resource=f"restore:{backup_id}",
            details={
                "target_path": target_path,
                "backup_id": backup_id,
                **(details or {})
            },
            user_id=user_id,
            username=username,
            result=result
        )
    
    def log_security_event(self, action: str, level: AuditLevel, details: Dict[str, Any],
                          user_id: str = None, username: str = None,
                          ip_address: str = None, result: str = "success") -> str:
        """Log security event"""
        return self.log_event(
            level=level,
            category=AuditCategory.SECURITY,
            action=action,
            resource="security",
            details=details,
            user_id=user_id,
            username=username,
            ip_address=ip_address,
            result=result
        )
    
    def log_configuration_event(self, action: str, user_id: str, username: str,
                              config_key: str, old_value: Any, new_value: Any,
                              result: str = "success") -> str:
        """Log configuration change event"""
        return self.log_event(
            level=AuditLevel.INFO,
            category=AuditCategory.CONFIGURATION,
            action=action,
            resource=f"config:{config_key}",
            details={
                "config_key": config_key,
                "old_value": str(old_value),
                "new_value": str(new_value)
            },
            user_id=user_id,
            username=username,
            result=result
        )
    
    def log_data_access_event(self, action: str, user_id: str, username: str,
                            data_type: str, data_id: str, access_method: str,
                            result: str = "success", details: Dict[str, Any] = None) -> str:
        """Log data access event"""
        return self.log_event(
            level=AuditLevel.INFO,
            category=AuditCategory.DATA,
            action=action,
            resource=f"data:{data_type}:{data_id}",
            details={
                "data_type": data_type,
                "data_id": data_id,
                "access_method": access_method,
                **(details or {})
            },
            user_id=user_id,
            username=username,
            result=result
        )
    
    def _log_system_event(self, level: AuditLevel, category: AuditCategory,
                         action: str, resource: str, details: Dict[str, Any],
                         result: str = "success") -> str:
        """Log system event"""
        return self.log_event(
            level=level,
            category=category,
            action=action,
            resource=resource,
            details=details,
            result=result
        )
    
    def _generate_event_id(self) -> str:
        """Generate unique event ID"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
        random_part = secrets.token_hex(8)
        return f"audit_{timestamp}_{random_part}"
    
    def _calculate_event_checksum(self, event: AuditEvent) -> str:
        """Calculate checksum for audit event"""
        # Create checksum data (excluding checksum field itself)
        checksum_data = {
            'event_id': event.event_id,
            'timestamp': event.timestamp.isoformat(),
            'level': event.level.value,
            'category': event.category.value,
            'user_id': event.user_id,
            'username': event.username,
            'ip_address': event.ip_address,
            'user_agent': event.user_agent,
            'action': event.action,
            'resource': event.resource,
            'details': event.details,
            'result': event.result,
            'session_id': event.session_id
        }
        
        # Convert to JSON and calculate SHA-256
        json_data = json.dumps(checksum_data, sort_keys=True)
        return hashlib.sha256(json_data.encode()).hexdigest()
    
    def _write_audit_log(self, event: AuditEvent):
        """Write audit event to log file"""
        try:
            # Create log entry
            log_entry = {
                'event_id': event.event_id,
                'timestamp': event.timestamp.isoformat(),
                'level': event.level.value,
                'category': event.category.value,
                'user_id': event.user_id,
                'username': event.username,
                'ip_address': event.ip_address,
                'user_agent': event.user_agent,
                'action': event.action,
                'resource': event.resource,
                'details': event.details,
                'result': event.result,
                'session_id': event.session_id,
                'checksum': event.checksum
            }
            
            # Write to log file
            with open(self.audit_config.log_file, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
            
            # Check file size and rotate if needed
            self._check_log_rotation()
            
        except Exception as e:
            logger.error(f"Error writing audit log: {e}")
    
    def _check_log_rotation(self):
        """Check and perform log rotation if needed"""
        try:
            log_file = Path(self.audit_config.log_file)
            if not log_file.exists():
                return
            
            # Check file size
            if log_file.stat().st_size > self.audit_config.max_file_size:
                self._rotate_log_file()
                
        except Exception as e:
            logger.error(f"Error checking log rotation: {e}")
    
    def _rotate_log_file(self):
        """Rotate audit log file"""
        try:
            log_file = Path(self.audit_config.log_file)
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            
            # Rename current log file
            backup_file = log_file.with_suffix(f'.{timestamp}')
            log_file.rename(backup_file)
            
            # Compress if configured
            if self.audit_config.compression:
                import gzip
                with open(backup_file, 'rb') as f_in:
                    with gzip.open(f"{backup_file}.gz", 'wb') as f_out:
                        f_out.writelines(f_in)
                backup_file.unlink()  # Remove uncompressed file
            
            # Clean up old files
            self._cleanup_old_logs()
            
            logger.info(f"Audit log rotated: {backup_file}")
            
        except Exception as e:
            logger.error(f"Error rotating audit log: {e}")
    
    def _cleanup_old_logs(self):
        """Clean up old audit log files"""
        try:
            log_dir = Path(self.audit_config.log_file).parent
            cutoff_date = datetime.now() - timedelta(days=self.audit_config.retention_days)
            
            # Find old log files
            old_files = []
            for log_file in log_dir.glob(f"{Path(self.audit_config.log_file).stem}.*"):
                if log_file.is_file():
                    # Try to extract timestamp from filename
                    try:
                        timestamp_str = log_file.suffix.lstrip('.')
                        if timestamp_str.endswith('.gz'):
                            timestamp_str = timestamp_str[:-3]
                        file_date = datetime.strptime(timestamp_str, '%Y%m%d_%H%M%S')
                        if file_date < cutoff_date:
                            old_files.append(log_file)
                    except ValueError:
                        # If we can't parse the timestamp, skip this file
                        continue
            
            # Remove old files
            for old_file in old_files:
                old_file.unlink()
                logger.info(f"Removed old audit log: {old_file}")
            
        except Exception as e:
            logger.error(f"Error cleaning up old logs: {e}")
    
    def _send_to_syslog(self, event: AuditEvent):
        """Send audit event to syslog"""
        try:
            import socket
            
            # Create syslog message
            message = f"AUDIT: {event.action} {event.resource} by {event.username or 'system'} - {event.result}"
            
            # Create UDP socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            
            # Send message
            sock.sendto(message.encode(), (self.audit_config.syslog_host, self.audit_config.syslog_port))
            sock.close()
            
        except Exception as e:
            logger.error(f"Error sending to syslog: {e}")
    
    def _check_security_alerts(self, event: AuditEvent):
        """Check for security alerts based on audit event"""
        try:
            # Check for failed authentication attempts
            if (event.category == AuditCategory.AUTHENTICATION and 
                event.action == "login" and event.result == "failure"):
                self._trigger_security_alert("failed_login", event)
            
            # Check for unauthorized access attempts
            if (event.category == AuditCategory.AUTHORIZATION and 
                event.result == "failure"):
                self._trigger_security_alert("unauthorized_access", event)
            
            # Check for suspicious activities
            if (event.category == AuditCategory.SECURITY and 
                event.level in [AuditLevel.WARNING, AuditLevel.ERROR, AuditLevel.CRITICAL]):
                self._trigger_security_alert("security_violation", event)
            
        except Exception as e:
            logger.error(f"Error checking security alerts: {e}")
    
    def _trigger_security_alert(self, alert_type: str, event: AuditEvent):
        """Trigger security alert"""
        alert = {
            'alert_type': alert_type,
            'timestamp': datetime.now().isoformat(),
            'event_id': event.event_id,
            'level': event.level.value,
            'category': event.category.value,
            'action': event.action,
            'resource': event.resource,
            'user_id': event.user_id,
            'username': event.username,
            'ip_address': event.ip_address,
            'details': event.details
        }
        
        # Log security alert
        logger.warning(f"SECURITY ALERT: {alert_type} - {event.action} by {event.username or 'unknown'}")
        
        # In a real implementation, this would send alerts to security monitoring systems
        # For now, we'll just log it
        self._log_system_event(
            AuditLevel.WARNING,
            AuditCategory.SECURITY,
            "security_alert",
            f"alert:{alert_type}",
            alert,
            "triggered"
        )
    
    def search_events(self, filters: Dict[str, Any] = None, 
                     start_time: datetime = None, end_time: datetime = None,
                     limit: int = 100) -> List[AuditEvent]:
        """Search audit events based on filters"""
        events = []
        
        try:
            with open(self.audit_config.log_file, 'r') as f:
                for line in f:
                    try:
                        event_data = json.loads(line.strip())
                        
                        # Apply time filters
                        event_time = datetime.fromisoformat(event_data['timestamp'])
                        if start_time and event_time < start_time:
                            continue
                        if end_time and event_time > end_time:
                            continue
                        
                        # Apply other filters
                        if filters:
                            if not self._matches_filters(event_data, filters):
                                continue
                        
                        # Create AuditEvent object
                        event = AuditEvent(
                            event_id=event_data['event_id'],
                            timestamp=event_time,
                            level=AuditLevel(event_data['level']),
                            category=AuditCategory(event_data['category']),
                            user_id=event_data['user_id'],
                            username=event_data['username'],
                            ip_address=event_data['ip_address'],
                            user_agent=event_data['user_agent'],
                            action=event_data['action'],
                            resource=event_data['resource'],
                            details=event_data['details'],
                            result=event_data['result'],
                            session_id=event_data['session_id'],
                            checksum=event_data['checksum']
                        )
                        
                        events.append(event)
                        
                        # Check limit
                        if len(events) >= limit:
                            break
                            
                    except json.JSONDecodeError:
                        continue
                    except Exception as e:
                        logger.error(f"Error parsing audit event: {e}")
                        continue
            
        except FileNotFoundError:
            logger.warning("Audit log file not found")
        except Exception as e:
            logger.error(f"Error searching audit events: {e}")
        
        return events
    
    def _matches_filters(self, event_data: Dict[str, Any], filters: Dict[str, Any]) -> bool:
        """Check if event matches filters"""
        for key, value in filters.items():
            if key not in event_data:
                return False
            
            if isinstance(value, list):
                if event_data[key] not in value:
                    return False
            else:
                if event_data[key] != value:
                    return False
        
        return True
    
    def get_audit_summary(self, start_time: datetime = None, end_time: datetime = None) -> Dict[str, Any]:
        """Get audit summary statistics"""
        events = self.search_events(start_time=start_time, end_time=end_time, limit=10000)
        
        summary = {
            'total_events': len(events),
            'time_range': {
                'start': start_time.isoformat() if start_time else None,
                'end': end_time.isoformat() if end_time else None
            },
            'by_level': {},
            'by_category': {},
            'by_action': {},
            'by_result': {},
            'top_users': {},
            'top_resources': {},
            'security_events': 0
        }
        
        for event in events:
            # Count by level
            level = event.level.value
            summary['by_level'][level] = summary['by_level'].get(level, 0) + 1
            
            # Count by category
            category = event.category.value
            summary['by_category'][category] = summary['by_category'].get(category, 0) + 1
            
            # Count by action
            action = event.action
            summary['by_action'][action] = summary['by_action'].get(action, 0) + 1
            
            # Count by result
            result = event.result
            summary['by_result'][result] = summary['by_result'].get(result, 0) + 1
            
            # Count by user
            if event.username:
                summary['top_users'][event.username] = summary['top_users'].get(event.username, 0) + 1
            
            # Count by resource
            summary['top_resources'][event.resource] = summary['top_resources'].get(event.resource, 0) + 1
            
            # Count security events
            if event.category == AuditCategory.SECURITY:
                summary['security_events'] += 1
        
        return summary
    
    def stop(self):
        """Stop audit manager"""
        self.running = False
        if self.audit_thread:
            self.audit_thread.join(timeout=5)
        logger.info("Audit manager stopped")

def main():
    """Main entry point for audit testing"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grimm Audit Manager")
    parser.add_argument("--action", choices=["search", "summary", "test"], required=True)
    parser.add_argument("--start-time", help="Start time for search (YYYY-MM-DD HH:MM:SS)")
    parser.add_argument("--end-time", help="End time for search (YYYY-MM-DD HH:MM:SS)")
    parser.add_argument("--filters", help="JSON filters for search")
    parser.add_argument("--limit", type=int, default=100, help="Limit for search results")
    
    args = parser.parse_args()
    
    # Initialize audit manager
    audit_manager = AuditManager()
    
    if args.action == "search":
        # Parse filters
        filters = {}
        if args.filters:
            try:
                filters = json.loads(args.filters)
            except json.JSONDecodeError:
                print("Invalid JSON filters")
                return
        
        # Parse time range
        start_time = None
        end_time = None
        if args.start_time:
            start_time = datetime.strptime(args.start_time, '%Y-%m-%d %H:%M:%S')
        if args.end_time:
            end_time = datetime.strptime(args.end_time, '%Y-%m-%d %H:%M:%S')
        
        # Search events
        events = audit_manager.search_events(
            filters=filters,
            start_time=start_time,
            end_time=end_time,
            limit=args.limit
        )
        
        print(f"Found {len(events)} audit events:")
        for event in events:
            print(f"- {event.timestamp}: {event.action} {event.resource} by {event.username or 'system'} ({event.result})")
    
    elif args.action == "summary":
        # Parse time range
        start_time = None
        end_time = None
        if args.start_time:
            start_time = datetime.strptime(args.start_time, '%Y-%m-%d %H:%M:%S')
        if args.end_time:
            end_time = datetime.strptime(args.end_time, '%Y-%m-%d %H:%M:%S')
        
        # Get summary
        summary = audit_manager.get_audit_summary(start_time=start_time, end_time=end_time)
        
        print("Audit Summary:")
        print(f"Total Events: {summary['total_events']}")
        print(f"Security Events: {summary['security_events']}")
        print("\nBy Level:")
        for level, count in summary['by_level'].items():
            print(f"  {level}: {count}")
        print("\nBy Category:")
        for category, count in summary['by_category'].items():
            print(f"  {category}: {count}")
    
    elif args.action == "test":
        # Generate test audit events
        print("Generating test audit events...")
        
        # Test authentication events
        audit_manager.log_authentication_event("login", "testuser", "192.168.1.100", "Mozilla/5.0", "success")
        audit_manager.log_authentication_event("login", "testuser", "192.168.1.100", "Mozilla/5.0", "failure")
        
        # Test backup events
        audit_manager.log_backup_event("create", "user123", "testuser", "backup_001", "/home/user/data", "success")
        audit_manager.log_backup_event("restore", "user123", "testuser", "backup_001", "/home/user/restored", "success")
        
        # Test security events
        audit_manager.log_security_event("failed_login_attempt", AuditLevel.WARNING, {"attempts": 5}, "user123", "testuser", "192.168.1.100", "failure")
        
        print("Test audit events generated")

if __name__ == "__main__":
    main() 