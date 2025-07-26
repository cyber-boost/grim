#!/usr/bin/env python3
"""
Authentication and Authorization System for Grim Reaper & Scythe License Platforms
Implements user management, API key authentication, session management, and security features
"""

import os
import json
import time
import hashlib
import hmac
import base64
import secrets
import logging
import re
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime, timedelta
from dataclasses import dataclass
import sqlite3
from contextlib import contextmanager
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import jwt
from cryptography.fernet import Fernet

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class User:
    """User data structure"""
    id: int
    email: str
    first_name: Optional[str]
    last_name: Optional[str]
    company: Optional[str]
    is_active: bool
    email_verified: bool
    created_at: datetime
    last_login: Optional[datetime]
    tier_id: Optional[int] = None

@dataclass
class APIKey:
    """API key data structure"""
    id: int
    user_id: int
    key_prefix: str
    name: str
    scopes: List[str]
    is_active: bool
    created_at: datetime
    expires_at: Optional[datetime]
    last_used: Optional[datetime]

@dataclass
class Session:
    """User session data structure"""
    id: str
    user_id: int
    ip_address: Optional[str]
    user_agent: Optional[str]
    created_at: datetime
    expires_at: datetime
    is_active: bool

class PasswordManager:
    """Handles password hashing, validation, and security"""
    
    def __init__(self, salt_length: int = 32):
        self.salt_length = salt_length
    
    def hash_password(self, password: str) -> str:
        """Hash password using SHA-256 with salt"""
        salt = secrets.token_hex(self.salt_length)
        hash_obj = hashlib.sha256()
        hash_obj.update((password + salt).encode('utf-8'))
        password_hash = hash_obj.hexdigest()
        return f"sha256:{salt}:{password_hash}"
    
    def verify_password(self, password: str, hashed_password: str) -> bool:
        """Verify password against hash"""
        try:
            parts = hashed_password.split(':')
            if len(parts) != 3 or parts[0] != 'sha256':
                return False
            
            salt = parts[1]
            stored_hash = parts[2]
            
            hash_obj = hashlib.sha256()
            hash_obj.update((password + salt).encode('utf-8'))
            password_hash = hash_obj.hexdigest()
            
            return hmac.compare_digest(password_hash, stored_hash)
        except Exception as e:
            logger.error(f"Password verification error: {e}")
            return False
    
    def validate_password_strength(self, password: str) -> Tuple[bool, str]:
        """Validate password strength requirements"""
        if len(password) < 8:
            return False, "Password must be at least 8 characters long"
        
        if not re.search(r'[A-Z]', password):
            return False, "Password must contain at least one uppercase letter"
        
        if not re.search(r'[a-z]', password):
            return False, "Password must contain at least one lowercase letter"
        
        if not re.search(r'\d', password):
            return False, "Password must contain at least one digit"
        
        if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
            return False, "Password must contain at least one special character"
        
        return True, "Password meets strength requirements"

class EmailManager:
    """Handles email verification and notifications"""
    
    def __init__(self, smtp_config: Dict[str, str]):
        self.smtp_config = smtp_config
        self.from_email = smtp_config.get('from_email', 'noreply@grim.so')
        self.from_name = smtp_config.get('from_name', 'Grim Reaper')
    
    def send_verification_email(self, email: str, token: str, verification_url: str) -> bool:
        """Send email verification email"""
        try:
            subject = "Verify Your Email Address - Grim Reaper"
            body = f"""
            Hello,
            
            Please verify your email address by clicking the link below:
            
            {verification_url}?token={token}
            
            This link will expire in 24 hours.
            
            If you didn't create an account, please ignore this email.
            
            Best regards,
            The Grim Reaper Team
            """
            
            return self._send_email(email, subject, body)
        except Exception as e:
            logger.error(f"Failed to send verification email: {e}")
            return False
    
    def send_password_reset_email(self, email: str, token: str, reset_url: str) -> bool:
        """Send password reset email"""
        try:
            subject = "Reset Your Password - Grim Reaper"
            body = f"""
            Hello,
            
            You requested a password reset. Click the link below to reset your password:
            
            {reset_url}?token={token}
            
            This link will expire in 1 hour.
            
            If you didn't request this reset, please ignore this email.
            
            Best regards,
            The Grim Reaper Team
            """
            
            return self._send_email(email, subject, body)
        except Exception as e:
            logger.error(f"Failed to send password reset email: {e}")
            return False
    
    def _send_email(self, to_email: str, subject: str, body: str) -> bool:
        """Send email using SMTP"""
        try:
            msg = MIMEMultipart()
            msg['From'] = f"{self.from_name} <{self.from_email}>"
            msg['To'] = to_email
            msg['Subject'] = subject
            
            msg.attach(MIMEText(body, 'plain'))
            
            with smtplib.SMTP(self.smtp_config['host'], self.smtp_config['port']) as server:
                if self.smtp_config.get('use_tls', True):
                    server.starttls()
                
                if self.smtp_config.get('username') and self.smtp_config.get('password'):
                    server.login(self.smtp_config['username'], self.smtp_config['password'])
                
                server.send_message(msg)
            
            return True
        except Exception as e:
            logger.error(f"Failed to send email: {e}")
            return False

class AuthManager:
    """Main authentication and authorization manager"""
    
    def __init__(self, db_path: str, jwt_secret: str, smtp_config: Optional[Dict] = None):
        self.db_path = db_path
        self.jwt_secret = jwt_secret
        self.password_manager = PasswordManager()
        self.email_manager = EmailManager(smtp_config or {})
        self.rate_limit_window = 300  # 5 minutes
        self.max_attempts = 5
        self.lockout_duration = 900  # 15 minutes
        
        # Initialize database
        self._init_database()
    
    @contextmanager
    def get_db_connection(self):
        """Get database connection with proper error handling"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()
    
    def _init_database(self):
        """Initialize authentication database tables"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                # Create rate limiting table
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS auth_rate_limits (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        identifier TEXT NOT NULL,
                        attempt_count INTEGER DEFAULT 0,
                        first_attempt DATETIME DEFAULT CURRENT_TIMESTAMP,
                        last_attempt DATETIME DEFAULT CURRENT_TIMESTAMP,
                        locked_until DATETIME,
                        UNIQUE(identifier)
                    )
                """)
                
                # Create audit log table
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS auth_audit_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id INTEGER,
                        action TEXT NOT NULL,
                        ip_address TEXT,
                        user_agent TEXT,
                        success BOOLEAN DEFAULT 1,
                        details TEXT,
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                
                conn.commit()
        except Exception as e:
            logger.error(f"Failed to initialize auth database: {e}")
            raise
    
    def register_user(self, email: str, password: str, first_name: Optional[str] = None,
                     last_name: Optional[str] = None, company: Optional[str] = None,
                     ip_address: Optional[str] = None, user_agent: Optional[str] = None) -> Tuple[bool, str, Optional[int]]:
        """Register a new user"""
        try:
            # Validate email format
            if not self._is_valid_email(email):
                return False, "Invalid email format", None
            
            # Check rate limiting
            if self._is_rate_limited(f"register:{email}"):
                return False, "Too many registration attempts. Please try again later.", None
            
            # Validate password strength
            is_valid, message = self.password_manager.validate_password_strength(password)
            if not is_valid:
                return False, message, None
            
            # Hash password
            password_hash = self.password_manager.hash_password(password)
            
            # Generate verification token
            verification_token = secrets.token_urlsafe(32)
            
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                # Check if user already exists
                cursor.execute("SELECT id FROM grim_users WHERE email = ?", (email,))
                if cursor.fetchone():
                    return False, "User with this email already exists", None
                
                # Insert new user
                cursor.execute("""
                    INSERT INTO grim_users (email, password_hash, first_name, last_name, company, 
                                          email_verification_token, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, (email, password_hash, first_name, last_name, company, verification_token))
                
                user_id = cursor.lastrowid
                
                # Assign default FREE tier
                cursor.execute("SELECT id FROM grim_command_tiers WHERE name = 'free'")
                free_tier = cursor.fetchone()
                if free_tier:
                    cursor.execute("""
                        INSERT INTO grim_subscriptions (user_id, tier_id, status, 
                                                      current_period_start, current_period_end)
                        VALUES (?, ?, 'active', CURRENT_TIMESTAMP, 
                                datetime('now', '+30 days'))
                    """, (user_id, free_tier['id']))
                
                # Log audit event
                self._log_audit_event(user_id, 'user_registration', ip_address, user_agent, True)
                
                conn.commit()
                
                # Send verification email
                if self.email_manager.smtp_config:
                    verification_url = "https://grim.so/verify-email"
                    self.email_manager.send_verification_email(email, verification_token, verification_url)
                
                return True, "User registered successfully", user_id
                
        except Exception as e:
            logger.error(f"User registration failed: {e}")
            return False, "Registration failed. Please try again.", None
    
    def verify_email(self, token: str) -> Tuple[bool, str]:
        """Verify user email address"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT id, email FROM grim_users 
                    WHERE email_verification_token = ? AND email_verified = 0
                """, (token,))
                
                user = cursor.fetchone()
                if not user:
                    return False, "Invalid or expired verification token"
                
                # Update user as verified
                cursor.execute("""
                    UPDATE grim_users 
                    SET email_verified = 1, email_verification_token = NULL, 
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                """, (user['id'],))
                
                # Log audit event
                self._log_audit_event(user['id'], 'email_verification', None, None, True)
                
                conn.commit()
                
                return True, "Email verified successfully"
                
        except Exception as e:
            logger.error(f"Email verification failed: {e}")
            return False, "Email verification failed"
    
    def login_user(self, email: str, password: str, ip_address: Optional[str] = None,
                   user_agent: Optional[str] = None) -> Tuple[bool, str, Optional[Dict]]:
        """Authenticate user login"""
        try:
            # Check rate limiting
            if self._is_rate_limited(f"login:{email}"):
                return False, "Too many login attempts. Please try again later.", None
            
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT id, email, password_hash, first_name, last_name, company, 
                           is_active, email_verified, last_login
                    FROM grim_users 
                    WHERE email = ?
                """, (email,))
                
                user = cursor.fetchone()
                if not user:
                    self._increment_rate_limit(f"login:{email}")
                    return False, "Invalid email or password", None
                
                # Check if user is active
                if not user['is_active']:
                    return False, "Account is deactivated", None
                
                # Verify password
                if not self.password_manager.verify_password(password, user['password_hash']):
                    self._increment_rate_limit(f"login:{email}")
                    return False, "Invalid email or password", None
                
                # Update last login
                cursor.execute("""
                    UPDATE grim_users 
                    SET last_login = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                """, (user['id'],))
                
                # Create session
                session_id = secrets.token_urlsafe(32)
                expires_at = datetime.now() + timedelta(hours=24)
                
                cursor.execute("""
                    INSERT INTO grim_user_sessions (id, user_id, ip_address, user_agent, 
                                                  created_at, expires_at, is_active)
                    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, ?, 1)
                """, (session_id, user['id'], ip_address, user_agent, expires_at))
                
                # Log audit event
                self._log_audit_event(user['id'], 'user_login', ip_address, user_agent, True)
                
                conn.commit()
                
                # Generate JWT token
                jwt_token = self._generate_jwt_token(user['id'], user['email'])
                
                user_data = {
                    'id': user['id'],
                    'email': user['email'],
                    'first_name': user['first_name'],
                    'last_name': user['last_name'],
                    'company': user['company'],
                    'email_verified': bool(user['email_verified']),
                    'session_id': session_id,
                    'jwt_token': jwt_token
                }
                
                return True, "Login successful", user_data
                
        except Exception as e:
            logger.error(f"User login failed: {e}")
            return False, "Login failed. Please try again.", None
    
    def logout_user(self, session_id: str, user_id: int) -> bool:
        """Logout user and invalidate session"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    UPDATE grim_user_sessions 
                    SET is_active = 0, last_activity = CURRENT_TIMESTAMP
                    WHERE id = ? AND user_id = ?
                """, (session_id, user_id))
                
                # Log audit event
                self._log_audit_event(user_id, 'user_logout', None, None, True)
                
                conn.commit()
                return True
                
        except Exception as e:
            logger.error(f"User logout failed: {e}")
            return False
    
    def create_api_key(self, user_id: int, name: str, scopes: List[str] = None,
                       expires_at: Optional[datetime] = None) -> Tuple[bool, str, Optional[str]]:
        """Create API key for user"""
        try:
            # Generate API key
            api_key = f"grim_{secrets.token_urlsafe(32)}"
            key_hash = hashlib.sha256(api_key.encode()).hexdigest()
            key_prefix = api_key[:8]
            
            scopes_json = json.dumps(scopes or ["basic"])
            
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    INSERT INTO grim_api_keys (user_id, key_hash, key_prefix, name, scopes, 
                                             created_at, expires_at, is_active)
                    VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, 1)
                """, (user_id, key_hash, key_prefix, name, scopes_json, expires_at))
                
                # Log audit event
                self._log_audit_event(user_id, 'api_key_created', None, None, True, 
                                    f"API key: {name}")
                
                conn.commit()
                
                return True, "API key created successfully", api_key
                
        except Exception as e:
            logger.error(f"API key creation failed: {e}")
            return False, "Failed to create API key", None
    
    def validate_api_key(self, api_key: str) -> Tuple[bool, Optional[Dict]]:
        """Validate API key and return user info"""
        try:
            key_hash = hashlib.sha256(api_key.encode()).hexdigest()
            
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT ak.id, ak.user_id, ak.name, ak.scopes, ak.expires_at, ak.is_active,
                           u.email, u.first_name, u.last_name, u.is_active as user_active
                    FROM grim_api_keys ak
                    JOIN grim_users u ON ak.user_id = u.id
                    WHERE ak.key_hash = ?
                """, (key_hash,))
                
                key_data = cursor.fetchone()
                if not key_data:
                    return False, None
                
                # Check if key is active
                if not key_data['is_active']:
                    return False, None
                
                # Check if user is active
                if not key_data['user_active']:
                    return False, None
                
                # Check expiration
                if key_data['expires_at'] and datetime.fromisoformat(key_data['expires_at']) < datetime.now():
                    return False, None
                
                # Update last used
                cursor.execute("""
                    UPDATE grim_api_keys 
                    SET last_used = CURRENT_TIMESTAMP
                    WHERE id = ?
                """, (key_data['id']))
                
                conn.commit()
                
                user_info = {
                    'user_id': key_data['user_id'],
                    'email': key_data['email'],
                    'first_name': key_data['first_name'],
                    'last_name': key_data['last_name'],
                    'api_key_name': key_data['name'],
                    'scopes': json.loads(key_data['scopes']) if key_data['scopes'] else []
                }
                
                return True, user_info
                
        except Exception as e:
            logger.error(f"API key validation failed: {e}")
            return False, None
    
    def request_password_reset(self, email: str, ip_address: Optional[str] = None) -> Tuple[bool, str]:
        """Request password reset"""
        try:
            # Check rate limiting
            if self._is_rate_limited(f"reset:{email}"):
                return False, "Too many reset requests. Please try again later."
            
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("SELECT id FROM grim_users WHERE email = ? AND is_active = 1", (email,))
                user = cursor.fetchone()
                
                if not user:
                    # Don't reveal if user exists
                    return True, "If the email exists, a reset link has been sent."
                
                # Generate reset token
                reset_token = secrets.token_urlsafe(32)
                expires_at = datetime.now() + timedelta(hours=1)
                
                cursor.execute("""
                    UPDATE grim_users 
                    SET password_reset_token = ?, password_reset_expires = ?, 
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                """, (reset_token, expires_at, user['id']))
                
                # Log audit event
                self._log_audit_event(user['id'], 'password_reset_requested', ip_address, None, True)
                
                conn.commit()
                
                # Send reset email
                if self.email_manager.smtp_config:
                    reset_url = "https://grim.so/reset-password"
                    self.email_manager.send_password_reset_email(email, reset_token, reset_url)
                
                return True, "Password reset link sent to your email."
                
        except Exception as e:
            logger.error(f"Password reset request failed: {e}")
            return False, "Failed to process reset request."
    
    def reset_password(self, token: str, new_password: str) -> Tuple[bool, str]:
        """Reset password using token"""
        try:
            # Validate password strength
            is_valid, message = self.password_manager.validate_password_strength(new_password)
            if not is_valid:
                return False, message
            
            # Hash new password
            password_hash = self.password_manager.hash_password(new_password)
            
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT id FROM grim_users 
                    WHERE password_reset_token = ? AND password_reset_expires > CURRENT_TIMESTAMP
                """, (token,))
                
                user = cursor.fetchone()
                if not user:
                    return False, "Invalid or expired reset token"
                
                # Update password and clear reset token
                cursor.execute("""
                    UPDATE grim_users 
                    SET password_hash = ?, password_reset_token = NULL, 
                        password_reset_expires = NULL, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                """, (password_hash, user['id']))
                
                # Log audit event
                self._log_audit_event(user['id'], 'password_reset_completed', None, None, True)
                
                conn.commit()
                
                return True, "Password reset successfully"
                
        except Exception as e:
            logger.error(f"Password reset failed: {e}")
            return False, "Password reset failed"
    
    def get_user_profile(self, user_id: int) -> Optional[Dict]:
        """Get user profile information"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT u.id, u.email, u.first_name, u.last_name, u.company, u.phone,
                           u.timezone, u.created_at, u.last_login, u.email_verified,
                           u.notification_email, u.notification_sms, u.dashboard_theme,
                           t.name as tier_name, t.display_name as tier_display_name,
                           s.status as subscription_status, s.current_period_end
                    FROM grim_users u
                    LEFT JOIN grim_subscriptions s ON u.id = s.user_id AND s.status = 'active'
                    LEFT JOIN grim_command_tiers t ON s.tier_id = t.id
                    WHERE u.id = ?
                """, (user_id,))
                
                user = cursor.fetchone()
                if not user:
                    return None
                
                return dict(user)
                
        except Exception as e:
            logger.error(f"Failed to get user profile: {e}")
            return None
    
    def update_user_profile(self, user_id: int, updates: Dict[str, Any]) -> Tuple[bool, str]:
        """Update user profile information"""
        try:
            allowed_fields = {
                'first_name', 'last_name', 'company', 'phone', 'timezone',
                'notification_email', 'notification_sms', 'dashboard_theme'
            }
            
            # Filter allowed fields
            valid_updates = {k: v for k, v in updates.items() if k in allowed_fields}
            
            if not valid_updates:
                return False, "No valid fields to update"
            
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                # Build update query
                set_clause = ", ".join([f"{field} = ?" for field in valid_updates.keys()])
                values = list(valid_updates.values()) + [user_id]
                
                cursor.execute(f"""
                    UPDATE grim_users 
                    SET {set_clause}, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                """, values)
                
                # Log audit event
                self._log_audit_event(user_id, 'profile_updated', None, None, True, 
                                    f"Updated fields: {list(valid_updates.keys())}")
                
                conn.commit()
                
                return True, "Profile updated successfully"
                
        except Exception as e:
            logger.error(f"Profile update failed: {e}")
            return False, "Failed to update profile"
    
    def _is_valid_email(self, email: str) -> bool:
        """Validate email format"""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return re.match(pattern, email) is not None
    
    def _is_rate_limited(self, identifier: str) -> bool:
        """Check if identifier is rate limited"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT attempt_count, first_attempt, locked_until
                    FROM auth_rate_limits 
                    WHERE identifier = ?
                """, (identifier,))
                
                rate_limit = cursor.fetchone()
                
                if not rate_limit:
                    return False
                
                # Check if locked
                if rate_limit['locked_until'] and datetime.fromisoformat(rate_limit['locked_until']) > datetime.now():
                    return True
                
                # Check if within rate limit window
                first_attempt = datetime.fromisoformat(rate_limit['first_attempt'])
                if datetime.now() - first_attempt > timedelta(seconds=self.rate_limit_window):
                    # Reset rate limit
                    cursor.execute("DELETE FROM auth_rate_limits WHERE identifier = ?", (identifier,))
                    conn.commit()
                    return False
                
                return rate_limit['attempt_count'] >= self.max_attempts
                
        except Exception as e:
            logger.error(f"Rate limit check failed: {e}")
            return False
    
    def _increment_rate_limit(self, identifier: str):
        """Increment rate limit counter"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    INSERT OR REPLACE INTO auth_rate_limits 
                    (identifier, attempt_count, first_attempt, last_attempt, locked_until)
                    VALUES (?, 
                           COALESCE((SELECT attempt_count FROM auth_rate_limits WHERE identifier = ?), 0) + 1,
                           COALESCE((SELECT first_attempt FROM auth_rate_limits WHERE identifier = ?), CURRENT_TIMESTAMP),
                           CURRENT_TIMESTAMP,
                           CASE 
                               WHEN COALESCE((SELECT attempt_count FROM auth_rate_limits WHERE identifier = ?), 0) + 1 >= ?
                               THEN datetime('now', '+{} seconds')
                               ELSE NULL
                           END)
                """.format(self.lockout_duration), 
                (identifier, identifier, identifier, identifier, self.max_attempts))
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"Rate limit increment failed: {e}")
    
    def _generate_jwt_token(self, user_id: int, email: str) -> str:
        """Generate JWT token for user"""
        payload = {
            'user_id': user_id,
            'email': email,
            'exp': datetime.utcnow() + timedelta(hours=24),
            'iat': datetime.utcnow()
        }
        return jwt.encode(payload, self.jwt_secret, algorithm='HS256')
    
    def _log_audit_event(self, user_id: int, action: str, ip_address: Optional[str],
                        user_agent: Optional[str], success: bool, details: Optional[str] = None):
        """Log authentication audit event"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    INSERT INTO auth_audit_log (user_id, action, ip_address, user_agent, 
                                              success, details, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                """, (user_id, action, ip_address, user_agent, success, details))
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"Failed to log audit event: {e}")

# Example usage and testing
if __name__ == "__main__":
    # Example configuration
    db_path = "grim_scythe_complete.db"
    jwt_secret = "your-super-secret-jwt-key-change-in-production"
    
    smtp_config = {
        'host': 'smtp.gmail.com',
        'port': 587,
        'use_tls': True,
        'username': 'your-email@gmail.com',
        'password': 'your-app-password',
        'from_email': 'noreply@grim.so',
        'from_name': 'Grim Reaper'
    }
    
    # Initialize auth manager
    auth_manager = AuthManager(db_path, jwt_secret, smtp_config)
    
    # Example: Register user
    success, message, user_id = auth_manager.register_user(
        email="test@example.com",
        password="SecurePass123!",
        first_name="John",
        last_name="Doe",
        company="Test Corp"
    )
    
    print(f"Registration: {success} - {message}")
    
    if success:
        # Example: Login user
        login_success, login_message, user_data = auth_manager.login_user(
            email="test@example.com",
            password="SecurePass123!"
        )
        
        print(f"Login: {login_success} - {login_message}")
        
        if login_success:
            # Example: Create API key
            key_success, key_message, api_key = auth_manager.create_api_key(
                user_id=user_data['id'],
                name="Test API Key",
                scopes=["backup", "monitor"]
            )
            
            print(f"API Key: {key_success} - {key_message}")
            if key_success:
                print(f"Generated API Key: {api_key}")
                
                # Example: Validate API key
                valid, user_info = auth_manager.validate_api_key(api_key)
                print(f"API Key Validation: {valid}")
                if valid:
                    print(f"User Info: {user_info}") 