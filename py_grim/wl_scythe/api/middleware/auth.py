"""
Authentication middleware for Scythe API
"""

import jwt
import hashlib
import time
from functools import wraps
from flask import request, jsonify, g, current_app
from typing import Optional, Dict, Any
import logging

logger = logging.getLogger(__name__)

def generate_token(user_id: str, permissions: list = None, expires_in: int = 3600) -> str:
    """Generate JWT token"""
    payload = {
        'user_id': user_id,
        'permissions': permissions or [],
        'exp': time.time() + expires_in,
        'iat': time.time()
    }
    return jwt.encode(payload, current_app.config['JWT_SECRET_KEY'], algorithm='HS256')

def verify_token(token: str) -> Optional[Dict[str, Any]]:
    """Verify JWT token"""
    try:
        payload = jwt.decode(token, current_app.config['JWT_SECRET_KEY'], algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("Token expired")
        return None
    except jwt.InvalidTokenError:
        logger.warning("Invalid token")
        return None

def hash_api_key(api_key: str) -> str:
    """Hash API key for storage"""
    return hashlib.sha256(api_key.encode()).hexdigest()

def verify_api_key(api_key: str, db_manager) -> Optional[Dict[str, Any]]:
    """Verify API key"""
    try:
        key_hash = hash_api_key(api_key)
        results = db_manager.execute_query(
            "SELECT * FROM api_keys WHERE key_hash = ? AND (expires_at IS NULL OR expires_at > datetime('now'))",
            (key_hash,)
        )
        if results:
            return results[0]
        return None
    except Exception as e:
        logger.error(f"Error verifying API key: {e}")
        return None

def auth_middleware():
    """Authentication middleware"""
    # Skip auth for health check and docs
    if request.endpoint in ['health_check', 'api_documentation']:
        return
    
    # Get authorization header
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return jsonify({'error': 'Authorization header required'}), 401
    
    # Check if it's a Bearer token
    if auth_header.startswith('Bearer '):
        token = auth_header[7:]  # Remove 'Bearer ' prefix
        payload = verify_token(token)
        if not payload:
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        g.user_id = payload['user_id']
        g.permissions = payload.get('permissions', [])
        g.auth_type = 'jwt'
    
    # Check if it's an API key
    elif auth_header.startswith('ApiKey '):
        api_key = auth_header[8:]  # Remove 'ApiKey ' prefix
        from ..utils.database import DatabaseManager
        db_manager = DatabaseManager()
        api_key_data = verify_api_key(api_key, db_manager)
        if not api_key_data:
            return jsonify({'error': 'Invalid API key'}), 401
        
        g.user_id = api_key_data['user_id']
        g.permissions = api_key_data['permissions'].split(',') if api_key_data['permissions'] else []
        g.auth_type = 'api_key'
    
    else:
        return jsonify({'error': 'Invalid authorization header format'}), 401

def require_auth(f):
    """Decorator to require authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not hasattr(g, 'user_id'):
            return jsonify({'error': 'Authentication required'}), 401
        return f(*args, **kwargs)
    return decorated_function

def require_permission(permission: str):
    """Decorator to require specific permission"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not hasattr(g, 'user_id'):
                return jsonify({'error': 'Authentication required'}), 401
            
            if not hasattr(g, 'permissions'):
                return jsonify({'error': 'Insufficient permissions'}), 403
            
            if permission not in g.permissions and 'admin' not in g.permissions:
                return jsonify({'error': f'Permission {permission} required'}), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def require_tier(tier: str):
    """Decorator to require minimum tier"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not hasattr(g, 'user_id'):
                return jsonify({'error': 'Authentication required'}), 401
            
            # Get user's tier from database
            from ..utils.database import DatabaseManager
            db_manager = DatabaseManager()
            
            # This would need to be implemented based on your user tier system
            # For now, we'll assume all authenticated users have access
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def get_current_user() -> Optional[Dict[str, Any]]:
    """Get current user information"""
    if not hasattr(g, 'user_id'):
        return None
    
    from ..utils.database import DatabaseManager
    db_manager = DatabaseManager()
    
    # This would need to be implemented based on your user system
    # For now, return basic user info
    return {
        'user_id': g.user_id,
        'permissions': getattr(g, 'permissions', []),
        'auth_type': getattr(g, 'auth_type', 'unknown')
    } 