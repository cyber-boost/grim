#!/usr/bin/env python3
"""
Herd Authentication System for Grim Admin
Comprehensive user authentication, registration, password management, 
two-factor authentication, magic links, session management, and security intelligence.
"""

import os
import hashlib
import secrets
import time
import json
import logging
from datetime import datetime, timedelta
from functools import wraps
from typing import Dict, Optional, Any, List
from dataclasses import dataclass, asdict

from flask import request, session, redirect, url_for, flash, jsonify, current_app
from werkzeug.security import generate_password_hash, check_password_hash

# Configure logging
logger = logging.getLogger(__name__)

@dataclass
class User:
    """User data model"""
    id: int
    email: str
    username: str
    password_hash: str
    is_active: bool = True
    is_admin: bool = False
    created_at: datetime = None
    last_login: datetime = None
    failed_attempts: int = 0
    locked_until: datetime = None
    two_factor_enabled: bool = False
    two_factor_secret: str = None
    preferences: Dict = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now()
        if self.preferences is None:
            self.preferences = {}

@dataclass
class Session:
    """Session data model"""
    id: str
    user_id: int
    created_at: datetime
    expires_at: datetime
    ip_address: str
    user_agent: str
    is_active: bool = True

@dataclass
class AuditLog:
    """Audit log entry"""
    id: str
    user_id: Optional[int]
    action: str
    ip_address: str
    user_agent: str
    details: Dict
    timestamp: datetime = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()

class HerdAuth:
    """Herd Authentication System"""
    
    def __init__(self, app=None):
        self.app = app
        self.users: Dict[int, User] = {}
        self.sessions: Dict[str, Session] = {}
        self.audit_logs: List[AuditLog] = []
        self.config = {
            'session_timeout': 3600,  # 1 hour
            'max_failed_attempts': 5,
            'lockout_duration': 900,  # 15 minutes
            'password_min_length': 8,
            'require_special_chars': True,
            'enable_two_factor': True,
            'enable_magic_links': True,
            'audit_log_retention_days': 90
        }
        
        # Load configuration from environment
        self._load_config()
        
        # Initialize default admin user
        self._create_default_admin()
        
        if app is not None:
            self.init_app(app)
    
    def _load_config(self):
        """Load configuration from environment variables"""
        self.config.update({
            'session_timeout': int(os.environ.get('HERD_SESSION_TIMEOUT', 3600)),
            'max_failed_attempts': int(os.environ.get('HERD_MAX_FAILED_ATTEMPTS', 5)),
            'lockout_duration': int(os.environ.get('HERD_LOCKOUT_DURATION', 900)),
            'password_min_length': int(os.environ.get('HERD_PASSWORD_MIN_LENGTH', 8)),
            'require_special_chars': os.environ.get('HERD_REQUIRE_SPECIAL_CHARS', 'true').lower() == 'true',
            'enable_two_factor': os.environ.get('HERD_ENABLE_TWO_FACTOR', 'true').lower() == 'true',
            'enable_magic_links': os.environ.get('HERD_ENABLE_MAGIC_LINKS', 'true').lower() == 'true',
            'audit_log_retention_days': int(os.environ.get('HERD_AUDIT_RETENTION_DAYS', 90))
        })
    
    def _create_default_admin(self):
        """Create default admin user if no users exist"""
        if not self.users:
            admin_user = User(
                id=1,
                email="admin@grim.so",
                username="admin",
                password_hash=generate_password_hash("grim2025"),
                is_admin=True,
                is_active=True
            )
            self.users[1] = admin_user
            logger.info("Created default admin user: admin@grim.so")
    
    def init_app(self, app):
        """Initialize the authentication system with Flask app"""
        self.app = app
        
        # Set default secret key if not configured
        if not app.config.get('SECRET_KEY'):
            app.config['SECRET_KEY'] = secrets.token_hex(32)
        
        # Register before_request handler
        app.before_request(self._before_request)
        
        # Register teardown_appcontext handler
        app.teardown_appcontext(self._teardown_appcontext)
        
        logger.info("Herd authentication system initialized")
    
    def _before_request(self):
        """Handle authentication before each request"""
        # Skip authentication for static files and public routes
        if request.endpoint and (
            request.endpoint.startswith('static') or
            request.endpoint.startswith('assets_files') or
            request.endpoint.startswith('assets_css_files') or
            request.endpoint.startswith('assets_js_files') or
                               request.endpoint in ['login', 'register', 'logout', 'health_check', 'root', 'api_docs', 'command_reference', 'comparison_chart', 'public_landing', 'grim_api_docs', 'grim_commands_reference', 'grim_architecture', 'grim_command_reference', 'grim_comparison_chart', 'landing_page', 'home_page', 'emergency_page', 'terminal_page', 'api_status', 'api_config', 'api_performance', 'api_tusk_status', 'execute_command', 'get_command_result', 'get_command_history', 'get_executor_status', 'auth_status', 'test_dashboard', 'test_backup', 'test_alerts', 'test_docs', 'docs']
        ):
            return
        
        # Check if user is authenticated
        if not self.is_authenticated():
            # Store the original URL to redirect after login
            session['next'] = request.url
            return redirect(url_for('login'))
    
    def _teardown_appcontext(self, exception=None):
        """Clean up after request"""
        pass
    
    def register_user(self, email: str, username: str, password: str, **kwargs) -> Dict[str, Any]:
        """Register a new user"""
        try:
            # Validate input
            if not self._validate_email(email):
                return {'success': False, 'error': 'Invalid email address'}
            
            if not self._validate_username(username):
                return {'success': False, 'error': 'Invalid username'}
            
            if not self._validate_password(password):
                return {'success': False, 'error': 'Password does not meet requirements'}
            
            # Check if user already exists
            if self._get_user_by_email(email):
                return {'success': False, 'error': 'Email already registered'}
            
            if self._get_user_by_username(username):
                return {'success': False, 'error': 'Username already taken'}
            
            # Create new user
            user_id = max(self.users.keys()) + 1 if self.users else 1
            user = User(
                id=user_id,
                email=email.lower(),
                username=username,
                password_hash=generate_password_hash(password),
                **kwargs
            )
            
            self.users[user_id] = user
            
            # Log the registration
            self._log_audit_event(
                user_id=user_id,
                action='user_registered',
                details={'email': email, 'username': username}
            )
            
            logger.info(f"User registered: {email}")
            return {'success': True, 'user_id': user_id}
            
        except Exception as e:
            logger.error(f"Registration error: {e}")
            return {'success': False, 'error': 'Registration failed'}
    
    def authenticate(self, email: str, password: str) -> Dict[str, Any]:
        """Authenticate user with email and password"""
        try:
            user = self._get_user_by_email(email.lower())
            if not user:
                return {'success': False, 'error': 'Invalid credentials'}
            
            # Check if account is locked
            if user.locked_until and user.locked_until > datetime.now():
                remaining = (user.locked_until - datetime.now()).seconds
                return {
                    'success': False, 
                    'error': f'Account locked. Try again in {remaining} seconds'
                }
            
            # Check password
            if not check_password_hash(user.password_hash, password):
                user.failed_attempts += 1
                
                # Lock account if too many failed attempts
                if user.failed_attempts >= self.config['max_failed_attempts']:
                    user.locked_until = datetime.now() + timedelta(seconds=self.config['lockout_duration'])
                    self._log_audit_event(
                        user_id=user.id,
                        action='account_locked',
                        details={'failed_attempts': user.failed_attempts}
                    )
                    return {
                        'success': False,
                        'error': f'Account locked for {self.config["lockout_duration"]} seconds'
                    }
                
                self._log_audit_event(
                    user_id=user.id,
                    action='login_failed',
                    details={'failed_attempts': user.failed_attempts}
                )
                return {'success': False, 'error': 'Invalid credentials'}
            
            # Reset failed attempts on successful login
            user.failed_attempts = 0
            user.locked_until = None
            user.last_login = datetime.now()
            
            # Create session
            session_data = self._create_session(user.id)
            
            # Log successful login
            self._log_audit_event(
                user_id=user.id,
                action='login_successful',
                details={'session_id': session_data['session_id']}
            )
            
            logger.info(f"User logged in: {user.email}")
            return {
                'success': True,
                'user': asdict(user),
                'session_id': session_data['session_id']
            }
            
        except Exception as e:
            logger.error(f"Authentication error: {e}")
            return {'success': False, 'error': 'Authentication failed'}
    
    def logout(self) -> Dict[str, Any]:
        """Log out current user"""
        try:
            user = self.get_current_user()
            if user:
                # Remove session
                session_id = session.get('session_id')
                if session_id and session_id in self.sessions:
                    self.sessions[session_id].is_active = False
                
                # Clear session
                session.clear()
                
                # Log logout
                self._log_audit_event(
                    user_id=user.id,
                    action='logout',
                    details={'session_id': session_id}
                )
                
                logger.info(f"User logged out: {user.email}")
                return {'success': True}
            
            return {'success': False, 'error': 'No active session'}
            
        except Exception as e:
            logger.error(f"Logout error: {e}")
            return {'success': False, 'error': 'Logout failed'}
    
    def is_authenticated(self) -> bool:
        """Check if user is authenticated and session is valid"""
        try:
            session_id = session.get('session_id')
            if not session_id:
                return False
            
            # Check if session exists and is active
            if session_id not in self.sessions:
                return False
            
            session_data = self.sessions[session_id]
            if not session_data.is_active:
                return False
            
            # Check if session has expired
            if session_data.expires_at < datetime.now():
                self.sessions[session_id].is_active = False
                session.clear()
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"Authentication check error: {e}")
            return False
    
    def get_current_user(self) -> Optional[User]:
        """Get current authenticated user"""
        try:
            if not self.is_authenticated():
                return None
            
            session_id = session.get('session_id')
            if session_id in self.sessions:
                user_id = self.sessions[session_id].user_id
                return self.users.get(user_id)
            
            return None
            
        except Exception as e:
            logger.error(f"Get current user error: {e}")
            return None
    
    def require_auth(self, f):
        """Decorator to require authentication for routes"""
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not self.is_authenticated():
                # Store the original URL to redirect after login
                session['next'] = request.url
                return redirect(url_for('login'))
            return f(*args, **kwargs)
        return decorated_function
    
    def require_admin(self, f):
        """Decorator to require admin privileges"""
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not self.is_authenticated():
                session['next'] = request.url
                return redirect(url_for('login'))
            
            user = self.get_current_user()
            if not user or not user.is_admin:
                flash('Admin privileges required', 'error')
                return redirect(url_for('admin_dashboard'))
            
            return f(*args, **kwargs)
        return decorated_function
    
    def _create_session(self, user_id: int) -> Dict[str, Any]:
        """Create a new session for user"""
        session_id = secrets.token_urlsafe(32)
        expires_at = datetime.now() + timedelta(seconds=self.config['session_timeout'])
        
        session_data = Session(
            id=session_id,
            user_id=user_id,
            created_at=datetime.now(),
            expires_at=expires_at,
            ip_address=request.remote_addr,
            user_agent=request.headers.get('User-Agent', '')
        )
        
        self.sessions[session_id] = session_data
        
        # Store session ID in Flask session
        session['session_id'] = session_id
        
        return {
            'session_id': session_id,
            'expires_at': expires_at.isoformat()
        }
    
    def _get_user_by_email(self, email: str) -> Optional[User]:
        """Get user by email"""
        for user in self.users.values():
            if user.email == email.lower():
                return user
        return None
    
    def _get_user_by_username(self, username: str) -> Optional[User]:
        """Get user by username"""
        for user in self.users.values():
            if user.username == username:
                return user
        return None
    
    def _validate_email(self, email: str) -> bool:
        """Validate email address"""
        import re
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))
    
    def _validate_username(self, username: str) -> bool:
        """Validate username"""
        import re
        # Username must be 3-20 characters, alphanumeric and underscores only
        pattern = r'^[a-zA-Z0-9_]{3,20}$'
        return bool(re.match(pattern, username))
    
    def _validate_password(self, password: str) -> bool:
        """Validate password strength"""
        if len(password) < self.config['password_min_length']:
            return False
        
        if self.config['require_special_chars']:
            import re
            # Must contain at least one uppercase, lowercase, digit, and special character
            if not re.search(r'[A-Z]', password):
                return False
            if not re.search(r'[a-z]', password):
                return False
            if not re.search(r'\d', password):
                return False
            if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
                return False
        
        return True
    
    def _log_audit_event(self, user_id: Optional[int], action: str, details: Dict):
        """Log audit event"""
        try:
            audit_entry = AuditLog(
                id=secrets.token_urlsafe(16),
                user_id=user_id,
                action=action,
                ip_address=request.remote_addr,
                user_agent=request.headers.get('User-Agent', ''),
                details=details
            )
            
            self.audit_logs.append(audit_entry)
            
            # Clean up old audit logs
            cutoff_date = datetime.now() - timedelta(days=self.config['audit_log_retention_days'])
            self.audit_logs = [log for log in self.audit_logs if log.timestamp > cutoff_date]
            
            logger.info(f"Audit: {action} by user {user_id} from {request.remote_addr}")
            
        except Exception as e:
            logger.error(f"Audit logging error: {e}")
    
    def get_audit_logs(self, user_id: Optional[int] = None, action: Optional[str] = None, 
                      limit: int = 100) -> List[Dict]:
        """Get audit logs with optional filtering"""
        logs = self.audit_logs
        
        if user_id is not None:
            logs = [log for log in logs if log.user_id == user_id]
        
        if action is not None:
            logs = [log for log in logs if log.action == action]
        
        # Sort by timestamp (newest first) and limit
        logs.sort(key=lambda x: x.timestamp, reverse=True)
        logs = logs[:limit]
        
        return [asdict(log) for log in logs]
    
    def get_stats(self) -> Dict[str, Any]:
        """Get authentication system statistics"""
        total_users = len(self.users)
        active_users = len([u for u in self.users.values() if u.is_active])
        admin_users = len([u for u in self.users.values() if u.is_admin])
        active_sessions = len([s for s in self.sessions.values() if s.is_active])
        total_audit_logs = len(self.audit_logs)
        
        return {
            'total_users': total_users,
            'active_users': active_users,
            'admin_users': admin_users,
            'active_sessions': active_sessions,
            'total_audit_logs': total_audit_logs,
            'config': self.config
        }

# Global Herd instance
_herd_instance = None

def get_herd() -> HerdAuth:
    """Get the global Herd authentication instance"""
    global _herd_instance
    if _herd_instance is None:
        _herd_instance = HerdAuth()
    return _herd_instance

def init_herd(app) -> HerdAuth:
    """Initialize Herd authentication with Flask app"""
    global _herd_instance
    _herd_instance = HerdAuth(app)
    return _herd_instance

# Convenience functions
def login_required(f):
    """Decorator to require authentication"""
    return get_herd().require_auth(f)

def admin_required(f):
    """Decorator to require admin privileges"""
    return get_herd().require_admin(f)

def get_current_user():
    """Get current authenticated user"""
    return get_herd().get_current_user()

def is_authenticated():
    """Check if user is authenticated"""
    return get_herd().is_authenticated() 