"""
Rate limiting middleware for Scythe API
"""

from flask import request, jsonify, g
from functools import wraps
import time
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

# In-memory rate limit storage (in production, use Redis)
rate_limit_store = {}

def get_client_ip() -> str:
    """Get client IP address"""
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0]
    return request.remote_addr

def get_rate_limit_key() -> str:
    """Get rate limit key based on user or IP"""
    if hasattr(g, 'user_id'):
        return f"user:{g.user_id}"
    return f"ip:{get_client_ip()}"

def check_rate_limit(key: str, limit: int, window: int) -> bool:
    """Check if request is within rate limit"""
    current_time = time.time()
    
    if key not in rate_limit_store:
        rate_limit_store[key] = []
    
    # Remove expired entries
    rate_limit_store[key] = [t for t in rate_limit_store[key] if current_time - t < window]
    
    # Check if limit exceeded
    if len(rate_limit_store[key]) >= limit:
        return False
    
    # Add current request
    rate_limit_store[key].append(current_time)
    return True

def rate_limit_middleware():
    """Rate limiting middleware"""
    # Skip rate limiting for health check
    if request.endpoint == 'health_check':
        return
    
    # Get rate limit key
    key = get_rate_limit_key()
    
    # Define rate limits based on endpoint
    if request.path.startswith('/scythe/storage'):
        limit = 100  # requests per hour
        window = 3600  # 1 hour
    elif request.path.startswith('/scythe/validate'):
        limit = 50  # requests per hour
        window = 3600  # 1 hour
    elif request.path.startswith('/scythe/license'):
        limit = 20  # requests per hour
        window = 3600  # 1 hour
    else:
        limit = 200  # requests per day
        window = 86400  # 24 hours
    
    # Check rate limit
    if not check_rate_limit(key, limit, window):
        return jsonify({
            'error': 'Rate limit exceeded',
            'limit': limit,
            'window': window,
            'retry_after': window
        }), 429

def rate_limit(limit: int, window: int):
    """Decorator for custom rate limiting"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            key = get_rate_limit_key()
            
            if not check_rate_limit(key, limit, window):
                return jsonify({
                    'error': 'Rate limit exceeded',
                    'limit': limit,
                    'window': window,
                    'retry_after': window
                }), 429
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def tier_based_rate_limit():
    """Tier-based rate limiting"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not hasattr(g, 'user_id'):
                # For unauthenticated users, use default limits
                limit = 50
                window = 3600
            else:
                # Get user tier and apply appropriate limits
                # This would need to be implemented based on your tier system
                tier = get_user_tier(g.user_id)
                
                if tier == 'FREE':
                    limit = 50
                    window = 3600
                elif tier == 'PRO':
                    limit = 200
                    window = 3600
                elif tier == 'MASTER':
                    limit = 500
                    window = 3600
                elif tier == 'REAPER':
                    limit = 1000
                    window = 3600
                else:
                    limit = 50
                    window = 3600
            
            key = get_rate_limit_key()
            
            if not check_rate_limit(key, limit, window):
                return jsonify({
                    'error': 'Rate limit exceeded for your tier',
                    'limit': limit,
                    'window': window,
                    'retry_after': window
                }), 429
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def get_user_tier(user_id: str) -> str:
    """Get user tier (placeholder implementation)"""
    # This would need to be implemented based on your user tier system
    # For now, return a default tier
    return 'FREE'

def clear_rate_limits():
    """Clear all rate limits (useful for testing)"""
    global rate_limit_store
    rate_limit_store.clear()

def get_rate_limit_status(key: str) -> Dict[str, Any]:
    """Get current rate limit status for a key"""
    current_time = time.time()
    
    if key not in rate_limit_store:
        return {
            'key': key,
            'requests': 0,
            'limit': 200,
            'window': 86400,
            'remaining': 200
        }
    
    # Count requests in the last hour
    hour_ago = current_time - 3600
    requests_last_hour = len([t for t in rate_limit_store[key] if t > hour_ago])
    
    return {
        'key': key,
        'requests': requests_last_hour,
        'limit': 100,
        'window': 3600,
        'remaining': max(0, 100 - requests_last_hour)
    } 