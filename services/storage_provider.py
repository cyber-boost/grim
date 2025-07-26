#!/usr/bin/env python3
"""
Storage Provider System for Grim Reaper Multi-Cloud Strategy
Implements base class and concrete providers for Hetzner, Backblaze, and Wasabi
"""

import os
import json
import time
import hashlib
import hmac
import base64
import logging
from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime, timedelta
from dataclasses import dataclass
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
import requests
from cryptography.fernet import Fernet
import sqlite3
from contextlib import contextmanager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class StorageMetrics:
    """Storage usage metrics for a provider"""
    total_bytes: int
    object_count: int
    last_updated: datetime
    cost_per_gb_monthly: float
    transfer_cost_per_gb: float

@dataclass
class HealthStatus:
    """Health status for a storage provider"""
    is_healthy: bool
    response_time_ms: int
    error_count: int
    last_check: datetime
    error_message: Optional[str] = None

@dataclass
class UploadResult:
    """Result of file upload operation"""
    success: bool
    file_path: str
    file_size: int
    provider_id: str
    upload_time_ms: int
    error_message: Optional[str] = None
    etag: Optional[str] = None

@dataclass
class DownloadResult:
    """Result of file download operation"""
    success: bool
    file_path: str
    file_size: int
    provider_id: str
    download_time_ms: int
    error_message: Optional[str] = None

class StorageProvider(ABC):
    """Abstract base class for storage providers"""
    
    def __init__(self, provider_id: str, config: Dict[str, Any]):
        self.provider_id = provider_id
        self.config = config
        self.client = None
        self.bucket_name = config.get('bucket_name', 'grim-backups')
        self.region = config.get('region', 'us-east-1')
        self.encryption_key = config.get('encryption_key')
        self.retry_attempts = config.get('retry_attempts', 3)
        self.retry_delay = config.get('retry_delay', 1)
        self.health_check_interval = config.get('health_check_interval', 300)  # 5 minutes
        self.last_health_check = None
        self.health_status = HealthStatus(True, 0, 0, datetime.now())
        
        # Initialize encryption if key provided
        if self.encryption_key:
            self.cipher = Fernet(self.encryption_key.encode())
        else:
            self.cipher = None
            
        self._initialize_client()
    
    @abstractmethod
    def _initialize_client(self):
        """Initialize the storage client"""
        pass
    
    @abstractmethod
    def upload_file(self, local_path: str, remote_path: str, metadata: Optional[Dict] = None) -> UploadResult:
        """Upload a file to storage"""
        pass
    
    @abstractmethod
    def download_file(self, remote_path: str, local_path: str) -> DownloadResult:
        """Download a file from storage"""
        pass
    
    @abstractmethod
    def delete_file(self, remote_path: str) -> bool:
        """Delete a file from storage"""
        pass
    
    @abstractmethod
    def get_usage_stats(self) -> StorageMetrics:
        """Get storage usage statistics"""
        pass
    
    @abstractmethod
    def list_files(self, prefix: str = "") -> List[str]:
        """List files in storage with optional prefix"""
        pass
    
    def check_health(self) -> HealthStatus:
        """Check provider health status"""
        if (self.last_health_check and 
            datetime.now() - self.last_health_check < timedelta(seconds=self.health_check_interval)):
            return self.health_status
        
        start_time = time.time()
        try:
            # Simple health check - try to list objects
            self.list_files(prefix="health-check")
            response_time = int((time.time() - start_time) * 1000)
            
            self.health_status = HealthStatus(
                is_healthy=True,
                response_time_ms=response_time,
                error_count=0,
                last_check=datetime.now()
            )
            
        except Exception as e:
            self.health_status.error_count += 1
            self.health_status = HealthStatus(
                is_healthy=False,
                response_time_ms=int((time.time() - start_time) * 1000),
                error_count=self.health_status.error_count,
                last_check=datetime.now(),
                error_message=str(e)
            )
            logger.error(f"Health check failed for {self.provider_id}: {e}")
        
        self.last_health_check = datetime.now()
        return self.health_status
    
    def _encrypt_credentials(self, credentials: Dict[str, str]) -> Dict[str, str]:
        """Encrypt sensitive credentials"""
        if not self.cipher:
            return credentials
        
        encrypted_creds = {}
        for key, value in credentials.items():
            if key in ['secret_access_key', 'api_secret', 'password']:
                encrypted_value = self.cipher.encrypt(value.encode())
                encrypted_creds[key] = base64.b64encode(encrypted_value).decode()
            else:
                encrypted_creds[key] = value
        
        return encrypted_creds
    
    def _decrypt_credentials(self, encrypted_creds: Dict[str, str]) -> Dict[str, str]:
        """Decrypt sensitive credentials"""
        if not self.cipher:
            return encrypted_creds
        
        decrypted_creds = {}
        for key, value in encrypted_creds.items():
            if key in ['secret_access_key', 'api_secret', 'password']:
                try:
                    encrypted_value = base64.b64decode(value.encode())
                    decrypted_value = self.cipher.decrypt(encrypted_value)
                    decrypted_creds[key] = decrypted_value.decode()
                except Exception as e:
                    logger.error(f"Failed to decrypt {key}: {e}")
                    decrypted_creds[key] = value
            else:
                decrypted_creds[key] = value
        
        return decrypted_creds

class HetznerStorage(StorageProvider):
    """Hetzner Cloud Object Storage implementation"""
    
    def _initialize_client(self):
        """Initialize Hetzner S3-compatible client"""
        try:
            access_key = self.config['access_key_id']
            secret_key = self.config['secret_access_key']
            endpoint_url = self.config['endpoint_url']
            
            self.client = boto3.client(
                's3',
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key,
                endpoint_url=endpoint_url,
                region_name=self.region
            )
            logger.info(f"Initialized Hetzner storage client for {self.provider_id}")
        except Exception as e:
            logger.error(f"Failed to initialize Hetzner client: {e}")
            raise
    
    def upload_file(self, local_path: str, remote_path: str, metadata: Optional[Dict] = None) -> UploadResult:
        """Upload file to Hetzner storage"""
        start_time = time.time()
        
        for attempt in range(self.retry_attempts):
            try:
                file_size = os.path.getsize(local_path)
                
                with open(local_path, 'rb') as file:
                    response = self.client.upload_fileobj(
                        file,
                        self.bucket_name,
                        remote_path,
                        ExtraArgs={'Metadata': metadata or {}}
                    )
                
                upload_time = int((time.time() - start_time) * 1000)
                
                return UploadResult(
                    success=True,
                    file_path=remote_path,
                    file_size=file_size,
                    provider_id=self.provider_id,
                    upload_time_ms=upload_time,
                    etag=response.get('ETag', '').strip('"')
                )
                
            except Exception as e:
                logger.warning(f"Upload attempt {attempt + 1} failed: {e}")
                if attempt < self.retry_attempts - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                else:
                    return UploadResult(
                        success=False,
                        file_path=remote_path,
                        file_size=0,
                        provider_id=self.provider_id,
                        upload_time_ms=int((time.time() - start_time) * 1000),
                        error_message=str(e)
                    )
    
    def download_file(self, remote_path: str, local_path: str) -> DownloadResult:
        """Download file from Hetzner storage"""
        start_time = time.time()
        
        for attempt in range(self.retry_attempts):
            try:
                response = self.client.download_file(
                    self.bucket_name,
                    remote_path,
                    local_path
                )
                
                file_size = os.path.getsize(local_path)
                download_time = int((time.time() - start_time) * 1000)
                
                return DownloadResult(
                    success=True,
                    file_path=local_path,
                    file_size=file_size,
                    provider_id=self.provider_id,
                    download_time_ms=download_time
                )
                
            except Exception as e:
                logger.warning(f"Download attempt {attempt + 1} failed: {e}")
                if attempt < self.retry_attempts - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                else:
                    return DownloadResult(
                        success=False,
                        file_path=local_path,
                        file_size=0,
                        provider_id=self.provider_id,
                        download_time_ms=int((time.time() - start_time) * 1000),
                        error_message=str(e)
                    )
    
    def delete_file(self, remote_path: str) -> bool:
        """Delete file from Hetzner storage"""
        try:
            self.client.delete_object(
                Bucket=self.bucket_name,
                Key=remote_path
            )
            return True
        except Exception as e:
            logger.error(f"Failed to delete {remote_path}: {e}")
            return False
    
    def get_usage_stats(self) -> StorageMetrics:
        """Get Hetzner storage usage statistics"""
        try:
            response = self.client.list_objects_v2(Bucket=self.bucket_name)
            
            total_bytes = 0
            object_count = 0
            
            if 'Contents' in response:
                for obj in response['Contents']:
                    total_bytes += obj['Size']
                    object_count += 1
            
            return StorageMetrics(
                total_bytes=total_bytes,
                object_count=object_count,
                last_updated=datetime.now(),
                cost_per_gb_monthly=0.0049,  # Hetzner pricing
                transfer_cost_per_gb=0.0049
            )
        except Exception as e:
            logger.error(f"Failed to get usage stats: {e}")
            return StorageMetrics(0, 0, datetime.now(), 0.0049, 0.0049)
    
    def list_files(self, prefix: str = "") -> List[str]:
        """List files in Hetzner storage"""
        try:
            response = self.client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )
            
            files = []
            if 'Contents' in response:
                files = [obj['Key'] for obj in response['Contents']]
            
            return files
        except Exception as e:
            logger.error(f"Failed to list files: {e}")
            return []

class BackblazeStorage(StorageProvider):
    """Backblaze B2 Storage implementation"""
    
    def _initialize_client(self):
        """Initialize Backblaze B2 client"""
        try:
            access_key = self.config['access_key_id']
            secret_key = self.config['secret_access_key']
            endpoint_url = self.config['endpoint_url']
            
            self.client = boto3.client(
                's3',
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key,
                endpoint_url=endpoint_url,
                region_name=self.region
            )
            logger.info(f"Initialized Backblaze storage client for {self.provider_id}")
        except Exception as e:
            logger.error(f"Failed to initialize Backblaze client: {e}")
            raise
    
    def upload_file(self, local_path: str, remote_path: str, metadata: Optional[Dict] = None) -> UploadResult:
        """Upload file to Backblaze B2"""
        start_time = time.time()
        
        for attempt in range(self.retry_attempts):
            try:
                file_size = os.path.getsize(local_path)
                
                with open(local_path, 'rb') as file:
                    response = self.client.upload_fileobj(
                        file,
                        self.bucket_name,
                        remote_path,
                        ExtraArgs={'Metadata': metadata or {}}
                    )
                
                upload_time = int((time.time() - start_time) * 1000)
                
                return UploadResult(
                    success=True,
                    file_path=remote_path,
                    file_size=file_size,
                    provider_id=self.provider_id,
                    upload_time_ms=upload_time,
                    etag=response.get('ETag', '').strip('"')
                )
                
            except Exception as e:
                logger.warning(f"Upload attempt {attempt + 1} failed: {e}")
                if attempt < self.retry_attempts - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                else:
                    return UploadResult(
                        success=False,
                        file_path=remote_path,
                        file_size=0,
                        provider_id=self.provider_id,
                        upload_time_ms=int((time.time() - start_time) * 1000),
                        error_message=str(e)
                    )
    
    def download_file(self, remote_path: str, local_path: str) -> DownloadResult:
        """Download file from Backblaze B2"""
        start_time = time.time()
        
        for attempt in range(self.retry_attempts):
            try:
                response = self.client.download_file(
                    self.bucket_name,
                    remote_path,
                    local_path
                )
                
                file_size = os.path.getsize(local_path)
                download_time = int((time.time() - start_time) * 1000)
                
                return DownloadResult(
                    success=True,
                    file_path=local_path,
                    file_size=file_size,
                    provider_id=self.provider_id,
                    download_time_ms=download_time
                )
                
            except Exception as e:
                logger.warning(f"Download attempt {attempt + 1} failed: {e}")
                if attempt < self.retry_attempts - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                else:
                    return DownloadResult(
                        success=False,
                        file_path=local_path,
                        file_size=0,
                        provider_id=self.provider_id,
                        download_time_ms=int((time.time() - start_time) * 1000),
                        error_message=str(e)
                    )
    
    def delete_file(self, remote_path: str) -> bool:
        """Delete file from Backblaze B2"""
        try:
            self.client.delete_object(
                Bucket=self.bucket_name,
                Key=remote_path
            )
            return True
        except Exception as e:
            logger.error(f"Failed to delete {remote_path}: {e}")
            return False
    
    def get_usage_stats(self) -> StorageMetrics:
        """Get Backblaze B2 storage usage statistics"""
        try:
            response = self.client.list_objects_v2(Bucket=self.bucket_name)
            
            total_bytes = 0
            object_count = 0
            
            if 'Contents' in response:
                for obj in response['Contents']:
                    total_bytes += obj['Size']
                    object_count += 1
            
            return StorageMetrics(
                total_bytes=total_bytes,
                object_count=object_count,
                last_updated=datetime.now(),
                cost_per_gb_monthly=0.005,  # Backblaze B2 pricing
                transfer_cost_per_gb=0.01
            )
        except Exception as e:
            logger.error(f"Failed to get usage stats: {e}")
            return StorageMetrics(0, 0, datetime.now(), 0.005, 0.01)
    
    def list_files(self, prefix: str = "") -> List[str]:
        """List files in Backblaze B2 storage"""
        try:
            response = self.client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )
            
            files = []
            if 'Contents' in response:
                files = [obj['Key'] for obj in response['Contents']]
            
            return files
        except Exception as e:
            logger.error(f"Failed to list files: {e}")
            return []

class WasabiStorage(StorageProvider):
    """Wasabi Storage implementation"""
    
    def _initialize_client(self):
        """Initialize Wasabi S3-compatible client"""
        try:
            access_key = self.config['access_key_id']
            secret_key = self.config['secret_access_key']
            endpoint_url = self.config['endpoint_url']
            
            self.client = boto3.client(
                's3',
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key,
                endpoint_url=endpoint_url,
                region_name=self.region
            )
            logger.info(f"Initialized Wasabi storage client for {self.provider_id}")
        except Exception as e:
            logger.error(f"Failed to initialize Wasabi client: {e}")
            raise
    
    def upload_file(self, local_path: str, remote_path: str, metadata: Optional[Dict] = None) -> UploadResult:
        """Upload file to Wasabi storage"""
        start_time = time.time()
        
        for attempt in range(self.retry_attempts):
            try:
                file_size = os.path.getsize(local_path)
                
                with open(local_path, 'rb') as file:
                    response = self.client.upload_fileobj(
                        file,
                        self.bucket_name,
                        remote_path,
                        ExtraArgs={'Metadata': metadata or {}}
                    )
                
                upload_time = int((time.time() - start_time) * 1000)
                
                return UploadResult(
                    success=True,
                    file_path=remote_path,
                    file_size=file_size,
                    provider_id=self.provider_id,
                    upload_time_ms=upload_time,
                    etag=response.get('ETag', '').strip('"')
                )
                
            except Exception as e:
                logger.warning(f"Upload attempt {attempt + 1} failed: {e}")
                if attempt < self.retry_attempts - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                else:
                    return UploadResult(
                        success=False,
                        file_path=remote_path,
                        file_size=0,
                        provider_id=self.provider_id,
                        upload_time_ms=int((time.time() - start_time) * 1000),
                        error_message=str(e)
                    )
    
    def download_file(self, remote_path: str, local_path: str) -> DownloadResult:
        """Download file from Wasabi storage"""
        start_time = time.time()
        
        for attempt in range(self.retry_attempts):
            try:
                response = self.client.download_file(
                    self.bucket_name,
                    remote_path,
                    local_path
                )
                
                file_size = os.path.getsize(local_path)
                download_time = int((time.time() - start_time) * 1000)
                
                return DownloadResult(
                    success=True,
                    file_path=local_path,
                    file_size=file_size,
                    provider_id=self.provider_id,
                    download_time_ms=download_time
                )
                
            except Exception as e:
                logger.warning(f"Download attempt {attempt + 1} failed: {e}")
                if attempt < self.retry_attempts - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                else:
                    return DownloadResult(
                        success=False,
                        file_path=local_path,
                        file_size=0,
                        provider_id=self.provider_id,
                        download_time_ms=int((time.time() - start_time) * 1000),
                        error_message=str(e)
                    )
    
    def delete_file(self, remote_path: str) -> bool:
        """Delete file from Wasabi storage"""
        try:
            self.client.delete_object(
                Bucket=self.bucket_name,
                Key=remote_path
            )
            return True
        except Exception as e:
            logger.error(f"Failed to delete {remote_path}: {e}")
            return False
    
    def get_usage_stats(self) -> StorageMetrics:
        """Get Wasabi storage usage statistics"""
        try:
            response = self.client.list_objects_v2(Bucket=self.bucket_name)
            
            total_bytes = 0
            object_count = 0
            
            if 'Contents' in response:
                for obj in response['Contents']:
                    total_bytes += obj['Size']
                    object_count += 1
            
            return StorageMetrics(
                total_bytes=total_bytes,
                object_count=object_count,
                last_updated=datetime.now(),
                cost_per_gb_monthly=0.0059,  # Wasabi pricing
                transfer_cost_per_gb=0.00  # Free egress
            )
        except Exception as e:
            logger.error(f"Failed to get usage stats: {e}")
            return StorageMetrics(0, 0, datetime.now(), 0.0059, 0.00)
    
    def list_files(self, prefix: str = "") -> List[str]:
        """List files in Wasabi storage"""
        try:
            response = self.client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )
            
            files = []
            if 'Contents' in response:
                files = [obj['Key'] for obj in response['Contents']]
            
            return files
        except Exception as e:
            logger.error(f"Failed to list files: {e}")
            return []

class StorageProviderFactory:
    """Factory for creating storage provider instances"""
    
    _providers = {
        'hetzner': HetznerStorage,
        'backblaze': BackblazeStorage,
        'wasabi': WasabiStorage
    }
    
    @classmethod
    def create_provider(cls, provider_type: str, provider_id: str, config: Dict[str, Any]) -> StorageProvider:
        """Create a storage provider instance"""
        if provider_type not in cls._providers:
            raise ValueError(f"Unsupported provider type: {provider_type}")
        
        provider_class = cls._providers[provider_type]
        return provider_class(provider_id, config)
    
    @classmethod
    def register_provider(cls, provider_type: str, provider_class: type):
        """Register a new provider type"""
        cls._providers[provider_type] = provider_class

class StorageManager:
    """Manages multiple storage providers with health monitoring and cost tracking"""
    
    def __init__(self, db_path: str = "grim_scythe_complete.db"):
        self.db_path = db_path
        self.providers: Dict[str, StorageProvider] = {}
        self._load_providers_from_db()
    
    @contextmanager
    def get_db_connection(self):
        """Get database connection with proper error handling"""
        conn = sqlite3.connect(self.db_path)
        try:
            yield conn
        finally:
            conn.close()
    
    def _load_providers_from_db(self):
        """Load storage providers from database"""
        try:
            with self.get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT provider_name, provider_type, endpoint_url, region, 
                           access_key_id, secret_access_key_encrypted, bucket_name,
                           cost_per_gb_monthly, cost_per_gb_transfer, max_storage_gb
                    FROM storage_providers 
                    WHERE status = 'active'
                """)
                
                for row in cursor.fetchall():
                    provider_name, provider_type, endpoint_url, region, access_key_id, \
                    secret_key_encrypted, bucket_name, cost_per_gb_monthly, \
                    cost_per_gb_transfer, max_storage_gb = row
                    
                    config = {
                        'endpoint_url': endpoint_url,
                        'region': region,
                        'access_key_id': access_key_id,
                        'secret_access_key': secret_key_encrypted,  # Will be decrypted by provider
                        'bucket_name': bucket_name,
                        'cost_per_gb_monthly': cost_per_gb_monthly,
                        'cost_per_gb_transfer': cost_per_gb_transfer,
                        'max_storage_gb': max_storage_gb
                    }
                    
                    try:
                        provider = StorageProviderFactory.create_provider(
                            provider_type, provider_name, config
                        )
                        self.providers[provider_name] = provider
                        logger.info(f"Loaded provider: {provider_name}")
                    except Exception as e:
                        logger.error(f"Failed to load provider {provider_name}: {e}")
                        
        except Exception as e:
            logger.error(f"Failed to load providers from database: {e}")
    
    def get_provider(self, provider_name: str) -> Optional[StorageProvider]:
        """Get a specific provider by name"""
        return self.providers.get(provider_name)
    
    def get_healthy_providers(self) -> List[StorageProvider]:
        """Get all healthy providers"""
        healthy_providers = []
        for provider in self.providers.values():
            health = provider.check_health()
            if health.is_healthy:
                healthy_providers.append(provider)
        return healthy_providers
    
    def get_provider_health_status(self) -> Dict[str, HealthStatus]:
        """Get health status for all providers"""
        health_status = {}
        for name, provider in self.providers.items():
            health_status[name] = provider.check_health()
        return health_status
    
    def upload_to_best_provider(self, local_path: str, remote_path: str, 
                               metadata: Optional[Dict] = None) -> UploadResult:
        """Upload file to the best available provider"""
        healthy_providers = self.get_healthy_providers()
        
        if not healthy_providers:
            return UploadResult(
                success=False,
                file_path=remote_path,
                file_size=0,
                provider_id="none",
                upload_time_ms=0,
                error_message="No healthy providers available"
            )
        
        # Select provider with lowest cost (simple strategy)
        best_provider = min(healthy_providers, 
                           key=lambda p: p.config.get('cost_per_gb_monthly', float('inf')))
        
        return best_provider.upload_file(local_path, remote_path, metadata)
    
    def download_from_provider(self, provider_name: str, remote_path: str, 
                              local_path: str) -> DownloadResult:
        """Download file from specific provider"""
        provider = self.get_provider(provider_name)
        if not provider:
            return DownloadResult(
                success=False,
                file_path=local_path,
                file_size=0,
                provider_id=provider_name,
                download_time_ms=0,
                error_message=f"Provider {provider_name} not found"
            )
        
        return provider.download_file(remote_path, local_path)
    
    def get_cost_analytics(self) -> Dict[str, Dict]:
        """Get cost analytics for all providers"""
        analytics = {}
        
        for name, provider in self.providers.items():
            try:
                metrics = provider.get_usage_stats()
                monthly_cost = (metrics.total_bytes / (1024**3)) * metrics.cost_per_gb_monthly
                
                analytics[name] = {
                    'total_bytes': metrics.total_bytes,
                    'object_count': metrics.object_count,
                    'cost_per_gb_monthly': metrics.cost_per_gb_monthly,
                    'transfer_cost_per_gb': metrics.transfer_cost_per_gb,
                    'monthly_cost': monthly_cost,
                    'last_updated': metrics.last_updated.isoformat(),
                    'health_status': provider.check_health()
                }
            except Exception as e:
                logger.error(f"Failed to get analytics for {name}: {e}")
                analytics[name] = {'error': str(e)}
        
        return analytics
    
    def update_provider_health(self, provider_name: str):
        """Update health status for a specific provider"""
        provider = self.get_provider(provider_name)
        if provider:
            health = provider.check_health()
            
            try:
                with self.get_db_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute("""
                        UPDATE storage_providers 
                        SET health_status = ?, last_health_check = ?
                        WHERE provider_name = ?
                    """, (health.is_healthy, health.last_check, provider_name))
                    conn.commit()
            except Exception as e:
                logger.error(f"Failed to update health status for {provider_name}: {e}")

# Example usage and testing
if __name__ == "__main__":
    # Example configuration
    config = {
        'endpoint_url': 'https://s3.eu-central-1.hetzner.com',
        'region': 'eu-central-1',
        'access_key_id': 'your_access_key',
        'secret_access_key': 'your_secret_key',
        'bucket_name': 'grim-backups',
        'cost_per_gb_monthly': 0.0049,
        'cost_per_gb_transfer': 0.0049
    }
    
    # Create provider
    provider = StorageProviderFactory.create_provider('hetzner', 'test-hetzner', config)
    
    # Test health check
    health = provider.check_health()
    print(f"Provider health: {health}")
    
    # Test usage stats
    stats = provider.get_usage_stats()
    print(f"Usage stats: {stats}")
    
    # Create storage manager
    manager = StorageManager()
    
    # Get health status for all providers
    health_status = manager.get_provider_health_status()
    print(f"All providers health: {health_status}")
    
    # Get cost analytics
    analytics = manager.get_cost_analytics()
    print(f"Cost analytics: {analytics}") 