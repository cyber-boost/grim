#!/usr/bin/env python3
"""
Grimm Security Authentication Module
Comprehensive authentication and authorization for backup system access
"""

import os
import sys
import json
import hashlib
import hmac
import secrets
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional, Union, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
import jwt
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.backends import default_backend
import bcrypt

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class User:
    """User data structure"""
    user_id: str
    username: str
    email: str
    password_hash: str
    salt: bytes
    role: str
    permissions: List[str]
    is_active: bool
    created_at: datetime
    last_login: datetime
    failed_attempts: int
    locked_until: Optional[datetime]

@dataclass
class Session:
    """Session data structure"""
    session_id: str
    user_id: str
    token: str
    created_at: datetime
    expires_at: datetime
    ip_address: str
    user_agent: str
    is_active: bool

@dataclass
class AuthResult:
    """Authentication result data structure"""
    success: bool
    user: Optional[User]
    session: Optional[Session]
    token: str
    message: str
    timestamp: datetime

class AuthenticationManager:
    """Main authentication management class"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.users: Dict[str, User] = {}
        self.sessions: Dict[str, Session] = {}
        self.jwt_secret = self.config.get('jwt_secret', secrets.token_hex(32))
        self.jwt_expiry_hours = self.config.get('jwt_expiry_hours', 24)
        self.max_failed_attempts = self.config.get('max_failed_attempts', 5)
        self.lockout_duration_minutes = self.config.get('lockout_duration_minutes', 30)
        
        # Load users from storage
        self._load_users()
        
        logger.info("Authentication manager initialized")
    
    def _load_users(self):
        """Load users from storage"""
        users_file = self.config.get('users_file', 'users.json')
        if os.path.exists(users_file):
            try:
                with open(users_file, 'r') as f:
                    users_data = json.load(f)
                
                for user_data in users_data:
                    user = User(
                        user_id=user_data['user_id'],
                        username=user_data['username'],
                        email=user_data['email'],
                        password_hash=user_data['password_hash'],
                        salt=bytes.fromhex(user_data['salt']),
                        role=user_data['role'],
                        permissions=user_data['permissions'],
                        is_active=user_data['is_active'],
                        created_at=datetime.fromisoformat(user_data['created_at']),
                        last_login=datetime.fromisoformat(user_data['last_login']),
                        failed_attempts=user_data['failed_attempts'],
                        locked_until=datetime.fromisoformat(user_data['locked_until']) if user_data['locked_until'] else None
                    )
                    self.users[user['user_id']] = user
                
                logger.info(f"Loaded {len(self.users)} users from storage")
            except Exception as e:
                logger.error(f"Error loading users: {e}")
    
    def _save_users(self):
        """Save users to storage"""
        users_file = self.config.get('users_file', 'users.json')
        try:
            users_data = []
            for user in self.users.values():
                user_data = {
                    'user_id': user.user_id,
                    'username': user.username,
                    'email': user.email,
                    'password_hash': user.password_hash,
                    'salt': user.salt.hex(),
                    'role': user.role,
                    'permissions': user.permissions,
                    'is_active': user.is_active,
                    'created_at': user.created_at.isoformat(),
                    'last_login': user.last_login.isoformat(),
                    'failed_attempts': user.failed_attempts,
                    'locked_until': user.locked_until.isoformat() if user.locked_until else None
                }
                users_data.append(user_data)
            
            with open(users_file, 'w') as f:
                json.dump(users_data, f, indent=2)
            
            logger.info(f"Saved {len(self.users)} users to storage")
        except Exception as e:
            logger.error(f"Error saving users: {e}")
    
    def create_user(self, username: str, email: str, password: str, 
                   role: str = "user", permissions: List[str] = None) -> str:
        """Create a new user"""
        # Check if username already exists
        for user in self.users.values():
            if user.username == username:
                raise ValueError(f"Username already exists: {username}")
        
        # Check if email already exists
        for user in self.users.values():
            if user.email == email:
                raise ValueError(f"Email already exists: {email}")
        
        # Generate user ID
        user_id = f"user_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{secrets.token_hex(8)}"
        
        # Hash password
        password_hash, salt = self._hash_password(password)
        
        # Set default permissions
        if permissions is None:
            permissions = self._get_default_permissions(role)
        
        # Create user
        user = User(
            user_id=user_id,
            username=username,
            email=email,
            password_hash=password_hash,
            salt=salt,
            role=role,
            permissions=permissions,
            is_active=True,
            created_at=datetime.now(),
            last_login=datetime.now(),
            failed_attempts=0,
            locked_until=None
        )
        
        # Store user
        self.users[user_id] = user
        
        # Save to storage
        self._save_users()
        
        logger.info(f"Created user: {username} ({user_id})")
        return user_id
    
    def authenticate_user(self, username: str, password: str, 
                         ip_address: str = "", user_agent: str = "") -> AuthResult:
        """Authenticate a user"""
        try:
            # Find user by username
            user = None
            for u in self.users.values():
                if u.username == username:
                    user = u
                    break
            
            if not user:
                return AuthResult(
                    success=False,
                    user=None,
                    session=None,
                    token="",
                    message="Invalid username or password",
                    timestamp=datetime.now()
                )
            
            # Check if user is active
            if not user.is_active:
                return AuthResult(
                    success=False,
                    user=None,
                    session=None,
                    token="",
                    message="User account is disabled",
                    timestamp=datetime.now()
                )
            
            # Check if user is locked
            if user.locked_until and user.locked_until > datetime.now():
                return AuthResult(
                    success=False,
                    user=None,
                    session=None,
                    token="",
                    message=f"Account locked until {user.locked_until}",
                    timestamp=datetime.now()
                )
            
            # Verify password
            if not self._verify_password(password, user.password_hash, user.salt):
                # Increment failed attempts
                user.failed_attempts += 1
                
                # Lock account if max attempts exceeded
                if user.failed_attempts >= self.max_failed_attempts:
                    user.locked_until = datetime.now() + timedelta(minutes=self.lockout_duration_minutes)
                    self._save_users()
                    
                    return AuthResult(
                        success=False,
                        user=None,
                        session=None,
                        token="",
                        message=f"Account locked due to too many failed attempts",
                        timestamp=datetime.now()
                    )
                
                self._save_users()
                
                return AuthResult(
                    success=False,
                    user=None,
                    session=None,
                    token="",
                    message="Invalid username or password",
                    timestamp=datetime.now()
                )
            
            # Reset failed attempts on successful login
            user.failed_attempts = 0
            user.locked_until = None
            user.last_login = datetime.now()
            self._save_users()
            
            # Create session
            session = self._create_session(user.user_id, ip_address, user_agent)
            
            # Generate JWT token
            token = self._generate_jwt_token(user, session)
            
            return AuthResult(
                success=True,
                user=user,
                session=session,
                token=token,
                message="Authentication successful",
                timestamp=datetime.now()
            )
            
        except Exception as e:
            logger.error(f"Authentication error: {e}")
            return AuthResult(
                success=False,
                user=None,
                session=None,
                token="",
                message="Authentication error",
                timestamp=datetime.now()
            )
    
    def verify_token(self, token: str) -> Optional[User]:
        """Verify JWT token and return user"""
        try:
            # Decode JWT token
            payload = jwt.decode(token, self.jwt_secret, algorithms=['HS256'])
            
            # Check if token is expired
            if datetime.fromtimestamp(payload['exp']) < datetime.now():
                return None
            
            # Get user
            user_id = payload['user_id']
            if user_id not in self.users:
                return None
            
            user = self.users[user_id]
            
            # Check if user is still active
            if not user.is_active:
                return None
            
            # Check if session is still valid
            session_id = payload['session_id']
            if session_id not in self.sessions:
                return None
            
            session = self.sessions[session_id]
            if not session.is_active or session.expires_at < datetime.now():
                return None
            
            return user
            
        except jwt.InvalidTokenError:
            return None
        except Exception as e:
            logger.error(f"Token verification error: {e}")
            return None
    
    def logout(self, token: str) -> bool:
        """Logout user by invalidating session"""
        try:
            # Decode JWT token
            payload = jwt.decode(token, self.jwt_secret, algorithms=['HS256'])
            
            # Get session
            session_id = payload['session_id']
            if session_id in self.sessions:
                session = self.sessions[session_id]
                session.is_active = False
                logger.info(f"User logged out: {session.user_id}")
                return True
            
            return False
            
        except jwt.InvalidTokenError:
            return False
        except Exception as e:
            logger.error(f"Logout error: {e}")
            return False
    
    def change_password(self, user_id: str, current_password: str, new_password: str) -> bool:
        """Change user password"""
        if user_id not in self.users:
            return False
        
        user = self.users[user_id]
        
        # Verify current password
        if not self._verify_password(current_password, user.password_hash, user.salt):
            return False
        
        # Hash new password
        new_password_hash, new_salt = self._hash_password(new_password)
        
        # Update user
        user.password_hash = new_password_hash
        user.salt = new_salt
        user.failed_attempts = 0
        user.locked_until = None
        
        # Save to storage
        self._save_users()
        
        logger.info(f"Password changed for user: {user.username}")
        return True
    
    def reset_password(self, email: str) -> bool:
        """Reset user password (send reset email)"""
        # Find user by email
        user = None
        for u in self.users.values():
            if u.email == email:
                user = u
                break
        
        if not user:
            return False
        
        # Generate reset token
        reset_token = secrets.token_urlsafe(32)
        reset_expiry = datetime.now() + timedelta(hours=1)
        
        # Store reset token (in real implementation, this would be in database)
        # For now, we'll just log it
        logger.info(f"Password reset token for {email}: {reset_token}")
        logger.info(f"Reset token expires: {reset_expiry}")
        
        return True
    
    def has_permission(self, user: User, permission: str) -> bool:
        """Check if user has specific permission"""
        return permission in user.permissions
    
    def has_role(self, user: User, role: str) -> bool:
        """Check if user has specific role"""
        return user.role == role
    
    def get_user_by_id(self, user_id: str) -> Optional[User]:
        """Get user by ID"""
        return self.users.get(user_id)
    
    def get_user_by_username(self, username: str) -> Optional[User]:
        """Get user by username"""
        for user in self.users.values():
            if user.username == username:
                return user
        return None
    
    def list_users(self) -> List[User]:
        """List all users"""
        return list(self.users.values())
    
    def update_user(self, user_id: str, **kwargs) -> bool:
        """Update user information"""
        if user_id not in self.users:
            return False
        
        user = self.users[user_id]
        
        # Update allowed fields
        allowed_fields = ['email', 'role', 'permissions', 'is_active']
        for field, value in kwargs.items():
            if field in allowed_fields:
                setattr(user, field, value)
        
        # Save to storage
        self._save_users()
        
        logger.info(f"Updated user: {user.username}")
        return True
    
    def delete_user(self, user_id: str) -> bool:
        """Delete user"""
        if user_id not in self.users:
            return False
        
        user = self.users[user_id]
        
        # Remove user
        del self.users[user_id]
        
        # Invalidate all sessions for this user
        for session in self.sessions.values():
            if session.user_id == user_id:
                session.is_active = False
        
        # Save to storage
        self._save_users()
        
        logger.info(f"Deleted user: {user.username}")
        return True
    
    def _hash_password(self, password: str) -> Tuple[str, bytes]:
        """Hash password using bcrypt"""
        salt = bcrypt.gensalt()
        password_hash = bcrypt.hashpw(password.encode(), salt)
        return password_hash.decode(), salt
    
    def _verify_password(self, password: str, password_hash: str, salt: bytes) -> bool:
        """Verify password using bcrypt"""
        try:
            return bcrypt.checkpw(password.encode(), password_hash.encode())
        except Exception:
            return False
    
    def _get_default_permissions(self, role: str) -> List[str]:
        """Get default permissions for role"""
        if role == "admin":
            return ["read", "write", "delete", "admin", "backup", "restore", "configure"]
        elif role == "backup_admin":
            return ["read", "write", "backup", "restore", "configure"]
        elif role == "backup_user":
            return ["read", "write", "backup", "restore"]
        elif role == "readonly":
            return ["read"]
        else:
            return ["read"]
    
    def _create_session(self, user_id: str, ip_address: str, user_agent: str) -> Session:
        """Create a new session"""
        session_id = f"session_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{secrets.token_hex(8)}"
        
        session = Session(
            session_id=session_id,
            user_id=user_id,
            token="",  # Will be set by JWT generation
            created_at=datetime.now(),
            expires_at=datetime.now() + timedelta(hours=self.jwt_expiry_hours),
            ip_address=ip_address,
            user_agent=user_agent,
            is_active=True
        )
        
        self.sessions[session_id] = session
        return session
    
    def _generate_jwt_token(self, user: User, session: Session) -> str:
        """Generate JWT token for user session"""
        payload = {
            'user_id': user.user_id,
            'username': user.username,
            'role': user.role,
            'permissions': user.permissions,
            'session_id': session.session_id,
            'iat': datetime.now(),
            'exp': session.expires_at
        }
        
        token = jwt.encode(payload, self.jwt_secret, algorithm='HS256')
        
        # Update session with token
        session.token = token
        
        return token
    
    def cleanup_expired_sessions(self):
        """Clean up expired sessions"""
        current_time = datetime.now()
        expired_sessions = []
        
        for session_id, session in self.sessions.items():
            if session.expires_at < current_time:
                expired_sessions.append(session_id)
        
        for session_id in expired_sessions:
            del self.sessions[session_id]
        
        if expired_sessions:
            logger.info(f"Cleaned up {len(expired_sessions)} expired sessions")

def main():
    """Main entry point for authentication testing"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grimm Authentication Manager")
    parser.add_argument("--action", choices=["create-user", "authenticate", "list-users"], required=True)
    parser.add_argument("--username", help="Username")
    parser.add_argument("--email", help="Email")
    parser.add_argument("--password", help="Password")
    parser.add_argument("--role", choices=["admin", "backup_admin", "backup_user", "readonly"], default="backup_user")
    
    args = parser.parse_args()
    
    # Initialize authentication manager
    auth_manager = AuthenticationManager()
    
    if args.action == "create-user":
        if not all([args.username, args.email, args.password]):
            print("Username, email, and password required for user creation")
            return
        
        try:
            user_id = auth_manager.create_user(args.username, args.email, args.password, args.role)
            print(f"User created successfully: {user_id}")
        except ValueError as e:
            print(f"Error creating user: {e}")
    
    elif args.action == "authenticate":
        if not all([args.username, args.password]):
            print("Username and password required for authentication")
            return
        
        result = auth_manager.authenticate_user(args.username, args.password)
        if result.success:
            print(f"Authentication successful for user: {result.user.username}")
            print(f"Token: {result.token[:50]}...")
        else:
            print(f"Authentication failed: {result.message}")
    
    elif args.action == "list-users":
        users = auth_manager.list_users()
        print(f"Total users: {len(users)}")
        for user in users:
            print(f"- {user.username} ({user.email}) - {user.role}")

if __name__ == "__main__":
    main() 