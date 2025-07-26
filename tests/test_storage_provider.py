#!/usr/bin/env python3
"""
Test suite for Storage Provider System
Tests all providers, health monitoring, and cost tracking functionality
"""

import unittest
import tempfile
import os
import time
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime

# Import the storage provider classes
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'services'))

from storage_provider import (
    StorageProvider, HetznerStorage, BackblazeStorage, WasabiStorage,
    StorageProviderFactory, StorageManager, HealthStatus, StorageMetrics,
    UploadResult, DownloadResult
)

class TestStorageProvider(unittest.TestCase):
    """Test cases for storage provider base class and implementations"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.test_config = {
            'endpoint_url': 'https://test-endpoint.com',
            'region': 'test-region',
            'access_key_id': 'test_access_key',
            'secret_access_key': 'test_secret_key',
            'bucket_name': 'test-bucket',
            'cost_per_gb_monthly': 0.01,
            'cost_per_gb_transfer': 0.005,
            'retry_attempts': 2,
            'retry_delay': 0.1
        }
        
        # Create temporary test file
        self.temp_file = tempfile.NamedTemporaryFile(delete=False)
        self.temp_file.write(b"Test file content for storage provider testing")
        self.temp_file.close()
    
    def tearDown(self):
        """Clean up test fixtures"""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)
    
    def test_hetzner_storage_initialization(self):
        """Test Hetzner storage provider initialization"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            self.assertEqual(provider.provider_id, 'test-hetzner')
            self.assertEqual(provider.bucket_name, 'test-bucket')
            self.assertEqual(provider.region, 'test-region')
            self.assertIsNotNone(provider.client)
    
    def test_backblaze_storage_initialization(self):
        """Test Backblaze storage provider initialization"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client
            
            provider = BackblazeStorage('test-backblaze', self.test_config)
            
            self.assertEqual(provider.provider_id, 'test-backblaze')
            self.assertEqual(provider.bucket_name, 'test-bucket')
            self.assertIsNotNone(provider.client)
    
    def test_wasabi_storage_initialization(self):
        """Test Wasabi storage provider initialization"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client
            
            provider = WasabiStorage('test-wasabi', self.test_config)
            
            self.assertEqual(provider.provider_id, 'test-wasabi')
            self.assertEqual(provider.bucket_name, 'test-bucket')
            self.assertIsNotNone(provider.client)
    
    def test_upload_file_success(self):
        """Test successful file upload"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_client.upload_fileobj.return_value = {'ETag': '"test-etag"'}
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            result = provider.upload_file(self.temp_file.name, 'test/upload.txt')
            
            self.assertTrue(result.success)
            self.assertEqual(result.file_path, 'test/upload.txt')
            self.assertEqual(result.provider_id, 'test-hetzner')
            self.assertIsNotNone(result.etag)
    
    def test_upload_file_failure(self):
        """Test file upload failure with retry logic"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_client.upload_fileobj.side_effect = Exception("Upload failed")
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            result = provider.upload_file(self.temp_file.name, 'test/upload.txt')
            
            self.assertFalse(result.success)
            self.assertIn("Upload failed", result.error_message)
    
    def test_download_file_success(self):
        """Test successful file download"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_client.download_file.return_value = None
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            download_path = self.temp_file.name + '.download'
            result = provider.download_file('test/download.txt', download_path)
            
            self.assertTrue(result.success)
            self.assertEqual(result.file_path, download_path)
            self.assertEqual(result.provider_id, 'test-hetzner')
    
    def test_delete_file_success(self):
        """Test successful file deletion"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_client.delete_object.return_value = {}
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            result = provider.delete_file('test/delete.txt')
            
            self.assertTrue(result)
    
    def test_get_usage_stats(self):
        """Test getting usage statistics"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_client.list_objects_v2.return_value = {
                'Contents': [
                    {'Key': 'file1.txt', 'Size': 1024},
                    {'Key': 'file2.txt', 'Size': 2048}
                ]
            }
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            stats = provider.get_usage_stats()
            
            self.assertEqual(stats.total_bytes, 3072)
            self.assertEqual(stats.object_count, 2)
            self.assertEqual(stats.cost_per_gb_monthly, 0.0049)
    
    def test_list_files(self):
        """Test listing files"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_client.list_objects_v2.return_value = {
                'Contents': [
                    {'Key': 'folder/file1.txt'},
                    {'Key': 'folder/file2.txt'}
                ]
            }
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            files = provider.list_files(prefix='folder/')
            
            self.assertEqual(len(files), 2)
            self.assertIn('folder/file1.txt', files)
            self.assertIn('folder/file2.txt', files)
    
    def test_health_check_success(self):
        """Test successful health check"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_client.list_objects_v2.return_value = {'Contents': []}
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            health = provider.check_health()
            
            self.assertTrue(health.is_healthy)
            self.assertEqual(health.error_count, 0)
            self.assertIsNone(health.error_message)
    
    def test_health_check_failure(self):
        """Test health check failure"""
        with patch('boto3.client') as mock_boto3:
            mock_client = Mock()
            mock_client.list_objects_v2.side_effect = Exception("Connection failed")
            mock_boto3.return_value = mock_client
            
            provider = HetznerStorage('test-hetzner', self.test_config)
            
            health = provider.check_health()
            
            self.assertFalse(health.is_healthy)
            self.assertEqual(health.error_count, 1)
            self.assertIn("Connection failed", health.error_message)

class TestStorageProviderFactory(unittest.TestCase):
    """Test cases for storage provider factory"""
    
    def test_create_hetzner_provider(self):
        """Test creating Hetzner provider"""
        config = {'endpoint_url': 'https://test.com', 'access_key_id': 'key', 'secret_access_key': 'secret'}
        
        with patch('boto3.client'):
            provider = StorageProviderFactory.create_provider('hetzner', 'test', config)
            self.assertIsInstance(provider, HetznerStorage)
    
    def test_create_backblaze_provider(self):
        """Test creating Backblaze provider"""
        config = {'endpoint_url': 'https://test.com', 'access_key_id': 'key', 'secret_access_key': 'secret'}
        
        with patch('boto3.client'):
            provider = StorageProviderFactory.create_provider('backblaze', 'test', config)
            self.assertIsInstance(provider, BackblazeStorage)
    
    def test_create_wasabi_provider(self):
        """Test creating Wasabi provider"""
        config = {'endpoint_url': 'https://test.com', 'access_key_id': 'key', 'secret_access_key': 'secret'}
        
        with patch('boto3.client'):
            provider = StorageProviderFactory.create_provider('wasabi', 'test', config)
            self.assertIsInstance(provider, WasabiStorage)
    
    def test_create_unsupported_provider(self):
        """Test creating unsupported provider type"""
        config = {'endpoint_url': 'https://test.com'}
        
        with self.assertRaises(ValueError):
            StorageProviderFactory.create_provider('unsupported', 'test', config)

class TestStorageManager(unittest.TestCase):
    """Test cases for storage manager"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
    
    def tearDown(self):
        """Clean up test fixtures"""
        if os.path.exists(self.temp_db.name):
            os.unlink(self.temp_db.name)
    
    @patch('sqlite3.connect')
    def test_storage_manager_initialization(self, mock_connect):
        """Test storage manager initialization"""
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = []
        
        manager = StorageManager(self.temp_db.name)
        
        self.assertEqual(manager.db_path, self.temp_db.name)
        self.assertIsInstance(manager.providers, dict)
    
    @patch('sqlite3.connect')
    @patch('storage_provider.StorageProviderFactory.create_provider')
    def test_load_providers_from_db(self, mock_create_provider, mock_connect):
        """Test loading providers from database"""
        mock_provider = Mock()
        mock_create_provider.return_value = mock_provider
        
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = [
            ('hetzner', 'hetzner', 'https://test.com', 'eu-central-1', 
             'access_key', 'secret_key', 'bucket', 0.0049, 0.0049, 1000)
        ]
        
        manager = StorageManager(self.temp_db.name)
        
        self.assertIn('hetzner', manager.providers)
        mock_create_provider.assert_called_once()
    
    def test_get_provider(self):
        """Test getting provider by name"""
        manager = StorageManager(self.temp_db.name)
        manager.providers['test-provider'] = Mock()
        
        provider = manager.get_provider('test-provider')
        self.assertIsNotNone(provider)
        
        provider = manager.get_provider('non-existent')
        self.assertIsNone(provider)
    
    def test_get_healthy_providers(self):
        """Test getting healthy providers"""
        manager = StorageManager(self.temp_db.name)
        
        # Create mock providers
        healthy_provider = Mock()
        healthy_provider.check_health.return_value = HealthStatus(True, 100, 0, datetime.now())
        
        unhealthy_provider = Mock()
        unhealthy_provider.check_health.return_value = HealthStatus(False, 0, 1, datetime.now(), "Error")
        
        manager.providers['healthy'] = healthy_provider
        manager.providers['unhealthy'] = unhealthy_provider
        
        healthy_providers = manager.get_healthy_providers()
        
        self.assertEqual(len(healthy_providers), 1)
        self.assertEqual(healthy_providers[0], healthy_provider)
    
    def test_get_provider_health_status(self):
        """Test getting health status for all providers"""
        manager = StorageManager(self.temp_db.name)
        
        mock_provider = Mock()
        mock_health = HealthStatus(True, 100, 0, datetime.now())
        mock_provider.check_health.return_value = mock_health
        
        manager.providers['test'] = mock_provider
        
        health_status = manager.get_provider_health_status()
        
        self.assertIn('test', health_status)
        self.assertEqual(health_status['test'], mock_health)
    
    @patch('storage_provider.StorageProvider.upload_file')
    def test_upload_to_best_provider(self, mock_upload):
        """Test uploading to best provider"""
        manager = StorageManager(self.temp_db.name)
        
        # Create mock providers with different costs
        provider1 = Mock()
        provider1.config = {'cost_per_gb_monthly': 0.01}
        provider1.check_health.return_value = HealthStatus(True, 100, 0, datetime.now())
        
        provider2 = Mock()
        provider2.config = {'cost_per_gb_monthly': 0.005}
        provider2.check_health.return_value = HealthStatus(True, 100, 0, datetime.now())
        
        manager.providers['expensive'] = provider1
        manager.providers['cheap'] = provider2
        
        mock_result = UploadResult(True, 'test.txt', 1024, 'cheap', 100)
        mock_upload.return_value = mock_result
        
        result = manager.upload_to_best_provider('local.txt', 'remote.txt')
        
        self.assertTrue(result.success)
        # Should use the cheaper provider
        provider2.upload_file.assert_called_once()
    
    def test_upload_to_best_provider_no_healthy(self):
        """Test uploading when no healthy providers available"""
        manager = StorageManager(self.temp_db.name)
        
        # Create only unhealthy providers
        unhealthy_provider = Mock()
        unhealthy_provider.check_health.return_value = HealthStatus(False, 0, 1, datetime.now(), "Error")
        manager.providers['unhealthy'] = unhealthy_provider
        
        result = manager.upload_to_best_provider('local.txt', 'remote.txt')
        
        self.assertFalse(result.success)
        self.assertIn("No healthy providers available", result.error_message)
    
    def test_get_cost_analytics(self):
        """Test getting cost analytics"""
        manager = StorageManager(self.temp_db.name)
        
        mock_provider = Mock()
        mock_metrics = StorageMetrics(1024**3, 10, datetime.now(), 0.01, 0.005)  # 1GB
        mock_provider.get_usage_stats.return_value = mock_metrics
        mock_provider.check_health.return_value = HealthStatus(True, 100, 0, datetime.now())
        
        manager.providers['test'] = mock_provider
        
        analytics = manager.get_cost_analytics()
        
        self.assertIn('test', analytics)
        self.assertEqual(analytics['test']['total_bytes'], 1024**3)
        self.assertEqual(analytics['test']['monthly_cost'], 0.01)  # 1GB * $0.01/GB

class TestIntegration(unittest.TestCase):
    """Integration tests for the complete storage system"""
    
    def setUp(self):
        """Set up integration test fixtures"""
        self.temp_file = tempfile.NamedTemporaryFile(delete=False)
        self.temp_file.write(b"Integration test content")
        self.temp_file.close()
        
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
    
    def tearDown(self):
        """Clean up integration test fixtures"""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)
        if os.path.exists(self.temp_db.name):
            os.unlink(self.temp_db.name)
    
    @patch('boto3.client')
    def test_complete_workflow(self, mock_boto3):
        """Test complete storage workflow"""
        # Mock S3 client
        mock_client = Mock()
        mock_client.upload_fileobj.return_value = {'ETag': '"test-etag"'}
        mock_client.download_file.return_value = None
        mock_client.delete_object.return_value = {}
        mock_client.list_objects_v2.return_value = {'Contents': []}
        mock_boto3.return_value = mock_client
        
        # Create provider
        config = {
            'endpoint_url': 'https://test.com',
            'access_key_id': 'test_key',
            'secret_access_key': 'test_secret',
            'bucket_name': 'test-bucket'
        }
        
        provider = StorageProviderFactory.create_provider('hetzner', 'test', config)
        
        # Test health check
        health = provider.check_health()
        self.assertTrue(health.is_healthy)
        
        # Test upload
        upload_result = provider.upload_file(self.temp_file.name, 'test/upload.txt')
        self.assertTrue(upload_result.success)
        
        # Test download
        download_path = self.temp_file.name + '.download'
        download_result = provider.download_file('test/download.txt', download_path)
        self.assertTrue(download_result.success)
        
        # Test delete
        delete_result = provider.delete_file('test/delete.txt')
        self.assertTrue(delete_result)
        
        # Test usage stats
        stats = provider.get_usage_stats()
        self.assertIsInstance(stats, StorageMetrics)

if __name__ == '__main__':
    # Run the tests
    unittest.main(verbosity=2) 