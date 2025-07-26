#!/usr/bin/env python3
"""
UP.GRIM.SO - Grim Reaper Version Check Service
Auto-update endpoint for 3000+ Grimsters
"""

import os
import json
import sqlite3
import hashlib
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, abort
import logging
from logging.handlers import RotatingFileHandler

# Flask app setup
app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'grim-reaper-version-service')

# Logging setup
if not os.path.exists('logs'):
    os.makedirs('logs')
    
logging.basicConfig(level=logging.INFO)
handler = RotatingFileHandler('logs/up_grim.log', maxBytes=10000000, backupCount=3)
handler.setFormatter(logging.Formatter(
    '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
))
app.logger.addHandler(handler)

# Configuration
BUILDS_DIR = "/opt/reaper/builds"
CURRENT_VERSION_FILE = os.path.join(BUILDS_DIR, "latest_version.json")
USAGE_DB = "logs/version_checks.db"

# ============================================================================
# DATABASE SETUP
# ============================================================================
def init_db():
    """Initialize version check tracking database"""
    conn = sqlite3.connect(USAGE_DB)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS version_checks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_ip TEXT,
            user_agent TEXT,
            current_version TEXT,
            latest_version TEXT,
            update_available INTEGER,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS update_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT UNIQUE,
            total_checks INTEGER DEFAULT 0,
            unique_ips INTEGER DEFAULT 0,
            updates_available INTEGER DEFAULT 0,
            old_versions INTEGER DEFAULT 0
        )
    ''')
    conn.commit()
    conn.close()

# ============================================================================
# VERSION DETECTION
# ============================================================================
def get_latest_version():
    """Get latest build version from builds directory"""
    try:
        # Read from latest version cache first
        if os.path.exists(CURRENT_VERSION_FILE):
            with open(CURRENT_VERSION_FILE, 'r') as f:
                return json.load(f)
        
        # Fallback: scan builds directory
        latest_build = None
        latest_time = 0
        
        if os.path.exists(BUILDS_DIR):
            for item in os.listdir(BUILDS_DIR):
                if item.startswith('grim-reaper-') and item.endswith('.tar.gz'):
                    build_path = os.path.join(BUILDS_DIR, item)
                    build_time = os.path.getmtime(build_path)
                    
                    if build_time > latest_time:
                        latest_time = build_time
                        latest_build = item
        
        if latest_build:
            # Extract version from filename: grim-reaper-20250724_230520.tar.gz
            version = latest_build.replace('grim-reaper-', '').replace('.tar.gz', '')
            
            # Calculate file hash for integrity
            build_path = os.path.join(BUILDS_DIR, latest_build)
            with open(build_path, 'rb') as f:
                file_hash = hashlib.sha256(f.read()).hexdigest()[:16]
            
            version_info = {
                'version': version,
                'build_date': datetime.fromtimestamp(latest_time).isoformat(),
                'download_url': f'https://get.grim.so/builds/{latest_build}',
                'hash': file_hash,
                'size_mb': round(os.path.getsize(build_path) / (1024*1024), 2),
                'critical_update': False,  # Can be manually set for emergencies
                'changelog_url': 'https://grim.so/changelog',
                'release_notes': 'Latest Grim Reaper release with enhanced death prevention'
            }
            
            # Cache the result
            with open(CURRENT_VERSION_FILE, 'w') as f:
                json.dump(version_info, f, indent=2)
            
            return version_info
            
    except Exception as e:
        app.logger.error(f"Error getting latest version: {e}")
    
    # Ultimate fallback
    return {
        'version': '20250724_230520',
        'build_date': datetime.now().isoformat(),
        'download_url': 'https://get.grim.so/builds/latest.tar.gz',
        'hash': 'unknown',
        'size_mb': 11.0,
        'critical_update': False,
        'changelog_url': 'https://grim.so/changelog',
        'release_notes': 'Emergency fallback version'
    }

def log_version_check(client_ip, user_agent, current_version, latest_version, update_available):
    """Log version check for analytics"""
    try:
        conn = sqlite3.connect(USAGE_DB)
        conn.execute('''
            INSERT INTO version_checks 
            (client_ip, user_agent, current_version, latest_version, update_available)
            VALUES (?, ?, ?, ?, ?)
        ''', (client_ip, user_agent, current_version, latest_version, update_available))
        conn.commit()
        conn.close()
    except Exception as e:
        app.logger.error(f"Error logging version check: {e}")

# ============================================================================
# API ENDPOINTS
# ============================================================================
@app.route('/')
def index():
    """Service status page"""
    return jsonify({
        'service': 'up.grim.so',
        'description': '💀 Grim Reaper Version Check Service',
        'status': 'Death is always watching...',
        'endpoints': {
            '/version-check': 'Check for updates',
            '/stats': 'Usage statistics', 
            '/health': 'Service health'
        },
        'contact': 'rip@grim.so',
        'motto': 'Keeping your Grim up to date, one soul at a time'
    })

@app.route('/version-check', methods=['GET', 'POST'])
def version_check():
    """Main version check endpoint for auto-updates"""
    try:
        # Get current version from request
        current_version = request.json.get('current_version') if request.is_json else request.args.get('current_version', 'unknown')
        client_info = request.json.get('client_info', {}) if request.is_json else {}
        
        # Get latest version
        latest_info = get_latest_version()
        latest_version = latest_info['version']
        
        # Compare versions
        update_available = current_version != latest_version
        
        # Log the check
        client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.remote_addr)
        user_agent = request.headers.get('User-Agent', 'unknown')
        log_version_check(client_ip, user_agent, current_version, latest_version, update_available)
        
        # Prepare response
        response = {
            'current_version': current_version,
            'latest_version': latest_version,
            'update_available': update_available,
            'critical_update': latest_info.get('critical_update', False),
            'download_url': latest_info['download_url'],
            'changelog_url': latest_info['changelog_url'],
            'release_notes': latest_info['release_notes'],
            'file_hash': latest_info['hash'],
            'size_mb': latest_info['size_mb'],
            'checked_at': datetime.now().isoformat()
        }
        
        # Add update instructions if needed
        if update_available:
            response['update_instructions'] = [
                'curl -fsSL https://get.grim.so | sudo bash',
                'Or: wget -qO- https://get.grim.so | sudo bash'
            ]
            
            if latest_info.get('critical_update'):
                response['update_priority'] = 'critical'
                response['message'] = '💀 CRITICAL UPDATE: Your Grim needs immediate attention!'
            else:
                response['update_priority'] = 'normal'
                response['message'] = '🗡️ New Grim version available - Death awaits your upgrade'
        else:
            response['message'] = '✅ Your Grim is sharp and ready for battle'
        
        return jsonify(response)
        
    except Exception as e:
        app.logger.error(f"Error in version check: {e}")
        return jsonify({
            'error': 'version_check_failed',
            'message': '💀 Death cannot determine version status',
            'fallback_url': 'https://get.grim.so'
        }), 500

@app.route('/stats')
def stats():
    """Version check statistics (for Bernie's monitoring)"""
    try:
        conn = sqlite3.connect(USAGE_DB)
        
        # Get today's stats
        today = datetime.now().strftime('%Y-%m-%d')
        stats = conn.execute('''
            SELECT 
                COUNT(*) as total_checks,
                COUNT(DISTINCT client_ip) as unique_grimsters,
                SUM(CASE WHEN update_available = 1 THEN 1 ELSE 0 END) as updates_needed,
                COUNT(DISTINCT current_version) as version_diversity
            FROM version_checks 
            WHERE DATE(timestamp) = ?
        ''', (today,)).fetchone()
        
        # Get version distribution
        versions = conn.execute('''
            SELECT current_version, COUNT(*) as grimster_count
            FROM version_checks 
            WHERE DATE(timestamp) = ?
            GROUP BY current_version 
            ORDER BY grimster_count DESC
        ''', (today,)).fetchall()
        
        conn.close()
        
        return jsonify({
            'date': today,
            'total_checks': stats[0] or 0,
            'unique_grimsters': stats[1] or 0,
            'updates_needed': stats[2] or 0,
            'version_diversity': stats[3] or 0,
            'grimster_versions': [{'version': v[0], 'count': v[1]} for v in versions[:10]],
            'reaper_status': '💀 Death is monitoring all Grimsters',
            'contact': 'rip@grim.so'
        })
        
    except Exception as e:
        app.logger.error(f"Error getting stats: {e}")
        return jsonify({'error': '💀 Death cannot reveal statistics'}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        # Check if we can get latest version
        latest = get_latest_version()
        
        # Check database connectivity
        conn = sqlite3.connect(USAGE_DB)
        conn.execute('SELECT 1').fetchone()
        conn.close()
        
        return jsonify({
            'status': '💀 Death is operational',
            'timestamp': datetime.now().isoformat(),
            'latest_grim_version': latest['version'],
            'database': 'Connected to the underworld',
            'service': 'up.grim.so ready to serve'
        })
        
    except Exception as e:
        app.logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': '☠️ Death is experiencing technical difficulties',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

# ============================================================================
# APPLICATION STARTUP
# ============================================================================
if __name__ == '__main__':
    # Initialize database
    init_db()
    
    print("💀 UP.GRIM.SO Version Check Service Starting...")
    print("🗡️ Monitoring 3000+ Grimsters for updates...")
    print("📧 Contact: rip@grim.so")
    
    # Run Flask app
    port = int(os.environ.get('PORT', 4745))
    app.run(
        host='0.0.0.0',
        port=port,  # Configurable port for PM2
        debug=False
    )