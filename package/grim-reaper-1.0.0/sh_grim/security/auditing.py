"""
Grimm Security - Audit Management
Comprehensive audit logging and security monitoring
"""

import json
import logging
import os
import sqlite3
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from enum import Enum
import hashlib
import threading
from pathlib import Path


class AuditLevel(Enum):
    """Audit log levels"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"
    SECURITY = "SECURITY"


class AuditCategory(Enum):
    """Audit event categories"""
    AUTHENTICATION = "authentication"
    AUTHORIZATION = "authorization"
    DATA_ACCESS = "data_access"
    SYSTEM_OPERATION = "system_operation"
    SECURITY_EVENT = "security_event"
    BACKUP_OPERATION = "backup_operation"
    CONFIGURATION_CHANGE = "configuration_change"
    USER_ACTION = "user_action"


class AuditManager:
    """Comprehensive audit logging and security monitoring"""
    
    def __init__(self, db_path: str = "/var/log/grimm/audit.db"):
        self.db_path = db_path
        self.logger = logging.getLogger('grimm.audit')
        self._setup_database()
        self._setup_logging()
        self._lock = threading.Lock()
        
    def _setup_database(self):
        """Initialize audit database"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS audit_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    level TEXT NOT NULL,
                    category TEXT NOT NULL,
                    user_id TEXT,
                    session_id TEXT,
                    ip_address TEXT,
                    user_agent TEXT,
                    event_type TEXT NOT NULL,
                    description TEXT NOT NULL,
                    details TEXT,
                    severity INTEGER DEFAULT 0,
                    source_module TEXT,
                    target_resource TEXT,
                    success BOOLEAN DEFAULT 1,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_audit_timestamp 
                ON audit_events(timestamp)
            """)
            
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_audit_user 
                ON audit_events(user_id)
            """)
            
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_audit_category 
                ON audit_events(category)
            """)
            
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_audit_level 
                ON audit_events(level)
            """)
            
    def _setup_logging(self):
        """Setup audit logging"""
        log_dir = "/var/log/grimm"
        os.makedirs(log_dir, exist_ok=True)
        
        handler = logging.FileHandler(f"{log_dir}/audit.log")
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        handler.setFormatter(formatter)
        self.logger.addHandler(handler)
        self.logger.setLevel(logging.INFO)
        
    def log_event(self, 
                  level: AuditLevel,
                  category: AuditCategory,
                  event_type: str,
                  description: str,
                  user_id: Optional[str] = None,
                  session_id: Optional[str] = None,
                  ip_address: Optional[str] = None,
                  user_agent: Optional[str] = None,
                  details: Optional[Dict] = None,
                  severity: int = 0,
                  source_module: Optional[str] = None,
                  target_resource: Optional[str] = None,
                  success: bool = True) -> bool:
        """Log an audit event"""
        try:
            with self._lock:
                timestamp = datetime.utcnow().isoformat()
                
                # Log to database
                with sqlite3.connect(self.db_path) as conn:
                    conn.execute("""
                        INSERT INTO audit_events 
                        (timestamp, level, category, user_id, session_id, 
                         ip_address, user_agent, event_type, description, 
                         details, severity, source_module, target_resource, success)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        timestamp, level.value, category.value, user_id,
                        session_id, ip_address, user_agent, event_type,
                        description, json.dumps(details) if details else None,
                        severity, source_module, target_resource, success
                    ))
                
                # Log to file
                log_message = f"{event_type}: {description}"
                if user_id:
                    log_message += f" (User: {user_id})"
                if ip_address:
                    log_message += f" (IP: {ip_address})"
                    
                if level == AuditLevel.SECURITY:
                    self.logger.critical(log_message)
                elif level == AuditLevel.ERROR:
                    self.logger.error(log_message)
                elif level == AuditLevel.WARNING:
                    self.logger.warning(log_message)
                else:
                    self.logger.info(log_message)
                    
                return True
                
        except Exception as e:
            print(f"Audit logging failed: {e}")
            return False
            
    def log_security_event(self, event_type: str, description: str, **kwargs):
        """Log a security-critical event"""
        return self.log_event(
            level=AuditLevel.SECURITY,
            category=AuditCategory.SECURITY_EVENT,
            event_type=event_type,
            description=description,
            severity=10,
            **kwargs
        )
        
    def log_authentication(self, event_type: str, description: str, **kwargs):
        """Log authentication events"""
        return self.log_event(
            level=AuditLevel.INFO,
            category=AuditCategory.AUTHENTICATION,
            event_type=event_type,
            description=description,
            **kwargs
        )
        
    def log_data_access(self, event_type: str, description: str, **kwargs):
        """Log data access events"""
        return self.log_event(
            level=AuditLevel.INFO,
            category=AuditCategory.DATA_ACCESS,
            event_type=event_type,
            description=description,
            **kwargs
        )
        
    def log_backup_operation(self, event_type: str, description: str, **kwargs):
        """Log backup operation events"""
        return self.log_event(
            level=AuditLevel.INFO,
            category=AuditCategory.BACKUP_OPERATION,
            event_type=event_type,
            description=description,
            **kwargs
        )
        
    def search_events(self, 
                     start_date: Optional[datetime] = None,
                     end_date: Optional[datetime] = None,
                     user_id: Optional[str] = None,
                     category: Optional[AuditCategory] = None,
                     level: Optional[AuditLevel] = None,
                     event_type: Optional[str] = None,
                     limit: int = 100) -> List[Dict]:
        """Search audit events"""
        try:
            query = "SELECT * FROM audit_events WHERE 1=1"
            params = []
            
            if start_date:
                query += " AND timestamp >= ?"
                params.append(start_date.isoformat())
                
            if end_date:
                query += " AND timestamp <= ?"
                params.append(end_date.isoformat())
                
            if user_id:
                query += " AND user_id = ?"
                params.append(user_id)
                
            if category:
                query += " AND category = ?"
                params.append(category.value)
                
            if level:
                query += " AND level = ?"
                params.append(level.value)
                
            if event_type:
                query += " AND event_type = ?"
                params.append(event_type)
                
            query += " ORDER BY timestamp DESC LIMIT ?"
            params.append(limit)
            
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.execute(query, params)
                return [dict(row) for row in cursor.fetchall()]
                
        except Exception as e:
            print(f"Audit search failed: {e}")
            return []
            
    def get_security_alerts(self, hours: int = 24) -> List[Dict]:
        """Get security alerts from the last N hours"""
        since = datetime.utcnow() - timedelta(hours=hours)
        return self.search_events(
            start_date=since,
            level=AuditLevel.SECURITY,
            limit=50
        )
        
    def get_failed_logins(self, hours: int = 24) -> List[Dict]:
        """Get failed login attempts from the last N hours"""
        since = datetime.utcnow() - timedelta(hours=hours)
        return self.search_events(
            start_date=since,
            category=AuditCategory.AUTHENTICATION,
            event_type="login_failed",
            limit=100
        )
        
    def cleanup_old_events(self, days: int = 365) -> int:
        """Clean up audit events older than specified days"""
        try:
            cutoff_date = datetime.utcnow() - timedelta(days=days)
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute(
                    "DELETE FROM audit_events WHERE timestamp < ?",
                    (cutoff_date.isoformat(),)
                )
                return cursor.rowcount
                
        except Exception as e:
            print(f"Audit cleanup failed: {e}")
            return 0
            
    def get_statistics(self, days: int = 30) -> Dict:
        """Get audit statistics for the last N days"""
        try:
            since = datetime.utcnow() - timedelta(days=days)
            
            with sqlite3.connect(self.db_path) as conn:
                # Total events
                total = conn.execute(
                    "SELECT COUNT(*) FROM audit_events WHERE timestamp >= ?",
                    (since.isoformat(),)
                ).fetchone()[0]
                
                # Events by level
                levels = conn.execute("""
                    SELECT level, COUNT(*) as count 
                    FROM audit_events 
                    WHERE timestamp >= ? 
                    GROUP BY level
                """, (since.isoformat(),)).fetchall()
                
                # Events by category
                categories = conn.execute("""
                    SELECT category, COUNT(*) as count 
                    FROM audit_events 
                    WHERE timestamp >= ? 
                    GROUP BY category
                """, (since.isoformat(),)).fetchall()
                
                # Security events
                security = conn.execute("""
                    SELECT COUNT(*) FROM audit_events 
                    WHERE timestamp >= ? AND level = 'SECURITY'
                """, (since.isoformat(),)).fetchone()[0]
                
                return {
                    'total_events': total,
                    'security_events': security,
                    'by_level': {row[0]: row[1] for row in levels},
                    'by_category': {row[0]: row[1] for row in categories},
                    'period_days': days
                }
                
        except Exception as e:
            print(f"Statistics generation failed: {e}")
            return {}
            
    def export_events(self, 
                     start_date: Optional[datetime] = None,
                     end_date: Optional[datetime] = None,
                     format: str = 'json') -> str:
        """Export audit events"""
        events = self.search_events(start_date, end_date, limit=10000)
        
        if format == 'json':
            return json.dumps(events, indent=2)
        elif format == 'csv':
            if not events:
                return ""
            headers = events[0].keys()
            csv_lines = [','.join(headers)]
            for event in events:
                csv_lines.append(','.join(str(event[h]) for h in headers))
            return '\n'.join(csv_lines)
        else:
            raise ValueError(f"Unsupported format: {format}")


def main():
    """CLI interface for audit management"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grimm Audit Manager CLI')
    parser.add_argument('action', choices=['log', 'search', 'stats', 'cleanup', 'export'])
    parser.add_argument('--level', choices=[l.value for l in AuditLevel])
    parser.add_argument('--category', choices=[c.value for c in AuditCategory])
    parser.add_argument('--event-type', help='Event type')
    parser.add_argument('--description', help='Event description')
    parser.add_argument('--user-id', help='User ID')
    parser.add_argument('--days', type=int, default=30, help='Number of days')
    parser.add_argument('--format', choices=['json', 'csv'], default='json')
    parser.add_argument('--output', help='Output file')
    
    args = parser.parse_args()
    audit = AuditManager()
    
    if args.action == 'log':
        if not all([args.level, args.category, args.event_type, args.description]):
            print("Error: level, category, event-type, and description required for logging")
            return
            
        success = audit.log_event(
            level=AuditLevel(args.level),
            category=AuditCategory(args.category),
            event_type=args.event_type,
            description=args.description,
            user_id=args.user_id
        )
        print(f"Event logged: {'Success' if success else 'Failed'}")
        
    elif args.action == 'search':
        events = audit.search_events(
            level=AuditLevel(args.level) if args.level else None,
            category=AuditCategory(args.category) if args.category else None,
            event_type=args.event_type,
            limit=50
        )
        print(json.dumps(events, indent=2))
        
    elif args.action == 'stats':
        stats = audit.get_statistics(args.days)
        print(json.dumps(stats, indent=2))
        
    elif args.action == 'cleanup':
        deleted = audit.cleanup_old_events(args.days)
        print(f"Deleted {deleted} old audit events")
        
    elif args.action == 'export':
        data = audit.export_events(format=args.format)
        if args.output:
            with open(args.output, 'w') as f:
                f.write(data)
            print(f"Exported to {args.output}")
        else:
            print(data)


if __name__ == "__main__":
    main() 