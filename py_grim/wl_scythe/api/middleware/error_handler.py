"""
Error handling middleware for Scythe API
"""

from flask import jsonify, request, g
import logging
import traceback
from datetime import datetime
from typing import Dict, Any

logger = logging.getLogger(__name__)

def error_handler_middleware(error):
    """Global error handler middleware"""
    
    # Log the error
    error_data = {
        'error_type': type(error).__name__,
        'error_message': str(error),
        'endpoint': request.endpoint,
        'method': request.method,
        'path': request.path,
        'user_id': getattr(g, 'user_id', None),
        'timestamp': datetime.utcnow().isoformat(),
        'traceback': traceback.format_exc()
    }
    
    logger.error(f"API Error: {error_data}")
    
    # Determine status code based on error type
    if hasattr(error, 'code'):
        status_code = error.code
    elif isinstance(error, ValueError):
        status_code = 400
    elif isinstance(error, PermissionError):
        status_code = 403
    elif isinstance(error, FileNotFoundError):
        status_code = 404
    elif isinstance(error, TimeoutError):
        status_code = 408
    else:
        status_code = 500
    
    # Create error response
    error_response = {
        'error': {
            'type': type(error).__name__,
            'message': str(error),
            'status_code': status_code,
            'timestamp': datetime.utcnow().isoformat(),
            'request_id': getattr(g, 'request_id', None)
        }
    }
    
    # Add additional context for development
    if hasattr(g, 'app') and g.app.config.get('DEBUG', False):
        error_response['error']['traceback'] = traceback.format_exc()
        error_response['error']['endpoint'] = request.endpoint
        error_response['error']['method'] = request.method
    
    return jsonify(error_response), status_code

def handle_validation_error(error):
    """Handle validation errors"""
    return jsonify({
        'error': {
            'type': 'ValidationError',
            'message': 'Invalid request data',
            'details': error.messages,
            'status_code': 400,
            'timestamp': datetime.utcnow().isoformat()
        }
    }), 400

def handle_database_error(error):
    """Handle database errors"""
    logger.error(f"Database error: {error}")
    
    return jsonify({
        'error': {
            'type': 'DatabaseError',
            'message': 'Database operation failed',
            'status_code': 500,
            'timestamp': datetime.utcnow().isoformat()
        }
    }), 500

def handle_storage_error(error):
    """Handle storage-related errors"""
    logger.error(f"Storage error: {error}")
    
    return jsonify({
        'error': {
            'type': 'StorageError',
            'message': 'Storage operation failed',
            'status_code': 500,
            'timestamp': datetime.utcnow().isoformat()
        }
    }), 500

def handle_license_error(error):
    """Handle license-related errors"""
    logger.error(f"License error: {error}")
    
    return jsonify({
        'error': {
            'type': 'LicenseError',
            'message': str(error),
            'status_code': 400,
            'timestamp': datetime.utcnow().isoformat()
        }
    }), 400

def handle_payment_error(error):
    """Handle payment-related errors"""
    logger.error(f"Payment error: {error}")
    
    return jsonify({
        'error': {
            'type': 'PaymentError',
            'message': 'Payment operation failed',
            'status_code': 400,
            'timestamp': datetime.utcnow().isoformat()
        }
    }), 400

def handle_webhook_error(error):
    """Handle webhook-related errors"""
    logger.error(f"Webhook error: {error}")
    
    return jsonify({
        'error': {
            'type': 'WebhookError',
            'message': 'Webhook delivery failed',
            'status_code': 500,
            'timestamp': datetime.utcnow().isoformat()
        }
    }), 500

def log_request_error(error: Exception, context: str = None):
    """Log request errors with context"""
    error_data = {
        'error_type': type(error).__name__,
        'error_message': str(error),
        'context': context,
        'endpoint': request.endpoint,
        'method': request.method,
        'path': request.path,
        'user_id': getattr(g, 'user_id', None),
        'ip_address': request.remote_addr,
        'user_agent': request.headers.get('User-Agent'),
        'timestamp': datetime.utcnow().isoformat()
    }
    
    logger.error(f"Request Error: {error_data}")
    
    # Send webhook notification for critical errors
    if status_code >= 500:
        send_error_webhook(error_data)

def send_error_webhook(error_data: Dict[str, Any]):
    """Send error notification webhook"""
    try:
        # This would be implemented to send webhook notifications
        # for critical errors to monitoring systems
        pass
    except Exception as e:
        logger.error(f"Failed to send error webhook: {e}")

def create_error_response(error_type: str, message: str, status_code: int = 400, 
                         details: Dict[str, Any] = None) -> tuple:
    """Create standardized error response"""
    error_response = {
        'error': {
            'type': error_type,
            'message': message,
            'status_code': status_code,
            'timestamp': datetime.utcnow().isoformat()
        }
    }
    
    if details:
        error_response['error']['details'] = details
    
    return jsonify(error_response), status_code

# Common error responses
def bad_request(message: str = "Bad request", details: Dict[str, Any] = None):
    """400 Bad Request"""
    return create_error_response('BadRequest', message, 400, details)

def unauthorized(message: str = "Unauthorized"):
    """401 Unauthorized"""
    return create_error_response('Unauthorized', message, 401)

def forbidden(message: str = "Forbidden"):
    """403 Forbidden"""
    return create_error_response('Forbidden', message, 403)

def not_found(message: str = "Resource not found"):
    """404 Not Found"""
    return create_error_response('NotFound', message, 404)

def method_not_allowed(message: str = "Method not allowed"):
    """405 Method Not Allowed"""
    return create_error_response('MethodNotAllowed', message, 405)

def conflict(message: str = "Resource conflict"):
    """409 Conflict"""
    return create_error_response('Conflict', message, 409)

def unprocessable_entity(message: str = "Unprocessable entity", details: Dict[str, Any] = None):
    """422 Unprocessable Entity"""
    return create_error_response('UnprocessableEntity', message, 422, details)

def too_many_requests(message: str = "Too many requests", retry_after: int = None):
    """429 Too Many Requests"""
    error_response = {
        'error': {
            'type': 'TooManyRequests',
            'message': message,
            'status_code': 429,
            'timestamp': datetime.utcnow().isoformat()
        }
    }
    
    if retry_after:
        error_response['error']['retry_after'] = retry_after
    
    return jsonify(error_response), 429

def internal_server_error(message: str = "Internal server error"):
    """500 Internal Server Error"""
    return create_error_response('InternalServerError', message, 500)

def service_unavailable(message: str = "Service unavailable"):
    """503 Service Unavailable"""
    return create_error_response('ServiceUnavailable', message, 503) 