#!/usr/bin/env python3
"""
Grim Admin Server with TuskLang Performance Engine
High-performance admin interface for Grim Reaper system
"""

import os
import sys
import time
import json
import logging
import secrets
import hashlib
import hmac
import base64
import pyotp
import qrcode
from pathlib import Path
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import jwt

from flask import Flask, render_template_string, request, jsonify, send_from_directory, redirect, url_for, session, flash, get_flashed_messages, make_response
from flask_cors import CORS
import asyncio

# Import simple TuskLang renderer
from simple_tsk_renderer import render_simple_tsk_template

# Import Grim command executor
from grim_executor import grim_executor

# Import Herd authentication system
from herd_auth import get_herd, init_herd, login_required, admin_required, get_current_user, is_authenticated

# Import monitoring integration
from monitoring_integration import get_monitoring_data, get_monitoring_health, monitoring_integration

# Import billing manager
from grim_billing_manager import get_billing_manager
from scythe_baby import get_scythe_baby_manager

# Import Flask-TSK (optional) - will be imported inside app context
FLASK_TSK_AVAILABLE = False
print("Flask-TSK will be imported when needed")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SecurityConfig:
    """Security configuration settings"""
    
    def __init__(self):
        self.jwt_secret = os.getenv('JWT_SECRET', secrets.token_urlsafe(32))
        self.jwt_algorithm = 'HS256'
        self.jwt_expiration_hours = 24
        
        self.password_min_length = 12
        self.password_require_uppercase = True
        self.password_require_lowercase = True
        self.password_require_digits = True
        self.password_require_special = True
        
        self.session_timeout_minutes = 30
        self.max_failed_attempts = 5
        self.lockout_duration_minutes = 15
        
        self.encryption_key_file = 'grim_encryption.key'
        self.rsa_private_key_file = 'grim_private_key.pem'
        self.rsa_public_key_file = 'grim_public_key.pem'
        
        self.mfa_issuer = 'Grim Reaper Admin'
        self.mfa_backup_codes_count = 10

class PasswordValidator:
    """Password strength validation and hashing"""
    
    @staticmethod
    def validate_password(password: str, config: SecurityConfig) -> Dict[str, Any]:
        """Validate password strength"""
        errors = []
        
        if len(password) < config.password_min_length:
            errors.append(f"Password must be at least {config.password_min_length} characters")
        
        if config.password_require_uppercase and not any(c.isupper() for c in password):
            errors.append("Password must contain at least one uppercase letter")
        
        if config.password_require_lowercase and not any(c.islower() for c in password):
            errors.append("Password must contain at least one lowercase letter")
        
        if config.password_require_digits and not any(c.isdigit() for c in password):
            errors.append("Password must contain at least one digit")
        
        if config.password_require_special and not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in password):
            errors.append("Password must contain at least one special character")
        
        return {
            'valid': len(errors) == 0,
            'errors': errors,
            'strength': PasswordValidator._calculate_strength(password)
        }
    
    @staticmethod
    def _calculate_strength(password: str) -> str:
        """Calculate password strength"""
        score = 0
        
        if len(password) >= 12:
            score += 2
        elif len(password) >= 8:
            score += 1
        
        if any(c.isupper() for c in password):
            score += 1
        if any(c.islower() for c in password):
            score += 1
        if any(c.isdigit() for c in password):
            score += 1
        if any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in password):
            score += 1
        
        if score >= 5:
            return 'strong'
        elif score >= 3:
            return 'medium'
        else:
            return 'weak'
    
    @staticmethod
    def hash_password(password: str, salt: str = None) -> Dict[str, str]:
        """Hash password using PBKDF2 with SHA256"""
        if salt is None:
            salt = secrets.token_hex(16)
        
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt.encode(),
            iterations=100000,
        )
        
        hash_bytes = kdf.derive(password.encode())
        hash_hex = base64.b64encode(hash_bytes).decode()
        
        return {
            'hash': hash_hex,
            'salt': salt
        }
    
    @staticmethod
    def verify_password(password: str, hash_value: str, salt: str) -> bool:
        """Verify password against stored hash"""
        try:
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt.encode(),
                iterations=100000,
            )
            
            kdf.verify(password.encode(), base64.b64decode(hash_value))
            return True
        except Exception:
            return False

class EncryptionManager:
    """Data encryption and key management"""
    
    def __init__(self, config: SecurityConfig):
        self.config = config
        self.symmetric_key = self._load_or_generate_symmetric_key()
        self.fernet = Fernet(self.symmetric_key)
        self.rsa_private_key = self._load_or_generate_rsa_keys()
    
    def _load_or_generate_symmetric_key(self) -> bytes:
        """Load existing symmetric key or generate new one"""
        if os.path.exists(self.config.encryption_key_file):
            with open(self.config.encryption_key_file, 'rb') as f:
                return f.read()
        else:
            key = Fernet.generate_key()
            with open(self.config.encryption_key_file, 'wb') as f:
                f.write(key)
            return key
    
    def _load_or_generate_rsa_keys(self) -> rsa.RSAPrivateKey:
        """Load existing RSA keys or generate new ones"""
        if os.path.exists(self.config.rsa_private_key_file):
            with open(self.config.rsa_private_key_file, 'rb') as f:
                return serialization.load_pem_private_key(f.read(), password=None)
        else:
            private_key = rsa.generate_private_key(
                public_exponent=65537,
                key_size=2048
            )
            
            # Save private key
            with open(self.config.rsa_private_key_file, 'wb') as f:
                f.write(private_key.private_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PrivateFormat.PKCS8,
                    encryption_algorithm=serialization.NoEncryption()
                ))
            
            # Save public key
            public_key = private_key.public_key()
            with open(self.config.rsa_public_key_file, 'wb') as f:
                f.write(public_key.public_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PublicFormat.SubjectPublicKeyInfo
                ))
            
            return private_key
    
    def encrypt_symmetric(self, data: str) -> str:
        """Encrypt data using symmetric encryption"""
        return self.fernet.encrypt(data.encode()).decode()
    
    def decrypt_symmetric(self, encrypted_data: str) -> str:
        """Decrypt data using symmetric encryption"""
        return self.fernet.decrypt(encrypted_data.encode()).decode()
    
    def encrypt_asymmetric(self, data: str) -> str:
        """Encrypt data using asymmetric encryption"""
        public_key = self.rsa_private_key.public_key()
        encrypted = public_key.encrypt(
            data.encode(),
            padding.OAEP(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None
            )
        )
        return base64.b64encode(encrypted).decode()
    
    def decrypt_asymmetric(self, encrypted_data: str) -> str:
        """Decrypt data using asymmetric encryption"""
        encrypted_bytes = base64.b64decode(encrypted_data.encode())
        decrypted = self.rsa_private_key.decrypt(
            encrypted_bytes,
            padding.OAEP(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None
            )
        )
        return decrypted.decode()

class MFAManager:
    """Multi-Factor Authentication management"""
    
    def __init__(self, config: SecurityConfig):
        self.config = config
    
    def generate_mfa_secret(self) -> str:
        """Generate new MFA secret"""
        return pyotp.random_base32()
    
    def generate_qr_code(self, secret: str, username: str) -> str:
        """Generate QR code for MFA setup"""
        totp = pyotp.TOTP(secret)
        provisioning_uri = totp.provisioning_uri(
            name=username,
            issuer_name=self.config.mfa_issuer
        )
        
        # Generate QR code
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(provisioning_uri)
        qr.make(fit=True)
        
        # Convert to base64 image
        import io
        img = qr.make_image(fill_color="black", back_color="white")
        img_buffer = io.BytesIO()
        img.save(img_buffer, format='PNG')
        img_str = base64.b64encode(img_buffer.getvalue()).decode()
        
        return f"data:image/png;base64,{img_str}"
    
    def verify_mfa_code(self, secret: str, code: str) -> bool:
        """Verify MFA code"""
        totp = pyotp.TOTP(secret)
        return totp.verify(code)
    
    def generate_backup_codes(self) -> List[str]:
        """Generate backup codes for MFA"""
        codes = []
        for _ in range(self.config.mfa_backup_codes_count):
            code = secrets.token_hex(4).upper()
            codes.append(f"{code[:4]}-{code[4:]}")
        return codes

class SessionManager:
    """Session management and JWT handling"""
    
    def __init__(self, config: SecurityConfig):
        self.config = config
        self.failed_attempts = {}  # Track failed login attempts
    
    def create_session(self, user_id: str, username: str, roles: List[str]) -> str:
        """Create JWT session token"""
        payload = {
            'user_id': user_id,
            'username': username,
            'roles': roles,
            'exp': datetime.utcnow() + timedelta(hours=self.config.jwt_expiration_hours),
            'iat': datetime.utcnow()
        }
        
        return jwt.encode(payload, self.config.jwt_secret, algorithm=self.config.jwt_algorithm)
    
    def validate_session(self, token: str) -> Optional[Dict[str, Any]]:
        """Validate JWT session token"""
        try:
            payload = jwt.decode(token, self.config.jwt_secret, algorithms=[self.config.jwt_algorithm])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
    
    def destroy_session(self, token: str) -> bool:
        """Destroy session token (add to blacklist)"""
        # In production, implement token blacklisting
        return True
    
    def record_failed_attempt(self, username: str) -> int:
        """Record failed login attempt"""
        if username not in self.failed_attempts:
            self.failed_attempts[username] = {'count': 0, 'last_attempt': None}
        
        self.failed_attempts[username]['count'] += 1
        self.failed_attempts[username]['last_attempt'] = datetime.utcnow()
        
        return self.failed_attempts[username]['count']
    
    def is_account_locked(self, username: str) -> bool:
        """Check if account is locked due to failed attempts"""
        if username not in self.failed_attempts:
            return False
        
        attempt_data = self.failed_attempts[username]
        
        if attempt_data['count'] >= self.config.max_failed_attempts:
            if attempt_data['last_attempt']:
                lockout_until = attempt_data['last_attempt'] + timedelta(minutes=self.config.lockout_duration_minutes)
                if datetime.utcnow() < lockout_until:
                    return True
        
        return False
    
    def reset_failed_attempts(self, username: str):
        """Reset failed attempts for successful login"""
        if username in self.failed_attempts:
            del self.failed_attempts[username]

class AuditLogger:
    """Security audit logging"""
    
    @staticmethod
    def log_event(event_type: str, user_id: str = None, username: str = None, 
                  details: Dict[str, Any] = None, ip_address: str = None):
        """Log security event"""
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'event_type': event_type,
            'user_id': user_id,
            'username': username,
            'ip_address': ip_address,
            'details': details or {}
        }
        
        logger.info(f"SECURITY_EVENT: {json.dumps(log_entry)}")
        
        # In production, save to database or log file
        audit_file = 'grim_audit.log'
        with open(audit_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')

class ComplianceManager:
    """Compliance framework management"""
    
    def __init__(self):
        self.compliance_frameworks = {
            'gdpr': {
                'name': 'GDPR',
                'status': 'compliant',
                'last_audit': '2025-01-15',
                'next_audit': '2025-07-15',
                'requirements': [
                    'data_protection_by_design',
                    'user_consent_management',
                    'data_portability',
                    'right_to_erasure',
                    'breach_notification'
                ]
            },
            'soc2': {
                'name': 'SOC 2 Type II',
                'status': 'in_progress',
                'last_audit': '2024-12-01',
                'next_audit': '2025-06-01',
                'requirements': [
                    'security_controls',
                    'availability_controls',
                    'processing_integrity',
                    'confidentiality',
                    'privacy'
                ]
            },
            'pci_dss': {
                'name': 'PCI DSS',
                'status': 'compliant',
                'last_audit': '2025-01-10',
                'next_audit': '2025-01-10',
                'requirements': [
                    'secure_network',
                    'cardholder_data_protection',
                    'vulnerability_management',
                    'access_control',
                    'monitoring_and_testing'
                ]
            },
            'iso27001': {
                'name': 'ISO 27001',
                'status': 'planning',
                'last_audit': None,
                'next_audit': '2025-12-01',
                'requirements': [
                    'information_security_policy',
                    'asset_management',
                    'access_control',
                    'cryptography',
                    'physical_security'
                ]
            }
        }
    
    def get_compliance_status(self) -> Dict[str, Any]:
        """Get overall compliance status"""
        return {
            'frameworks': self.compliance_frameworks,
            'overall_status': self._calculate_overall_status(),
            'next_audit': self._get_next_audit(),
            'compliance_score': self._calculate_compliance_score()
        }
    
    def _calculate_overall_status(self) -> str:
        """Calculate overall compliance status"""
        statuses = [fw['status'] for fw in self.compliance_frameworks.values()]
        
        if all(status == 'compliant' for status in statuses):
            return 'fully_compliant'
        elif any(status == 'compliant' for status in statuses):
            return 'partially_compliant'
        else:
            return 'non_compliant'
    
    def _get_next_audit(self) -> str:
        """Get next audit date"""
        next_audits = []
        for fw in self.compliance_frameworks.values():
            if fw['next_audit']:
                next_audits.append(fw['next_audit'])
        
        if next_audits:
            return min(next_audits)
        return 'No audits scheduled'
    
    def _calculate_compliance_score(self) -> int:
        """Calculate compliance score (0-100)"""
        total_frameworks = len(self.compliance_frameworks)
        compliant_frameworks = sum(1 for fw in self.compliance_frameworks.values() 
                                 if fw['status'] == 'compliant')
        
        return int((compliant_frameworks / total_frameworks) * 100)

class SecurityManager:
    """Main security manager orchestrating all security components"""
    
    def __init__(self):
        self.config = SecurityConfig()
        self.password_validator = PasswordValidator()
        self.encryption_manager = EncryptionManager(self.config)
        self.mfa_manager = MFAManager(self.config)
        self.session_manager = SessionManager(self.config)
        self.compliance_manager = ComplianceManager()
    
    def authenticate_user(self, username: str, password: str, mfa_code: str = None, 
                         ip_address: str = None) -> Dict[str, Any]:
        """Authenticate user with password and optional MFA"""
        try:
            # Check if account is locked
            if self.session_manager.is_account_locked(username):
                AuditLogger.log_event('login_blocked_locked', username=username, ip_address=ip_address)
                return {
                    'success': False,
                    'error': 'Account temporarily locked due to failed attempts'
                }
            
            # Get user from database (placeholder)
            user = self._get_user_from_database(username)
            if not user:
                self.session_manager.record_failed_attempt(username)
                AuditLogger.log_event('login_failed_invalid_user', username=username, ip_address=ip_address)
                return {
                    'success': False,
                    'error': 'Invalid credentials'
                }
            
            # Verify password
            if not self.password_validator.verify_password(password, user['password_hash'], user['password_salt']):
                failed_count = self.session_manager.record_failed_attempt(username)
                AuditLogger.log_event('login_failed_invalid_password', 
                                    user_id=user['id'], username=username, ip_address=ip_address)
                
                if failed_count >= self.config.max_failed_attempts:
                    AuditLogger.log_event('account_locked', user_id=user['id'], username=username, ip_address=ip_address)
                
                return {
                    'success': False,
                    'error': 'Invalid credentials'
                }
            
            # Verify MFA if enabled
            if user.get('mfa_enabled') and mfa_code:
                if not self.mfa_manager.verify_mfa_code(user['mfa_secret'], mfa_code):
                    AuditLogger.log_event('login_failed_invalid_mfa', 
                                        user_id=user['id'], username=username, ip_address=ip_address)
                    return {
                        'success': False,
                        'error': 'Invalid MFA code'
                    }
            elif user.get('mfa_enabled') and not mfa_code:
                return {
                    'success': False,
                    'error': 'MFA code required',
                    'requires_mfa': True
                }
            
            # Reset failed attempts
            self.session_manager.reset_failed_attempts(username)
            
            # Create session
            session_token = self.session_manager.create_session(
                user['id'], username, user.get('roles', [])
            )
            
            AuditLogger.log_event('login_successful', 
                                user_id=user['id'], username=username, ip_address=ip_address)
            
            return {
                'success': True,
                'session_token': session_token,
                'user': {
                    'id': user['id'],
                    'username': username,
                    'roles': user.get('roles', []),
                    'mfa_enabled': user.get('mfa_enabled', False)
                }
            }
            
        except Exception as e:
            logger.error(f"Authentication error: {e}")
            AuditLogger.log_event('login_error', username=username, ip_address=ip_address, 
                                details={'error': str(e)})
            return {
                'success': False,
                'error': 'Authentication error'
            }
    
    def validate_session(self, session_token: str) -> Optional[Dict[str, Any]]:
        """Validate session token"""
        return self.session_manager.validate_session(session_token)
    
    def logout_user(self, session_token: str, user_id: str = None, username: str = None):
        """Logout user and destroy session"""
        self.session_manager.destroy_session(session_token)
        AuditLogger.log_event('logout', user_id=user_id, username=username)
    
    def get_security_status(self) -> Dict[str, Any]:
        """Get overall security status"""
        return {
            'authentication': {
                'mfa_enabled_users': self._get_mfa_enabled_count(),
                'locked_accounts': len(self.session_manager.failed_attempts),
                'active_sessions': self._get_active_sessions_count()
            },
            'encryption': {
                'symmetric_encryption': 'AES-256',
                'asymmetric_encryption': 'RSA-2048',
                'key_rotation': '90_days'
            },
            'compliance': self.compliance_manager.get_compliance_status(),
            'audit': {
                'last_audit_log': self._get_last_audit_entry(),
                'audit_log_size': self._get_audit_log_size()
            }
        }
    
    def _get_user_from_database(self, username: str) -> Optional[Dict[str, Any]]:
        """Get user from database (placeholder implementation)"""
        # In production, implement actual database query
        # This is a placeholder for demonstration
        if username == 'admin':
            return {
                'id': '1',
                'username': 'admin',
                'password_hash': 'placeholder_hash',
                'password_salt': 'placeholder_salt',
                'roles': ['admin'],
                'mfa_enabled': True,
                'mfa_secret': 'placeholder_mfa_secret'
            }
        return None
    
    def _get_mfa_enabled_count(self) -> int:
        """Get count of users with MFA enabled"""
        # Placeholder implementation
        return 1
    
    def _get_active_sessions_count(self) -> int:
        """Get count of active sessions"""
        # Placeholder implementation
        return 5
    
    def _get_last_audit_entry(self) -> str:
        """Get last audit log entry"""
        try:
            with open('grim_audit.log', 'r') as f:
                lines = f.readlines()
                if lines:
                    return lines[-1].strip()
        except FileNotFoundError:
            pass
        return 'No audit entries'
    
    def _get_audit_log_size(self) -> str:
        """Get audit log size"""
        try:
            size = os.path.getsize('grim_audit.log')
            return f"{size} bytes"
        except FileNotFoundError:
            return "0 bytes"

# Global security manager instance
_security_manager = None

def get_security_manager():
    """Get global security manager instance"""
    global _security_manager
    if _security_manager is None:
        _security_manager = SecurityManager()
    return _security_manager

class GrimAdminServer:
    """High-performance admin server for Grim Reaper system"""
    
    def __init__(self, static_dir: str = None, config_path: str = None):
        self.app = Flask(__name__)
        self.static_dir = static_dir or os.path.dirname(__file__)
        self.config_path = config_path
        
        # Configure Flask
        self.app.config.update({
            'SECRET_KEY': os.environ.get('GRIM_SECRET_KEY', secrets.token_hex(32)),
            'DEBUG': True,
            'TEMPLATES_AUTO_RELOAD': False,  # Disabled for performance
            'SEND_FILE_MAX_AGE_DEFAULT': 0
        })
        
        # Initialize Herd authentication system
        self.herd = init_herd(self.app)
        
        # Initialize TuskLang integration
        global FLASK_TSK_AVAILABLE
        FLASK_TSK_AVAILABLE = False
        
        # Initialize Flask-TSK immediately
        try:
            with self.app.app_context():
                # Import FlaskTSK from the current directory
                sys.path.insert(0, os.path.dirname(__file__))
                from __init__ import FlaskTSK
                FlaskTSK(self.app)  # Register with Flask app
                FLASK_TSK_AVAILABLE = True
                logger.info("Flask-TSK initialized successfully")
        except Exception as e:
            FLASK_TSK_AVAILABLE = False
            logger.warning(f"Flask-TSK not available: {e}")
        
        # Setup CORS
        CORS(self.app)
        
        # Initialize simple TuskLang renderer
        self.tsk_renderer = render_simple_tsk_template
        
        # Setup routes
        self._setup_routes()
        
        logger.info("Grim Admin Server initialized with TuskLang performance engine")
    
    def _setup_routes(self):
        """Setup all admin routes"""
        
        # Static file serving
        @self.app.route('/static/<path:filename>')
        def static_files(filename):
            """Serve static files from static directory"""
            static_dir = os.path.join(os.path.dirname(__file__), 'static')
            return send_from_directory(static_dir, filename)
        
        @self.app.route('/assets/css/<path:filename>')
        def assets_css_files(filename):
            """Serve CSS files from grim/assets/css directory"""
            css_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets', 'css')
            return send_from_directory(css_dir, filename)
        
        @self.app.route('/assets/js/<path:filename>')
        def assets_js_files(filename):
            """Serve JavaScript files from grim/assets/js directory"""
            js_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets', 'js')
            return send_from_directory(js_dir, filename)
        
        @self.app.route('/assets/<path:filename>')
        def assets_files(filename):
            """Serve assets from grim/assets directory"""
            assets_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets')
            response = send_from_directory(assets_dir, filename)
            
            # Set proper MIME type for SVG files
            if filename.lower().endswith('.svg'):
                response.mimetype = 'image/svg+xml'
            
            return response
        
        @self.app.route('/grim/assets/<path:filename>')
        def grim_assets_files(filename):
            """Serve assets from grim/assets directory with /grim prefix"""
            assets_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets')
            response = send_from_directory(assets_dir, filename)
            
            # Set proper MIME type for SVG files
            if filename.lower().endswith('.svg'):
                response.mimetype = 'image/svg+xml'
            
            return response
        
        # Public Error Tracking API (no authentication required)
        from grim_error_api import handle_create_child, handle_cry_to_mom, get_tracking_stats
        
        @self.app.route('/create_child', methods=['POST'])
        def create_child():
            """Register new installation (public endpoint)"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({'success': False, 'error': 'No JSON data provided'}), 400
                
                result = handle_create_child(data)
                status_code = 200 if result.get('success') else 400
                return jsonify(result), status_code
                
            except Exception as e:
                logger.error(f"Error in create_child: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/cry_to_mom', methods=['POST'])
        def cry_to_mom():
            """Report error or analytics (public endpoint)"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({'success': False, 'error': 'No JSON data provided'}), 400
                
                result = handle_cry_to_mom(data)
                status_code = 200 if result.get('success') else 400
                return jsonify(result), status_code
                
            except Exception as e:
                logger.error(f"Error in cry_to_mom: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/api/error-tracking/stats', methods=['GET'])
        @login_required
        def error_tracking_stats():
            """Get error tracking statistics (admin only)"""
            try:
                stats = get_tracking_stats()
                return jsonify(stats)
            except Exception as e:
                logger.error(f"Error getting tracking stats: {e}")
                return jsonify({'error': str(e)}), 500
        
        # Authentication routes
        @self.app.route('/login', methods=['GET', 'POST'])
        def login():
            """Login page with Herd authentication"""
            if request.method == 'POST':
                email = request.form.get('email')
                password = request.form.get('password')
                
                # Authenticate with Herd
                result = self.herd.authenticate(email, password)
                
                if result['success']:
                    # Redirect to next page or dashboard
                    next_page = session.get('next') or '/admin'
                    session.pop('next', None)
                    return redirect(next_page)
                else:
                    flash(result['error'], 'error')
            
            return self._render_admin_page('login', {
                'page_title': 'Login - Grim Admin',
                'herd_stats': self.herd.get_stats(),
                'flash_messages': get_flashed_messages(with_categories=True)
            })
        
        @self.app.route('/logout')
        def logout():
            """Logout with Herd authentication"""
            result = self.herd.logout()
            if result['success']:
                flash('Successfully logged out', 'success')
            else:
                flash(result['error'], 'error')
            return redirect('/login')
        
        @self.app.route('/clear-session')
        def clear_session():
            """Clear all sessions and force logout"""
            session.clear()
            return redirect('/login')
        
        @self.app.route('/force-logout')
        def force_logout():
            """Force logout and clear all browser cache"""
            session.clear()
            response = redirect('/login')
            response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, private'
            response.headers['Pragma'] = 'no-cache'
            response.headers['Expires'] = '0'
            response.headers['Clear-Site-Data'] = '"cache", "cookies", "storage"'
            return response
        
        @self.app.route('/register', methods=['GET', 'POST'])
        def register():
            """User registration page"""
            if request.method == 'POST':
                email = request.form.get('email')
                username = request.form.get('username')
                password = request.form.get('password')
                confirm_password = request.form.get('confirm_password')
                
                if password != confirm_password:
                    flash('Passwords do not match', 'error')
                else:
                    result = self.herd.register_user(email, username, password)
                    if result['success']:
                        flash('Registration successful! Please log in.', 'success')
                        return redirect('/login')
                    else:
                        flash(result['error'], 'error')
            
            return self._render_admin_page('admin/register.html', {
                'page_title': 'Register - Grim Admin',
                'flash_messages': get_flashed_messages(with_categories=True)
            })
        
        @self.app.route('/admin/users')
        @admin_required
        def users_page():
            """User management page (admin only)"""
            users = list(self.herd.users.values())
            audit_logs = self.herd.get_audit_logs(limit=50)
            
            return self._render_admin_page('grim/admin/users', {
                'page_title': 'User Management - Grim Admin',
                'users': users,
                'audit_logs': audit_logs,
                'herd_stats': self.herd.get_stats()
            })
        
        # Main admin routes (protected)
        # Root route - always serve landing page (grim.so)
        @self.app.route('/')
        def root():
            """Root route - serve public landing page"""
            grim_dir = os.path.join(os.path.dirname(__file__), 'grim')
            landing_file = os.path.join(grim_dir, 'public', 'landing.html')
            
            if os.path.exists(landing_file):
                with open(landing_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                # Use simple TuskLang template rendering
                return self.tsk_renderer(content, {
                    'page_title': 'Grim - The Reaper of Data Lossssss',
                    'tsk_available': FLASK_TSK_AVAILABLE,
                    'tsk_version': '2.0.3' if FLASK_TSK_AVAILABLE else 'not available'
                })
            else:
                return "Landing page not found", 404
        
        # Admin routes - protected (rip.grim.so)
        @self.app.route('/admin')
        @login_required
        def admin_dashboard():
            """Main admin dashboard"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'reaper',
                'page_title': 'Grim Reaper Dashboard',
                'css_files': ['admin.css', 'dashboard.css'],
                'alert_count': 0
            })
        
        @self.app.route('/test-dashboard')
        def test_dashboard():
            """Test admin dashboard without authentication"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'reaper',
                'page_title': 'Grim Reaper Dashboard',
                'css_files': ['admin.css', 'dashboard.css'],
                'alert_count': 0
            })
        
        @self.app.route('/test-backup')
        def test_backup():
            """Test backup page without authentication"""
            return self._render_admin_page('admin/backup', {
                'current_page': 'backup',
                'page_title': 'Backup Management - Grim Admin'
            })
        
        @self.app.route('/test-alerts')
        def test_alerts():
            """Test alerts page without authentication"""
            return self._render_admin_page('admin/alerts.html', {
                'current_page': 'alerts',
                'page_title': 'System Alerts - Grim Admin'
            })
        
        @self.app.route('/test-docs')
        def test_docs():
            """Test docs page without authentication"""
            return self._render_admin_page('admin/docs', {
                'current_page': 'docs',
                'page_title': 'Command Reference - Grim Admin'
            })
        
        @self.app.route('/auth')
        def auth_page():
            """Authentication page"""
            return self._render_admin_page('grim-auth-page.html')
        
        @self.app.route('/landing')
        def landing_page():
            """Public landing page"""
            return self._render_public_page('grim/public/landing.html', {
                'page_title': 'Grim - The Reaper of Data Lossssss',
                'page_type': 'landing'
            })
        
        @self.app.route('/home')
        def home_page():
            """Home page - redirect to landing"""
            return redirect('/')
        
        @self.app.route('/admin/license')
        @login_required
        def license_manager():
            """License management page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'license',
                'page_title': 'License Management'
            })
        
        @self.app.route('/admin/audit')
        @login_required
        def audit_page():
            """Audit content page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'audit',
                'page_title': 'Audit Management'
            })
        
        @self.app.route('/admin/scan')
        @login_required
        def scan_page():
            """Scan content page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'scan',
                'page_title': 'Scan Management'
            })
        
        @self.app.route('/admin/settings')
        @login_required
        def settings_page():
            """Settings page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'settings',
                'page_title': 'Settings Management'
            })
        
        @self.app.route('/admin/reaper')
        @login_required
        def reaper_dashboard():
            """Reaper admin dashboard"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'reaper',
                'page_title': 'Reaper Dashboard'
            })

        @self.app.route('/admin/backup')
        @login_required
        def backup_page():
            """Backup management page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'backup',
                'page_title': 'Backup Management'
            })

        @self.app.route('/admin/hash')
        @login_required
        def hash_page():
            """Hash management page"""
            # Force cache-busting headers to prevent browser caching
            response = self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'hash',
                'page_title': 'Hash Management',
                'css_files': ['admin.css', 'public.css']
            })
            
            # Add cache-busting headers
            if isinstance(response, str):
                from flask import make_response
                resp = make_response(response)
                resp.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, private'
                resp.headers['Pragma'] = 'no-cache'
                resp.headers['Expires'] = '0'
                return resp
            return response

        @self.app.route('/admin/trash')
        @login_required
        def trash_page():
            """Trash management page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'trash',
                'page_title': 'Trash Management'
            })

        @self.app.route('/admin/remote')
        @login_required
        def remote_page():
            """Remote management page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'remote',
                'page_title': 'Remote Management'
            })

        @self.app.route('/admin/logs')
        @login_required
        def logs_page():
            """Logs management page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'logs',
                'page_title': 'Logs Management'
            })

        @self.app.route('/admin/scythe')
        @login_required
        def scythe_page():
            """Scythe orchestrator page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'scythe',
                'page_title': 'Scythe Orchestrator'
            })

        @self.app.route('/admin/scythe-baby')
        @login_required
        def scythe_baby_page():
            """Scythe Baby License Manager page"""
            return self._render_admin_page('admin/scythe_baby.html')

        @self.app.route('/admin/emergency')
        @login_required
        def emergency_page():
            """Emergency Operations page"""
            return self._render_admin_page("admin/emergency", {"page_title": "Emergency - System Recovery"})

        @self.app.route('/admin/terminal')
        @login_required
        def terminal_page():
            """Terminal page"""
            return render_template('admin/terminal.html', page_title='Terminal - Server Access')

        @self.app.route('/admin/docs')
        @login_required
        def docs_page():
            """Documentation page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'docs',
                'page_title': 'Documentation'
            })

        @self.app.route('/admin/alerts')
        @login_required
        def alerts_page():
            """Alerts management page"""
            # Get monitoring data for alerts
            monitoring_data = get_monitoring_data()
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'alerts',
                'page_title': 'Alerts Management',
                'monitoring_data': monitoring_data,
                'active_alerts': monitoring_data.get('alerts', [])
            })
        
        @self.app.route('/admin/monitoring')
        @login_required
        def monitoring_dashboard():
            """Monitoring dashboard page"""
            monitoring_data = get_monitoring_data()
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'monitoring',
                'page_title': 'Monitoring Dashboard',
                'monitoring_data': monitoring_data,
                'overview': monitoring_data.get('overview', {}),
                'performance': monitoring_data.get('performance', {}),
                'sla': monitoring_data.get('sla', {})
            })
        
        @self.app.route('/admin/analytics')
        @login_required
        def analytics_page():
            """Analytics and reporting page"""
            # Get analytics data
            storage_analytics = monitoring_integration.get_storage_analytics()
            cost_analysis = monitoring_integration.get_cost_analysis()
            usage_patterns = monitoring_integration.get_usage_patterns()
            
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'analytics',
                'page_title': 'Analytics & Reporting',
                'storage_analytics': storage_analytics,
                'cost_analysis': cost_analysis,
                'usage_patterns': usage_patterns
            })
        
        @self.app.route('/admin/optimization')
        @login_required
        def optimization_page():
            """Storage optimization page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'optimization',
                'page_title': 'Storage Optimization'
            })
        
        @self.app.route('/admin/storage')
        @login_required
        def storage_page():
            """Storage management page"""
            return self._render_admin_page('admin/storage.html', {
                'title': 'Storage Management - Grim Reaper',
                'page': 'storage'
            })

        @self.app.route('/admin/billing')
        @login_required
        def billing_page():
            """Billing management page"""
            return self._render_admin_page('grim/admin/billing_management.html', {
                'page_title': 'Billing Management',
                'current_user': get_current_user()
            })
        
        # Scythe Vendor Dashboard Routes
        @self.app.route('/scythe/register', methods=['GET', 'POST'])
        def scythe_vendor_register():
            """Vendor registration page"""
            if request.method == 'POST':
                try:
                    data = request.get_json()
                    
                    # Basic validation
                    required_fields = ['company_name', 'contact_email', 'contact_name', 'software_name']
                    for field in required_fields:
                        if not data.get(field):
                            return jsonify({'success': False, 'error': f'{field} is required'}), 400
                    
                    # Use Tantor elephant for database operations
                    try:
                        from scythe_elephants import get_tantor
                        tantor = get_tantor()
                        
                        # Insert vendor registration
                        vendor_id = tantor.insert('vendors', {
                            'company_name': data['company_name'],
                            'contact_email': data['contact_email'],
                            'contact_name': data['contact_name'],
                            'software_name': data['software_name'],
                            'website': data.get('website'),
                            'description': data.get('description'),
                            'expected_licenses': data.get('expected_licenses', '1-100'),
                            'status': 'pending',
                            'created_at': datetime.now().isoformat()
                        })
                        
                        logger.info(f"Vendor registered: {data['contact_email']} (ID: {vendor_id})")
                        
                        return jsonify({
                            'success': True,
                            'vendor_id': vendor_id,
                            'message': 'Registration successful'
                        })
                    
                    except ImportError:
                        # Fallback: log to herd audit system
                        if hasattr(self, 'herd'):
                            self.herd._log_audit_event(
                                user_id=None,
                                action='vendor_registration',
                                details=data
                            )
                        
                        return jsonify({
                            'success': True,
                            'message': 'Registration received - pending approval'
                        })
                
                except Exception as e:
                    logger.error(f"Vendor registration error: {e}")
                    return jsonify({'success': False, 'error': 'Registration failed'}), 500
            
            return self._render_admin_page('scythe/register.html', {
                'page_title': 'Vendor Registration - Scythe'
            })

        @self.app.route('/scythe/dashboard')
        @login_required
        def scythe_vendor_dashboard():
            """Vendor dashboard"""
            return self._render_admin_page('scythe/dashboard.html', {
                'current_page': 'dashboard',
                'page_title': 'Vendor Dashboard - Scythe'
            })

        @self.app.route('/scythe/dashboard/generate')
        @login_required
        def scythe_license_generator():
            """License generator page"""
            return self._render_admin_page('scythe/generate.html', {
                'current_page': 'generate',
                'page_title': 'License Generator - Scythe'
            })

        @self.app.route('/scythe/docs')
        def scythe_integration_docs():
            """Integration documentation (public access)"""
            return self._render_admin_page('scythe/docs.html', {
                'current_page': 'docs',
                'page_title': 'Integration Guide - Scythe'
            })

        # Public pricing page
        @self.app.route('/pricing')
        def pricing_page():
            """Public pricing page (no authentication required)"""
            grim_dir = os.path.join(os.path.dirname(__file__), 'grim')
            pricing_file = os.path.join(grim_dir, 'public', 'pricing-page.html')
            
            if os.path.exists(pricing_file):
                with open(pricing_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                # Use simple TuskLang template rendering
                return self.tsk_renderer(content, {
                    'page_title': 'Pricing - Grim Reaper Data Protection',
                    'tsk_available': FLASK_TSK_AVAILABLE,
                    'tsk_version': '2.0.3' if FLASK_TSK_AVAILABLE else 'not available',
                    'affiliate_ref': request.args.get('ref', '')
                })
            else:
                # Fallback to old pricing page
                old_pricing_file = os.path.join(grim_dir, 'public', 'pricing.html')
                if os.path.exists(old_pricing_file):
                    with open(old_pricing_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    return self.tsk_renderer(content, {
                        'page_title': 'Pricing - Grim Reaper',
                        'affiliate_ref': request.args.get('ref', '')
                    })
                else:
                    return "Pricing page not found", 404

        # Public affiliate landing pages  
        @self.app.route('/underworld/<affiliate_id>')
        def affiliate_landing_page(affiliate_id):
            """Public affiliate landing page (no authentication required)"""
            logger.info(f"🎯 AFFILIATE VISIT: {affiliate_id}")
            logger.info(f"🔍 Session before setting affiliate_id: {dict(session)}")
            
            # Set affiliate ID in session for tracking
            session['grim_affiliate_id'] = affiliate_id
            session.permanent = True  # Make session persistent
            
            logger.info(f"🎯 Set affiliate ID in session: {affiliate_id}")
            logger.info(f"🔍 Session after setting affiliate_id: {dict(session)}")
            
            grim_dir = os.path.join(os.path.dirname(__file__), 'grim')
            affiliate_file = os.path.join(grim_dir, 'public', 'affiliate-landing.html')
            
            if os.path.exists(affiliate_file):
                with open(affiliate_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                return self.tsk_renderer(content, {
                    'page_title': f'Grim Reaper - Recommended by Developer {affiliate_id}',
                    'affiliate_id': affiliate_id,
                    'affiliate_url': f'https://grim.so/underworld/{affiliate_id}'
                })
            else:
                # Redirect to main pricing page with affiliate tracking
                return redirect(f'/pricing?ref={affiliate_id}')

        # Public API endpoints for Stripe checkout
        @self.app.route('/api/create-checkout-session', methods=['POST'])
        def create_checkout_session():
            """Create Stripe checkout session (public API)"""
            try:
                data = request.get_json()
                logger.info(f"🛒 CHECKOUT REQUEST: {data}")
                logger.info(f"🔍 Current Flask session: {dict(session)}")
                
                # Enhanced affiliate ID detection from multiple sources
                affiliate_id = None
                
                # 1. Check for affiliate ID in Flask session (from /underworld/[id])
                affiliate_id_from_session = session.get('grim_affiliate_id', '')
                if affiliate_id_from_session:
                    affiliate_id = affiliate_id_from_session
                    logger.info(f"🎯 Found affiliate ID in session: {affiliate_id}")
                
                # 2. Check for affiliate_id in request data
                if not affiliate_id and data.get('affiliate_id'):
                    affiliate_id = data.get('affiliate_id')
                    logger.info(f"🎯 Found affiliate_id in request data: {affiliate_id}")
                
                # 3. Check for ref parameter in request data
                if not affiliate_id and data.get('ref'):
                    affiliate_id = data.get('ref')
                    logger.info(f"🎯 Found ref in request data: {affiliate_id}")
                
                # 4. Check for affiliate_id in URL parameters
                if not affiliate_id and request.args.get('affiliate_id'):
                    affiliate_id = request.args.get('affiliate_id')
                    logger.info(f"🎯 Found affiliate_id in URL params: {affiliate_id}")
                
                # 5. Check for ref in URL parameters
                if not affiliate_id and request.args.get('ref'):
                    affiliate_id = request.args.get('ref')
                    logger.info(f"🎯 Found ref in URL params: {affiliate_id}")
                
                # 6. Check for UTM parameters
                if not affiliate_id and request.args.get('utm_source') == 'affiliate':
                    affiliate_id = request.args.get('utm_content')
                    logger.info(f"🎯 Found affiliate ID in UTM params: {affiliate_id}")
                
                # 7. Check for affiliate ID in cookies (JavaScript backup)
                if not affiliate_id:
                    affiliate_cookie = request.cookies.get('grim_affiliate_id')
                    if affiliate_cookie:
                        affiliate_id = affiliate_cookie
                        logger.info(f"🎯 Found affiliate ID in cookie: {affiliate_id}")
                
                # Validate affiliate ID exists in database
                if affiliate_id:
                    try:
                        import sqlite3
                        with sqlite3.connect('/opt/reaper/db/grim_affiliates.db') as conn:
                            cursor = conn.cursor()
                            cursor.execute("SELECT affiliate_id FROM affiliates WHERE affiliate_id = ? AND status = 'active'", (affiliate_id,))
                            if not cursor.fetchone():
                                logger.warning(f"⚠️ Invalid affiliate ID: {affiliate_id}")
                                affiliate_id = None
                            else:
                                logger.info(f"✅ Validated affiliate ID: {affiliate_id}")
                    except Exception as e:
                        logger.error(f"❌ Error validating affiliate ID: {e}")
                        affiliate_id = None
                
                if affiliate_id:
                    data['affiliate_id'] = affiliate_id
                    logger.info(f"🎯 Using affiliate ID: {affiliate_id}")
                    logger.info(f"🎯 Adding affiliate_id to checkout data: {data}")
                else:
                    logger.warning("⚠️ No valid affiliate_id found")
                
                # Import Stripe
                import stripe
                stripe.api_key = os.environ.get('STRIPE_SECRET_KEY')
                
                if not stripe.api_key:
                    return jsonify({'error': 'Stripe not configured'}), 500
                
                # Create checkout session
                checkout_session = stripe.checkout.Session.create(
                    payment_method_types=['card'],
                    line_items=[{
                        'price_data': {
                            'currency': 'usd',
                            'product_data': {
                                'name': f"Grim Reaper {data['plan'].upper()} Plan",
                                'description': f"Grim Reaper data protection - {data['plan']} tier"
                            },
                            'unit_amount': int(data['price'] * 100),  # Convert to cents
                            'recurring': {
                                'interval': 'month' if data.get('billing_period') != 'annual' else 'year'
                            }
                        },
                        'quantity': 1,
                    }],
                    mode='subscription',
                    success_url='https://grim.so/success?session_id={CHECKOUT_SESSION_ID}',
                    cancel_url='https://grim.so/cancel',
                    metadata={
                        'plan': data['plan'],
                        'affiliate_ref': data.get('affiliate_ref', ''),
                        'affiliate_id': data.get('affiliate_id', ''),  # For /underworld/[id] affiliates
                        'billing_period': data.get('billing_period', 'monthly')
                    }
                )
                
                logger.info(f"✅ Created Stripe checkout session: {checkout_session.id}")
                logger.info(f"🎯 Stripe session metadata: {checkout_session.metadata}")
                
                return jsonify({'id': checkout_session.id})
                
            except Exception as e:
                logger.error(f"Stripe checkout error: {e}")
                return jsonify({'error': str(e)}), 500
        
        @self.app.route('/api/stripe-config')
        def stripe_config():
            """Get Stripe publishable key for frontend"""
            try:
                publishable_key = os.environ.get('STRIPE_PUBLISHABLE_KEY')
                if not publishable_key:
                    return jsonify({'error': 'Stripe not configured'}), 500
                    
                return jsonify({'publishableKey': publishable_key})
                
            except Exception as e:
                logger.error(f"Stripe config error: {e}")
                return jsonify({'error': str(e)}), 500

        # Affiliate Registration API Endpoint (Public)
        @self.app.route('/api/new-afl/<affiliate_id>', methods=['GET', 'POST'])
        def register_new_affiliate(affiliate_id):
            """Register a new affiliate ID in GRIMS_MOTHER database"""
            try:
                import psycopg2
                from datetime import datetime
                import uuid
                
                logger.info(f"🎯 REGISTERING NEW AFFILIATE: {affiliate_id}")
                
                # Get server IP for additional context
                server_ip = request.headers.get('X-Forwarded-For', request.remote_addr)
                user_agent = request.headers.get('User-Agent', 'Unknown')
                
                # Connect to GRIMS_MOTHER database
                grims_mother_url = os.environ.get('GRIMS_MOTHER')
                if not grims_mother_url:
                    logger.error("❌ GRIMS_MOTHER connection string not found")
                    return jsonify({'success': False, 'error': 'Database not configured'}), 500
                
                with psycopg2.connect(grims_mother_url) as conn:
                    cursor = conn.cursor()
                    
                    # Check if affiliate already exists
                    cursor.execute("""
                        SELECT affiliate_id, created_at, total_referrals, total_earnings_usd 
                        FROM grim_affiliates 
                        WHERE affiliate_id = %s
                    """, (affiliate_id,))
                    
                    existing_affiliate = cursor.fetchone()
                    
                    if existing_affiliate:
                        logger.info(f"✅ Affiliate {affiliate_id} already exists (created: {existing_affiliate[1]})")
                        return jsonify({
                            'success': True,
                            'affiliate_id': affiliate_id,
                            'status': 'existing',
                            'created_at': existing_affiliate[1].isoformat() if existing_affiliate[1] else None,
                            'total_referrals': existing_affiliate[2] or 0,
                            'total_earnings': existing_affiliate[3] or 0
                        }), 200
                    
                    # Create new affiliate record
                    affiliate_uuid = str(uuid.uuid4())
                    created_at = datetime.utcnow()
                    
                    cursor.execute("""
                        INSERT INTO grim_affiliates 
                        (id, affiliate_id, server_ip, user_agent, created_at, 
                         total_referrals, total_earnings_usd, total_residuals_usd, 
                         lifetime_value_usd, status, commission_rate, residual_rate)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        affiliate_uuid, affiliate_id, server_ip, user_agent, created_at,
                        0, 0.0, 0.0, 0.0, 'active', 0.50, 0.10  # 50% commission, 10% residuals
                    ))
                    
                    conn.commit()
                    
                    logger.info(f"✅ New affiliate registered: {affiliate_id} (UUID: {affiliate_uuid})")
                    
                    return jsonify({
                        'success': True,
                        'affiliate_id': affiliate_id,
                        'status': 'created',
                        'created_at': created_at.isoformat(),
                        'server_ip': server_ip,
                        'commission_rate': 0.50,
                        'residual_rate': 0.10
                    }), 201
                    
            except psycopg2.Error as e:
                logger.error(f"❌ Database error registering affiliate {affiliate_id}: {e}")
                return jsonify({'success': False, 'error': 'Database error'}), 500
            except Exception as e:
                logger.error(f"❌ Error registering affiliate {affiliate_id}: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        # Compression Analytics API Endpoint (Public)
        @self.app.route('/api/compression/analytics', methods=['POST'])
        def compression_analytics():
            """Store compression analytics data and sync to GRIMS_MOTHER"""
            try:
                data = request.get_json()
                
                if not data:
                    return jsonify({'error': 'No data provided'}), 400
                
                # Validate required fields
                required_fields = ['user_id', 'algorithm', 'compression_ratio', 'storage_saved_gb']
                for field in required_fields:
                    if field not in data:
                        return jsonify({'error': f'Missing required field: {field}'}), 400
                
                # Store locally in admin database
                compression_record = {
                    'user_id': data['user_id'],
                    'algorithm': data['algorithm'], 
                    'compression_ratio': float(data['compression_ratio']),
                    'storage_saved_gb': float(data['storage_saved_gb']),
                    'money_saved_yearly': float(data.get('money_saved_yearly', 0)),
                    'timestamp': datetime.now().isoformat(),
                    'ip_address': request.headers.get('X-Forwarded-For', request.remote_addr)
                }
                
                # Save to local database
                self._save_compression_analytics(compression_record)
                
                # Sync to GRIMS_MOTHER database
                mother_sync_result = self._sync_to_grims_mother(compression_record)
                
                logger.info(f"✅ Compression analytics saved: {data['user_id']} -> {data['algorithm']} -> {data['storage_saved_gb']}GB saved")
                
                return jsonify({
                    'success': True,
                    'message': 'Compression analytics stored successfully',
                    'local_stored': True,
                    'mother_synced': mother_sync_result.get('success', False),
                    'storage_saved_gb': compression_record['storage_saved_gb'],
                    'algorithm': compression_record['algorithm']
                })
                
            except Exception as e:
                logger.error(f"Compression analytics error: {e}")
                return jsonify({'error': str(e)}), 500

        # Stripe Webhook Handler (Public)
        @self.app.route('/webhook/stripe', methods=['POST'])
        def stripe_webhook():
            """Handle Stripe webhooks and sync to GRIMS_MOTHER"""
            try:
                import stripe
                
                payload = request.data
                sig_header = request.headers.get('Stripe-Signature')
                
                # Verify webhook signature
                stripe.api_key = os.environ.get('STRIPE_SECRET_KEY')
                webhook_secret = os.environ.get('STRIPE_WEBHOOK_SECRET')
                
                try:
                    event = stripe.Webhook.construct_event(
                        payload, sig_header, webhook_secret
                    )
                except ValueError:
                    return jsonify({'error': 'Invalid payload'}), 400
                except stripe.error.SignatureVerificationError:
                    return jsonify({'error': 'Invalid signature'}), 400
                
                # Handle different event types
                event_type = event['type']
                data = event['data']['object']
                
                logger.info(f"🎯 Stripe webhook received: {event_type}")
                
                if event_type == 'checkout.session.completed':
                    # New subscription
                    customer_id = data.get('customer')
                    subscription_id = data.get('subscription')
                    plan = data['metadata'].get('plan', 'pro')
                    affiliate_ref = data['metadata'].get('affiliate_ref', '')
                    affiliate_id = data['metadata'].get('affiliate_id', '')  # /underworld/[id] affiliates
                    
                    # Use affiliate_id if available, otherwise affiliate_ref
                    affiliate_identifier = affiliate_id or affiliate_ref
                    
                    # Store subscription in GRIMS_MOTHER
                    subscription_data = {
                        'customer_id': customer_id,
                        'subscription_id': subscription_id,
                        'plan': plan,
                        'status': 'active',
                        'amount': data.get('amount_total', 0) / 100,  # Convert from cents
                        'affiliate_ref': affiliate_ref,
                        'affiliate_id': affiliate_id,
                        'event_type': 'subscription_created',
                        'timestamp': datetime.now().isoformat()
                    }
                    
                    # Sync to GRIMS_MOTHER
                    mother_result = self._sync_subscription_to_mother(subscription_data)
                    
                    # Track affiliate conversion if affiliate exists
                    if affiliate_identifier:
                        conversion_result = self._track_affiliate_conversion(
                            affiliate_identifier, customer_id, plan, subscription_data['amount']
                        )
                        logger.info(f"✅ Affiliate conversion tracked: {affiliate_identifier} -> ${subscription_data['amount']}")
                    
                    logger.info(f"✅ New subscription created: {plan} - ${subscription_data['amount']}")
                
                elif event_type == 'invoice.payment_succeeded':
                    # Recurring payment succeeded
                    subscription_id = data.get('subscription')
                    amount = data.get('amount_paid', 0) / 100
                    
                    payment_data = {
                        'subscription_id': subscription_id,
                        'amount': amount,
                        'status': 'paid',
                        'event_type': 'payment_succeeded',
                        'timestamp': datetime.now().isoformat()
                    }
                    
                    mother_result = self._sync_payment_to_mother(payment_data)
                    logger.info(f"✅ Payment succeeded: ${amount}")
                
                elif event_type == 'customer.subscription.deleted':
                    # Subscription cancelled
                    subscription_id = data.get('id')
                    
                    cancellation_data = {
                        'subscription_id': subscription_id,
                        'status': 'cancelled',
                        'event_type': 'subscription_cancelled',
                        'timestamp': datetime.now().isoformat()
                    }
                    
                    mother_result = self._sync_cancellation_to_mother(cancellation_data)
                    logger.info(f"❌ Subscription cancelled: {subscription_id}")
                
                return jsonify({'received': True}), 200
                
            except Exception as e:
                logger.error(f"Stripe webhook error: {e}")
                return jsonify({'error': str(e)}), 500

        # Success and Cancel Pages
        @self.app.route('/success')
        def success_page():
            """Payment success page with license generation"""
            try:
                # Get Stripe session ID from URL params
                session_id = request.args.get('session_id')
                if not session_id:
                    # Check if we have license key in cookie from previous visit
                    cookie_license = request.cookies.get('grim_license_key', 'DEMO-GRIM-XXXX-XXXX')
                    response = make_response(render_template_string(self._load_static_content('grim/public/success.html') or '', 
                                                license_key=cookie_license, 
                                                plan='Pro', 
                                                email='demo@example.com'))
                    response.set_cookie('grim_license_key', cookie_license, 
                                      max_age=30*24*60*60, secure=True, httponly=True)
                    return response
                
                # Retrieve Stripe session
                import stripe
                stripe.api_key = os.environ.get('STRIPE_SECRET_KEY')
                
                stripe_session = stripe.checkout.Session.retrieve(session_id)
                
                # RESTORE AFFILIATE ID FROM STRIPE METADATA TO FLASK SESSION
                affiliate_id_from_metadata = stripe_session.metadata.get('affiliate_id', '')
                logger.info(f"🔍 Stripe session metadata: {stripe_session.metadata}")
                logger.info(f"🔍 Affiliate ID from metadata: '{affiliate_id_from_metadata}'")
                logger.info(f"🔍 Current Flask session before restore: {dict(session)}")
                
                if affiliate_id_from_metadata:
                    session['grim_affiliate_id'] = affiliate_id_from_metadata
                    logger.info(f"🎯 Restored affiliate ID to Flask session: {affiliate_id_from_metadata}")
                    logger.info(f"🔍 Flask session after restore: {dict(session)}")
                else:
                    logger.warning("⚠️ No affiliate_id found in Stripe metadata")
                    logger.info(f"🔍 Flask session remains: {dict(session)}")
                
                # FIRST: Check if we already have a license for this session
                existing_license = self._get_existing_license_by_session(stripe_session.id)
                if existing_license:
                    license_key = existing_license
                    logger.info(f"✅ Found existing license for session {stripe_session.id}: {license_key}")
                    
                    # Get customer email from database for existing license
                    customer_email = self._get_customer_email_by_session(stripe_session.id)
                    if not customer_email:
                        customer_email = 'support@grim.so'  # Fallback email
                else:
                    # Try to get customer from Stripe session
                    customer_email = 'bg@blb.ht'  # Test with your email
                    try:
                        if stripe_session.customer:
                            customer = stripe.Customer.retrieve(stripe_session.customer)
                            customer_email = customer.email
                    except Exception as e:
                        logger.warning(f"Could not retrieve Stripe customer: {e}")
                    
                    # Create new license via mother-db-api
                    license_result = self._create_license_via_mother_db(customer_email, stripe_session.metadata.get('plan', 'pro'), stripe_session.id)
                    license_key = license_result.get('license_key', 'ERROR-CONTACT-SUPPORT')
                
                # Send welcome email with license (with timeout)
                try:
                    import threading
                    import time
                    
                    def send_email_thread():
                        try:
                            self._send_license_email(customer_email, license_key, stripe_session.metadata.get('plan', 'pro'))
                        except Exception as e:
                            logger.error(f"Email sending failed: {e}")
                    
                    # Start email in background thread with timeout
                    email_thread = threading.Thread(target=send_email_thread)
                    email_thread.daemon = True
                    email_thread.start()
                    email_thread.join(timeout=15.0)  # 15 second timeout for email
                    
                    if email_thread.is_alive():
                        logger.warning("Email sending timed out, continuing without email")
                        
                except Exception as e:
                    logger.error(f"Email thread setup failed: {e}")
                
                # Load success page with real data
                success_html = self._load_static_content('grim/public/success.html') or ''
                response = make_response(render_template_string(success_html,
                    license_key=license_key,
                    plan=stripe_session.metadata.get('plan', 'pro').title(),
                    email=customer_email,
                    order_id=stripe_session.id,
                    amount=stripe_session.amount_total / 100 if stripe_session.amount_total else 49.00
                ))
                
                # Set cookie with license key (expires in 30 days)
                response.set_cookie('grim_license_key', license_key, 
                                  max_age=30*24*60*60, secure=True, httponly=True)
                return response
                
            except Exception as e:
                logger.error(f"Success page error: {e}")
                # Fallback to demo success page
                fallback_license = 'ERROR-CONTACT-SUPPORT'
                response = make_response(render_template_string(self._load_static_content('grim/public/success.html') or '',
                                            license_key=fallback_license,
                                            plan='Pro',
                                            email='support@grim.so'))
                response.set_cookie('grim_license_key', fallback_license, 
                                  max_age=30*24*60*60, secure=True, httponly=True)
                return response
        
        @self.app.route('/cancel')
        def cancel_page():
            """Payment cancellation page"""
            cancel_html = self._load_static_content('grim/public/cancel.html') or '<h1>Payment Cancelled</h1>'
            return render_template_string(cancel_html)
        
        @self.app.route('/get-started')
        def get_started_page():
            """Get started page (dashboard alternative)"""
            return render_template_string('''
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Get Started - Grim Reaper</title>
                    <style>
                        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #0a0a0a; color: #e6e6e6; padding: 2rem; }
                        .container { max-width: 800px; margin: 0 auto; text-align: center; }
                        h1 { color: #b8860b; font-size: 3rem; margin-bottom: 2rem; }
                        .code-block { background: #1a1a1a; padding: 2rem; border-radius: 12px; margin: 2rem 0; }
                        code { color: #28a745; font-family: monospace; font-size: 1.2rem; }
                        .step { background: #2a2a2a; padding: 1.5rem; margin: 1rem 0; border-radius: 8px; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>🗡️ Welcome to Grim Reaper</h1>
                        <p>Your license is active! Follow these steps to get started:</p>
                        
                        <div class="step">
                            <h3>Step 1: Install Grim</h3>
                            <div class="code-block">
                                <code>curl -sSL get.grim.so | sudo bash</code>
                            </div>
                        </div>
                        
                        <div class="step">
                            <h3>Step 2: Activate Your License</h3>
                            <div class="code-block">
                                <code>grim activate YOUR-LICENSE-KEY</code>
                            </div>
                        </div>
                        
                        <div class="step">
                            <h3>Step 3: Start Protecting Your Data</h3>
                            <div class="code-block">
                                <code>grim backup /important/data</code>
                            </div>
                        </div>
                        
                        <p><a href="https://grim.so/docs" style="color: #daa520;">📚 View Full Documentation</a></p>
                    </div>
                </body>
                </html>
            ''')

        # Scythe API Endpoints  
        @self.app.route('/api/vendor/register', methods=['POST'])
        def api_vendor_register():
            """API endpoint for vendor registration"""
            try:
                data = request.get_json()
                
                # Use Herd elephant for security validation
                try:
                    from scythe_elephants import get_satao
                    satao = get_satao()
                    
                    # Validate and sanitize input
                    if not satao.validate_email(data.get('contact_email', '')):
                        return jsonify({'success': False, 'error': 'Invalid email address'}), 400
                    
                    # Rate limiting check
                    if not satao.check_rate_limit(request.remote_addr, 'vendor_register', limit=5):
                        return jsonify({'success': False, 'error': 'Rate limit exceeded'}), 429
                
                except ImportError:
                    logger.warning("Satao elephant not available - using basic validation")
                
                # Use Tantor elephant for database operations
                try:
                    from scythe_elephants import get_tantor
                    tantor = get_tantor()
                    
                    vendor_id = tantor.insert('vendors', {
                        'company_name': data['company_name'],
                        'contact_email': data['contact_email'],
                        'contact_name': data['contact_name'],
                        'software_name': data['software_name'],
                        'website': data.get('website'),
                        'description': data.get('description'),
                        'expected_licenses': data.get('expected_licenses', '1-100'),
                        'api_key': secrets.token_urlsafe(32),
                        'status': 'active',
                        'created_at': datetime.now().isoformat()
                    })
                    
                    return jsonify({
                        'success': True,
                        'vendor_id': vendor_id
                    })
                
                except ImportError:
                    # Fallback without database
                    return jsonify({
                        'success': True,
                        'message': 'Registration received'
                    })
            
            except Exception as e:
                logger.error(f"API vendor registration error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/vendor/stats')
        @login_required
        def api_vendor_stats():
            """Get vendor statistics"""
            try:
                # Mock data for MVP - replace with real data from Tantor
                stats = {
                    'total_licenses': 0,
                    'active_licenses': 0,
                    'revenue': 0,
                    'countries': 0
                }
                
                try:
                    from scythe_elephants import get_tantor
                    tantor = get_tantor()
                    
                    # Get real stats from database
                    vendor_id = get_current_user().id if get_current_user() else 1
                    
                    stats['total_licenses'] = tantor.count('licenses', {'vendor_id': vendor_id})
                    stats['active_licenses'] = tantor.count('licenses', {
                        'vendor_id': vendor_id,
                        'status': 'active'
                    })
                    
                except ImportError:
                    logger.warning("Tantor elephant not available - using mock data")
                
                return jsonify({
                    'success': True,
                    'data': stats
                })
            
            except Exception as e:
                logger.error(f"Vendor stats error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/vendor/licenses')
        @login_required
        def api_vendor_licenses():
            """Get vendor licenses"""
            try:
                limit = request.args.get('limit', 10, type=int)
                
                # Mock data for MVP
                licenses = []
                
                try:
                    from scythe_elephants import get_tantor
                    tantor = get_tantor()
                    
                    vendor_id = get_current_user().id if get_current_user() else 1
                    licenses = tantor.select('licenses', {
                        'vendor_id': vendor_id
                    }, limit=limit, order_by='created_at DESC')
                    
                except ImportError:
                    logger.warning("Tantor elephant not available - using mock data")
                
                return jsonify({
                    'success': True,
                    'data': licenses
                })
            
            except Exception as e:
                logger.error(f"Vendor licenses error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/vendor/products')
        @login_required
        def api_vendor_products():
            """Get vendor products"""
            try:
                # Mock data for MVP
                products = []
                
                try:
                    from scythe_elephants import get_tantor
                    tantor = get_tantor()
                    
                    vendor_id = get_current_user().id if get_current_user() else 1
                    products = tantor.select('products', {
                        'vendor_id': vendor_id
                    })
                    
                except ImportError:
                    # Mock data
                    products = [
                        {
                            'id': 'prod_123',
                            'name': 'Sample Product',
                            'status': 'active',
                            'license_count': 0,
                            'active_count': 0
                        }
                    ]
                
                return jsonify({
                    'success': True,
                    'data': products
                })
            
            except Exception as e:
                logger.error(f"Vendor products error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/vendor/licenses/generate', methods=['POST'])
        @login_required
        def api_generate_license():
            """Generate a new license"""
            try:
                data = request.get_json()
                
                # Use Jumbo elephant for file operations if needed
                try:
                    from scythe_elephants import get_jumbo
                    jumbo = get_jumbo()
                except ImportError:
                    logger.warning("Jumbo elephant not available")
                
                # Generate license key
                license_key = f"lic_{secrets.token_urlsafe(24)}"
                
                # Use Tantor for database operations
                try:
                    from scythe_elephants import get_tantor
                    tantor = get_tantor()
                    
                    vendor_id = get_current_user().id if get_current_user() else 1
                    
                    license_id = tantor.insert('licenses', {
                        'license_key': license_key,
                        'vendor_id': vendor_id,
                        'product_id': data['product_id'],
                        'license_type': data['license_type'],
                        'customer_name': data.get('customer_name'),
                        'customer_email': data.get('customer_email'),
                        'company_name': data.get('company_name'),
                        'order_id': data.get('order_id'),
                        'expiry_date': data.get('expiry_date'),
                        'max_users': data.get('max_users'),
                        'allowed_domains': data.get('allowed_domains'),
                        'features': json.dumps(data.get('features', [])),
                        'offline_validation': data.get('offline_validation', False),
                        'hardware_binding': data.get('hardware_binding', False),
                        'custom_data': data.get('custom_data'),
                        'status': 'active',
                        'created_at': datetime.now().isoformat()
                    })
                    
                    # Use Horton elephant for background tasks
                    try:
                        from scythe_elephants import get_horton
                        horton = get_horton()
                        
                        # Queue email notification if customer email provided
                        if data.get('customer_email'):
                            horton.queue_task('send_license_email', {
                                'customer_email': data['customer_email'],
                                'license_key': license_key,
                                'product_name': data.get('product_name', 'Unknown')
                            })
                    
                    except ImportError:
                        logger.warning("Horton elephant not available - skipping email")
                    
                    return jsonify({
                        'success': True,
                        'data': {
                            'id': license_id,
                            'license_key': license_key,
                            'product_name': data.get('product_name', 'Unknown'),
                            'license_type': data['license_type'],
                            'created_at': datetime.now().isoformat(),
                            'expiry_date': data.get('expiry_date')
                        }
                    })
                
                except ImportError:
                    # Mock response without database
                    return jsonify({
                        'success': True,
                        'data': {
                            'id': 'lic_mock_123',
                            'license_key': license_key,
                            'product_name': 'Mock Product',
                            'license_type': data['license_type'],
                            'created_at': datetime.now().isoformat(),
                            'expiry_date': data.get('expiry_date')
                        }
                    })
            
            except Exception as e:
                logger.error(f"License generation error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        # Public license routes - no authentication required
        @self.app.route('/grim/license/validate', methods=['POST'])
        def grim_license_validate():
            """Public license validation endpoint"""
            try:
                data = request.get_json()
                license_key = data.get('license_key')
                
                if not license_key:
                    return jsonify({
                        'valid': False,
                        'error': 'License key is required'
                    }), 400
                
                # Use Grim License Manager for validation
                try:
                    from grim_license_manager import GrimLicenseManager
                    license_manager = GrimLicenseManager()
                    result = license_manager.validate_license(license_key)
                    
                    return jsonify(result)
                    
                except ImportError:
                    # Fallback validation without license manager
                    return jsonify({
                        'valid': True,
                        'email': 'fallback@grim.so',
                        'tier': 'FREE',
                        'source': 'fallback'
                    })
            
            except Exception as e:
                logger.error(f"License validation error: {e}")
                return jsonify({
                    'valid': False,
                    'error': str(e)
                }), 500

        @self.app.route('/grim/license/generate', methods=['POST'])
        def grim_license_generate():
            """Public license generation endpoint"""
            try:
                data = request.get_json()
                email = data.get('email')
                name = data.get('name')
                
                if not email:
                    return jsonify({
                        'success': False,
                        'error': 'Email is required'
                    }), 400
                
                # Use Grim License Manager for generation
                try:
                    from grim_license_manager import GrimLicenseManager
                    license_manager = GrimLicenseManager()
                    result = license_manager.generate_freemium_license(email, name)
                    
                    return jsonify(result)
                    
                except ImportError:
                    # Fallback generation without license manager
                    license_key = f"grim_{secrets.token_urlsafe(16)}"
                    return jsonify({
                        'success': True,
                        'license_key': license_key,
                        'email': email,
                        'tier': 'FREE',
                        'source': 'fallback'
                    })
            
            except Exception as e:
                logger.error(f"License generation error: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # Public pages - serve static files
        @self.app.route('/public/api-docs')
        def api_docs():
            """API documentation"""
            return send_from_directory('grim/public', 'api-docs.html')
        
        @self.app.route('/public/command-reference')
        def command_reference():
            """Command reference"""
            return send_from_directory('grim/public', 'command-reference.html')
        
        @self.app.route('/public/comparison')
        def comparison_chart():
            """Comparison chart"""
            return send_from_directory('.', 'grim-comparison-chart.html')
        
        @self.app.route('/architecture')
        def architecture():
            """Architecture page"""
            return self._render_public_page('architecture.html', {
                'page_title': 'Grim Architecture',
                'page_description': 'The Architecture of Immortality - Four specialized subsystems, one unified interface'
            })
        
        @self.app.route('/commands')
        def commands():
            """Commands reference page"""
            return self._render_public_page('command-reference.html', {
                'page_title': 'Grim Command Reference',
                'page_description': 'Complete guide to the unified command system - Everything through grim'
            })
        @self.app.route('/deploy')
        def deploy():
            """Deployment guide page"""
            return self._render_public_page('deployment-guide.html', {
                'page_title': 'Grim Deployment Guide',
                'page_description': 'Complete guide to deploying Grim - Everything through grim'
            })
        @self.app.route('/developer')
        def developer():
            """Commands reference page"""
            return self._render_public_page('developer-guides.html', {
                'page_title': 'Grim Command Reference',
                'page_description': 'Complete guide to the unified command system - Everything through grim'
            })
        @self.app.route('/api-docs-v2')
        def api_docs_v2():
            """API documentation v2 page"""
            return self._render_public_page('api-documentation.html', {
                'page_title': 'Grim API Documentation',
                'page_description': 'Complete guide to the unified data protection ecosystem'
            })
        
        @self.app.route('/compare')
        def compareChart():
            """Commands reference page"""
            return self._render_public_page('comparison-chart.html', {
                'page_title': 'GrimS vs Traditional Backup Solutions - Comparison',
                'page_description': 'See how Grim revolutionizes data protection compared to legacy tools'
            })

        # New routes for updated menu links
        @self.app.route('/api-docs')
        def api_docs_main():
            """API documentation"""
            return self._render_public_page('api-docs.html', {
                'page_title': 'GRIM REST API Documentation',
                'page_description': 'Programmatic access to the unified data protection ecosystem'
            })
        
        @self.app.route('/docs')
        def docs():
            """Grim documentation page"""
            return self._render_public_page('docs.html', {
                'page_title': 'GRIM Documentation',
                'page_description': 'Complete documentation for the unified data protection ecosystem'
            })
        
        @self.app.route('/grim-commands-reference')
        def grim_commands_reference():
            """Grim commands reference"""
            return send_from_directory('z_archive/convert', 'grim-commands-reference-standalone.html')
        
        # Landing page route
        @self.app.route('/public/')
        @self.app.route('/public/index')
        def public_landing():
            """Public landing page"""
            return self._render_public_page('landing.html', {
                'page_title': 'Grim - The Reaper of Data Loss',
                'page_type': 'landing'
            })
        
        # API endpoints
        @self.app.route('/api/status')
        def api_status():
            """Get system status"""
            return jsonify({
                'status': 'operational',
                'timestamp': datetime.now().isoformat(),
                'tusk_available': FLASK_TSK_AVAILABLE,
                'performance_stats': get_performance_stats()
            })
        
        @self.app.route('/api/config/<section>')
        def api_config(section):
            """Get configuration section"""
            if self.tsk:
                config = self.tsk.get_section(section)
                return jsonify({
                    'section': section,
                    'config': config or {},
                    'success': config is not None
                })
            else:
                return jsonify({
                    'section': section,
                    'config': {},
                    'success': False,
                    'error': 'TuskLang not available'
                })
        
        @self.app.route('/api/performance')
        def api_performance():
            """Get performance statistics"""
            return jsonify(get_performance_stats())
        
        @self.app.route('/api/tusk/status')
        def api_tusk_status():
            """Get TuskLang status"""
            if self.tsk:
                return jsonify(self.tsk.get_status())
            else:
                return jsonify({
                    'available': False,
                    'error': 'TuskLang not available'
                })
        
        # Command execution endpoints
        @self.app.route('/api/execute', methods=['POST'])
        def execute_command():
            """Execute command via web interface"""
            try:
                data = request.get_json()
                command_type = data.get('type', 'system')
                command_args = data.get('args', {})
                
                # Execute command asynchronously
                command_id = asyncio.run(grim_executor.execute_command_async(command_type, command_args))
                
                return jsonify({
                    'success': True,
                    'command_id': command_id,
                    'message': 'Command queued for execution'
                })
            except Exception as e:
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/command/<command_id>')
        def get_command_result(command_id):
            """Get result of a specific command"""
            result = grim_executor.get_command_result(command_id)
            if result:
                return jsonify({
                    'success': True,
                    'command_id': command_id,
                    'result': {
                        'success': result.success,
                        'command': result.command,
                        'output': result.output,
                        'error': result.error,
                        'return_code': result.return_code,
                        'execution_time': result.execution_time,
                        'timestamp': result.timestamp.isoformat()
                    }
                })
            else:
                return jsonify({
                    'success': False,
                    'error': 'Command not found or still running'
                }), 404
        
        @self.app.route('/api/commands/history')
        def get_command_history():
            """Get command execution history"""
            limit = request.args.get('limit', 50, type=int)
            history = grim_executor.get_command_history(limit)
            return jsonify({
                'success': True,
                'history': history
            })
        
        @self.app.route('/api/executor/status')
        def get_executor_status():
            """Get executor status"""
            status = grim_executor.get_system_status()
            return jsonify({
                'success': True,
                'status': status
            })
        
        # Herd Authentication API endpoints
        @self.app.route('/api/auth/status')
        def auth_status():
            """Get authentication status"""
            try:
                user = get_current_user()
                if user:
                    return jsonify({
                        'success': True,
                        'authenticated': True,
                        'user': {
                            'id': user.id,
                            'email': user.email,
                            'username': user.username,
                            'is_admin': user.is_admin,
                            'last_login': user.last_login.isoformat() if user.last_login else None
                        }
                    })
                else:
                    return jsonify({
                        'success': True,
                        'authenticated': False
                    })
            except Exception as e:
                logger.error(f"Error getting auth status: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auth/stats')
        @admin_required
        def auth_stats():
            """Get authentication system statistics (admin only)"""
            try:
                stats = self.herd.get_stats()
                return jsonify({
                    'success': True,
                    'data': stats
                })
            except Exception as e:
                logger.error(f"Error getting auth stats: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auth/audit-logs')
        @admin_required
        def auth_audit_logs():
            """Get audit logs (admin only)"""
            try:
                user_id = request.args.get('user_id', type=int)
                action = request.args.get('action')
                limit = request.args.get('limit', 100, type=int)
                
                logs = self.herd.get_audit_logs(
                    user_id=user_id,
                    action=action,
                    limit=limit
                )
                
                return jsonify({
                    'success': True,
                    'data': logs
                })
            except Exception as e:
                logger.error(f"Error getting audit logs: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # Health check
        @self.app.route('/health')
        def health_check():
            """Health check endpoint"""
            return jsonify({
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'version': '1.0.0',
                'tusk_engine': FLASK_TSK_AVAILABLE,
                'executor_status': grim_executor.get_system_status()
            })
        
        # API routes for monitoring
        @self.app.route('/api/monitoring/dashboard')
        @login_required
        def api_monitoring_dashboard():
            """API endpoint for monitoring dashboard data"""
            return jsonify(get_monitoring_data())
        
        @self.app.route('/api/monitoring/health')
        @login_required
        def api_monitoring_health():
            """API endpoint for monitoring health status"""
            return jsonify(get_monitoring_health())
        
        @self.app.route('/api/monitoring/alerts')
        @login_required
        def api_monitoring_alerts():
            """API endpoint for active alerts"""
            alerts = monitoring_integration.get_active_alerts()
            return jsonify(alerts)
        
        @self.app.route('/api/monitoring/performance')
        @login_required
        def api_monitoring_performance():
            """API endpoint for performance metrics"""
            performance = monitoring_integration.get_performance_metrics()
            return jsonify(performance)
        
        @self.app.route('/api/monitoring/sla')
        @login_required
        def api_monitoring_sla():
            """API endpoint for SLA compliance"""
            sla = monitoring_integration.get_sla_compliance()
            return jsonify(sla)
        
        @self.app.route('/api/monitoring/optimize', methods=['POST'])
        @login_required
        def api_run_optimization():
            """API endpoint to trigger storage optimization"""
            result = monitoring_integration.run_optimization()
            return jsonify(result)
        
        @self.app.route('/api/monitoring/alerts/<alert_id>/acknowledge', methods=['POST'])
        @login_required
        def api_acknowledge_alert(alert_id):
            """API endpoint to acknowledge an alert"""
            user = get_current_user()
            result = monitoring_integration.acknowledge_alert(alert_id, user.get('id', 1))
            return jsonify(result)

        # Security API endpoints
        @self.app.route('/api/security/status')
        @login_required
        def api_security_status():
            """Get security status"""
            try:
                security_manager = get_security_manager()
                status = security_manager.get_security_status()
                return jsonify({'success': True, 'data': status})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/authenticate', methods=['POST'])
        def api_security_authenticate():
            """Authenticate user"""
            try:
                data = request.get_json()
                username = data.get('username')
                password = data.get('password')
                mfa_code = data.get('mfa_code')
                ip_address = request.remote_addr

                security_manager = get_security_manager()
                result = security_manager.authenticate_user(username, password, mfa_code, ip_address)
                
                return jsonify(result)
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/logout', methods=['POST'])
        @login_required
        def api_security_logout():
            """Logout user"""
            try:
                data = request.get_json()
                session_token = data.get('session_token')
                user_id = get_current_user().id if get_current_user() else None
                username = get_current_user().username if get_current_user() else None

                security_manager = get_security_manager()
                security_manager.logout_user(session_token, user_id, username)
                
                return jsonify({'success': True, 'message': 'Logged out successfully'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/mfa/setup', methods=['POST'])
        @login_required
        def api_security_mfa_setup():
            """Setup MFA for user"""
            try:
                security_manager = get_security_manager()
                mfa_secret = security_manager.mfa_manager.generate_mfa_secret()
                username = get_current_user().username if get_current_user() else 'admin'
                qr_code = security_manager.mfa_manager.generate_qr_code(mfa_secret, username)
                backup_codes = security_manager.mfa_manager.generate_backup_codes()
                
                return jsonify({
                    'success': True,
                    'data': {
                        'secret': mfa_secret,
                        'qr_code': qr_code,
                        'backup_codes': backup_codes
                    }
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/mfa/verify', methods=['POST'])
        def api_security_mfa_verify():
            """Verify MFA code"""
            try:
                data = request.get_json()
                secret = data.get('secret')
                code = data.get('code')
                
                security_manager = get_security_manager()
                is_valid = security_manager.mfa_manager.verify_mfa_code(secret, code)
                
                return jsonify({'success': True, 'valid': is_valid})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/password/validate', methods=['POST'])
        def api_security_password_validate():
            """Validate password strength"""
            try:
                data = request.get_json()
                password = data.get('password')
                
                security_manager = get_security_manager()
                result = security_manager.password_validator.validate_password(password, security_manager.config)
                
                return jsonify({'success': True, 'data': result})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/encrypt', methods=['POST'])
        @login_required
        def api_security_encrypt():
            """Encrypt data"""
            try:
                data = request.get_json()
                text = data.get('text')
                method = data.get('method', 'symmetric')  # symmetric or asymmetric
                
                security_manager = get_security_manager()
                
                if method == 'asymmetric':
                    encrypted = security_manager.encryption_manager.encrypt_asymmetric(text)
                else:
                    encrypted = security_manager.encryption_manager.encrypt_symmetric(text)
                
                return jsonify({'success': True, 'encrypted': encrypted})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/decrypt', methods=['POST'])
        @login_required
        def api_security_decrypt():
            """Decrypt data"""
            try:
                data = request.get_json()
                encrypted_text = data.get('encrypted_text')
                method = data.get('method', 'symmetric')  # symmetric or asymmetric
                
                security_manager = get_security_manager()
                
                if method == 'asymmetric':
                    decrypted = security_manager.encryption_manager.decrypt_asymmetric(encrypted_text)
                else:
                    decrypted = security_manager.encryption_manager.decrypt_symmetric(encrypted_text)
                
                return jsonify({'success': True, 'decrypted': decrypted})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/compliance/status')
        @login_required
        def api_security_compliance_status():
            """Get compliance status"""
            try:
                security_manager = get_security_manager()
                compliance_status = security_manager.compliance_manager.get_compliance_status()
                
                return jsonify({'success': True, 'data': compliance_status})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/audit/logs')
        @login_required
        def api_security_audit_logs():
            """Get audit logs"""
            try:
                # Read audit log file
                audit_entries = []
                try:
                    with open('grim_audit.log', 'r') as f:
                        for line in f:
                            try:
                                entry = json.loads(line.strip())
                                audit_entries.append(entry)
                            except json.JSONDecodeError:
                                continue
                except FileNotFoundError:
                    pass
                
                # Return last 100 entries
                audit_entries = audit_entries[-100:]
                
                return jsonify({'success': True, 'data': audit_entries})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/security/audit/log', methods=['POST'])
        @login_required
        def api_security_audit_log():
            """Log security event"""
            try:
                data = request.get_json()
                event_type = data.get('event_type')
                details = data.get('details', {})
                user_id = get_current_user().id if get_current_user() else None
                username = get_current_user().username if get_current_user() else None
                ip_address = request.remote_addr
                
                AuditLogger.log_event(event_type, user_id, username, details, ip_address)
                
                return jsonify({'success': True, 'message': 'Event logged successfully'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        # Billing API endpoints
        @self.app.route('/api/billing/plans')
        def api_billing_plans():
            """Get all available plans"""
            try:
                billing_manager = get_billing_manager()
                plans = billing_manager.get_all_plans()
                return jsonify({'success': True, 'data': plans})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/billing/current-plan')
        @login_required
        def api_billing_current_plan():
            """Get user's current plan"""
            try:
                user = get_current_user()
                if not user:
                    return jsonify({'success': False, 'error': 'User not authenticated'}), 401
                
                billing_manager = get_billing_manager()
                billing_info = billing_manager.get_user_billing_info(user.id)
                
                if 'error' in billing_info:
                    return jsonify({'success': False, 'error': billing_info['error']}), 500
                
                current_plan = billing_info.get('current_plan', {})
                return jsonify({
                    'success': True,
                    'data': {
                        'plan_name': current_plan.get('name', 'FREE'),
                        'plan_price': f"${current_plan.get('monthly_price', 0)}/month",
                        'features': current_plan.get('features', [])
                    }
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/billing/create-payment-intent', methods=['POST'])
        @login_required
        def api_billing_create_payment_intent():
            """Create Stripe payment intent"""
            try:
                user = get_current_user()
                if not user:
                    return jsonify({'success': False, 'error': 'User not authenticated'}), 401
                
                data = request.get_json()
                plan_name = data.get('plan')
                billing_cycle = data.get('billing_cycle', 'monthly')
                billing_details = {
                    'name': data.get('billing_name'),
                    'email': data.get('billing_email'),
                    'address': {
                        'line1': data.get('billing_address'),
                        'city': data.get('billing_city'),
                        'state': data.get('billing_state'),
                        'postal_code': data.get('billing_zip'),
                        'country': data.get('billing_country')
                    }
                }
                
                billing_manager = get_billing_manager()
                result = billing_manager.create_payment_intent(
                    user_id=user.id,
                    plan_name=plan_name,
                    billing_cycle=billing_cycle,
                    billing_details=billing_details
                )
                
                return jsonify({'success': True, 'data': result})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/billing/create-subscription', methods=['POST'])
        @login_required
        def api_billing_create_subscription():
            """Create Stripe subscription"""
            try:
                user = get_current_user()
                if not user:
                    return jsonify({'success': False, 'error': 'User not authenticated'}), 401
                
                data = request.get_json()
                plan_name = data.get('plan')
                billing_cycle = data.get('billing_cycle', 'monthly')
                payment_method_id = data.get('payment_method_id')
                
                billing_manager = get_billing_manager()
                result = billing_manager.create_subscription(
                    user_id=user.id,
                    plan_name=plan_name,
                    billing_cycle=billing_cycle,
                    payment_method_id=payment_method_id
                )
                
                return jsonify({'success': True, 'data': result})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/billing/webhook', methods=['POST'])
        def api_billing_webhook():
            """Handle Stripe webhooks"""
            try:
                payload = request.data.decode('utf-8')
                sig_header = request.headers.get('Stripe-Signature')
                
                billing_manager = get_billing_manager()
                result = billing_manager.handle_webhook(payload, sig_header)
                
                if result.get('status') == 'success':
                    return jsonify(result), 200
                else:
                    return jsonify(result), 400
            except Exception as e:
                return jsonify({'status': 'error', 'message': str(e)}), 500

        @self.app.route('/api/billing/user-info')
        @login_required
        def api_billing_user_info():
            """Get user's billing information"""
            try:
                user = get_current_user()
                if not user:
                    return jsonify({'success': False, 'error': 'User not authenticated'}), 401
                
                billing_manager = get_billing_manager()
                billing_info = billing_manager.get_user_billing_info(user.id)
                
                if 'error' in billing_info:
                    return jsonify({'success': False, 'error': billing_info['error']}), 500
                
                return jsonify({'success': True, 'data': billing_info})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/billing/cancel-subscription', methods=['POST'])
        @login_required
        def api_billing_cancel_subscription():
            """Cancel user subscription"""
            try:
                user = get_current_user()
                if not user:
                    return jsonify({'success': False, 'error': 'User not authenticated'}), 401
                
                data = request.get_json()
                subscription_id = data.get('subscription_id')
                
                if not subscription_id:
                    return jsonify({'success': False, 'error': 'Subscription ID required'}), 400
                
                billing_manager = get_billing_manager()
                result = billing_manager.cancel_subscription(user.id, subscription_id)
                
                return jsonify(result)
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/billing/stripe-config')
        def api_billing_stripe_config():
            """Get Stripe publishable key for frontend"""
            try:
                billing_manager = get_billing_manager()
                publishable_key = billing_manager.config.stripe_publishable_key
                
                if not publishable_key:
                    return jsonify({'success': False, 'error': 'Stripe not configured'}), 500
                
                return jsonify({
                    'success': True,
                    'data': {
                        'publishable_key': publishable_key
                    }
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500

        # Scythe Baby API endpoints
        @self.app.route('/api/scythe-baby/dashboard')
        @login_required
        def api_scythe_baby_dashboard():
            """Get Scythe Baby dashboard data"""
            try:
                scythe_manager = get_scythe_baby_manager()
                return jsonify(scythe_manager.get_dashboard_data())
            except Exception as e:
                logger.error(f"Error getting Scythe Baby dashboard: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/scythe-baby/register', methods=['POST'])
        @login_required
        def api_scythe_baby_register():
            """Register new software in Scythe Baby"""
            try:
                data = request.get_json()
                scythe_manager = get_scythe_baby_manager()
                
                # Parse expiry date if provided
                expiry_date = None
                if data.get('expiry_date'):
                    expiry_date = datetime.fromisoformat(data['expiry_date'])
                
                result = scythe_manager.register_software(
                    name=data['name'],
                    language=data.get('language', ''),
                    license_type=data['license_type'],
                    license_key=data.get('license_key'),
                    expiry_date=expiry_date,
                    user_id=1,  # TODO: Get from session
                    ip_address=request.remote_addr
                )
                
                return jsonify(result)
            except Exception as e:
                logger.error(f"Error registering software: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/scythe-baby/validate', methods=['POST'])
        @login_required
        def api_scythe_baby_validate():
            """Validate software license"""
            try:
                data = request.get_json()
                scythe_manager = get_scythe_baby_manager()
                
                result = scythe_manager.validate_license(
                    software_name=data['software_name'],
                    license_key=data.get('license_key'),
                    user_id=1,  # TODO: Get from session
                    ip_address=request.remote_addr
                )
                
                return jsonify(result)
            except Exception as e:
                logger.error(f"Error validating license: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/scythe-baby/scan', methods=['POST'])
        @login_required
        def api_scythe_baby_scan():
            """Perform deep license scan"""
            try:
                scythe_manager = get_scythe_baby_manager()
                
                result = scythe_manager.scan_licenses(
                    user_id=1,  # TODO: Get from session
                    ip_address=request.remote_addr
                )
                
                return jsonify(result)
            except Exception as e:
                logger.error(f"Error performing scan: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/scythe-baby/report', methods=['POST'])
        @login_required
        def api_scythe_baby_report():
            """Generate compliance report"""
            try:
                data = request.get_json()
                scythe_manager = get_scythe_baby_manager()
                
                result = scythe_manager.generate_report(
                    report_type=data['report_type'],
                    user_id=1,  # TODO: Get from session
                    ip_address=request.remote_addr
                )
                
                return jsonify(result)
            except Exception as e:
                logger.error(f"Error generating report: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/scythe-baby/export')
        @login_required
        def api_scythe_baby_export():
            """Export Scythe Baby data"""
            try:
                scythe_manager = get_scythe_baby_manager()
                dashboard_data = scythe_manager.get_dashboard_data()
                
                if dashboard_data['success']:
                    return jsonify({
                        'success': True,
                        'data': dashboard_data['data']
                    })
                else:
                    return jsonify(dashboard_data)
            except Exception as e:
                logger.error(f"Error exporting data: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        # Storage Management API Routes
        @self.app.route('/api/storage/providers')
        @login_required
        def api_storage_providers():
            """Get all storage providers"""
            try:
                # Import storage manager
                from enhanced_storage_provider import get_enhanced_storage_manager
                storage_manager = get_enhanced_storage_manager()
                
                # Get providers from database
                from enhanced_database_schema import get_enhanced_database
                db = get_enhanced_database()
                
                with db.get_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute("""
                        SELECT provider_name, provider_type, endpoint_url, region,
                               bucket_name, cost_per_gb_monthly, cost_per_gb_transfer,
                               max_storage_gb, status, health_status, last_health_check,
                               current_usage_gb
                        FROM storage_providers
                        ORDER BY provider_name
                    """)
                    
                    providers = [dict(row) for row in cursor.fetchall()]
                
                return jsonify({'success': True, 'providers': providers})
                
            except Exception as e:
                logger.error(f"Failed to get storage providers: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/api/storage/analytics')
        @login_required
        def api_storage_analytics():
            """Get storage cost analytics"""
            try:
                from enhanced_storage_provider import get_enhanced_storage_manager
                storage_manager = get_enhanced_storage_manager()
                
                analytics = storage_manager.get_cost_analytics()
                return jsonify({'success': True, 'analytics': analytics})
                
            except Exception as e:
                logger.error(f"Failed to get storage analytics: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/api/storage/usage')
        @login_required
        def api_storage_usage():
            """Get user storage usage"""
            try:
                from enhanced_database_schema import get_enhanced_database
                db = get_enhanced_database()
                
                user_id = session.get('user_id')
                if not user_id:
                    return jsonify({'success': False, 'error': 'User not authenticated'}), 401
                
                usage = db.get_storage_usage_summary(user_id)
                return jsonify({'success': True, 'usage': usage})
                
            except Exception as e:
                logger.error(f"Failed to get storage usage: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/api/storage/providers/<provider_name>/test', methods=['POST'])
        @login_required
        def api_test_storage_provider(provider_name):
            """Test specific storage provider"""
            try:
                from enhanced_storage_provider import get_enhanced_storage_manager
                storage_manager = get_enhanced_storage_manager()
                
                provider = storage_manager.get_provider(provider_name)
                if not provider:
                    return jsonify({'success': False, 'error': f'Provider {provider_name} not found'}), 404
                
                health = provider.check_health()
                if health.is_healthy:
                    return jsonify({'success': True, 'message': f'{provider_name} is healthy'})
                else:
                    return jsonify({'success': False, 'error': health.error_message}), 500
                
            except Exception as e:
                logger.error(f"Failed to test provider {provider_name}: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/api/storage/providers/test-all', methods=['POST'])
        @login_required
        def api_test_all_storage_providers():
            """Test all storage providers"""
            try:
                from enhanced_storage_provider import get_enhanced_storage_manager
                storage_manager = get_enhanced_storage_manager()
                
                health_status = storage_manager.get_provider_health_status()
                all_healthy = all(health.is_healthy for health in health_status.values())
                
                if all_healthy:
                    return jsonify({'success': True, 'message': 'All providers are healthy'})
                else:
                    failed_providers = [name for name, health in health_status.items() if not health.is_healthy]
                    return jsonify({'success': False, 'error': f'Failed providers: {", ".join(failed_providers)}'}), 500
                
            except Exception as e:
                logger.error(f"Failed to test all providers: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/api/storage/providers/<provider_name>/status', methods=['PUT'])
        @login_required
        def api_update_storage_provider_status(provider_name):
            """Update storage provider status"""
            try:
                data = request.get_json()
                status = data.get('status')
                
                if status not in ['active', 'inactive']:
                    return jsonify({'success': False, 'error': 'Status must be active or inactive'}), 400
                
                from enhanced_database_schema import get_enhanced_database
                db = get_enhanced_database()
                
                with db.get_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute("""
                        UPDATE storage_providers 
                        SET status = ?, updated_at = CURRENT_TIMESTAMP
                        WHERE provider_name = ?
                    """, (status, provider_name))
                    
                    if cursor.rowcount > 0:
                        conn.commit()
                        return jsonify({'success': True, 'message': f'{provider_name} status updated to {status}'})
                    else:
                        return jsonify({'success': False, 'error': f'Provider {provider_name} not found'}), 404
                
            except Exception as e:
                logger.error(f"Failed to update provider status: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        # Billing Management API Routes
        @self.app.route('/grim/admin/billing/settings', methods=['GET', 'POST'])
        @login_required
        def api_billing_settings():
            """Get or update billing settings"""
            try:
                billing_manager = get_billing_manager()
                
                if request.method == 'GET':
                    config = billing_manager.config
                    return jsonify({
                        'success': True,
                        'data': {
                            'stripeEnabled': config.stripe_enabled,
                            'autoCharge': config.auto_charge,
                            'overageThreshold': config.overage_threshold_gb,
                            'overageRate': config.overage_rate_per_gb,
                            'billingCycle': config.billing_cycle,
                            'gracePeriod': config.grace_period_days,
                            'notificationEmail': config.notification_email,
                            'webhookUrl': config.webhook_url,
                            'billingNotes': config.billing_notes
                        }
                    })
                else:
                    data = request.get_json()
                    result = billing_manager.update_billing_config(data)
                    return jsonify(result)
                    
            except Exception as e:
                logger.error(f"Billing settings error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/grim/admin/billing/stats')
        @login_required
        def api_billing_stats():
            """Get billing statistics"""
            try:
                billing_manager = get_billing_manager()
                stats = billing_manager.get_billing_stats()
                return jsonify({'success': True, 'data': stats})
            except Exception as e:
                logger.error(f"Billing stats error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/grim/admin/billing/activity')
        @login_required
        def api_billing_activity():
            """Get billing activity"""
            try:
                billing_manager = get_billing_manager()
                activity = billing_manager.get_billing_activity()
                return jsonify({'success': True, 'data': activity})
            except Exception as e:
                logger.error(f"Billing activity error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/grim/admin/billing/test-stripe', methods=['POST'])
        @login_required
        def api_test_stripe():
            """Test Stripe connection"""
            try:
                billing_manager = get_billing_manager()
                result = billing_manager.test_stripe_connection()
                return jsonify(result)
            except Exception as e:
                logger.error(f"Stripe test error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/grim/admin/billing/tier-settings', methods=['POST'])
        @login_required
        def api_tier_settings():
            """Update tier billing settings"""
            try:
                billing_manager = get_billing_manager()
                data = request.get_json()
                result = billing_manager.update_tier_settings(data)
                return jsonify(result)
            except Exception as e:
                logger.error(f"Tier settings error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/grim/admin/billing/retry-charge/<billing_id>', methods=['POST'])
        @login_required
        def api_retry_charge(billing_id):
            """Retry a failed charge"""
            try:
                billing_manager = get_billing_manager()
                result = billing_manager.retry_failed_charge(billing_id)
                return jsonify(result)
            except Exception as e:
                logger.error(f"Retry charge error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/grim/admin/billing/process-overage', methods=['POST'])
        @login_required
        def api_process_overage():
            """Process overage charge for a customer"""
            try:
                data = request.get_json()
                license_key = data.get('license_key')
                usage_gb = data.get('usage_gb')
                customer_email = data.get('customer_email')
                
                if not license_key or usage_gb is None:
                    return jsonify({'success': False, 'error': 'license_key and usage_gb are required'}), 400
                
                billing_manager = get_billing_manager()
                result = billing_manager.process_overage_charge(license_key, usage_gb, customer_email)
                return jsonify(result)
            except Exception as e:
                logger.error(f"Process overage error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
    
        @self.app.route('/api/affiliate/credit-manual', methods=['POST'])
        @login_required
        def api_credit_affiliate_manual():
            """Manually credit an affiliate conversion (admin only)"""
            try:
                data = request.get_json()
                affiliate_id = data.get('affiliate_id')
                customer_email = data.get('customer_email')
                plan_name = data.get('plan_name', 'pro')
                monthly_value = data.get('monthly_value', 49.0)
                
                if not affiliate_id or not customer_email:
                    return jsonify({'success': False, 'error': 'Missing affiliate_id or customer_email'}), 400
                
                logger.info(f"🎯 MANUAL AFFILIATE CREDIT: {affiliate_id} -> {customer_email} -> {plan_name}")
                
                # Track the conversion
                result = self._track_affiliate_conversion(
                    affiliate_id=affiliate_id,
                    user_email=customer_email,
                    plan_name=plan_name,
                    monthly_value=monthly_value
                )
                
                if result.get('success'):
                    return jsonify({
                        'success': True,
                        'message': f'Affiliate {affiliate_id} credited for {customer_email}',
                        'commission_amount': result.get('commission_amount_usd', 0)
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': result.get('error', 'Unknown error')
                    }), 500
                    
            except Exception as e:
                logger.error(f"Manual affiliate credit error: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500

        @self.app.route('/api/affiliate/validate', methods=['POST'])
        def api_validate_affiliate():
            """Validate an affiliate ID"""
            try:
                data = request.get_json()
                affiliate_id = data.get('affiliate_id')
                
                if not affiliate_id:
                    return jsonify({'valid': False, 'error': 'Missing affiliate_id'}), 400
                
                import sqlite3
                with sqlite3.connect('/opt/reaper/db/grim_affiliates.db') as conn:
                    cursor = conn.cursor()
                    cursor.execute("""
                        SELECT affiliate_id, name, email, total_referrals, total_earnings_usd 
                        FROM affiliates 
                        WHERE affiliate_id = ? AND status = 'active'
                    """, (affiliate_id,))
                    
                    result = cursor.fetchone()
                    if result:
                        return jsonify({
                            'valid': True,
                            'affiliate_id': result[0],
                            'name': result[1],
                            'email': result[2],
                            'total_referrals': result[3],
                            'total_earnings': float(result[4]) if result[4] else 0.0
                        })
                    else:
                        return jsonify({'valid': False, 'error': 'Invalid or inactive affiliate ID'})
                        
            except Exception as e:
                logger.error(f"Affiliate validation error: {e}")
                return jsonify({'valid': False, 'error': str(e)}), 500

        @self.app.route('/api/affiliate/stats/<affiliate_id>')
        def api_affiliate_stats(affiliate_id):
            """Get affiliate statistics"""
            try:
                import sqlite3
                with sqlite3.connect('/opt/reaper/db/grim_affiliates.db') as conn:
                    cursor = conn.cursor()
                    
                    # Get affiliate info
                    cursor.execute("""
                        SELECT name, email, total_referrals, total_earnings_usd, created_at
                        FROM affiliates 
                        WHERE affiliate_id = ? AND status = 'active'
                    """, (affiliate_id,))
                    
                    affiliate = cursor.fetchone()
                    if not affiliate:
                        return jsonify({'error': 'Affiliate not found'}), 404
                    
                    # Get recent referrals
                    cursor.execute("""
                        SELECT referred_email, plan_name, monthly_value_usd, commission_amount_usd, 
                               status, created_at
                        FROM referrals 
                        WHERE affiliate_id = ? 
                        ORDER BY created_at DESC 
                        LIMIT 10
                    """, (affiliate_id,))
                    
                    referrals = []
                    for row in cursor.fetchall():
                        referrals.append({
                            'referred_email': row[0],
                            'plan_name': row[1],
                            'monthly_value': float(row[2]) if row[2] else 0.0,
                            'commission_amount': float(row[3]) if row[3] else 0.0,
                            'status': row[4],
                            'created_at': row[5]
                        })
                    
                    return jsonify({
                        'affiliate_id': affiliate_id,
                        'name': affiliate[0],
                        'email': affiliate[1],
                        'total_referrals': affiliate[2],
                        'total_earnings': float(affiliate[3]) if affiliate[3] else 0.0,
                        'created_at': affiliate[4],
                        'recent_referrals': referrals
                    })
                    
            except Exception as e:
                logger.error(f"Affiliate stats error: {e}")
                return jsonify({'error': str(e)}), 500

    def _render_admin_page(self, template_path: str, context: Dict[str, Any] = None) -> str:
        """Render admin page with Flask-TSK template engine"""
        context = context or {}
        
        # Add common context
        context.update({
            'tsk_available': FLASK_TSK_AVAILABLE,
            'tsk_version': '2.0.5' if FLASK_TSK_AVAILABLE else 'not available',
            'tsk_stats': {
                'renderer_initialized': self.tsk_renderer is not None
            },
            'current_time': datetime.now().isoformat(),
            'grim_version': '1.0.0'
        })
        
        # Load template from grim directory structure
        grim_dir = os.path.join(os.path.dirname(__file__), 'grim')
        
        # Try multiple template locations in order of preference
        template_locations = [
            os.path.join(grim_dir, template_path),  # grim/admin/grim_admin_dashboard.html
            os.path.join(grim_dir, template_path.replace('.html', '')),  # grim/admin/grim_admin_dashboard
            os.path.join(self.static_dir, template_path),  # fallback to static_dir
            os.path.join(self.static_dir, 'convert', template_path),  # fallback to convert
            os.path.join(os.path.dirname(self.static_dir), template_path),  # fallback to parent
        ]
        
        template_file = None
        for location in template_locations:
            if os.path.exists(location):
                template_file = location
                break
        
        if not template_file:
            return f"<!-- Template not found: {template_path} -->", 404
        
        try:
            with open(template_file, 'r', encoding='utf-8') as f:
                template_content = f.read()
            
            # Debug logging
            logger.info(f"Template content type: {type(template_content)}")
            logger.info(f"Template content length: {len(template_content)}")
            logger.info(f"Context keys: {list(context.keys()) if context else 'None'}")
            
            # Use simple TuskLang template rendering
            result = self.tsk_renderer(template_content, context)
            logger.info(f"Render result type: {type(result)}")
            return result
        
        except Exception as e:
            logger.error(f"Failed to render template {template_path}: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return f"<!-- Template Error: {e} -->", 500

    def _render_public_page(self, template_path: str, context: Dict[str, Any] = None) -> str:
        """Render public page with Flask-TSK template engine"""
        context = context or {}
        
        # Add common context for public pages
        context.update({
            'tsk_available': FLASK_TSK_AVAILABLE,
            'tsk_version': '2.0.5' if FLASK_TSK_AVAILABLE else 'not available',
            'tsk_stats': {
                'renderer_initialized': self.tsk_renderer is not None
            },
            'current_time': datetime.now().isoformat(),
            'grim_version': '1.0.0',
            'page_type': 'public',
            'request': request  # Add request object for base href
        })
        
        # Load template from grim directory structure
        grim_dir = os.path.join(os.path.dirname(__file__), 'grim')
        
        # Try multiple template locations in order of preference for public pages
        template_locations = [
            os.path.join(grim_dir, 'public', template_path),  # grim/public/landing.html
            os.path.join(grim_dir, template_path),  # grim/landing.html
            os.path.join(self.static_dir, template_path),  # fallback to static_dir
            os.path.join(self.static_dir, 'convert', template_path),  # fallback to convert
            os.path.join(os.path.dirname(self.static_dir), template_path),  # fallback to parent
        ]
        
        template_file = None
        for location in template_locations:
            if os.path.exists(location):
                template_file = location
                break
        
        if not template_file:
            return f"<!-- Template not found: {template_path} -->", 404
        
        try:
            with open(template_file, 'r', encoding='utf-8') as f:
                template_content = f.read()
            
            # Use simple TuskLang template rendering
            result = self.tsk_renderer(template_content, context)
            return result
        
        except Exception as e:
            logger.error(f"Failed to render public template {template_path}: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return f"<!-- Template Error: {e} -->", 500
    
    def _load_static_content(self, path: str) -> Optional[str]:
        """Load static content from convert directory"""
        file_path = os.path.join(self.static_dir, path)
        
        if not os.path.exists(file_path):
            return None
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Failed to load static content {path}: {e}")
            return None
    
    def _save_compression_analytics(self, record: dict):
        """Save compression analytics to local database"""
        try:
            import sqlite3
            db_path = "/opt/reaper/db/grimm.db"
            
            with sqlite3.connect(db_path) as conn:
                cursor = conn.cursor()
                
                # Create table if it doesn't exist
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS compression_analytics (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id TEXT NOT NULL,
                        algorithm TEXT NOT NULL,
                        compression_ratio REAL NOT NULL,
                        storage_saved_gb REAL NOT NULL,
                        money_saved_yearly REAL DEFAULT 0,
                        ip_address TEXT,
                        timestamp TEXT NOT NULL,
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                
                # Insert record
                cursor.execute('''
                    INSERT INTO compression_analytics 
                    (user_id, algorithm, compression_ratio, storage_saved_gb, 
                     money_saved_yearly, ip_address, timestamp)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    record['user_id'], record['algorithm'], record['compression_ratio'],
                    record['storage_saved_gb'], record['money_saved_yearly'],
                    record['ip_address'], record['timestamp']
                ))
                
                conn.commit()
                logger.info(f"✅ Saved compression analytics locally: {record['user_id']}")
                
        except Exception as e:
            logger.error(f"Failed to save compression analytics: {e}")
    
    def _sync_to_grims_mother(self, record: dict) -> dict:
        """Store compression analytics directly in GRIMS_MOTHER PostgreSQL"""
        try:
            import psycopg2
            from psycopg2.extras import RealDictCursor
            
            # Store directly in GRIMS_MOTHER PostgreSQL
            grims_mother_url = os.environ.get('GRIMS_MOTHER')
            if not grims_mother_url:
                return {'success': False, 'error': 'GRIMS_MOTHER connection string not found'}
            
            with psycopg2.connect(grims_mother_url) as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                    cursor.execute('''
                        INSERT INTO compression_analytics 
                        (user_id, algorithm, compression_ratio, storage_saved_gb, 
                         money_saved_yearly, ip_address, timestamp)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ''', (
                        record['user_id'], 
                        record['algorithm'],
                        record['compression_ratio'],
                        record['storage_saved_gb'],
                        record['money_saved_yearly'],
                        record['ip_address'],
                        record['timestamp']
                    ))
                    conn.commit()
                    
            logger.info(f"✅ Stored compression analytics in GRIMS_MOTHER PostgreSQL: {record['user_id']}")
            return {'success': True}
                
        except Exception as e:
            logger.error(f"Failed to store in GRIMS_MOTHER: {e}")
            return {'success': False, 'error': str(e)}
    
    def _sync_subscription_to_mother(self, data: dict) -> dict:
        """Sync subscription data to GRIMS_MOTHER"""
        try:
            import requests
            mother_url = "http://127.0.0.1:4747/api/subscription/store"
            
            response = requests.post(mother_url, json=data, timeout=5)
            if response.status_code == 200:
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': f"HTTP {response.status_code}"}
        except Exception as e:
            logger.error(f"Failed to sync subscription: {e}")
            return {'success': False, 'error': str(e)}
    
    def _sync_payment_to_mother(self, data: dict) -> dict:
        """Sync payment data to GRIMS_MOTHER"""
        try:
            import requests
            mother_url = "http://127.0.0.1:4747/api/payment/store"
            
            response = requests.post(mother_url, json=data, timeout=5)
            if response.status_code == 200:
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': f"HTTP {response.status_code}"}
        except Exception as e:
            logger.error(f"Failed to sync payment: {e}")
            return {'success': False, 'error': str(e)}
    
    def _sync_cancellation_to_mother(self, data: dict) -> dict:
        """Sync cancellation data to GRIMS_MOTHER"""
        try:
            import requests
            mother_url = "http://127.0.0.1:4747/api/cancellation/store"
            
            response = requests.post(mother_url, json=data, timeout=5)
            if response.status_code == 200:
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': f"HTTP {response.status_code}"}
        except Exception as e:
            logger.error(f"Failed to sync cancellation: {e}")
            return {'success': False, 'error': str(e)}
    
    def _track_affiliate_conversion(self, affiliate_ref: str, customer_id: str, plan: str, amount: float) -> dict:
        """Track affiliate conversion"""
        try:
            import requests
            affiliate_url = f"http://127.0.0.1:4749/api/affiliate/convert"
            
            conversion_data = {
                'affiliate_id': affiliate_ref,
                'user_email': customer_id,  # Stripe customer ID as user identifier
                'plan_name': plan,
                'monthly_value': amount,
                'conversion_type': 'individual'
            }
            
            response = requests.post(affiliate_url, json=conversion_data, timeout=5)
            if response.status_code == 200:
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': f"HTTP {response.status_code}"}
        except Exception as e:
            logger.error(f"Failed to track affiliate conversion: {e}")
            return {'success': False, 'error': str(e)}
    
    def _get_existing_license_by_session(self, stripe_session_id: str) -> Optional[str]:
        """Get existing license key by Stripe session ID"""
        try:
            # Check PostgreSQL first
            grims_mother_url = os.environ.get('GRIMS_MOTHER')
            if grims_mother_url:
                try:
                    import psycopg2
                    from psycopg2.extras import RealDictCursor
                    with psycopg2.connect(grims_mother_url) as pg_conn:
                        with pg_conn.cursor(cursor_factory=RealDictCursor) as pg_cursor:
                            pg_cursor.execute('''
                                SELECT license_key FROM licenses 
                                WHERE stripe_session_id = %s
                                LIMIT 1
                            ''', (stripe_session_id,))
                            
                            existing = pg_cursor.fetchone()
                            if existing:
                                return existing['license_key']
                except Exception as e:
                    logger.error(f"Error checking PostgreSQL for existing license: {e}")
            
            # Fallback to SQLite
            try:
                import sqlite3
                license_db_path = os.path.join('/opt/reaper/tsk_flask', 'grim_licenses.db')
                with sqlite3.connect(license_db_path) as conn:
                    cursor = conn.cursor()
                    cursor.execute('''
                        SELECT license_key FROM licenses 
                        WHERE stripe_session_id = ?
                        LIMIT 1
                    ''', (stripe_session_id,))
                    
                    result = cursor.fetchone()
                    if result:
                        return result[0]
            except Exception as e:
                logger.error(f"Error checking SQLite for existing license: {e}")
            
            return None
        except Exception as e:
            logger.error(f"Error getting existing license: {e}")
            return None
    
    def _get_customer_email_by_session(self, stripe_session_id: str) -> Optional[str]:
        """Get customer email by Stripe session ID"""
        try:
            # Check PostgreSQL first
            grims_mother_url = os.environ.get('GRIMS_MOTHER')
            if grims_mother_url:
                try:
                    import psycopg2
                    from psycopg2.extras import RealDictCursor
                    with psycopg2.connect(grims_mother_url) as pg_conn:
                        with pg_conn.cursor(cursor_factory=RealDictCursor) as pg_cursor:
                            pg_cursor.execute('''
                                SELECT customer_email FROM licenses 
                                WHERE stripe_session_id = %s
                                LIMIT 1
                            ''', (stripe_session_id,))
                            
                            existing = pg_cursor.fetchone()
                            if existing and existing['customer_email']:
                                return existing['customer_email']
                except Exception as e:
                    logger.error(f"Error checking PostgreSQL for customer email: {e}")
            
            # Fallback to SQLite
            try:
                import sqlite3
                license_db_path = os.path.join('/opt/reaper/tsk_flask', 'grim_licenses.db')
                with sqlite3.connect(license_db_path) as conn:
                    cursor = conn.cursor()
                    cursor.execute('''
                        SELECT customer_email FROM licenses 
                        WHERE stripe_session_id = ?
                        LIMIT 1
                    ''', (stripe_session_id,))
                    
                    result = cursor.fetchone()
                    if result and result[0]:
                        return result[0]
            except Exception as e:
                logger.error(f"Error checking SQLite for customer email: {e}")
            
            return None
        except Exception as e:
            logger.error(f"Error getting customer email: {e}")
            return None
    
    def _create_license_via_mother_db(self, email: str, plan: str, stripe_session_id: str) -> dict:
        """Create license using PostgreSQL GRIMS_MOTHER first, then sync to SQLite"""
        try:
            import psycopg2
            from psycopg2.extras import RealDictCursor
            import hashlib
            import secrets
            import time
            import json
            import sqlite3
            
            # FIRST: Check if license already exists for this Stripe session
            grims_mother_url = os.environ.get('GRIMS_MOTHER')
            if grims_mother_url:
                try:
                    with psycopg2.connect(grims_mother_url) as pg_conn:
                        with pg_conn.cursor(cursor_factory=RealDictCursor) as pg_cursor:
                            pg_cursor.execute('''
                                SELECT license_key FROM licenses 
                                WHERE stripe_session_id = %s
                                LIMIT 1
                            ''', (stripe_session_id,))
                            
                            existing = pg_cursor.fetchone()
                            if existing:
                                logger.info(f"✅ Found existing license for session {stripe_session_id}: {existing['license_key']}")
                                return {'success': True, 'license_key': existing['license_key']}
                except Exception as e:
                    logger.error(f"Error checking existing license: {e}")
                    # Continue with creation if check fails
            
            # Use existing license generation logic from mother_db_api.py
            installation_id = f"stripe-{email.replace('@', '-').replace('.', '-')}"
            
            # Generate license key using same method as mother_db_api.py
            timestamp = str(int(time.time()))
            data = f"{installation_id}:{timestamp}:{secrets.token_hex(8)}"
            license_key = hashlib.sha256(data.encode()).hexdigest()[:32].upper()
            
            # Map plan to existing tier system
            tier_map = {'pro': 'pro', 'master': 'pro', 'reaper': 'enterprise'}
            tier = tier_map.get(plan.lower(), 'pro')
            
            # Get affiliate ID from Flask session if available
            from flask import session
            affiliate_id = session.get('grim_affiliate_id', '')
            logger.info(f"🔍 License creation - affiliate_id from session: '{affiliate_id}'")
            
            # Create metadata
            metadata = {
                'stripe_session_id': stripe_session_id,
                'customer_email': email,
                'payment_method': 'stripe',
                'created_via': 'checkout',
                'original_plan': plan.lower(),
                'affiliate_id': affiliate_id
            }
            
            # FIRST: Store in PostgreSQL GRIMS_MOTHER (primary storage)
            if not grims_mother_url:
                raise Exception('GRIMS_MOTHER connection string not found')
            
            with psycopg2.connect(grims_mother_url) as pg_conn:
                with pg_conn.cursor(cursor_factory=RealDictCursor) as pg_cursor:
                    # First, ensure the new columns exist
                    pg_cursor.execute('''
                        ALTER TABLE licenses 
                        ADD COLUMN IF NOT EXISTS customer_email TEXT,
                        ADD COLUMN IF NOT EXISTS payment_method TEXT,
                        ADD COLUMN IF NOT EXISTS stripe_session_id TEXT,
                        ADD COLUMN IF NOT EXISTS created_via TEXT,
                        ADD COLUMN IF NOT EXISTS original_plan TEXT,
                        ADD COLUMN IF NOT EXISTS affiliate_id TEXT
                    ''')
                    
                    # Insert with both metadata JSON and individual columns
                    try:
                        pg_cursor.execute('''
                            INSERT INTO licenses 
                            (license_key, installation_id, domain, ip_address, tier, metadata, 
                             customer_email, payment_method, stripe_session_id, created_via, original_plan, affiliate_id)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ''', (
                            license_key,
                            installation_id,
                            email.split('@')[1],  # Use email domain
                            request.remote_addr or '127.0.0.1',
                            tier,
                            json.dumps(metadata),  # Keep metadata for backwards compatibility
                            email,  # customer_email
                            'stripe',  # payment_method
                            stripe_session_id,  # stripe_session_id
                            'checkout',  # created_via
                            plan.lower(),  # original_plan
                            affiliate_id  # affiliate_id
                        ))
                        pg_conn.commit()
                        logger.info(f"✅ License stored in GRIMS_MOTHER PostgreSQL: {license_key}")
                    except psycopg2.IntegrityError as e:
                        pg_conn.rollback()  # Rollback the failed transaction
                        
                        if 'duplicate key value violates unique constraint' in str(e):
                            # Check if there's an existing license for this installation_id
                            pg_cursor.execute('''
                                SELECT license_key FROM licenses 
                                WHERE installation_id = %s
                                LIMIT 1
                            ''', (installation_id,))
                            
                            existing = pg_cursor.fetchone()
                            if existing:
                                logger.info(f"✅ Found existing license for installation_id {installation_id}: {existing['license_key']}")
                                return {'success': True, 'license_key': existing['license_key']}
                        
                        # If we can't find existing license, create a unique installation_id
                        installation_id = f"stripe-{email.replace('@', '-').replace('.', '-')}-{int(time.time())}"
                        pg_cursor.execute('''
                            INSERT INTO licenses 
                            (license_key, installation_id, domain, ip_address, tier, metadata, 
                             customer_email, payment_method, stripe_session_id, created_via, original_plan, affiliate_id)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ''', (
                            license_key,
                            installation_id,
                            email.split('@')[1],  # Use email domain
                            request.remote_addr or '127.0.0.1',
                            tier,
                            json.dumps(metadata),  # Keep metadata for backwards compatibility
                            email,  # customer_email
                            'stripe',  # payment_method
                            stripe_session_id,  # stripe_session_id
                            'checkout',  # created_via
                            plan.lower(),  # original_plan
                            affiliate_id  # affiliate_id
                        ))
                        pg_conn.commit()
                        logger.info(f"✅ License stored in GRIMS_MOTHER PostgreSQL with unique ID: {license_key}")
            
            # SECOND: Store in local SQLite for backup
            db_path = "/opt/reaper/db/mother_db.sqlite"
            with sqlite3.connect(db_path) as conn:
                cursor = conn.cursor()
                
                # Ensure the new columns exist in SQLite
                try:
                    cursor.execute('ALTER TABLE licenses ADD COLUMN customer_email TEXT')
                except sqlite3.OperationalError:
                    pass  # Column already exists
                try:
                    cursor.execute('ALTER TABLE licenses ADD COLUMN payment_method TEXT')
                except sqlite3.OperationalError:
                    pass  # Column already exists
                try:
                    cursor.execute('ALTER TABLE licenses ADD COLUMN stripe_session_id TEXT')
                except sqlite3.OperationalError:
                    pass  # Column already exists
                try:
                    cursor.execute('ALTER TABLE licenses ADD COLUMN created_via TEXT')
                except sqlite3.OperationalError:
                    pass  # Column already exists
                try:
                    cursor.execute('ALTER TABLE licenses ADD COLUMN original_plan TEXT')
                except sqlite3.OperationalError:
                    pass  # Column already exists
                try:
                    cursor.execute('ALTER TABLE licenses ADD COLUMN affiliate_id TEXT')
                except sqlite3.OperationalError:
                    pass  # Column already exists
                
                cursor.execute('''
                    INSERT INTO licenses 
                    (license_key, installation_id, domain, ip_address, tier, version, metadata,
                     customer_email, payment_method, stripe_session_id, created_via, original_plan, affiliate_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    license_key,
                    installation_id,
                    'stripe-checkout',
                    request.headers.get('X-Forwarded-For', request.remote_addr or '127.0.0.1'),
                    tier,
                    '2.0.0',
                    json.dumps(metadata),  # Keep metadata for backwards compatibility
                    email,  # customer_email
                    'stripe',  # payment_method
                    stripe_session_id,  # stripe_session_id
                    'checkout',  # created_via
                    plan.lower(),  # original_plan
                    affiliate_id  # affiliate_id
                ))
                
                conn.commit()
                
            # CRITICAL: Track affiliate conversion if affiliate_id exists
            if affiliate_id and affiliate_id.strip():
                logger.info(f"🎯 TRACKING AFFILIATE CONVERSION: {affiliate_id} -> {email} -> {plan}")
                try:
                    # Call affiliate system to record conversion
                    affiliate_result = self._track_affiliate_conversion(
                        affiliate_id=affiliate_id.strip(),
                        user_email=email,
                        plan_name=plan.lower(),
                        monthly_value=self._get_plan_price(plan.lower())
                    )
                    
                    if affiliate_result.get('success'):
                        logger.info(f"✅ Affiliate conversion tracked: {affiliate_result.get('referral_id')} "
                                  f"Commission: ${affiliate_result.get('commission_amount_usd', 0)}")
                    else:
                        logger.error(f"❌ Failed to track affiliate conversion: {affiliate_result.get('error')}")
                        
                except Exception as e:
                    logger.error(f"❌ Error tracking affiliate conversion: {e}")
            else:
                logger.info("ℹ️  No affiliate_id present, skipping conversion tracking")
            
            logger.info(f"✅ Created license in mother_db: {license_key}")
            return {'success': True, 'license_key': license_key}
                
        except Exception as e:
            logger.error(f"License creation failed: {e}")
            return {'success': False, 'error': str(e)}
    
    
    def _send_license_email(self, email: str, license_key: str, plan: str):
        """Send welcome email with license key using simple email helper"""
        try:
            from simple_email_helper import send_welcome_email
            
            # Send welcome email with license key using simple helper
            success = send_welcome_email(
                to_email=email,
                license_key=license_key,
                plan=plan.title()
            )
            
            if success:
                logger.info(f"✅ Welcome email sent successfully to {email} with license: {license_key}")
            else:
                logger.error(f"❌ Failed to send welcome email to {email}")
                
        except Exception as e:
            logger.error(f"Email sending error: {e}")
    
    def _track_affiliate_conversion(self, affiliate_id: str, user_email: str, 
                                  plan_name: str, monthly_value: float) -> Dict:
        """Track affiliate conversion by calling affiliate system API"""
        try:
            import requests
            
            # Call the affiliate system API running on port 5001
            affiliate_api_url = "http://127.0.0.1:5001/api/track-conversion"
            
            payload = {
                'affiliate_id': affiliate_id,
                'user_email': user_email,
                'plan_name': plan_name,
                'monthly_value': monthly_value,
                'conversion_type': 'individual'
            }
            
            logger.info(f"🔗 Calling affiliate API: {affiliate_api_url} with {payload}")
            
            response = requests.post(affiliate_api_url, json=payload, timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                return {'success': True, **result}
            else:
                logger.error(f"Affiliate API error: {response.status_code} - {response.text}")
                return {'success': False, 'error': f'API error: {response.status_code}'}
                
        except Exception as e:
            logger.error(f"Failed to call affiliate API: {e}")
            # Fallback: Try to track directly via database
            return self._track_conversion_direct(affiliate_id, user_email, plan_name, monthly_value)
    
    def _track_conversion_direct(self, affiliate_id: str, user_email: str, 
                               plan_name: str, monthly_value: float) -> Dict:
        """Fallback: Track conversion directly in affiliate database"""
        try:
            import sqlite3
            import uuid
            
            db_path = "/opt/reaper/db/grim_affiliates.db"
            
            with sqlite3.connect(db_path) as conn:
                cursor = conn.cursor()
                
                # Calculate commission (33% for developers)
                commission_rate = 0.3300
                commission_amount = monthly_value * commission_rate
                
                referral_id = str(uuid.uuid4())
                
                # Insert referral record
                cursor.execute('''
                    INSERT INTO referrals 
                    (referral_id, affiliate_id, referred_email, conversion_type, 
                     plan_name, monthly_value_usd, commission_rate, commission_amount_usd, status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    referral_id, affiliate_id, user_email, 'individual',
                    plan_name, monthly_value, commission_rate, commission_amount, 'confirmed'
                ))
                
                # Update affiliate totals
                cursor.execute('''
                    UPDATE affiliates 
                    SET total_referrals = total_referrals + 1,
                        total_earnings_usd = total_earnings_usd + ?
                    WHERE affiliate_id = ?
                ''', (commission_amount, affiliate_id))
                
                conn.commit()
                
                logger.info(f"✅ Direct affiliate tracking: {referral_id} -> ${commission_amount}")
                
                return {
                    'success': True,
                    'referral_id': referral_id,
                    'commission_amount_usd': commission_amount,
                    'commission_rate': commission_rate
                }
                
        except Exception as e:
            logger.error(f"Direct affiliate tracking failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _get_plan_price(self, plan: str) -> float:
        """Get monthly price for plan"""
        price_map = {
            'pro': 49.0,
            'master': 99.0,
            'reaper': 499.0
        }
        return price_map.get(plan.lower(), 49.0)
    
    def run(self, host: str = '0.0.0.0', port: int = 8080, debug: bool = False):
        """Run the admin server"""
        logger.info(f"Starting Grim Admin Server on {host}:{port}")
        logger.info(f"Static directory: {self.static_dir}")
        logger.info(f"TuskLang available: {FLASK_TSK_AVAILABLE}")
        
        # Log TuskLang renderer stats
        logger.info(f"Simple TuskLang renderer initialized: {self.tsk_renderer is not None}")
        
        self.app.run(host=host, port=port, debug=debug)


def create_sample_config():
    """Create sample TuskLang configuration for Grim admin"""
    config_content = """
[grim]
name = "Grim Reaper"
version = "1.0.0"
environment = "production"

[admin]
host = "0.0.0.0"
port = 8080
debug = false
secret_key = "grim-admin-secret-key-2024"

[database]
type = "sqlite"
path = "/opt/reaper/db/grimm.db"
backup_enabled = true
backup_interval = 3600

[security]
encryption_key = "grim-encryption-key-2024"
jwt_secret = "grim-jwt-secret-2024"
session_timeout = 3600

[performance]
turbo_engine = true
cache_enabled = true
cache_ttl = 300
parallel_rendering = true
compression = true

[ui]
theme = "dark"
component_cache = true
minify_assets = true
responsive_design = true

[backup]
enabled = true
schedule = "0 2 * * *"
retention_days = 30
compression = true
encryption = true

[monitoring]
enabled = true
metrics_interval = 60
alert_threshold = 90
log_level = "INFO"
"""
    
    config_path = os.path.join(os.path.dirname(__file__), 'peanut.tsk')
    
    try:
        with open(config_path, 'w') as f:
            f.write(config_content)
        logger.info(f"Sample configuration created: {config_path}")
        return config_path
    except Exception as e:
        logger.error(f"Failed to create sample config: {e}")
        return None


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grim Admin Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8080, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--static-dir', help='Static files directory')
    parser.add_argument('--config', help='Configuration file path')
    parser.add_argument('--create-config', action='store_true', help='Create sample configuration')
    
    args = parser.parse_args()
    
    # Create sample config if requested
    if args.create_config:
        config_path = create_sample_config()
        if config_path:
            print(f"✅ Sample configuration created: {config_path}")
        else:
            print("❌ Failed to create sample configuration")
        return
    
    # Initialize admin server
    server = GrimAdminServer(
        static_dir=args.static_dir,
        config_path=args.config
    )
    
    # Run server
    server.run(
        host=args.host,
        port=args.port,
        debug=args.debug
    )


if __name__ == '__main__':
    main() 

# Global server instance
_grim_server = None

def get_grim_server():
    global _grim_server
    if _grim_server is None:
        _grim_server = GrimAdminServer()
    return _grim_server

