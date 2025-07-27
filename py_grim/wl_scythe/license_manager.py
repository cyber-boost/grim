#!/usr/bin/env python3
"""
Scythe License Manager
White-label licensing system for CLI developers
"""

import sqlite3
import hashlib
import secrets
import json
import os
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
import logging

logger = logging.getLogger(__name__)

class ScytheLicenseManager:
    """Simple licensing manager for CLI developers"""
    
    def __init__(self, db_path: str = None):
        """Initialize the license manager"""
        if db_path is None:
            # Default to local database
            script_dir = os.path.dirname(os.path.abspath(__file__))
            db_path = os.path.join(script_dir, "database", "scythe.db")
        
        self.db_path = db_path
        self._ensure_db_exists()
    
    def _ensure_db_exists(self):
        """Ensure database exists and has required tables"""
        if not os.path.exists(self.db_path):
            # Run database setup
            script_dir = os.path.dirname(os.path.abspath(__file__))
            setup_script = os.path.join(script_dir, "scythe_db.sh")
            if os.path.exists(setup_script):
                os.system(f"bash {setup_script}")
            else:
                raise FileNotFoundError(f"Database setup script not found: {setup_script}")
    
    def _get_connection(self):
        """Get database connection"""
        return sqlite3.connect(self.db_path)
    
    def register_vendor(self, name: str, email: str, webhook_url: str = None) -> Dict[str, Any]:
        """Register a new vendor (CLI developer)"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                # Generate API key
                api_key = secrets.token_urlsafe(32)
                api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
                
                # Insert vendor
                cursor.execute("""
                    INSERT INTO vendors (name, email, api_key_hash, webhook_url, webhook_secret)
                    VALUES (?, ?, ?, ?, ?)
                """, (name, email, api_key_hash, webhook_url, secrets.token_urlsafe(16)))
                
                vendor_id = cursor.lastrowid
                conn.commit()
                
                return {
                    "success": True,
                    "vendor_id": vendor_id,
                    "api_key": api_key,
                    "message": "Vendor registered successfully"
                }
                
        except sqlite3.IntegrityError:
            return {
                "success": False,
                "error": "Vendor with this email already exists"
            }
        except Exception as e:
            logger.error(f"Error registering vendor: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def create_product(self, vendor_id: int, name: str, description: str = None, 
                      price: float = None, version: str = "1.0.0") -> Dict[str, Any]:
        """Create a new product for a vendor"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    INSERT INTO products (vendor_id, name, description, price, version)
                    VALUES (?, ?, ?, ?, ?)
                """, (vendor_id, name, description, price, version))
                
                product_id = cursor.lastrowid
                conn.commit()
                
                return {
                    "success": True,
                    "product_id": product_id,
                    "message": "Product created successfully"
                }
                
        except Exception as e:
            logger.error(f"Error creating product: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def generate_license(self, product_id: int, customer_email: str, 
                        customer_name: str = None, expires_in_days: int = 365) -> Dict[str, Any]:
        """Generate a license for a customer"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                # Generate license key
                license_key = f"SCYTHE-{secrets.token_hex(8).upper()}-{secrets.token_hex(4).upper()}"
                
                # Calculate expiration
                expires_at = datetime.now() + timedelta(days=expires_in_days)
                
                # Insert license
                cursor.execute("""
                    INSERT INTO licenses (license_key, product_id, customer_email, customer_name, expires_at)
                    VALUES (?, ?, ?, ?, ?)
                """, (license_key, product_id, customer_email, customer_name, expires_at))
                
                license_id = cursor.lastrowid
                conn.commit()
                
                return {
                    "success": True,
                    "license_id": license_id,
                    "license_key": license_key,
                    "expires_at": expires_at.isoformat(),
                    "message": "License generated successfully"
                }
                
        except Exception as e:
            logger.error(f"Error generating license: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def validate_license(self, license_key: str, client_ip: str = None, 
                        user_agent: str = None) -> Dict[str, Any]:
        """Validate a license key"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                # Get license details
                cursor.execute("""
                    SELECT l.id, l.status, l.expires_at, l.customer_email, p.name as product_name
                    FROM licenses l
                    JOIN products p ON l.product_id = p.id
                    WHERE l.license_key = ?
                """, (license_key,))
                
                result = cursor.fetchone()
                if not result:
                    return {
                        "valid": False,
                        "error": "License not found"
                    }
                
                license_id, status, expires_at, customer_email, product_name = result
                
                # Check if license is active
                if status != "active":
                    return {
                        "valid": False,
                        "error": f"License is {status}"
                    }
                
                # Check if license is expired
                if expires_at and datetime.fromisoformat(expires_at) < datetime.now():
                    return {
                        "valid": False,
                        "error": "License has expired"
                    }
                
                # Log validation
                cursor.execute("""
                    INSERT INTO license_validations (license_id, validation_result, client_ip, user_agent)
                    VALUES (?, ?, ?, ?)
                """, (license_id, "valid", client_ip, user_agent))
                
                conn.commit()
                
                return {
                    "valid": True,
                    "license_id": license_id,
                    "customer_email": customer_email,
                    "product_name": product_name,
                    "expires_at": expires_at,
                    "message": "License is valid"
                }
                
        except Exception as e:
            logger.error(f"Error validating license: {e}")
            return {
                "valid": False,
                "error": str(e)
            }
    
    def list_licenses(self, vendor_id: int = None, product_id: int = None) -> Dict[str, Any]:
        """List licenses with optional filtering"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                query = """
                    SELECT l.id, l.license_key, l.customer_email, l.customer_name, 
                           l.status, l.expires_at, l.created_at, p.name as product_name
                    FROM licenses l
                    JOIN products p ON l.product_id = p.id
                """
                params = []
                
                if vendor_id:
                    query += " WHERE p.vendor_id = ?"
                    params.append(vendor_id)
                elif product_id:
                    query += " WHERE l.product_id = ?"
                    params.append(product_id)
                
                query += " ORDER BY l.created_at DESC"
                
                cursor.execute(query, params)
                results = cursor.fetchall()
                
                licenses = []
                for row in results:
                    licenses.append({
                        "id": row[0],
                        "license_key": row[1],
                        "customer_email": row[2],
                        "customer_name": row[3],
                        "status": row[4],
                        "expires_at": row[5],
                        "created_at": row[6],
                        "product_name": row[7]
                    })
                
                return {
                    "success": True,
                    "licenses": licenses,
                    "count": len(licenses)
                }
                
        except Exception as e:
            logger.error(f"Error listing licenses: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def revoke_license(self, license_key: str) -> Dict[str, Any]:
        """Revoke a license"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    UPDATE licenses SET status = 'revoked' WHERE license_key = ?
                """, (license_key,))
                
                if cursor.rowcount == 0:
                    return {
                        "success": False,
                        "error": "License not found"
                    }
                
                conn.commit()
                
                return {
                    "success": True,
                    "message": "License revoked successfully"
                }
                
        except Exception as e:
            logger.error(f"Error revoking license: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def get_vendor_info(self, vendor_id: int) -> Dict[str, Any]:
        """Get vendor information"""
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT id, name, email, webhook_url, commission_rate, status, created_at
                    FROM vendors WHERE id = ?
                """, (vendor_id,))
                
                result = cursor.fetchone()
                if not result:
                    return {
                        "success": False,
                        "error": "Vendor not found"
                    }
                
                return {
                    "success": True,
                    "vendor": {
                        "id": result[0],
                        "name": result[1],
                        "email": result[2],
                        "webhook_url": result[3],
                        "commission_rate": result[4],
                        "status": result[5],
                        "created_at": result[6]
                    }
                }
                
        except Exception as e:
            logger.error(f"Error getting vendor info: {e}")
            return {
                "success": False,
                "error": str(e)
            }

def main():
    """CLI interface for the license manager"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Scythe License Manager")
    parser.add_argument("command", choices=["register", "create-product", "generate", "validate", "list", "revoke"])
    parser.add_argument("--db", help="Database path")
    parser.add_argument("--name", help="Vendor/Product name")
    parser.add_argument("--email", help="Email address")
    parser.add_argument("--product-id", type=int, help="Product ID")
    parser.add_argument("--license-key", help="License key")
    parser.add_argument("--vendor-id", type=int, help="Vendor ID")
    
    args = parser.parse_args()
    
    manager = ScytheLicenseManager(args.db)
    
    if args.command == "register":
        if not args.name or not args.email:
            print("Error: --name and --email required for register")
            return
        
        result = manager.register_vendor(args.name, args.email)
        print(json.dumps(result, indent=2))
    
    elif args.command == "create-product":
        if not args.vendor_id or not args.name:
            print("Error: --vendor-id and --name required for create-product")
            return
        
        result = manager.create_product(args.vendor_id, args.name)
        print(json.dumps(result, indent=2))
    
    elif args.command == "generate":
        if not args.product_id or not args.email:
            print("Error: --product-id and --email required for generate")
            return
        
        result = manager.generate_license(args.product_id, args.email)
        print(json.dumps(result, indent=2))
    
    elif args.command == "validate":
        if not args.license_key:
            print("Error: --license-key required for validate")
            return
        
        result = manager.validate_license(args.license_key)
        print(json.dumps(result, indent=2))
    
    elif args.command == "list":
        result = manager.list_licenses(args.vendor_id)
        print(json.dumps(result, indent=2))
    
    elif args.command == "revoke":
        if not args.license_key:
            print("Error: --license-key required for revoke")
            return
        
        result = manager.revoke_license(args.license_key)
        print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main() 