"""
Grimm Security Module
Comprehensive security framework for the Grimm backup system
"""

from .encryption import EncryptionManager
from .authentication import AuthenticationManager
from .auditing import AuditManager

__version__ = "1.0.0"
__author__ = "Grimm Security Team"

# Export main security classes
__all__ = [
    'EncryptionManager',
    'AuthenticationManager', 
    'AuditManager'
]

# Security configuration
SECURITY_CONFIG = {
    'encryption_algorithm': 'AES-256-GCM',
    'key_derivation_iterations': 100000,
    'session_timeout': 3600,  # 1 hour
    'max_login_attempts': 5,
    'lockout_duration': 900,  # 15 minutes
    'audit_retention_days': 365,
    'password_min_length': 12,
    'require_special_chars': True,
    'require_numbers': True,
    'require_uppercase': True
}

def get_security_manager():
    """Get configured security manager instance"""
    return {
        'encryption': EncryptionManager(),
        'auth': AuthenticationManager(),
        'audit': AuditManager()
    } 