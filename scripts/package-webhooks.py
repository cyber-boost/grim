#!/usr/bin/env python3
"""
Package Manager Download Webhook System
Handles webhooks from npm, PyPI, Maven Central, RubyGems, and Packagist
Real-time download tracking for the 5,000+ download momentum
"""

import os
import sys
import json
import logging
import asyncio
import hashlib
import hmac
import subprocess
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from pathlib import Path

from flask import Flask, request, jsonify, abort
from flask_cors import CORS
import sqlite3
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PackageWebhookTracker:
    """Comprehensive package download webhook tracking system"""
    
    def __init__(self, db_path="/opt/reaper/db/download_tracking.db"):
        self.db_path = db_path
        self.init_database()
        self.error_tracker_script = "/opt/reaper/scripts/error-tracker.sh"
        
    def init_database(self):
        """Initialize download tracking database"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS downloads (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    download_id TEXT UNIQUE,
                    package_manager TEXT NOT NULL,
                    package_name TEXT NOT NULL,
                    version TEXT NOT NULL,
                    download_source TEXT,
                    user_agent TEXT,
                    ip_hash TEXT,
                    country TEXT,
                    user_id TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    raw_data TEXT
                )
            """)
            
            conn.execute("""
                CREATE TABLE IF NOT EXISTS download_analytics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    date DATE NOT NULL,
                    package_manager TEXT NOT NULL,
                    total_downloads INTEGER DEFAULT 0,
                    unique_users INTEGER DEFAULT 0,
                    top_countries TEXT,
                    conversion_rate REAL DEFAULT 0.0,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(date, package_manager)
                )
            """)
            
            conn.execute("""
                CREATE TABLE IF NOT EXISTS conversion_funnel (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    stage TEXT NOT NULL,
                    package_manager TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    details TEXT
                )
            """)
            
            conn.commit()
    
    def track_download(self, package_manager: str, package_name: str, version: str, 
                      user_agent: str = "", ip_address: str = "", 
                      additional_data: Dict[str, Any] = None) -> bool:
        """Track a package download with comprehensive analytics"""
        try:
            download_id = hashlib.sha256(
                f"{package_manager}-{package_name}-{version}-{datetime.now().isoformat()}-{ip_address}".encode()
            ).hexdigest()[:16]
            
            ip_hash = hashlib.sha256(ip_address.encode()).hexdigest()[:16] if ip_address else ""
            
            # Extract user identifier if possible
            user_id = self._extract_user_id(user_agent, additional_data)
            
            # Store in local database
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("""
                    INSERT OR REPLACE INTO downloads 
                    (download_id, package_manager, package_name, version, user_agent, 
                     ip_hash, user_id, raw_data)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, (download_id, package_manager, package_name, version, 
                      user_agent, ip_hash, user_id, json.dumps(additional_data or {})))
                conn.commit()
            
            # Send to central tracking system
            self._send_to_central_tracking(
                package_manager, package_name, version, user_agent, ip_hash, user_id
            )
            
            # Update analytics
            self._update_analytics(package_manager)
            
            logger.info(f"Tracked download: {package_manager}/{package_name}@{version}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to track download: {e}")
            return False
    
    def _extract_user_id(self, user_agent: str, additional_data: Dict[str, Any]) -> str:
        """Extract or generate user identifier for conversion tracking"""
        if additional_data:
            # Try various user identifier fields
            for field in ['user_id', 'username', 'email', 'npm_user', 'pip_user']:
                if field in additional_data:
                    return str(additional_data[field])
        
        # Generate hash-based user ID from user agent
        if user_agent:
            return hashlib.sha256(user_agent.encode()).hexdigest()[:12]
        
        return "anonymous"
    
    def _send_to_central_tracking(self, package_manager: str, package_name: str, 
                                 version: str, user_agent: str, ip_hash: str, user_id: str):
        """Send download data to central Grim tracking system"""
        try:
            cmd = [
                self.error_tracker_script, "download",
                package_manager, package_name, version, 
                f"{package_manager}_webhook", user_agent
            ]
            
            # Set environment variables for tracking
            env = os.environ.copy()
            env['GRIM_USER_ID'] = user_id
            env['GRIM_IP_HASH'] = ip_hash
            
            subprocess.run(cmd, env=env, check=True, capture_output=True)
            
        except subprocess.CalledProcessError as e:
            logger.warning(f"Failed to send to central tracking: {e}")
        except Exception as e:
            logger.error(f"Error sending to central tracking: {e}")
    
    def _update_analytics(self, package_manager: str):
        """Update real-time analytics"""
        try:
            today = datetime.now().date()
            
            with sqlite3.connect(self.db_path) as conn:
                # Get today's stats
                cursor = conn.execute("""
                    SELECT COUNT(*) as total, COUNT(DISTINCT user_id) as unique
                    FROM downloads 
                    WHERE package_manager = ? AND DATE(timestamp) = ?
                """, (package_manager, today))
                
                total, unique = cursor.fetchone()
                
                # Update or insert analytics
                conn.execute("""
                    INSERT OR REPLACE INTO download_analytics 
                    (date, package_manager, total_downloads, unique_users)
                    VALUES (?, ?, ?, ?)
                """, (today, package_manager, total, unique))
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"Failed to update analytics: {e}")
    
    def get_download_stats(self, days: int = 7) -> Dict[str, Any]:
        """Get download statistics for dashboard"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                # Total downloads by package manager
                cursor = conn.execute("""
                    SELECT package_manager, SUM(total_downloads), SUM(unique_users)
                    FROM download_analytics 
                    WHERE date >= date('now', '-{} days')
                    GROUP BY package_manager
                """.format(days))
                
                stats = {}
                total_downloads = 0
                total_unique = 0
                
                for pkg_mgr, downloads, unique in cursor.fetchall():
                    stats[pkg_mgr] = {
                        'downloads': downloads or 0,
                        'unique_users': unique or 0
                    }
                    total_downloads += downloads or 0
                    total_unique += unique or 0
                
                # Recent downloads
                cursor = conn.execute("""
                    SELECT package_manager, package_name, version, timestamp
                    FROM downloads 
                    ORDER BY timestamp DESC LIMIT 50
                """)
                
                recent_downloads = [
                    {
                        'package_manager': row[0],
                        'package_name': row[1],
                        'version': row[2],
                        'timestamp': row[3]
                    }
                    for row in cursor.fetchall()
                ]
                
                return {
                    'total_downloads': total_downloads,
                    'unique_users': total_unique,
                    'by_package_manager': stats,
                    'recent_downloads': recent_downloads,
                    'timestamp': datetime.now().isoformat()
                }
                
        except Exception as e:
            logger.error(f"Failed to get download stats: {e}")
            return {}

# Initialize Flask app
app = Flask(__name__)
CORS(app)
tracker = PackageWebhookTracker()

@app.route('/webhook/npm', methods=['POST'])
def npm_webhook():
    """Handle NPM download webhooks"""
    try:
        data = request.get_json() or {}
        user_agent = request.headers.get('User-Agent', '')
        ip_address = request.remote_addr
        
        # NPM webhook data structure
        package_name = data.get('name', 'unknown')
        version = data.get('version', 'unknown')
        
        tracker.track_download('npm', package_name, version, user_agent, ip_address, data)
        
        return jsonify({'status': 'success', 'message': 'NPM download tracked'})
        
    except Exception as e:
        logger.error(f"NPM webhook error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/webhook/pypi', methods=['POST'])
def pypi_webhook():
    """Handle PyPI download webhooks"""
    try:
        data = request.get_json() or {}
        user_agent = request.headers.get('User-Agent', '')
        ip_address = request.remote_addr
        
        # PyPI webhook data structure
        package_name = data.get('project', {}).get('name', 'unknown')
        version = data.get('file', {}).get('version', 'unknown')
        
        tracker.track_download('pypi', package_name, version, user_agent, ip_address, data)
        
        return jsonify({'status': 'success', 'message': 'PyPI download tracked'})
        
    except Exception as e:
        logger.error(f"PyPI webhook error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/webhook/maven', methods=['POST'])
def maven_webhook():
    """Handle Maven Central download webhooks"""
    try:
        data = request.get_json() or {}
        user_agent = request.headers.get('User-Agent', '')
        ip_address = request.remote_addr
        
        # Maven webhook data structure
        group_id = data.get('groupId', '')
        artifact_id = data.get('artifactId', 'unknown')
        version = data.get('version', 'unknown')
        package_name = f"{group_id}.{artifact_id}" if group_id else artifact_id
        
        tracker.track_download('maven', package_name, version, user_agent, ip_address, data)
        
        return jsonify({'status': 'success', 'message': 'Maven download tracked'})
        
    except Exception as e:
        logger.error(f"Maven webhook error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/webhook/rubygems', methods=['POST'])
def rubygems_webhook():
    """Handle RubyGems download webhooks"""
    try:
        data = request.get_json() or {}
        user_agent = request.headers.get('User-Agent', '')
        ip_address = request.remote_addr
        
        # RubyGems webhook data structure
        package_name = data.get('name', 'unknown')
        version = data.get('version', 'unknown')
        
        tracker.track_download('rubygems', package_name, version, user_agent, ip_address, data)
        
        return jsonify({'status': 'success', 'message': 'RubyGems download tracked'})
        
    except Exception as e:
        logger.error(f"RubyGems webhook error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/webhook/packagist', methods=['POST'])
def packagist_webhook():
    """Handle Packagist download webhooks"""
    try:
        data = request.get_json() or {}
        user_agent = request.headers.get('User-Agent', '')
        ip_address = request.remote_addr
        
        # Packagist webhook data structure
        package_name = data.get('package', {}).get('name', 'unknown')
        version = data.get('version', {}).get('version', 'unknown')
        
        tracker.track_download('packagist', package_name, version, user_agent, ip_address, data)
        
        return jsonify({'status': 'success', 'message': 'Packagist download tracked'})
        
    except Exception as e:
        logger.error(f"Packagist webhook error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/download-stats')
def download_stats():
    """Get download statistics for dashboard"""
    days = request.args.get('days', 7, type=int)
    stats = tracker.get_download_stats(days)
    return jsonify(stats)

@app.route('/api/download-stats/live')
def live_download_stats():
    """Get live download statistics"""
    stats = tracker.get_download_stats(1)  # Last 24 hours
    return jsonify(stats)

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'package-webhook-tracker',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    port = int(os.getenv('WEBHOOK_PORT', 5555))
    debug = os.getenv('FLASK_ENV') == 'development'
    
    logger.info(f"Starting Package Webhook Tracker on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)