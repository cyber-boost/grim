"""
Database management utilities for Scythe API
"""

import sqlite3
import json
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
import os

logger = logging.getLogger(__name__)

class DatabaseManager:
    """Database manager for Scythe API"""
    
    def __init__(self, db_path: str = "scythe_api.db"):
        self.db_path = db_path
        self.init_database()
    
    def get_connection(self):
        """Get database connection"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn
    
    def init_database(self):
        """Initialize database tables"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Storage providers table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS storage_providers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                config TEXT NOT NULL,
                enabled BOOLEAN DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Storage allocations table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS storage_allocations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                provider_id INTEGER NOT NULL,
                allocated_size BIGINT NOT NULL,
                used_size BIGINT DEFAULT 0,
                path TEXT NOT NULL,
                status TEXT DEFAULT 'active',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (provider_id) REFERENCES storage_providers (id)
            )
        ''')
        
        # Storage usage table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS storage_usage (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                allocation_id INTEGER NOT NULL,
                file_path TEXT NOT NULL,
                file_size BIGINT NOT NULL,
                file_type TEXT,
                uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (allocation_id) REFERENCES storage_allocations (id)
            )
        ''')
        
        # Storage policies table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS storage_policies (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                policy_type TEXT NOT NULL,
                config TEXT NOT NULL,
                enabled BOOLEAN DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Licenses table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS licenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                license_key TEXT UNIQUE NOT NULL,
                user_id TEXT NOT NULL,
                product_id TEXT NOT NULL,
                tier TEXT NOT NULL,
                status TEXT DEFAULT 'active',
                expires_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Vendors table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS vendors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL,
                api_key TEXT UNIQUE,
                commission_rate DECIMAL(5,2) DEFAULT 0.00,
                status TEXT DEFAULT 'active',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Products table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                vendor_id INTEGER NOT NULL,
                description TEXT,
                price DECIMAL(10,2) NOT NULL,
                tier_limits TEXT NOT NULL,
                status TEXT DEFAULT 'active',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (vendor_id) REFERENCES vendors (id)
            )
        ''')
        
        # API keys table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS api_keys (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key_hash TEXT UNIQUE NOT NULL,
                user_id TEXT NOT NULL,
                name TEXT NOT NULL,
                permissions TEXT NOT NULL,
                expires_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Webhooks table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS webhooks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                url TEXT NOT NULL,
                events TEXT NOT NULL,
                secret TEXT NOT NULL,
                enabled BOOLEAN DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        conn.close()
        
        # Insert default data
        self.insert_default_data()
    
    def insert_default_data(self):
        """Insert default data into database"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Insert default storage providers
        default_providers = [
            ('Local Storage', 'local', json.dumps({
                'path': '/var/scythe/storage',
                'max_size': 10737418240  # 10GB
            }), 1),
            ('Amazon S3', 's3', json.dumps({
                'bucket': 'scythe-storage',
                'region': 'us-east-1'
            }), 0),
            ('Google Cloud Storage', 'gcs', json.dumps({
                'bucket': 'scythe-storage'
            }), 0)
        ]
        
        cursor.executemany('''
            INSERT OR IGNORE INTO storage_providers (name, type, config, enabled)
            VALUES (?, ?, ?, ?)
        ''', default_providers)
        
        # Insert default storage policies
        default_policies = [
            ('Default Retention', 'retention', json.dumps({
                'days': 365,
                'action': 'archive'
            }), 1),
            ('File Type Restriction', 'file_type', json.dumps({
                'allowed_types': ['txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'zip']
            }), 1),
            ('Size Limit', 'size_limit', json.dumps({
                'max_file_size': 104857600  # 100MB
            }), 1)
        ]
        
        cursor.executemany('''
            INSERT OR IGNORE INTO storage_policies (name, policy_type, config, enabled)
            VALUES (?, ?, ?, ?)
        ''', default_policies)
        
        conn.commit()
        conn.close()
    
    def execute_query(self, query: str, params: tuple = ()) -> List[Dict[str, Any]]:
        """Execute a query and return results"""
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            cursor.execute(query, params)
            
            if query.strip().upper().startswith('SELECT'):
                results = [dict(row) for row in cursor.fetchall()]
            else:
                conn.commit()
                results = []
            
            conn.close()
            return results
        except Exception as e:
            logger.error(f"Database query error: {e}")
            raise
    
    def get_storage_providers(self) -> List[Dict[str, Any]]:
        """Get all storage providers"""
        return self.execute_query("SELECT * FROM storage_providers ORDER BY name")
    
    def create_storage_provider(self, name: str, provider_type: str, config: Dict[str, Any]) -> int:
        """Create a new storage provider"""
        query = '''
            INSERT INTO storage_providers (name, type, config)
            VALUES (?, ?, ?)
        '''
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(query, (name, provider_type, json.dumps(config)))
        provider_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return provider_id
    
    def get_storage_allocations(self, user_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get storage allocations"""
        if user_id:
            return self.execute_query(
                "SELECT * FROM storage_allocations WHERE user_id = ? ORDER BY created_at DESC",
                (user_id,)
            )
        return self.execute_query("SELECT * FROM storage_allocations ORDER BY created_at DESC")
    
    def create_storage_allocation(self, user_id: str, provider_id: int, allocated_size: int, path: str) -> int:
        """Create a new storage allocation"""
        query = '''
            INSERT INTO storage_allocations (user_id, provider_id, allocated_size, path)
            VALUES (?, ?, ?, ?)
        '''
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(query, (user_id, provider_id, allocated_size, path))
        allocation_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return allocation_id
    
    def update_storage_usage(self, allocation_id: int, file_path: str, file_size: int, file_type: str = None):
        """Update storage usage"""
        query = '''
            INSERT INTO storage_usage (allocation_id, file_path, file_size, file_type)
            VALUES (?, ?, ?, ?)
        '''
        self.execute_query(query, (allocation_id, file_path, file_size, file_type))
        
        # Update used size in allocation
        update_query = '''
            UPDATE storage_allocations 
            SET used_size = (
                SELECT COALESCE(SUM(file_size), 0) 
                FROM storage_usage 
                WHERE allocation_id = ?
            ),
            updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        '''
        self.execute_query(update_query, (allocation_id, allocation_id))
    
    def get_license_by_key(self, license_key: str) -> Optional[Dict[str, Any]]:
        """Get license by key"""
        results = self.execute_query(
            "SELECT * FROM licenses WHERE license_key = ? AND status = 'active'",
            (license_key,)
        )
        return results[0] if results else None
    
    def create_license(self, license_key: str, user_id: str, product_id: str, tier: str, expires_at: str = None) -> int:
        """Create a new license"""
        query = '''
            INSERT INTO licenses (license_key, user_id, product_id, tier, expires_at)
            VALUES (?, ?, ?, ?, ?)
        '''
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(query, (license_key, user_id, product_id, tier, expires_at))
        license_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return license_id
    
    def get_vendors(self) -> List[Dict[str, Any]]:
        """Get all vendors"""
        return self.execute_query("SELECT * FROM vendors ORDER BY name")
    
    def create_vendor(self, name: str, email: str, commission_rate: float = 0.0) -> int:
        """Create a new vendor"""
        query = '''
            INSERT INTO vendors (name, email, commission_rate)
            VALUES (?, ?, ?)
        '''
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(query, (name, email, commission_rate))
        vendor_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return vendor_id
    
    def get_products(self, vendor_id: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get products"""
        if vendor_id:
            return self.execute_query(
                "SELECT * FROM products WHERE vendor_id = ? ORDER BY name",
                (vendor_id,)
            )
        return self.execute_query("SELECT * FROM products ORDER BY name")
    
    def create_product(self, name: str, vendor_id: int, description: str, price: float, tier_limits: Dict[str, Any]) -> int:
        """Create a new product"""
        query = '''
            INSERT INTO products (name, vendor_id, description, price, tier_limits)
            VALUES (?, ?, ?, ?, ?)
        '''
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(query, (name, vendor_id, description, price, json.dumps(tier_limits)))
        product_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return product_id 