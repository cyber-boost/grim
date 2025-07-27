"""
Logging utilities for Scythe API
"""

import logging
import os
from datetime import datetime
from typing import Optional

def setup_logger(name: str = 'scythe_api', level: str = 'INFO', log_file: Optional[str] = None) -> logging.Logger:
    """Setup logger for Scythe API"""
    
    # Create logs directory if it doesn't exist
    if log_file and not os.path.exists(os.path.dirname(log_file)):
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
    
    # Create logger
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper()))
    
    # Clear existing handlers
    logger.handlers.clear()
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # File handler (if log_file is specified)
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    return logger

def log_api_request(logger: logging.Logger, method: str, endpoint: str, status_code: int, 
                   user_id: Optional[str] = None, duration: Optional[float] = None):
    """Log API request details"""
    log_data = {
        'method': method,
        'endpoint': endpoint,
        'status_code': status_code,
        'user_id': user_id,
        'duration_ms': round(duration * 1000, 2) if duration else None,
        'timestamp': datetime.utcnow().isoformat()
    }
    
    if status_code >= 400:
        logger.warning(f"API Request: {log_data}")
    else:
        logger.info(f"API Request: {log_data}")

def log_storage_operation(logger: logging.Logger, operation: str, user_id: str, 
                         file_path: str, file_size: int, provider: str):
    """Log storage operations"""
    log_data = {
        'operation': operation,
        'user_id': user_id,
        'file_path': file_path,
        'file_size': file_size,
        'provider': provider,
        'timestamp': datetime.utcnow().isoformat()
    }
    logger.info(f"Storage Operation: {log_data}")

def log_license_operation(logger: logging.Logger, operation: str, license_key: str, 
                         user_id: str, status: str):
    """Log license operations"""
    log_data = {
        'operation': operation,
        'license_key': license_key[:8] + '...',  # Mask full key
        'user_id': user_id,
        'status': status,
        'timestamp': datetime.utcnow().isoformat()
    }
    logger.info(f"License Operation: {log_data}")

def log_payment_operation(logger: logging.Logger, operation: str, user_id: str, 
                         amount: float, currency: str, status: str):
    """Log payment operations"""
    log_data = {
        'operation': operation,
        'user_id': user_id,
        'amount': amount,
        'currency': currency,
        'status': status,
        'timestamp': datetime.utcnow().isoformat()
    }
    logger.info(f"Payment Operation: {log_data}")

def log_error(logger: logging.Logger, error: Exception, context: str = None, 
              user_id: Optional[str] = None):
    """Log errors with context"""
    log_data = {
        'error_type': type(error).__name__,
        'error_message': str(error),
        'context': context,
        'user_id': user_id,
        'timestamp': datetime.utcnow().isoformat()
    }
    logger.error(f"Error: {log_data}", exc_info=True) 