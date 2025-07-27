"""
Configuration management for Scythe API
"""

import os
from typing import Dict, Any

class Config:
    """Base configuration class"""
    
    # Flask configuration
    SECRET_KEY = os.environ.get('SCYTHE_SECRET_KEY') or 'scythe-api-secret-key-2024'
    DEBUG = os.environ.get('SCYTHE_DEBUG', 'False').lower() == 'true'
    
    # Database configuration
    DATABASE_URL = os.environ.get('SCYTHE_DATABASE_URL') or 'sqlite:///scythe_api.db'
    
    # JWT configuration
    JWT_SECRET_KEY = os.environ.get('SCYTHE_JWT_SECRET') or 'scythe-jwt-secret-2024'
    JWT_ACCESS_TOKEN_EXPIRES = 3600  # 1 hour
    JWT_REFRESH_TOKEN_EXPIRES = 2592000  # 30 days
    
    # Rate limiting
    RATELIMIT_DEFAULT = "200 per day"
    RATELIMIT_STORAGE_ENDPOINTS = "100 per hour"
    RATELIMIT_LICENSE_ENDPOINTS = "50 per hour"
    
    # Storage configuration
    MAX_FILE_SIZE = int(os.environ.get('SCYTHE_MAX_FILE_SIZE', 100 * 1024 * 1024))  # 100MB
    ALLOWED_EXTENSIONS = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'zip', 'tar', 'gz'}
    
    # Webhook configuration
    WEBHOOK_SECRET = os.environ.get('SCYTHE_WEBHOOK_SECRET') or 'scythe-webhook-secret'
    WEBHOOK_TIMEOUT = 30  # seconds
    
    # Logging
    LOG_LEVEL = os.environ.get('SCYTHE_LOG_LEVEL', 'INFO')
    LOG_FILE = os.environ.get('SCYTHE_LOG_FILE', 'logs/scythe_api.log')
    
    # CORS
    CORS_ORIGINS = os.environ.get('SCYTHE_CORS_ORIGINS', '*').split(',')
    
    # API versioning
    API_VERSION = '1.0.0'
    API_PREFIX = '/scythe'
    
    # Pagination
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 100
    
    @staticmethod
    def get_storage_providers() -> Dict[str, Any]:
        """Get default storage providers configuration"""
        return {
            'local': {
                'name': 'Local Storage',
                'type': 'local',
                'enabled': True,
                'max_size': 1024 * 1024 * 1024 * 10,  # 10GB
                'path': '/var/scythe/storage'
            },
            's3': {
                'name': 'Amazon S3',
                'type': 's3',
                'enabled': False,
                'bucket': os.environ.get('SCYTHE_S3_BUCKET'),
                'region': os.environ.get('SCYTHE_S3_REGION', 'us-east-1'),
                'access_key': os.environ.get('SCYTHE_S3_ACCESS_KEY'),
                'secret_key': os.environ.get('SCYTHE_S3_SECRET_KEY')
            },
            'gcs': {
                'name': 'Google Cloud Storage',
                'type': 'gcs',
                'enabled': False,
                'bucket': os.environ.get('SCYTHE_GCS_BUCKET'),
                'credentials_file': os.environ.get('SCYTHE_GCS_CREDENTIALS_FILE')
            }
        }
    
    @staticmethod
    def get_tier_limits() -> Dict[str, Dict[str, int]]:
        """Get tier-based usage limits"""
        return {
            'FREE': {
                'storage_gb': 1,
                'api_calls_per_hour': 100,
                'file_size_mb': 10,
                'alerts_per_day': 5
            },
            'PRO': {
                'storage_gb': 10,
                'api_calls_per_hour': 500,
                'file_size_mb': 100,
                'alerts_per_day': 25
            },
            'MASTER': {
                'storage_gb': 100,
                'api_calls_per_hour': 2000,
                'file_size_mb': 500,
                'alerts_per_day': 100
            },
            'REAPER': {
                'storage_gb': 1000,
                'api_calls_per_hour': 10000,
                'file_size_mb': 2000,
                'alerts_per_day': 500
            }
        } 