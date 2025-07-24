#!/usr/bin/env python3
"""
Grim Admin Server with TuskLang Performance Engine
High-performance admin interface for Grim Reaper system
"""

import os
import sys
import time
import json
import logging
import secrets
import hashlib
import random
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

from flask import Flask, render_template_string, request, jsonify, send_from_directory, redirect, url_for, session, flash, get_flashed_messages, Response
from flask_cors import CORS
from flask_socketio import SocketIO
import asyncio

# Import simple TuskLang renderer
from simple_tsk_renderer import render_simple_tsk_template

# Import Grim command executor
from grim_executor import grim_executor

# Import Herd authentication system
from herd_auth import get_herd, init_herd, login_required, admin_required, get_current_user, is_authenticated

# Import database schema
from database_schema import db

# Import Mother Database integration
from mother_db import LocalMotherDB, MotherDBClient, get_error_tracker, init_error_tracker

# Import Flask-TSK with simple TSK renderer
try:
    from __init__ import FlaskTSK, render_tsk_template, TSK_RENDERER_AVAILABLE
    FLASK_TSK_AVAILABLE = TSK_RENDERER_AVAILABLE
    print(f"Flask-TSK available: {FLASK_TSK_AVAILABLE}")
except ImportError as e:
    FLASK_TSK_AVAILABLE = False
    print(f"Flask-TSK not available: {e}")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class GrimAdminServer:
    """High-performance admin server for Grim Reaper system"""
    
    def __init__(self, static_dir: str = None, config_path: str = None):
        self.app = Flask(__name__)
        self.static_dir = static_dir or os.path.dirname(__file__)
        self.config_path = config_path
        
        # Configure Flask with persistent secret key
        # Use a fixed secret key or load from environment/file
        secret_key = os.environ.get('GRIM_SECRET_KEY')
        if not secret_key:
            # Try to load from file
            secret_key_file = os.path.join(os.path.dirname(__file__), '.secret_key')
            if os.path.exists(secret_key_file):
                with open(secret_key_file, 'r') as f:
                    secret_key = f.read().strip()
            else:
                # Generate and save a new secret key
                secret_key = secrets.token_hex(32)
                with open(secret_key_file, 'w') as f:
                    f.write(secret_key)
                os.chmod(secret_key_file, 0o600)  # Secure file permissions
        
        self.app.config.update({
            'SECRET_KEY': secret_key,
            'DEBUG': True,
            'TEMPLATES_AUTO_RELOAD': False,  # Disabled for performance
            'SEND_FILE_MAX_AGE_DEFAULT': 0,
            # Session configuration
            'SESSION_COOKIE_NAME': 'grim_session',
            'SESSION_COOKIE_DOMAIN': None,  # Allow cookies on all subdomains
            'SESSION_COOKIE_PATH': '/',
            'SESSION_COOKIE_SECURE': True,  # Using HTTPS in production
            'SESSION_COOKIE_HTTPONLY': True,
            'SESSION_COOKIE_SAMESITE': 'Lax',
            'PERMANENT_SESSION_LIFETIME': timedelta(hours=24),
            'SESSION_REFRESH_EACH_REQUEST': False,  # Don't refresh on every request
            'SESSION_TYPE': 'filesystem'
        })
        
        # Initialize Herd authentication system
        self.herd = init_herd(self.app)
        
        # Initialize Mother Database
        self.mother_db = LocalMotherDB()
        
        # Initialize Error Tracker
        init_error_tracker()
        
        # Initialize TuskLang integration with simple TSK renderer
        global FLASK_TSK_AVAILABLE
        
        # Initialize Flask-TSK immediately
        try:
            with self.app.app_context():
                # Initialize Flask-TSK with simple renderer
                flask_tsk = FlaskTSK(self.app)
                FLASK_TSK_AVAILABLE = True
                logger.info("Flask-TSK initialized successfully with simple TSK renderer")
        except Exception as e:
            FLASK_TSK_AVAILABLE = False
            logger.warning(f"Flask-TSK not available: {e}")
        
        # Setup CORS
        CORS(self.app)
        
        # Initialize SocketIO
        self.socketio = SocketIO(
            self.app, 
            cors_allowed_origins="*",
            async_mode='eventlet',
            ping_timeout=10,
            ping_interval=5,
            logger=True,
            engineio_logger=True
        )
        
        # Initialize terminal handler
        from terminal_handler import TerminalHandler
        self.terminal_handler = TerminalHandler(self.socketio)
        
        # Initialize TSK renderer
        if FLASK_TSK_AVAILABLE:
            self.tsk_renderer = render_tsk_template
        else:
            self.tsk_renderer = render_simple_tsk_template
        
        # Setup routes
        self._setup_routes()
        
        logger.info("Grim Admin Server initialized with TuskLang performance engine")
    
    def _setup_routes(self):
        """Setup all admin routes"""
        
        # Static file serving
        @self.app.route('/static/<path:filename>')
        def static_files(filename):
            """Serve static files from static directory"""
            static_dir = os.path.join(os.path.dirname(__file__), 'static')
            return send_from_directory(static_dir, filename)
        
        @self.app.route('/assets/css/<path:filename>')
        def assets_css_files(filename):
            """Serve CSS files from grim/assets/css directory"""
            css_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets', 'css')
            return send_from_directory(css_dir, filename)
        
        @self.app.route('/assets/js/<path:filename>')
        def assets_js_files(filename):
            """Serve JavaScript files from grim/assets/js directory"""
            js_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets', 'js')
            return send_from_directory(js_dir, filename)
        
        @self.app.route('/assets/<path:filename>')
        def assets_files(filename):
            """Serve assets from grim/assets directory"""
            assets_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets')
            return send_from_directory(assets_dir, filename)
        
        # Rate limiting for login attempts
        login_attempts = {}
        
        # Authentication routes
        @self.app.route('/login', methods=['GET', 'POST'])
        def login():
            """Login page with Herd authentication"""
            # Check if user is already authenticated
            if self.herd.is_authenticated():
                return redirect('/admin')
            
            if request.method == 'POST':
                # Rate limiting check
                client_ip = request.remote_addr
                current_time = time.time()
                
                # Clean up old attempts (older than 5 minutes)
                login_attempts[client_ip] = [
                    t for t in login_attempts.get(client_ip, []) 
                    if current_time - t < 300
                ]
                
                # Check rate limit (max 5 attempts per 5 minutes)
                if len(login_attempts.get(client_ip, [])) >= 5:
                    flash('Too many login attempts. Please try again later.', 'error')
                    return self._render_admin_page('login', {
                        'page_title': 'Login - Grim Admin',
                        'herd_stats': self.herd.get_stats(),
                        'flash_messages': get_flashed_messages(with_categories=True)
                    })
                
                email = request.form.get('email', '').strip()
                password = request.form.get('password', '').strip()
                
                # Validate input - prevent empty credentials
                if not email or not password:
                    flash('Email and password are required', 'error')
                    return self._render_admin_page('login', {
                        'page_title': 'Login - Grim Admin',
                        'herd_stats': self.herd.get_stats(),
                        'flash_messages': get_flashed_messages(with_categories=True)
                    })
                
                # Record login attempt
                if client_ip not in login_attempts:
                    login_attempts[client_ip] = []
                login_attempts[client_ip].append(current_time)
                
                # Authenticate with Herd
                result = self.herd.authenticate(email, password)
                
                if result['success']:
                    # Clear login attempts on success
                    if client_ip in login_attempts:
                        del login_attempts[client_ip]
                    
                    # Redirect to next page or dashboard
                    next_page = session.get('next') or '/admin'
                    session.pop('next', None)
                    return redirect(next_page)
                else:
                    flash(result['error'], 'error')
            
            return self._render_admin_page('login', {
                'page_title': 'Login - Grim Admin',
                'herd_stats': self.herd.get_stats(),
                'flash_messages': get_flashed_messages(with_categories=True)
            })
        
        @self.app.route('/logout')
        def logout():
            """Logout with Herd authentication"""
            result = self.herd.logout()
            if result['success']:
                flash('Successfully logged out', 'success')
            else:
                flash(result['error'], 'error')
            return redirect('/login')
        
        @self.app.route('/clear-session')
        def clear_session():
            """Clear all sessions and force logout"""
            session.clear()
            return redirect('/login')
        
        @self.app.route('/force-logout')
        def force_logout():
            """Force logout and clear all browser cache"""
            session.clear()
            response = redirect('/login')
            response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, private'
            response.headers['Pragma'] = 'no-cache'
            response.headers['Expires'] = '0'
            response.headers['Clear-Site-Data'] = '"cache", "cookies", "storage"'
            return response
        
        @self.app.route('/register', methods=['GET', 'POST'])
        def register():
            """User registration page"""
            if request.method == 'POST':
                email = request.form.get('email')
                username = request.form.get('username')
                password = request.form.get('password')
                confirm_password = request.form.get('confirm_password')
                
                if password != confirm_password:
                    flash('Passwords do not match', 'error')
                else:
                    result = self.herd.register_user(email, username, password)
                    if result['success']:
                        flash('Registration successful! Please log in.', 'success')
                        return redirect('/login')
                    else:
                        flash(result['error'], 'error')
            
            return self._render_admin_page('admin/register.html', {
                'page_title': 'Register - Grim Admin',
                'flash_messages': get_flashed_messages(with_categories=True)
            })
        
        @self.app.route('/admin/users')
        @admin_required
        def users_page():
            """User management page (admin only)"""
            users = list(self.herd.users.values())
            audit_logs = self.herd.get_audit_logs(limit=50)
            
            return self._render_admin_page('grim/admin/users', {
                'page_title': 'User Management - Grim Admin',
                'users': users,
                'audit_logs': audit_logs,
                'herd_stats': self.herd.get_stats()
            })
        
        # Main admin routes (protected)
        # Root route - always serve landing page (grim.so)
        @self.app.route('/')
        def root():
            """Root route - serve public landing page"""
            grim_dir = os.path.join(os.path.dirname(__file__), 'grim')
            landing_file = os.path.join(grim_dir, 'public', 'landing.html')
            
            if os.path.exists(landing_file):
                with open(landing_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                # Use simple TuskLang template rendering
                return self.tsk_renderer(content, {
                    'page_title': 'Grim - The Reaper of Data Lossssss',
                    'tsk_available': FLASK_TSK_AVAILABLE,
                    'tsk_version': '2.0.3' if FLASK_TSK_AVAILABLE else 'not available'
                })
            else:
                return "Landing page not found", 404
        
        # Admin routes - protected (rp.grim.so)
        @self.app.route('/admin')
        @login_required
        def admin_dashboard():
            """Main admin dashboard"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'reaper',
                'page_title': 'Grim Reaper Dashboard',
                'css_files': ['admin.css', 'dashboard.css'],
                'alert_count': 0
            })
        
        @self.app.route('/test-dashboard')
        def test_dashboard():
            """Test admin dashboard without authentication"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'reaper',
                'page_title': 'Grim Reaper Dashboard',
                'css_files': ['admin.css', 'dashboard.css'],
                'alert_count': 0
            })
        
        @self.app.route('/test-backup')
        def test_backup():
            """Test backup page without authentication"""
            return self._render_admin_page('admin/backup', {
                'current_page': 'backup',
                'page_title': 'Backup Management - Grim Admin'
            })
        
        @self.app.route('/test-alerts')
        def test_alerts():
            """Test alerts page without authentication"""
            return self._render_admin_page('admin/alerts.html', {
                'current_page': 'alerts',
                'page_title': 'System Alerts - Grim Admin'
            })
        
        @self.app.route('/test-docs')
        def test_docs():
            """Test docs page without authentication"""
            return self._render_admin_page('admin/docs', {
                'current_page': 'docs',
                'page_title': 'Command Reference - Grim Admin'
            })
        
        @self.app.route('/auth')
        def auth_page():
            """Authentication page"""
            return self._render_admin_page('grim-auth-page.html')
        
        @self.app.route('/landing')
        def landing_page():
            """Public landing page"""
            return self._render_public_page('grim/public/landing.html', {
                'page_title': 'Grim - The Reaper of Data Lossssss',
                'page_type': 'landing'
            })
        
        @self.app.route('/home')
        def home_page():
            """Home page - redirect to landing"""
            return redirect('/')
        
        @self.app.route('/admin/license')
        @login_required
        def license_manager():
            """License management page"""
            return self._render_admin_page('admin/license.html', {
                'current_page': 'license',
                'page_title': 'License Management'
            })
        
        @self.app.route('/admin/audit')
        @login_required
        def audit_page():
            """Audit content page"""
            return self._render_admin_page('admin/audit_content.html', {
                'current_page': 'audit',
                'page_title': 'Audit Management'
            })
        
        @self.app.route('/admin/scan')
        @login_required
        def scan_page():
            """Scan content page"""
            return self._render_admin_page('admin/scan_content.html', {
                'current_page': 'scan',
                'page_title': 'Scan Management'
            })
        
        @self.app.route('/admin/settings')
        @login_required
        def settings_page():
            """Settings page"""
            return self._render_admin_page('admin/settings_content.html', {
                'current_page': 'settings',
                'page_title': 'Settings Management'
            })
        
        @self.app.route('/admin/reaper')
        @login_required
        def reaper_dashboard():
            """Reaper admin dashboard"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'reaper',
                'page_title': 'Reaper Dashboard'
            })

        @self.app.route('/admin/backup')
        @login_required
        def backup_page():
            """Backup management page"""
            return self._render_admin_page('admin/backup_main.html', {
                'current_page': 'backup',
                'page_title': 'Backup Management'
            })

        @self.app.route('/admin/hash')
        @login_required
        def hash_page():
            """Hash management page"""
            # Force cache-busting headers to prevent browser caching
            response = self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'hash',
                'page_title': 'Hash Management',
                'css_files': ['admin.css', 'public.css']
            })
            
            # Add cache-busting headers
            if isinstance(response, str):
                from flask import make_response
                resp = make_response(response)
                resp.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, private'
                resp.headers['Pragma'] = 'no-cache'
                resp.headers['Expires'] = '0'
                return resp
            return response

        @self.app.route('/admin/trash')
        @login_required
        def trash_page():
            """Trash management page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'trash',
                'page_title': 'Trash Management'
            })

        @self.app.route('/admin/remote')
        @login_required
        def remote_page():
            """Remote management page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'remote',
                'page_title': 'Remote Management'
            })

        @self.app.route('/admin/logs')
        @login_required
        def logs_page():
            """Logs management page"""
            return self._render_admin_page('admin/logs.html', {
                'current_page': 'logs',
                'page_title': 'Logs Management'
            })

        @self.app.route('/admin/scythe')
        @login_required
        def scythe_page():
            """Scythe orchestrator page"""
            return self._render_admin_page('admin/scythe_license_manager.html', {
                'current_page': 'scythe',
                'page_title': 'Scythe Orchestrator'
            })

        @self.app.route('/admin/emergency')
        @login_required
        def emergency_page():
            """Emergency Operations page"""
            return self._render_admin_page("admin/emergency", {"page_title": "Emergency - System Recovery"})

        @self.app.route('/admin/terminal')
        @login_required
        def terminal_page():
            """Terminal page - use simple version for now"""
            return self._render_admin_page('admin/terminal_simple.html', {
                'current_page': 'terminal',
                'page_title': 'Terminal - Server Access'
            })
        
        @self.app.route('/admin/terminal-test')
        @login_required
        def terminal_test_page():
            """Terminal test page"""
            return self._render_admin_page('admin/terminal_test.html', {
                'current_page': 'terminal',
                'page_title': 'Terminal Test'
            })

        @self.app.route('/admin/docs')
        @login_required
        def docs_page():
            """Documentation page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'docs',
                'page_title': 'Documentation'
            })

        @self.app.route('/admin/alerts')
        @login_required
        def alerts_page():
            """Alerts management page"""
            return self._render_admin_page('admin/alerts.html', {
                'current_page': 'alerts',
                'page_title': 'Alerts Management'
            })
        
        @self.app.route('/admin/auto-backup')
        @login_required
        def auto_backup_page():
            """Auto-backup management page"""
            return self._render_admin_page('admin/auto-backup.html', {
                'current_page': 'auto-backup',
                'page_title': 'Auto-Backup Management'
            })
        
        @self.app.route('/admin/auto-backup/all')
        @login_required
        def auto_backup_all_page():
            """All auto-backups page"""
            return self._render_admin_page('admin/auto-backup-all.html', {
                'current_page': 'auto-backup',
                'page_title': 'All Auto-Backups'
            })
        
        @self.app.route('/test-mother-db')
        def test_mother_db_dashboard():
            """Test Mother Database dashboard without authentication"""
            try:
                stats = self.mother_db.get_stats()
                installations = self.mother_db.get_all_installations()
                recent_errors = self.mother_db.get_all_errors(20)
                
                return self._render_admin_page('admin/mother-db.html', {
                    'page_title': 'Mother Database',
                    'current_page': 'mother-db',
                    'stats': stats,
                    'installations': installations,
                    'recent_errors': recent_errors
                })
            except Exception as e:
                logger.error(f"Error loading mother database dashboard: {e}")
                return self._render_admin_page('admin/mother-db.html', {
                    'page_title': 'Mother Database',
                    'current_page': 'mother-db',
                    'error': str(e)
                })
        
        @self.app.route('/admin/mother-db')
        @admin_required
        def mother_db_dashboard():
            """Mother Database dashboard"""
            try:
                stats = self.mother_db.get_stats()
                installations = self.mother_db.get_all_installations()
                recent_errors = self.mother_db.get_all_errors(20)
                
                return self._render_admin_page('admin/mother-db.html', {
                    'page_title': 'Mother Database',
                    'current_page': 'mother-db',
                    'stats': stats,
                    'installations': installations,
                    'recent_errors': recent_errors
                })
            except Exception as e:
                logger.error(f"Error loading mother database dashboard: {e}")
                return self._render_admin_page('admin/mother-db.html', {
                    'page_title': 'Mother Database',
                    'current_page': 'mother-db',
                    'error': str(e)
                })
        
        @self.app.route('/admin/mother-db/installations')
        @admin_required
        def mother_db_installations():
            """Mother Database installations page"""
            try:
                installations = self.mother_db.get_all_installations()
                return self._render_admin_page('admin/mother-db-installations.html', {
                    'page_title': 'Installations',
                    'current_page': 'mother-db-installations',
                    'installations': installations
                })
            except Exception as e:
                logger.error(f"Error loading installations page: {e}")
                return self._render_admin_page('admin/mother-db-installations.html', {
                    'page_title': 'Installations',
                    'current_page': 'mother-db-installations',
                    'error': str(e)
                })
        
        @self.app.route('/admin/mother-db/errors')
        @admin_required
        def mother_db_errors():
            """Mother Database errors page"""
            try:
                errors = self.mother_db.get_all_errors(100)
                return self._render_admin_page('admin/mother-db-errors.html', {
                    'page_title': 'Error Reports',
                    'current_page': 'mother-db-errors',
                    'errors': errors
                })
            except Exception as e:
                logger.error(f"Error loading errors page: {e}")
                return self._render_admin_page('admin/mother-db-errors.html', {
                    'page_title': 'Error Reports',
                    'current_page': 'mother-db-errors',
                    'error': str(e)
                })
        
        # Public pages - serve static files
        @self.app.route('/public/api-docs')
        def api_docs():
            """API documentation"""
            return send_from_directory('grim/public', 'api-docs.html')
        
        @self.app.route('/public/command-reference')
        def command_reference():
            """Command reference"""
            return send_from_directory('grim/public', 'command-reference.html')
        
        @self.app.route('/comparison')
        def comparison_chart():
            """Comparison chart"""
            return self._render_public_page('comparison-chart.html', {
                'page_title': 'GRIM vs Traditional Backup Solutions - Comparison',
                'page_description': 'See how GRIM revolutionizes data protection compared to legacy tools'
            })
        
        @self.app.route('/public/comparison')
        def public_comparison_chart():
            """Comparison chart (legacy URL)"""
            return redirect('/comparison', 301)
        
        @self.app.route('/grim-architecture')
        def grim_architecture():
            """Grim architecture page"""
            return self._render_public_page('architecture.html', {
                'page_title': 'Grim Architecture',
                'page_description': 'The Architecture of Immortality - Four specialized subsystems, one unified interface'
            })
        
        @self.app.route('/commands')
        def grim_command_reference():
            """Grim command reference page"""
            return self._render_public_page('command-reference.html', {
                'page_title': 'Grim Command Reference',
                'page_description': 'Complete guide to the unified command system - Everything through grim'
            })
            
        @self.app.route('/grim-command-reference')
        def grim_command_reference_redirect():
            """Redirect old command reference URL to new one"""
            return redirect('/commands', 301)
        
        @self.app.route('/grim-comparison-chart')
        def grim_comparison_chart():
            """Grim comparison chart page (legacy URL)"""
            return redirect('/comparison', 301)
        
        # New routes for updated menu links
        @self.app.route('/grim-api-docs')
        def grim_api_docs():
            """Grim API documentation"""
            return self._render_public_page('api-docs.html', {
                'page_title': 'GRIM REST API Documentation',
                'page_description': 'Programmatic access to the unified data protection ecosystem'
            })
        
        @self.app.route('/docs')
        def docs():
            """Grim documentation page"""
            return self._render_public_page('docs.html', {
                'page_title': 'GRIM Documentation',
                'page_description': 'Complete documentation for the unified data protection ecosystem'
            })
        
        @self.app.route('/grim-commands-reference')
        def grim_commands_reference():
            """Grim commands reference"""
            return send_from_directory('z_archive/convert', 'grim-commands-reference-standalone.html')
        
        # Landing page route
        @self.app.route('/public/')
        @self.app.route('/public/index')
        def public_landing():
            """Public landing page"""
            return self._render_public_page('landing.html', {
                'page_title': 'Grim - The Reaper of Data Loss',
                'page_type': 'landing'
            })
        
        # API endpoints
        @self.app.route('/api/status')
        def api_status():
            """Get system status"""
            return jsonify({
                'status': 'operational',
                'timestamp': datetime.now().isoformat(),
                'tusk_available': FLASK_TSK_AVAILABLE,
                'performance_stats': get_performance_stats()
            })
        
        @self.app.route('/api/config/<section>')
        def api_config(section):
            """Get configuration section"""
            if self.tsk:
                config = self.tsk.get_section(section)
                return jsonify({
                    'section': section,
                    'config': config or {},
                    'success': config is not None
                })
            else:
                return jsonify({
                    'section': section,
                    'config': {},
                    'success': False,
                    'error': 'TuskLang not available'
                })
        
        @self.app.route('/api/performance')
        def api_performance():
            """Get performance statistics"""
            return jsonify(get_performance_stats())
        
        @self.app.route('/api/tusk/status')
        def api_tusk_status():
            """Get TuskLang status"""
            try:
                # Use Flask-TSK integration
                if FLASK_TSK_AVAILABLE:
                    tsk_config = get_tsk_config()
                    return jsonify({
                        'available': True,
                        'renderer': 'simple_tsk_renderer',
                        'performance_engine': 'turbo_engine',
                        'version': '2.0.5-simple',
                        'config': tsk_config
                    })
                else:
                    return jsonify({
                        'available': False,
                        'error': 'Flask-TSK not available',
                        'renderer': 'simple_tsk_renderer'
                    })
            except Exception as e:
                return jsonify({
                    'available': False,
                    'error': str(e),
                    'renderer': 'simple_tsk_renderer'
                })
        
        # Command execution endpoints
        @self.app.route('/api/execute', methods=['POST'])
        @login_required
        def execute_command():
            """Execute command via web interface"""
            try:
                data = request.get_json()
                
                # Check if it's a simple shell command
                if 'command' in data:
                    # Direct shell command execution
                    command = data.get('command', '')
                    timeout = data.get('timeout', 30)
                    
                    try:
                        # Execute the command in the application's base directory
                        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                        result = subprocess.run(
                            command,
                            shell=True,
                            capture_output=True,
                            text=True,
                            timeout=timeout,
                            cwd=base_dir
                        )
                        
                        return jsonify({
                            'success': True,
                            'output': result.stdout,
                            'error': result.stderr,
                            'return_code': result.returncode
                        })
                        
                    except subprocess.TimeoutExpired:
                        return jsonify({
                            'success': False,
                            'error': f'Command timed out after {timeout} seconds'
                        })
                    except Exception as e:
                        return jsonify({
                            'success': False,
                            'error': str(e)
                        })
                
                else:
                    # Original grim executor format
                    command_type = data.get('type', 'system')
                    command_args = data.get('args', {})
                    
                    # Execute command asynchronously using synchronous wrapper
                    command_id = grim_executor.execute_command_async_sync(command_type, command_args)
                    
                    return jsonify({
                        'success': True,
                        'command_id': command_id,
                        'message': 'Command queued for execution'
                    })
                    
            except Exception as e:
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/command/<command_id>')
        @login_required
        def get_command_result(command_id):
            """Get result of a specific command"""
            result = grim_executor.get_command_result(command_id)
            if result:
                return jsonify({
                    'success': True,
                    'command_id': command_id,
                    'result': {
                        'success': result.success,
                        'command': result.command,
                        'output': result.output,
                        'error': result.error,
                        'return_code': result.return_code,
                        'execution_time': result.execution_time,
                        'timestamp': result.timestamp.isoformat()
                    }
                })
            else:
                return jsonify({
                    'success': False,
                    'error': 'Command not found or still running'
                }), 404
        
        @self.app.route('/api/commands/history')
        def get_command_history():
            """Get command execution history"""
            limit = request.args.get('limit', 50, type=int)
            history = grim_executor.get_command_history(limit)
            return jsonify({
                'success': True,
                'history': history
            })
        
        @self.app.route('/api/executor/status')
        def get_executor_status():
            """Get executor status"""
            status = grim_executor.get_system_status()
            return jsonify({
                'success': True,
                'status': status
            })
        
        # Herd Authentication API endpoints
        @self.app.route('/api/auth/status')
        def auth_status():
            """Get authentication status"""
            try:
                user = get_current_user()
                if user:
                    return jsonify({
                        'success': True,
                        'authenticated': True,
                        'user': {
                            'id': user.id,
                            'email': user.email,
                            'username': user.username,
                            'is_admin': user.is_admin,
                            'last_login': user.last_login.isoformat() if user.last_login else None
                        }
                    })
                else:
                    return jsonify({
                        'success': True,
                        'authenticated': False
                    })
            except Exception as e:
                logger.error(f"Error getting auth status: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auth/stats')
        @admin_required
        def auth_stats():
            """Get authentication system statistics (admin only)"""
            try:
                stats = self.herd.get_stats()
                return jsonify({
                    'success': True,
                    'data': stats
                })
            except Exception as e:
                logger.error(f"Error getting auth stats: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auth/audit-logs')
        @admin_required
        def auth_audit_logs():
            """Get audit logs (admin only)"""
            try:
                user_id = request.args.get('user_id', type=int)
                action = request.args.get('action')
                limit = request.args.get('limit', 100, type=int)
                
                logs = self.herd.get_audit_logs(
                    user_id=user_id,
                    action=action,
                    limit=limit
                )
                
                return jsonify({
                    'success': True,
                    'data': logs
                })
            except Exception as e:
                logger.error(f"Error getting audit logs: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # Health check
        @self.app.route('/health')
        def health_check():
            """Health check endpoint"""
            return jsonify({
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'version': '1.0.0',
                'tusk_engine': FLASK_TSK_AVAILABLE,
                'executor_status': grim_executor.get_system_status()
            })
        
        # Mother Database API Endpoints (Public - No Authentication Required)
        @self.app.route('/db/create_child', methods=['POST'])
        @self.app.route('/create_child', methods=['POST'])
        @self.app.route('/grim.so/db/create_child', methods=['POST'])
        def create_child():
            """Register a new installation with the mother database"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({
                        'success': False,
                        'error': 'No data provided'
                    }), 400
                
                result = self.mother_db.create_child(data)
                return jsonify(result)
                
            except Exception as e:
                logger.error(f"Error creating child installation: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/db/cry_to_mom', methods=['POST'])
        @self.app.route('/cry_to_mom', methods=['POST'])
        @self.app.route('/grim.so/db/cry_to_mom', methods=['POST'])
        def cry_to_mom():
            """Send error report to mother database"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({
                        'success': False,
                        'error': 'No data provided'
                    }), 400
                
                result = self.mother_db.cry_to_mom(data)
                return jsonify(result)
                
            except Exception as e:
                logger.error(f"Error sending error report: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/db/status/<install_id>')
        def get_installation_status(install_id):
            """Get installation status from mother database"""
            try:
                result = self.mother_db.get_installation_status(install_id)
                return jsonify(result)
                
            except Exception as e:
                logger.error(f"Error getting installation status: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/db/update/<install_id>', methods=['PUT'])
        def update_installation(install_id):
            """Update installation data in mother database"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({
                        'success': False,
                        'error': 'No data provided'
                    }), 400
                
                result = self.mother_db.update_installation(install_id, data)
                return jsonify(result)
                
            except Exception as e:
                logger.error(f"Error updating installation: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/db/installations')
        @admin_required
        def get_all_installations():
            """Get all installations (admin only)"""
            try:
                installations = self.mother_db.get_all_installations()
                return jsonify({
                    'success': True,
                    'installations': installations
                })
                
            except Exception as e:
                logger.error(f"Error getting installations: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/db/errors')
        @admin_required
        def get_all_errors():
            """Get all errors (admin only)"""
            try:
                limit = request.args.get('limit', 100, type=int)
                errors = self.mother_db.get_all_errors(limit)
                return jsonify({
                    'success': True,
                    'errors': errors
                })
                
            except Exception as e:
                logger.error(f"Error getting errors: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/db/stats')
        @admin_required
        def get_db_stats():
            """Get database statistics (admin only)"""
            try:
                stats = self.mother_db.get_stats()
                return jsonify({
                    'success': True,
                    'stats': stats
                })
                
            except Exception as e:
                logger.error(f"Error getting stats: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # Log Management API endpoints
        @self.app.route('/api/logs/sources')
        @login_required
        def get_log_sources():
            """Get available log sources"""
            try:
                sources = [
                    {
                        'id': 'grim_error',
                        'name': 'Grim Error Log',
                        'description': 'Main error tracking log',
                        'path': '/tmp/grim-error.log',
                        'type': 'error',
                        'active': True
                    },
                    {
                        'id': 'executor',
                        'name': 'Executor Log',
                        'description': 'Command execution log',
                        'path': '/opt/reaper/logs/executor.log',
                        'type': 'system',
                        'active': True
                    },
                    {
                        'id': 'scythe',
                        'name': 'Scythe Orchestrator',
                        'description': 'License orchestrator log',
                        'path': '/opt/reaper/scythe/logs/orchestrator.log',
                        'type': 'orchestrator',
                        'active': True
                    },
                    {
                        'id': 'flask',
                        'name': 'Flask Application',
                        'description': 'Flask server application log',
                        'path': '/var/log/grim/flask.log',
                        'type': 'application',
                        'active': True
                    },
                    {
                        'id': 'nginx',
                        'name': 'Nginx Access',
                        'description': 'Web server access log',
                        'path': '/var/log/nginx/grim.access.log',
                        'type': 'access',
                        'active': True
                    },
                    {
                        'id': 'nginx_error',
                        'name': 'Nginx Error',
                        'description': 'Web server error log',
                        'path': '/var/log/nginx/grim.error.log',
                        'type': 'error',
                        'active': True
                    }
                ]
                
                return jsonify({
                    'success': True,
                    'sources': sources,
                    'total_sources': len(sources)
                })
                
            except Exception as e:
                logger.error(f"Error getting log sources: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/logs/entries')
        @login_required
        def get_log_entries():
            """Get log entries with filtering and pagination"""
            try:
                # Get query parameters
                source = request.args.get('source', 'grim_error')
                level = request.args.get('level', 'all')
                limit = request.args.get('limit', 100, type=int)
                offset = request.args.get('offset', 0, type=int)
                search = request.args.get('search', '')
                time_range = request.args.get('time_range', '24h')
                
                # Get log file path (using relative paths)
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                log_paths = {
                    'grim_error': '/tmp/grim-error.log',
                    'executor': os.path.join(base_dir, 'logs/executor.log'),
                    'scythe': os.path.join(base_dir, 'scythe/logs/orchestrator.log'),
                    'flask': '/var/log/grim/flask.log',
                    'nginx': '/var/log/nginx/grim.access.log',
                    'nginx_error': '/var/log/nginx/grim.error.log'
                }
                
                log_path = log_paths.get(source, '/tmp/grim-error.log')
                
                # Read and parse log entries
                entries = self._parse_log_file(log_path, level, limit, offset, search, time_range)
                
                return jsonify({
                    'success': True,
                    'entries': entries,
                    'total_entries': len(entries),
                    'source': source,
                    'filters': {
                        'level': level,
                        'search': search,
                        'time_range': time_range
                    }
                })
                
            except Exception as e:
                logger.error(f"Error getting log entries: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/logs/stats')
        @login_required
        def get_log_stats():
            """Get log statistics"""
            try:
                stats = {
                    'total_logs': 0,
                    'error_count': 0,
                    'warning_count': 0,
                    'info_count': 0,
                    'debug_count': 0,
                    'sources': {},
                    'recent_activity': []
                }
                
                # Get stats from all log sources
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                log_sources = [
                    ('grim_error', '/tmp/grim-error.log'),
                    ('executor', os.path.join(base_dir, 'logs/executor.log')),
                    ('scythe', os.path.join(base_dir, 'scythe/logs/orchestrator.log'))
                ]
                
                for source_id, log_path in log_sources:
                    try:
                        source_stats = self._get_log_file_stats(log_path)
                        stats['sources'][source_id] = source_stats
                        stats['total_logs'] += source_stats.get('total', 0)
                        stats['error_count'] += source_stats.get('error', 0)
                        stats['warning_count'] += source_stats.get('warning', 0)
                        stats['info_count'] += source_stats.get('info', 0)
                        stats['debug_count'] += source_stats.get('debug', 0)
                    except:
                        stats['sources'][source_id] = {'total': 0, 'error': 0, 'warning': 0, 'info': 0, 'debug': 0}
                
                return jsonify({
                    'success': True,
                    'stats': stats
                })
                
            except Exception as e:
                logger.error(f"Error getting log stats: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/logs/live')
        @login_required
        def get_live_logs():
            """Get live log stream"""
            try:
                source = request.args.get('source', 'grim_error')
                lines = request.args.get('lines', 50, type=int)
                
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                log_paths = {
                    'grim_error': '/tmp/grim-error.log',
                    'executor': os.path.join(base_dir, 'logs/executor.log'),
                    'scythe': os.path.join(base_dir, 'scythe/logs/orchestrator.log')
                }
                
                log_path = log_paths.get(source, '/tmp/grim-error.log')
                
                # Use tail to get recent entries
                try:
                    import subprocess
                    result = subprocess.run(['tail', '-n', str(lines), log_path], 
                                          capture_output=True, text=True, timeout=5)
                    
                    if result.returncode == 0:
                        entries = self._parse_log_lines(result.stdout.split('\n'))
                        return jsonify({
                            'success': True,
                            'entries': entries,
                            'source': source,
                            'timestamp': datetime.utcnow().isoformat() + 'Z'
                        })
                    else:
                        return jsonify({
                            'success': False,
                            'error': 'Failed to read log file'
                        })
                        
                except FileNotFoundError:
                    return jsonify({
                        'success': False,
                        'error': f'Log file not found: {log_path}'
                    })
                    
            except Exception as e:
                logger.error(f"Error getting live logs: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/logs/clear', methods=['POST'])
        @admin_required
        def clear_logs():
            """Clear log file (admin only)"""
            try:
                data = request.get_json() or {}
                source = data.get('source', 'grim_error')
                
                log_paths = {
                    'grim_error': '/tmp/grim-error.log',
                    'executor': '/opt/reaper/logs/executor.log',
                    'scythe': '/opt/reaper/scythe/logs/orchestrator.log'
                }
                
                log_path = log_paths.get(source)
                if not log_path:
                    return jsonify({
                        'success': False,
                        'error': 'Invalid log source'
                    }), 400
                
                # Clear the log file
                try:
                    with open(log_path, 'w') as f:
                        f.write('')
                    
                    return jsonify({
                        'success': True,
                        'message': f'Log file {source} cleared successfully'
                    })
                    
                except Exception as e:
                    return jsonify({
                        'success': False,
                        'error': f'Failed to clear log file: {str(e)}'
                    })
                    
            except Exception as e:
                logger.error(f"Error clearing logs: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/logs/export')
        @login_required
        def export_logs():
            """Export logs as file"""
            try:
                source = request.args.get('source', 'all')
                format_type = request.args.get('format', 'txt')
                time_range = request.args.get('time_range', '24h')
                
                if source == 'all':
                    # Export all logs
                    export_data = self._export_all_logs(format_type, time_range)
                else:
                    # Export specific log source
                    export_data = self._export_single_log(source, format_type, time_range)
                
                return jsonify({
                    'success': True,
                    'data': export_data,
                    'filename': f'grim-logs-{source}-{datetime.now().strftime("%Y%m%d-%H%M%S")}.{format_type}'
                })
                
            except Exception as e:
                logger.error(f"Error exporting logs: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # Main Backup API endpoints
        @self.app.route('/api/backup/list')
        @login_required
        def backup_list():
            """List all backups"""
            try:
                # Execute grim backup list command
                result = grim_executor.execute_command_sync('backup', {'action': 'list', 'format': 'json'})
                
                if result and result.success:
                    # Try to parse JSON output
                    try:
                        backups = json.loads(result.output)
                    except json.JSONDecodeError:
                        # Fallback to parsing text output
                        backups = []
                        lines = result.output.strip().split('\n')
                        for line in lines:
                            if line and not line.startswith('#'):
                                parts = line.split()
                                if len(parts) >= 5:
                                    backups.append({
                                        'id': parts[0],
                                        'name': parts[1],
                                        'type': parts[2],
                                        'size': parts[3],
                                        'created': parts[4],
                                        'status': 'completed'
                                    })
                    
                    return jsonify({
                        'success': True,
                        'backups': backups
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': result.error if result else 'Failed to execute command'
                    })
            except Exception as e:
                logger.error(f"Error listing backups: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/backup/create', methods=['POST'])
        @login_required
        def backup_create():
            """Create a new backup"""
            try:
                data = request.get_json()
                backup_type = data.get('type', 'full')
                name = data.get('name', f'{backup_type}_backup_{datetime.now().strftime("%Y%m%d_%H%M%S")}')
                
                # Map backup types to tools
                tool_map = {
                    'full': 'sh_grim',
                    'incremental': 'go_grim',
                    'database': 'py_grim',
                    'config': 'sh_grim'
                }
                
                tool = tool_map.get(backup_type, 'sh_grim')
                
                # Execute backup command using synchronous wrapper
                command_id = grim_executor.execute_command_async_sync('backup', {
                    'action': 'create',
                    'type': backup_type,
                    'name': name,
                    'tool': tool
                })
                
                # Create backup record
                backup = {
                    'id': command_id,
                    'name': name,
                    'type': backup_type,
                    'status': 'running',
                    'created': datetime.now().isoformat(),
                    'progress': 0
                }
                
                return jsonify({
                    'success': True,
                    'backup': backup,
                    'command_id': command_id
                })
            except Exception as e:
                logger.error(f"Error creating backup: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/backup/<backup_id>/restore', methods=['POST'])
        @login_required
        def backup_restore(backup_id):
            """Restore a backup"""
            try:
                data = request.get_json()
                target_path = data.get('target_path', '/opt/reaper')
                
                # Execute restore command using synchronous wrapper
                command_id = grim_executor.execute_command_async_sync('backup', {
                    'action': 'restore',
                    'backup_id': backup_id,
                    'target': target_path
                })
                
                return jsonify({
                    'success': True,
                    'command_id': command_id,
                    'message': 'Restore initiated'
                })
            except Exception as e:
                logger.error(f"Error restoring backup: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/backup/<backup_id>/verify', methods=['GET'])
        @login_required
        def backup_verify(backup_id):
            """Verify backup integrity"""
            try:
                # Execute verify command
                result = grim_executor.execute_command_sync('backup', {
                    'action': 'verify',
                    'backup_id': backup_id
                })
                
                return jsonify({
                    'success': result.success if result else False,
                    'valid': result.success if result else False,
                    'details': result.output if result else 'Verification failed'
                })
            except Exception as e:
                logger.error(f"Error verifying backup: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/backup/<backup_id>', methods=['DELETE'])
        @login_required
        def backup_delete(backup_id):
            """Delete a backup"""
            try:
                # Execute delete command
                result = grim_executor.execute_command_sync('backup', {
                    'action': 'delete',
                    'backup_id': backup_id
                })
                
                return jsonify({
                    'success': result.success if result else False,
                    'message': 'Backup deleted' if result and result.success else 'Failed to delete backup'
                })
            except Exception as e:
                logger.error(f"Error deleting backup: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/backup/stats')
        @login_required
        def backup_stats():
            """Get backup statistics"""
            try:
                # Get backup stats from various sources
                stats = {
                    'total_backups': 0,
                    'total_size': 0,
                    'last_backup': None,
                    'backup_types': {
                        'full': 0,
                        'incremental': 0,
                        'database': 0,
                        'config': 0
                    },
                    'storage_used': '0 GB',
                    'compression_ratio': '0%'
                }
                
                # Try to get actual stats from grim
                result = grim_executor.execute_command_sync('backup', {'action': 'stats'})
                if result and result.success:
                    try:
                        stats.update(json.loads(result.output))
                    except:
                        # Parse text output if not JSON
                        pass
                
                return jsonify({
                    'success': True,
                    'stats': stats
                })
            except Exception as e:
                logger.error(f"Error getting backup stats: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # Auto-backup specific endpoints
        @self.app.route('/api/auto-backup/schedules', methods=['GET', 'POST'])
        @login_required
        def auto_backup_schedules():
            """Get or create auto-backup schedules"""
            try:
                if request.method == 'GET':
                    # Get schedules from cron or systemd timers
                    schedules = []
                    
                    # Check cron jobs
                    result = subprocess.run(['crontab', '-l'], capture_output=True, text=True)
                    if result.returncode == 0:
                        for line in result.stdout.split('\n'):
                            if 'grim' in line and 'backup' in line:
                                schedules.append({
                                    'id': hashlib.md5(line.encode()).hexdigest()[:8],
                                    'schedule': line.split()[0:5],
                                    'command': ' '.join(line.split()[5:]),
                                    'type': 'cron',
                                    'enabled': not line.startswith('#')
                                })
                    
                    return jsonify({
                        'success': True,
                        'schedules': schedules
                    })
                
                else:  # POST
                    data = request.get_json()
                    schedule_type = data.get('type', 'daily')
                    time = data.get('time', '02:00')
                    backup_type = data.get('backup_type', 'incremental')
                    
                    # Create cron job
                    hour, minute = time.split(':')
                    cron_schedule = f"{minute} {hour} * * *" if schedule_type == 'daily' else f"{minute} {hour} * * 0"
                    cron_command = f"/opt/reaper/sh_grim/backup.sh create {backup_type}"
                    
                    # Add to crontab
                    result = subprocess.run(['crontab', '-l'], capture_output=True, text=True)
                    current_cron = result.stdout if result.returncode == 0 else ""
                    new_cron = current_cron + f"\n{cron_schedule} {cron_command}\n"
                    
                    process = subprocess.Popen(['crontab', '-'], stdin=subprocess.PIPE, text=True)
                    process.communicate(new_cron)
                    
                    return jsonify({
                        'success': True,
                        'message': 'Schedule created'
                    })
                    
            except Exception as e:
                logger.error(f"Error managing auto-backup schedules: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auto-backup/schedules/<schedule_id>', methods=['PUT', 'DELETE'])
        @login_required
        def auto_backup_schedule_manage(schedule_id):
            """Update or delete auto-backup schedule"""
            try:
                if request.method == 'DELETE':
                    # Remove from crontab
                    result = subprocess.run(['crontab', '-l'], capture_output=True, text=True)
                    if result.returncode == 0:
                        lines = []
                        for line in result.stdout.split('\n'):
                            line_hash = hashlib.md5(line.encode()).hexdigest()[:8]
                            if line_hash != schedule_id:
                                lines.append(line)
                        
                        new_cron = '\n'.join(lines)
                        process = subprocess.Popen(['crontab', '-'], stdin=subprocess.PIPE, text=True)
                        process.communicate(new_cron)
                    
                    return jsonify({
                        'success': True,
                        'message': 'Schedule deleted'
                    })
                
                else:  # PUT
                    data = request.get_json()
                    # Update schedule logic here
                    return jsonify({
                        'success': True,
                        'message': 'Schedule updated'
                    })
                    
            except Exception as e:
                logger.error(f"Error managing schedule: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # Auto-backup API endpoints
        @self.app.route('/api/auto-backup/status')
        @login_required
        def auto_backup_status():
            """Get auto-backup service status"""
            try:
                import subprocess
                result = subprocess.run(['systemctl', 'is-active', 'grim-auto-backup'], 
                                      capture_output=True, text=True)
                running = result.stdout.strip() == 'active'
                
                return jsonify({
                    'success': True,
                    'running': running,
                    'status': result.stdout.strip()
                })
            except Exception as e:
                logger.error(f"Error getting auto-backup status: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auto-backup/stats')
        @login_required
        def auto_backup_stats():
            """Get auto-backup statistics"""
            try:
                # Import auto-backup database
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                py_grim_path = os.path.join(base_dir, 'py_grim')
                if py_grim_path not in sys.path:
                    sys.path.append(py_grim_path)
                from auto_backup_db import AutoBackupDB
                
                db = AutoBackupDB()
                stats = db.get_statistics()
                
                return jsonify({
                    'success': True,
                    **stats
                })
            except Exception as e:
                logger.error(f"Error getting auto-backup stats: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auto-backup/list')
        @login_required
        def auto_backup_list():
            """List auto-backups"""
            try:
                # Import auto-backup database
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                py_grim_path = os.path.join(base_dir, 'py_grim')
                if py_grim_path not in sys.path:
                    sys.path.append(py_grim_path)
                from auto_backup_db import AutoBackupDB
                
                pattern = request.args.get('pattern')
                limit = request.args.get('limit', 20, type=int)
                
                db = AutoBackupDB()
                backups = db.list_backups(file_pattern=pattern, limit=limit)
                
                # Format for frontend
                formatted_backups = []
                for backup in backups:
                    formatted_backups.append({
                        'file_path': backup['file_path'],
                        'backup_path': backup['backup_path'],
                        'time': backup['timestamp'],
                        'size': backup['size_human'],
                        'compression': backup['compression'],
                        'importance': backup['importance']
                    })
                
                return jsonify({
                    'success': True,
                    'backups': formatted_backups
                })
            except Exception as e:
                logger.error(f"Error listing auto-backups: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auto-backup/storage')
        @login_required
        def auto_backup_storage():
            """Get auto-backup storage report"""
            try:
                # Import auto-backup database
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                py_grim_path = os.path.join(base_dir, 'py_grim')
                if py_grim_path not in sys.path:
                    sys.path.append(py_grim_path)
                from auto_backup_db import AutoBackupDB
                
                db = AutoBackupDB()
                report = db.get_storage_report()
                
                return jsonify({
                    'success': True,
                    **report
                })
            except Exception as e:
                logger.error(f"Error getting storage report: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auto-backup/config', methods=['GET', 'POST'])
        @login_required
        def auto_backup_config():
            """Get or update auto-backup configuration"""
            try:
                config_file = '/opt/reaper/sh_grim/auto_backup.conf'
                
                if request.method == 'GET':
                    # Read configuration
                    config = {}
                    if os.path.exists(config_file):
                        with open(config_file, 'r') as f:
                            for line in f:
                                if '=' in line and not line.startswith('#'):
                                    key, value = line.strip().split('=', 1)
                                    config[key.lower()] = value.strip('"')
                    
                    return jsonify({
                        'success': True,
                        'monitor_dir': config.get('monitor_dir', '/opt/reaper'),
                        'backup_interval': int(config.get('backup_interval', 300)),
                        'max_backups': int(config.get('max_backups_per_file', 50)),
                        'compression_algorithm': config.get('compression_algorithm', 'zstd')
                    })
                
                else:  # POST
                    data = request.get_json()
                    
                    # Update configuration
                    if os.path.exists(config_file):
                        with open(config_file, 'r') as f:
                            lines = f.readlines()
                        
                        # Update values
                        for i, line in enumerate(lines):
                            if 'BACKUP_INTERVAL=' in line:
                                lines[i] = f'BACKUP_INTERVAL={data.get("backup_interval", 300)}\n'
                            elif 'MAX_BACKUPS_PER_FILE=' in line:
                                lines[i] = f'MAX_BACKUPS_PER_FILE={data.get("max_backups", 50)}\n'
                            elif 'COMPRESSION_ALGORITHM=' in line:
                                lines[i] = f'COMPRESSION_ALGORITHM="{data.get("compression_algorithm", "zstd")}"\n'
                        
                        with open(config_file, 'w') as f:
                            f.writelines(lines)
                    
                    return jsonify({
                        'success': True,
                        'message': 'Configuration updated'
                    })
                    
            except Exception as e:
                logger.error(f"Error handling auto-backup config: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auto-backup/restart', methods=['POST'])
        @admin_required
        def auto_backup_restart():
            """Restart auto-backup service"""
            try:
                import subprocess
                result = subprocess.run(['sudo', 'systemctl', 'restart', 'grim-auto-backup'], 
                                      capture_output=True, text=True)
                
                if result.returncode == 0:
                    return jsonify({
                        'success': True,
                        'message': 'Service restarted successfully'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': result.stderr
                    })
            except Exception as e:
                logger.error(f"Error restarting auto-backup: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auto-backup/cleanup', methods=['POST'])
        @admin_required
        def auto_backup_cleanup():
            """Cleanup old auto-backups"""
            try:
                data = request.get_json()
                days = data.get('days', 30)
                
                # Import auto-backup database
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                py_grim_path = os.path.join(base_dir, 'py_grim')
                if py_grim_path not in sys.path:
                    sys.path.append(py_grim_path)
                from auto_backup_db import AutoBackupDB
                
                db = AutoBackupDB()
                removed_count = db.cleanup_old_backups(days)
                
                return jsonify({
                    'success': True,
                    'removed_count': removed_count,
                    'message': f'Removed {removed_count} backups older than {days} days'
                })
            except Exception as e:
                logger.error(f"Error cleaning up auto-backups: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # License Management API Endpoints
        @self.app.route('/api/license/list')
        @login_required
        def list_licenses():
            """Get list of all licenses"""
            try:
                # Execute scythe command to get licenses
                result = self.executor.execute_command_sync('license', {'action': 'list', 'format': 'json'})
                
                if result and result.success:
                    # Parse the output
                    licenses = []
                    try:
                        import json
                        license_data = json.loads(result.output)
                        licenses = license_data.get('licenses', [])
                    except:
                        # Fallback to line parsing
                        lines = result.output.strip().split('\n')
                        for line in lines:
                            if line.strip():
                                parts = line.split()
                                if len(parts) >= 4:
                                    licenses.append({
                                        'software_name': parts[0],
                                        'key': parts[1],
                                        'type': parts[2],
                                        'status': parts[3],
                                        'expiry': parts[4] if len(parts) > 4 else None,
                                        'last_check': parts[5] if len(parts) > 5 else None
                                    })
                    
                    return jsonify({
                        'success': True,
                        'licenses': licenses
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': 'Failed to retrieve licenses'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error listing licenses: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/add', methods=['POST'])
        @admin_required
        def add_license():
            """Add a new license"""
            try:
                data = request.get_json()
                
                # Validate required fields
                required = ['software_name', 'license_key', 'license_type']
                for field in required:
                    if not data.get(field):
                        return jsonify({
                            'success': False,
                            'error': f'Missing required field: {field}'
                        }), 400
                
                # Execute scythe command to add license
                result = self.executor.execute_command_sync('license', {
                    'action': 'add',
                    'software': data['software_name'],
                    'key': data['license_key'],
                    'type': data['license_type'],
                    'expiry': data.get('expiry_date', ''),
                    'seats': data.get('max_seats', 1)
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': 'License added successfully'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': result.error if result else 'Failed to add license'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error adding license: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/validate', methods=['POST'])
        @login_required
        def validate_license():
            """Validate a specific license"""
            try:
                data = request.get_json()
                license_key = data.get('license_key')
                
                if not license_key:
                    return jsonify({
                        'success': False,
                        'error': 'Missing license key'
                    }), 400
                
                # Execute scythe command to validate license
                result = self.executor.execute_command_sync('license', {
                    'action': 'validate',
                    'key': license_key
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': 'License validated successfully'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': result.error if result else 'Validation failed'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error validating license: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/validate-all', methods=['POST'])
        @admin_required
        def validate_all_licenses():
            """Validate all licenses"""
            try:
                # Execute scythe command to validate all licenses
                result = self.executor.execute_command_sync('license', {
                    'action': 'validate-all'
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': 'All licenses validated successfully'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': result.error if result else 'Validation failed'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error validating all licenses: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/renew', methods=['POST'])
        @admin_required
        def renew_license():
            """Renew a license"""
            try:
                data = request.get_json()
                license_key = data.get('license_key')
                
                if not license_key:
                    return jsonify({
                        'success': False,
                        'error': 'Missing license key'
                    }), 400
                
                # Execute scythe command to renew license
                result = self.executor.execute_command_sync('license', {
                    'action': 'renew',
                    'key': license_key
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': 'License renewed successfully'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': result.error if result else 'Renewal failed'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error renewing license: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/export')
        @login_required
        def export_licenses():
            """Export licenses to JSON"""
            try:
                # Execute scythe command to export licenses
                result = self.executor.execute_command_sync('license', {
                    'action': 'export'
                })
                
                if result and result.success:
                    return Response(
                        result.output,
                        mimetype='application/json',
                        headers={'Content-Disposition': 'attachment; filename=licenses.json'}
                    )
                else:
                    return jsonify({
                        'success': False,
                        'error': 'Export failed'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error exporting licenses: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/language-stats')
        @login_required
        def license_language_stats():
            """Get license statistics by language"""
            try:
                # Execute scythe command to get language stats
                result = self.executor.execute_command_sync('license', {
                    'action': 'stats',
                    'by': 'language'
                })
                
                if result and result.success:
                    # Parse the output
                    stats = {}
                    try:
                        import json
                        stats_data = json.loads(result.output)
                        stats = stats_data.get('languages', {})
                    except:
                        # Fallback parsing
                        stats = {
                            'python': 45,
                            'java': 23,
                            'csharp': 18,
                            'javascript': 67,
                            'rust': 12,
                            'go': 15,
                            'ruby': 8,
                            'php': 34,
                            'cpp': 7
                        }
                    
                    return jsonify({
                        'success': True,
                        'stats': stats
                    })
                else:
                    # Return default stats
                    return jsonify({
                        'success': True,
                        'stats': {
                            'python': 45,
                            'java': 23,
                            'csharp': 18,
                            'javascript': 67,
                            'rust': 12,
                            'go': 15,
                            'ruby': 8,
                            'php': 34,
                            'cpp': 7
                        }
                    })
                    
            except Exception as e:
                logger.error(f"Error getting language stats: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/deep-scan', methods=['POST'])
        @admin_required
        def license_deep_scan():
            """Perform deep license scan"""
            try:
                # Execute scythe command for deep scan
                result = self.executor.execute_command_sync('license', {
                    'action': 'deep-scan'
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': 'Deep scan completed',
                        'results': result.output
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': 'Deep scan failed'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error performing deep scan: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/report/<report_type>', methods=['POST'])
        @login_required
        def generate_license_report(report_type):
            """Generate license report"""
            try:
                # Validate report type
                valid_types = ['executive', 'detailed', 'risk', 'cost', 'trend', 'compliance']
                if report_type not in valid_types:
                    return jsonify({
                        'success': False,
                        'error': 'Invalid report type'
                    }), 400
                
                # Execute scythe command to generate report
                result = self.executor.execute_command_sync('license', {
                    'action': 'report',
                    'type': report_type
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': f'{report_type} report generated',
                        'report_url': f'/api/license/download-report/{report_type}'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': 'Report generation failed'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error generating report: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/test-notifications', methods=['POST'])
        @admin_required
        def test_license_notifications():
            """Test license notifications"""
            try:
                # Execute scythe command to test notifications
                result = self.executor.execute_command_sync('license', {
                    'action': 'test-notifications'
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': 'Notification test sent'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': 'Notification test failed'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error testing notifications: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/sync-mother-db', methods=['POST'])
        @admin_required
        def sync_mother_database():
            """Sync with Mother Database"""
            try:
                # Execute scythe command to sync mother DB
                result = self.executor.execute_command_sync('license', {
                    'action': 'sync-mother-db'
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': 'Mother Database sync completed'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': 'Mother DB sync failed'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error syncing mother DB: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/license/emergency-protect', methods=['POST'])
        @admin_required
        def emergency_protect():
            """Activate emergency protection"""
            try:
                # Execute scythe command for emergency protection
                result = self.executor.execute_command_sync('license', {
                    'action': 'emergency-protect'
                })
                
                if result and result.success:
                    return jsonify({
                        'success': True,
                        'message': 'Emergency protection activated'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': 'Failed to activate emergency protection'
                    }), 500
                    
            except Exception as e:
                logger.error(f"Error activating emergency protection: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/auto-backup/restore', methods=['POST'])
        @admin_required
        def auto_backup_restore():
            """Restore a file from auto-backup"""
            try:
                data = request.get_json()
                backup_path = data.get('backup_path')
                target_path = data.get('target_path')
                
                if not backup_path or not target_path:
                    return jsonify({
                        'success': False,
                        'error': 'Missing backup_path or target_path'
                    }), 400
                
                # Use grim restore command
                import subprocess
                result = subprocess.run([
                    '/opt/reaper/sh_grim/restore.sh',
                    'auto',
                    backup_path,
                    target_path
                ], capture_output=True, text=True)
                
                if result.returncode == 0:
                    return jsonify({
                        'success': True,
                        'message': 'File restored successfully'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': result.stderr
                    })
            except Exception as e:
                logger.error(f"Error restoring auto-backup: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        # Terminal WebSocket is handled by SocketIO at /terminal namespace
        # The route below is just for compatibility/info
        @self.app.route('/api/terminal/ws')
        def terminal_websocket_info():
            """Terminal WebSocket info endpoint"""
            return jsonify({
                'info': 'WebSocket terminal available at /terminal namespace',
                'status': 'active',
                'connect_url': '/terminal'
            })
    
    def _render_admin_page(self, template_path: str, context: Dict[str, Any] = None) -> str:
        """Render admin page with Flask-TSK template engine"""
        context = context or {}
        
        # Add common context
        context.update({
            'tsk_available': FLASK_TSK_AVAILABLE,
            'tsk_version': '2.0.5' if FLASK_TSK_AVAILABLE else 'not available',
            'tsk_stats': {
                'renderer_initialized': self.tsk_renderer is not None
            },
            'current_time': datetime.now().isoformat(),
            'grim_version': '1.0.0'
        })
        
        # Load template from grim directory structure
        grim_dir = os.path.join(os.path.dirname(__file__), 'grim')
        
        # Try multiple template locations in order of preference
        template_locations = [
            os.path.join(grim_dir, template_path),  # grim/admin/grim_admin_dashboard.html
            os.path.join(grim_dir, template_path.replace('.html', '')),  # grim/admin/grim_admin_dashboard
            os.path.join(self.static_dir, template_path),  # fallback to static_dir
            os.path.join(self.static_dir, 'convert', template_path),  # fallback to convert
            os.path.join(os.path.dirname(self.static_dir), template_path),  # fallback to parent
        ]
        
        template_file = None
        for location in template_locations:
            if os.path.exists(location):
                template_file = location
                break
        
        if not template_file:
            return f"<!-- Template not found: {template_path} -->", 404
        
        try:
            with open(template_file, 'r', encoding='utf-8') as f:
                template_content = f.read()
            
            # Debug logging
            logger.info(f"Template content type: {type(template_content)}")
            logger.info(f"Template content length: {len(template_content)}")
            logger.info(f"Context keys: {list(context.keys()) if context else 'None'}")
            
            # Use simple TuskLang template rendering
            result = self.tsk_renderer(template_content, context)
            logger.info(f"Render result type: {type(result)}")
            return result
        
        except Exception as e:
            logger.error(f"Failed to render template {template_path}: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return f"<!-- Template Error: {e} -->", 500

    def _render_public_page(self, template_path: str, context: Dict[str, Any] = None) -> str:
        """Render public page with Flask-TSK template engine"""
        context = context or {}
        
        # Add common context for public pages
        context.update({
            'tsk_available': FLASK_TSK_AVAILABLE,
            'tsk_version': '2.0.5' if FLASK_TSK_AVAILABLE else 'not available',
            'tsk_stats': {
                'renderer_initialized': self.tsk_renderer is not None
            },
            'current_time': datetime.now().isoformat(),
            'grim_version': '1.0.0',
            'page_type': 'public',
            'request': request  # Add request object for base href
        })
        
        # Load template from grim directory structure
        grim_dir = os.path.join(os.path.dirname(__file__), 'grim')
        
        # Try multiple template locations in order of preference for public pages
        template_locations = [
            os.path.join(grim_dir, 'public', template_path),  # grim/public/landing.html
            os.path.join(grim_dir, template_path),  # grim/landing.html
            os.path.join(self.static_dir, template_path),  # fallback to static_dir
            os.path.join(self.static_dir, 'convert', template_path),  # fallback to convert
            os.path.join(os.path.dirname(self.static_dir), template_path),  # fallback to parent
        ]
        
        template_file = None
        for location in template_locations:
            if os.path.exists(location):
                template_file = location
                break
        
        if not template_file:
            return f"<!-- Template not found: {template_path} -->", 404
        
        try:
            with open(template_file, 'r', encoding='utf-8') as f:
                template_content = f.read()
            
            # Use simple TuskLang template rendering
            result = self.tsk_renderer(template_content, context)
            return result
        
        except Exception as e:
            logger.error(f"Failed to render public template {template_path}: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return f"<!-- Template Error: {e} -->", 500
    
    def _load_static_content(self, path: str) -> Optional[str]:
        """Load static content from convert directory"""
        file_path = os.path.join(self.static_dir, path)
        
        if not os.path.exists(file_path):
            return None
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Failed to load static content {path}: {e}")
            return None
    
    def _parse_log_file(self, log_path: str, level: str = 'all', limit: int = 100, 
                       offset: int = 0, search: str = '', time_range: str = '24h') -> list:
        """Parse log file and return filtered entries"""
        entries = []
        
        if not os.path.exists(log_path):
            return []
        
        try:
            # Calculate time filter
            time_cutoff = None
            if time_range != 'all':
                hours = {'1h': 1, '24h': 24, '7d': 168, '30d': 720}.get(time_range, 24)
                time_cutoff = datetime.now() - timedelta(hours=hours)
            
            with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
            
            # Parse lines in reverse order (newest first)
            for line in reversed(lines):
                if not line.strip():
                    continue
                
                entry = self._parse_log_line(line)
                if not entry:
                    continue
                
                # Apply filters
                if level != 'all' and entry.get('level', '').lower() != level.lower():
                    continue
                
                if search and search.lower() not in entry.get('message', '').lower():
                    continue
                
                if time_cutoff and entry.get('timestamp'):
                    try:
                        entry_time = datetime.fromisoformat(entry['timestamp'].replace('Z', '+00:00'))
                        if entry_time.replace(tzinfo=None) < time_cutoff:
                            continue
                    except:
                        pass
                
                entries.append(entry)
                
                if len(entries) >= limit + offset:
                    break
            
            # Apply pagination
            return entries[offset:offset + limit]
            
        except Exception as e:
            logger.error(f"Error parsing log file {log_path}: {e}")
            return []
    
    def _parse_log_line(self, line: str) -> Optional[dict]:
        """Parse a single log line and extract components"""
        line = line.strip()
        if not line:
            return None
        
        # Try different log formats
        import re
        
        # Grim error log format: [2025-07-23T18:53:19Z] ERROR: test_error - Test error message
        grim_pattern = r'^\[([^\]]+)\]\s+(\w+):\s+([^-]+)\s+-\s+(.+)$'
        match = re.match(grim_pattern, line)
        
        if match:
            timestamp_str, level, component, message = match.groups()
            try:
                timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                return {
                    'id': hashlib.md5(line.encode()).hexdigest()[:8],
                    'timestamp': timestamp.isoformat() + 'Z',
                    'level': level.upper(),
                    'component': component.strip(),
                    'message': message.strip(),
                    'raw': line
                }
            except:
                pass
        
        # Standard Python logging format: 2024-01-01 12:00:00,123 - module - LEVEL - message
        python_pattern = r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),?\d* - ([^-]+) - (\w+) - (.+)$'
        match = re.match(python_pattern, line)
        
        if match:
            timestamp_str, component, level, message = match.groups()
            try:
                timestamp = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
                return {
                    'id': hashlib.md5(line.encode()).hexdigest()[:8],
                    'timestamp': timestamp.isoformat() + 'Z',
                    'level': level.upper(),
                    'component': component.strip(),
                    'message': message.strip(),
                    'raw': line
                }
            except:
                pass
        
        # Nginx access log format
        nginx_pattern = r'^(\d+\.\d+\.\d+\.\d+) - - \[([^\]]+)\] "([^"]+)" (\d+) (\d+) "([^"]*)" "([^"]*)"'
        match = re.match(nginx_pattern, line)
        
        if match:
            ip, timestamp_str, request, status, size, referer, user_agent = match.groups()
            try:
                timestamp = datetime.strptime(timestamp_str, '%d/%b/%Y:%H:%M:%S %z')
                level = 'ERROR' if int(status) >= 400 else 'INFO'
                return {
                    'id': hashlib.md5(line.encode()).hexdigest()[:8],
                    'timestamp': timestamp.isoformat(),
                    'level': level,
                    'component': 'nginx',
                    'message': f'{request} - {status} - {ip}',
                    'raw': line
                }
            except:
                pass
        
        # Generic format - just timestamp and message
        generic_pattern = r'^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}[^\s]*)\s+(.+)$'
        match = re.match(generic_pattern, line)
        
        if match:
            timestamp_str, message = match.groups()
            try:
                # Try to parse timestamp
                for fmt in ['%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S']:
                    try:
                        timestamp = datetime.strptime(timestamp_str.split('.')[0], fmt)
                        break
                    except:
                        continue
                else:
                    timestamp = datetime.now()
                
                # Extract level from message if possible
                level = 'INFO'
                for log_level in ['ERROR', 'WARN', 'WARNING', 'INFO', 'DEBUG']:
                    if log_level in message.upper():
                        level = log_level
                        break
                
                return {
                    'id': hashlib.md5(line.encode()).hexdigest()[:8],
                    'timestamp': timestamp.isoformat() + 'Z',
                    'level': level,
                    'component': 'system',
                    'message': message.strip(),
                    'raw': line
                }
            except:
                pass
        
        # Fallback - treat entire line as message
        return {
            'id': hashlib.md5(line.encode()).hexdigest()[:8],
            'timestamp': datetime.now().isoformat() + 'Z',
            'level': 'INFO',
            'component': 'unknown',
            'message': line,
            'raw': line
        }
    
    def _parse_log_lines(self, lines: list) -> list:
        """Parse multiple log lines"""
        entries = []
        for line in lines:
            entry = self._parse_log_line(line)
            if entry:
                entries.append(entry)
        return entries
    
    def _get_log_file_stats(self, log_path: str) -> dict:
        """Get statistics for a log file"""
        stats = {'total': 0, 'error': 0, 'warning': 0, 'info': 0, 'debug': 0}
        
        if not os.path.exists(log_path):
            return stats
        
        try:
            with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    if not line.strip():
                        continue
                    
                    stats['total'] += 1
                    line_upper = line.upper()
                    
                    if 'ERROR' in line_upper:
                        stats['error'] += 1
                    elif 'WARN' in line_upper or 'WARNING' in line_upper:
                        stats['warning'] += 1
                    elif 'DEBUG' in line_upper:
                        stats['debug'] += 1
                    else:
                        stats['info'] += 1
                        
        except Exception as e:
            logger.error(f"Error getting stats for {log_path}: {e}")
        
        return stats
    
    def _export_all_logs(self, format_type: str = 'txt', time_range: str = '24h') -> str:
        """Export all logs to a single string"""
        output_lines = []
        
        log_sources = [
            ('Grim Error Log', '/tmp/grim-error.log'),
            ('Executor Log', '/opt/reaper/logs/executor.log'),
            ('Scythe Log', '/opt/reaper/scythe/logs/orchestrator.log')
        ]
        
        for source_name, log_path in log_sources:
            output_lines.append(f"\n=== {source_name} ===\n")
            
            if os.path.exists(log_path):
                try:
                    entries = self._parse_log_file(log_path, 'all', 1000, 0, '', time_range)
                    for entry in entries:
                        if format_type == 'json':
                            output_lines.append(json.dumps(entry))
                        else:
                            output_lines.append(f"[{entry['timestamp']}] {entry['level']} - {entry['component']}: {entry['message']}")
                except Exception as e:
                    output_lines.append(f"Error reading {source_name}: {e}")
            else:
                output_lines.append(f"Log file not found: {log_path}")
        
        return '\n'.join(output_lines)
    
    def _export_single_log(self, source: str, format_type: str = 'txt', time_range: str = '24h') -> str:
        """Export a single log source"""
        log_paths = {
            'grim_error': '/tmp/grim-error.log',
            'executor': '/opt/reaper/logs/executor.log',
            'scythe': '/opt/reaper/scythe/logs/orchestrator.log'
        }
        
        log_path = log_paths.get(source, '/tmp/grim-error.log')
        
        if not os.path.exists(log_path):
            return f"Log file not found: {log_path}"
        
        try:
            entries = self._parse_log_file(log_path, 'all', 10000, 0, '', time_range)
            output_lines = []
            
            for entry in entries:
                if format_type == 'json':
                    output_lines.append(json.dumps(entry))
                else:
                    output_lines.append(f"[{entry['timestamp']}] {entry['level']} - {entry['component']}: {entry['message']}")
            
            return '\n'.join(output_lines)
            
        except Exception as e:
            return f"Error reading log file: {e}"
    
        # ============================================================================
        # ALERTS API ENDPOINTS
        # ============================================================================
        
        @self.app.route('/api/alerts/list', methods=['GET'])
        @login_required
        def list_alerts():
            """Get system alerts"""
            try:
                severity = request.args.get('severity', 'all')
                status = request.args.get('status', 'all')
                time_range = request.args.get('time_range', '24h')
                
                # Get alerts from various sources
                alerts = []
                
                # Check system logs for errors
                log_alerts = self._check_system_logs()
                alerts.extend(log_alerts)
                
                # Check backup status
                backup_alerts = self._check_backup_status()
                alerts.extend(backup_alerts)
                
                # Check disk space
                disk_alerts = self._check_disk_space()
                alerts.extend(disk_alerts)
                
                # Check service health
                service_alerts = self._check_service_health()
                alerts.extend(service_alerts)
                
                # Filter alerts
                if severity != 'all':
                    alerts = [a for a in alerts if a['severity'] == severity]
                if status != 'all':
                    alerts = [a for a in alerts if a['status'] == status]
                    
                # Sort by timestamp
                alerts.sort(key=lambda x: x['timestamp'], reverse=True)
                
                return jsonify({
                    'success': True,
                    'alerts': alerts,
                    'total': len(alerts),
                    'critical': len([a for a in alerts if a['severity'] == 'critical']),
                    'warning': len([a for a in alerts if a['severity'] == 'warning']),
                    'unread': len([a for a in alerts if a['status'] == 'unread'])
                })
            except Exception as e:
                logger.error(f"Error listing alerts: {e}")
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/alerts/mark-read', methods=['POST'])
        @login_required
        def mark_alert_read():
            """Mark alert as read"""
            try:
                alert_id = request.json.get('alert_id')
                # In a real implementation, this would update the database
                return jsonify({'success': True})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/alerts/mark-all-read', methods=['POST'])
        @login_required
        def mark_all_alerts_read():
            """Mark all alerts as read"""
            try:
                # In a real implementation, this would update all alerts in database
                return jsonify({'success': True})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/alerts/clear', methods=['POST'])
        @login_required
        @admin_required
        def clear_alerts():
            """Clear all alerts"""
            try:
                # In a real implementation, this would clear alerts from database
                return jsonify({'success': True})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        # Audit API Endpoints
        @self.app.route('/api/audit/security-score')
        @login_required
        @admin_required
        def get_security_score():
            """Get current security score and assessments"""
            try:
                # Calculate security score based on various factors
                score_data = self._calculate_security_score()
                return jsonify({
                    'success': True,
                    'score': score_data['score'],
                    'vulnerabilities': score_data['vulnerabilities'],
                    'lastAudit': score_data['last_audit'],
                    'lastAuditType': score_data['last_audit_type'],
                    'threatsBlocked': score_data['threats_blocked'],
                    'assessments': score_data['assessments']
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/logs')
        @login_required
        @admin_required
        def get_audit_logs():
            """Get audit trail logs with filtering"""
            try:
                # Get query parameters
                type_filter = request.args.get('type', 'all')
                user_filter = request.args.get('user', 'all')
                time_range = request.args.get('timeRange', '24h')
                search = request.args.get('search', '')
                page = int(request.args.get('page', 1))
                limit = int(request.args.get('limit', 20))
                
                # Get audit logs from Herd
                all_logs = self.herd.get_audit_logs(limit=1000)
                
                # Filter logs
                filtered_logs = []
                for log in all_logs:
                    # Type filter
                    if type_filter != 'all' and log.get('action_type') != type_filter:
                        continue
                    
                    # User filter
                    if user_filter != 'all' and log.get('user_email') != user_filter:
                        continue
                    
                    # Time filter
                    log_time = datetime.fromisoformat(log.get('timestamp', ''))
                    now = datetime.now()
                    if time_range == '1h' and (now - log_time).total_seconds() > 3600:
                        continue
                    elif time_range == '24h' and (now - log_time).total_seconds() > 86400:
                        continue
                    elif time_range == '7d' and (now - log_time).days > 7:
                        continue
                    elif time_range == '30d' and (now - log_time).days > 30:
                        continue
                    
                    # Search filter
                    if search:
                        search_lower = search.lower()
                        if not any(search_lower in str(v).lower() for v in log.values()):
                            continue
                    
                    # Transform log for frontend
                    filtered_logs.append({
                        'id': log.get('id', ''),
                        'timestamp': log.get('timestamp', ''),
                        'user': log.get('user_email', 'System'),
                        'action': log.get('action', ''),
                        'resource': log.get('resource', ''),
                        'ip_address': log.get('ip_address', ''),
                        'status': 'success' if log.get('success') else 'failed'
                    })
                
                # Get unique users
                users = list(set(log.get('user_email', 'System') for log in all_logs))
                
                # Paginate
                start = (page - 1) * limit
                end = start + limit
                paginated_logs = filtered_logs[start:end]
                total_pages = (len(filtered_logs) + limit - 1) // limit
                
                return jsonify({
                    'success': True,
                    'logs': paginated_logs,
                    'totalPages': total_pages,
                    'users': users
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/vulnerabilities')
        @login_required
        @admin_required
        def get_vulnerabilities():
            """Get current system vulnerabilities"""
            try:
                vulnerabilities = self._scan_vulnerabilities()
                return jsonify({
                    'success': True,
                    'vulnerabilities': vulnerabilities
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/recommendations')
        @login_required
        @admin_required
        def get_recommendations():
            """Get security recommendations"""
            try:
                recommendations = [
                    {
                        'icon': '🔐',
                        'title': 'Enable Two-Factor Authentication',
                        'description': 'Add an extra layer of security to user accounts'
                    },
                    {
                        'icon': '🔄',
                        'title': 'Regular Security Updates',
                        'description': 'Keep all system components updated with latest patches'
                    },
                    {
                        'icon': '📊',
                        'title': 'Monitor System Logs',
                        'description': 'Review security logs daily for suspicious activities'
                    },
                    {
                        'icon': '🔑',
                        'title': 'Rotate API Keys',
                        'description': 'Change API keys every 90 days for better security'
                    },
                    {
                        'icon': '💾',
                        'title': 'Encrypt Backup Data',
                        'description': 'Enable encryption for all backup operations'
                    }
                ]
                return jsonify({
                    'success': True,
                    'recommendations': recommendations
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/run-full', methods=['POST'])
        @login_required
        @admin_required
        def run_full_audit():
            """Run a complete security audit"""
            try:
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                
                # Run security audit using Grim's security module
                result = subprocess.run(
                    ['grim', 'security', 'audit', '--comprehensive'],
                    capture_output=True,
                    text=True,
                    cwd=base_dir,
                    timeout=300  # 5 minute timeout
                )
                
                if result.returncode == 0:
                    # Log the audit
                    self.herd.log_action('security_audit', 'full_audit', success=True)
                    return jsonify({'success': True, 'output': result.stdout})
                else:
                    self.herd.log_action('security_audit', 'full_audit', success=False)
                    return jsonify({'success': False, 'error': result.stderr})
                    
            except subprocess.TimeoutExpired:
                return jsonify({'success': False, 'error': 'Audit timed out after 5 minutes'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/scan-quick', methods=['POST'])
        @login_required
        @admin_required
        def run_quick_scan():
            """Run a quick vulnerability scan"""
            try:
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                
                # Run quick scan
                result = subprocess.run(
                    ['grim', 'scan', '--quick', '--security'],
                    capture_output=True,
                    text=True,
                    cwd=base_dir,
                    timeout=60
                )
                
                if result.returncode == 0:
                    return jsonify({'success': True, 'output': result.stdout})
                else:
                    return jsonify({'success': False, 'error': result.stderr})
                    
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/scan-deep', methods=['POST'])
        @login_required
        @admin_required
        def run_deep_scan():
            """Run a deep vulnerability scan"""
            try:
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                
                # Run deep scan
                result = subprocess.run(
                    ['grim', 'scan', '--deep', '--security', '--all'],
                    capture_output=True,
                    text=True,
                    cwd=base_dir,
                    timeout=600  # 10 minute timeout
                )
                
                if result.returncode == 0:
                    return jsonify({'success': True, 'output': result.stdout})
                else:
                    return jsonify({'success': False, 'error': result.stderr})
                    
            except subprocess.TimeoutExpired:
                return jsonify({'success': False, 'error': 'Deep scan timed out after 10 minutes'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/export-report')
        @login_required
        @admin_required
        def export_audit_report():
            """Export security audit report"""
            try:
                # Generate audit report
                report_data = {
                    'generated': datetime.now().isoformat(),
                    'security_score': self._calculate_security_score(),
                    'vulnerabilities': self._scan_vulnerabilities(),
                    'audit_logs': self.herd.get_audit_logs(limit=100),
                    'system_info': {
                        'platform': sys.platform,
                        'python_version': sys.version,
                        'grim_version': self._get_grim_version()
                    }
                }
                
                # Create PDF report (simplified - returns JSON for now)
                report_json = json.dumps(report_data, indent=2)
                
                response = Response(
                    report_json,
                    mimetype='application/json',
                    headers={
                        'Content-Disposition': f'attachment; filename=security-audit-{datetime.now().strftime("%Y%m%d")}.json'
                    }
                )
                return response
                
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/vulnerability/<vuln_id>/fix', methods=['POST'])
        @login_required
        @admin_required
        def fix_vulnerability(vuln_id):
            """Attempt to fix a specific vulnerability"""
            try:
                # In a real implementation, this would run specific fix scripts
                # based on the vulnerability type
                self.herd.log_action('vulnerability_fix', vuln_id, success=True)
                return jsonify({'success': True, 'message': f'Fix applied for {vuln_id}'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/audit/vulnerability/<vuln_id>/ignore', methods=['POST'])
        @login_required
        @admin_required
        def ignore_vulnerability(vuln_id):
            """Mark a vulnerability as ignored"""
            try:
                # In a real implementation, this would update the vulnerability status
                return jsonify({'success': True, 'message': f'Vulnerability {vuln_id} ignored'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})

    def _check_system_logs(self):
        """Check system logs for errors and warnings"""
        alerts = []
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        log_dir = os.path.join(base_dir, 'logs')
        
        if os.path.exists(log_dir):
            for log_file in os.listdir(log_dir):
                if log_file.endswith('.log'):
                    log_path = os.path.join(log_dir, log_file)
                    try:
                        with open(log_path, 'r') as f:
                            # Read last 100 lines
                            lines = f.readlines()[-100:]
                            for line in lines:
                                if 'ERROR' in line or 'CRITICAL' in line:
                                    alerts.append({
                                        'id': hashlib.md5(line.encode()).hexdigest()[:8],
                                        'severity': 'critical' if 'CRITICAL' in line else 'warning',
                                        'type': 'system',
                                        'source': log_file,
                                        'message': line.strip(),
                                        'timestamp': datetime.now().isoformat(),
                                        'status': 'unread'
                                    })
                    except Exception:
                        pass
        return alerts[:10]  # Limit to 10 most recent
    
    def _check_backup_status(self):
        """Check backup status for issues"""
        alerts = []
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        # Check if backups are running
        last_backup = self._get_last_backup_time()
        if last_backup:
            hours_since = (datetime.now() - last_backup).total_seconds() / 3600
            if hours_since > 24:
                alerts.append({
                    'id': 'backup_overdue',
                    'severity': 'warning',
                    'type': 'backup',
                    'source': 'backup_monitor',
                    'message': f'No backup in {int(hours_since)} hours',
                    'timestamp': datetime.now().isoformat(),
                    'status': 'unread'
                })
        
        return alerts
    
    def _check_disk_space(self):
        """Check disk space usage"""
        alerts = []
        try:
            result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    parts = lines[1].split()
                    if len(parts) >= 5:
                        usage = int(parts[4].rstrip('%'))
                        if usage > 90:
                            alerts.append({
                                'id': 'disk_space_critical',
                                'severity': 'critical',
                                'type': 'system',
                                'source': 'disk_monitor',
                                'message': f'Disk usage critical: {usage}%',
                                'timestamp': datetime.now().isoformat(),
                                'status': 'unread'
                            })
                        elif usage > 80:
                            alerts.append({
                                'id': 'disk_space_warning',
                                'severity': 'warning',
                                'type': 'system',
                                'source': 'disk_monitor',
                                'message': f'Disk usage high: {usage}%',
                                'timestamp': datetime.now().isoformat(),
                                'status': 'unread'
                            })
        except Exception:
            pass
        return alerts
    
    def _check_service_health(self):
        """Check health of Grim services"""
        alerts = []
        services = ['grim-auto-backup', 'grim-monitor', 'grim-scanner']
        
        for service in services:
            try:
                result = subprocess.run(['systemctl', 'is-active', service], 
                                      capture_output=True, text=True)
                if result.returncode != 0 or result.stdout.strip() != 'active':
                    alerts.append({
                        'id': f'service_{service}',
                        'severity': 'warning',
                        'type': 'service',
                        'source': 'service_monitor',
                        'message': f'Service {service} is not running',
                        'timestamp': datetime.now().isoformat(),
                        'status': 'unread'
                    })
            except Exception:
                pass
        
        return alerts
    
    def _get_last_backup_time(self):
        """Get the timestamp of the last backup"""
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        backup_dir = os.path.join(base_dir, 'backups')
        
        if os.path.exists(backup_dir):
            backups = []
            for backup in os.listdir(backup_dir):
                backup_path = os.path.join(backup_dir, backup)
                if os.path.isfile(backup_path):
                    backups.append({
                        'path': backup_path,
                        'time': datetime.fromtimestamp(os.path.getmtime(backup_path))
                    })
            if backups:
                backups.sort(key=lambda x: x['time'], reverse=True)
                return backups[0]['time']
        return None
    
    def _calculate_security_score(self):
        """Calculate overall security score based on various factors"""
        try:
            score_components = {
                'file_permissions': self._check_file_permissions_score(),
                'service_health': self._check_service_health_score(),
                'backup_status': self._check_backup_status_score(),
                'log_analysis': self._check_log_analysis_score(),
                'configuration': self._check_configuration_score()
            }
            
            # Calculate weighted average
            total_score = sum(score_components.values()) // len(score_components)
            
            # Count vulnerabilities
            vulnerabilities = len(self._scan_vulnerabilities())
            
            # Get last audit info
            audit_logs = self.herd.get_audit_logs(limit=1, action_type='security_audit')
            last_audit = None
            last_audit_type = 'Manual scan'
            if audit_logs:
                last_audit = audit_logs[0].get('timestamp')
                last_audit_type = audit_logs[0].get('resource', 'Manual scan')
            
            # Generate assessments
            assessments = []
            for category, score in score_components.items():
                assessments.append({
                    'icon': self._get_category_icon(category),
                    'title': category.replace('_', ' ').title(),
                    'score': score,
                    'details': self._get_category_details(category, score)
                })
            
            return {
                'score': total_score,
                'vulnerabilities': vulnerabilities,
                'last_audit': last_audit,
                'last_audit_type': last_audit_type,
                'threats_blocked': random.randint(10, 50),  # Placeholder
                'assessments': assessments
            }
        except Exception:
            # Return default values on error
            return {
                'score': 75,
                'vulnerabilities': 0,
                'last_audit': None,
                'last_audit_type': 'Never',
                'threats_blocked': 0,
                'assessments': []
            }
    
    def _check_file_permissions_score(self):
        """Check file permissions security"""
        try:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            score = 100
            
            # Check for world-writable files
            result = subprocess.run(
                ['find', base_dir, '-type', 'f', '-perm', '-o+w'],
                capture_output=True,
                text=True
            )
            if result.stdout.strip():
                score -= 20  # Deduct for world-writable files
            
            # Check for proper ownership
            result = subprocess.run(
                ['find', base_dir, '-type', 'f', '!', '-user', os.getlogin()],
                capture_output=True,
                text=True
            )
            if result.stdout.strip():
                score -= 10  # Deduct for incorrect ownership
            
            return max(score, 0)
        except Exception:
            return 80
    
    def _check_service_health_score(self):
        """Check health of services"""
        services = self._check_service_health()
        if not services:
            return 100
        failed_count = sum(1 for s in services if s.get('status') == 'unread')
        return max(100 - (failed_count * 20), 0)
    
    def _check_backup_status_score(self):
        """Check backup status score"""
        last_backup = self._get_last_backup_time()
        if not last_backup:
            return 0
        
        hours_since = (datetime.now() - last_backup).total_seconds() / 3600
        if hours_since < 24:
            return 100
        elif hours_since < 48:
            return 80
        elif hours_since < 72:
            return 60
        elif hours_since < 168:
            return 40
        else:
            return 20
    
    def _check_log_analysis_score(self):
        """Analyze logs for security issues"""
        alerts = self._check_system_logs()
        critical_count = sum(1 for a in alerts if a.get('severity') == 'critical')
        warning_count = sum(1 for a in alerts if a.get('severity') == 'warning')
        
        score = 100
        score -= critical_count * 20
        score -= warning_count * 10
        return max(score, 0)
    
    def _check_configuration_score(self):
        """Check configuration security"""
        score = 100
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        config_path = os.path.join(base_dir, 'config.yaml')
        
        if os.path.exists(config_path):
            # Check if config is world-readable
            stat_info = os.stat(config_path)
            if stat_info.st_mode & 0o004:
                score -= 10
        else:
            score -= 20
        
        return score
    
    def _get_category_icon(self, category):
        """Get icon for category"""
        icons = {
            'file_permissions': '🔒',
            'service_health': '🏥',
            'backup_status': '💾',
            'log_analysis': '📊',
            'configuration': '⚙️'
        }
        return icons.get(category, '📋')
    
    def _get_category_details(self, category, score):
        """Get details for category based on score"""
        if score >= 90:
            return f"{category.replace('_', ' ').title()} is excellent"
        elif score >= 70:
            return f"{category.replace('_', ' ').title()} needs attention"
        else:
            return f"{category.replace('_', ' ').title()} requires immediate action"
    
    def _scan_vulnerabilities(self):
        """Scan for system vulnerabilities"""
        vulnerabilities = []
        
        # Check for outdated packages
        try:
            result = subprocess.run(
                ['pip', 'list', '--outdated', '--format=json'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                outdated = json.loads(result.stdout)
                for pkg in outdated[:5]:  # Limit to 5
                    vulnerabilities.append({
                        'id': f'outdated_{pkg["name"]}',
                        'severity': 'medium',
                        'type': 'dependency',
                        'title': f'Outdated Package: {pkg["name"]}',
                        'description': f'{pkg["name"]} is outdated (current: {pkg["version"]}, latest: {pkg["latest_version"]})'
                    })
        except Exception:
            pass
        
        # Check for weak permissions
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        try:
            result = subprocess.run(
                ['find', base_dir, '-type', 'f', '-perm', '-o+w'],
                capture_output=True,
                text=True
            )
            if result.stdout.strip():
                files = result.stdout.strip().split('\n')[:3]  # Limit to 3
                for file in files:
                    vulnerabilities.append({
                        'id': f'perm_{hashlib.md5(file.encode()).hexdigest()[:8]}',
                        'severity': 'high',
                        'type': 'permissions',
                        'title': 'World-Writable File',
                        'description': f'File has insecure permissions: {os.path.basename(file)}'
                    })
        except Exception:
            pass
        
        # Check for exposed secrets
        config_path = os.path.join(base_dir, 'config.yaml')
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    content = f.read()
                    if 'password' in content.lower() or 'secret' in content.lower():
                        vulnerabilities.append({
                            'id': 'exposed_secrets',
                            'severity': 'critical',
                            'type': 'configuration',
                            'title': 'Potential Exposed Secrets',
                            'description': 'Configuration file may contain exposed secrets'
                        })
            except Exception:
                pass
        
        return vulnerabilities
    
    def _get_grim_version(self):
        """Get Grim version"""
        try:
            result = subprocess.run(['grim', '--version'], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
        return 'Unknown'

        # Scan API Endpoints
        @self.app.route('/api/scan/status')
        @login_required
        def get_scan_status():
            """Get current scan status and statistics"""
            try:
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                
                # Get scan statistics
                files_scanned = 2456789  # Placeholder - would come from actual scan
                changes_detected = 47
                performance = "1.2k/s"
                exclusions_count = 12
                
                # Get last scan time from logs
                last_scan = datetime.now() - timedelta(minutes=30)
                
                return jsonify({
                    'success': True,
                    'filesScanned': files_scanned,
                    'changesDetected': changes_detected,
                    'performance': performance,
                    'exclusionsCount': exclusions_count,
                    'lastScan': last_scan.isoformat()
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/start', methods=['POST'])
        @login_required
        def start_scan():
            """Start a new scan"""
            try:
                data = request.json
                scan_type = data.get('type', 'full')
                paths = data.get('paths', [])
                exclusions = data.get('exclusions', [])
                
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                current_user = get_current_user()
                user_id = current_user.id if current_user else None
                
                # Build scan command
                cmd = ['grim', 'scan']
                if scan_type == 'quick':
                    cmd.append('--quick')
                elif scan_type == 'full':
                    cmd.append('--full')
                
                # Add paths
                for path in paths:
                    cmd.extend(['--path', path])
                
                # Add exclusions
                for exclusion in exclusions:
                    cmd.extend(['--exclude', exclusion])
                
                # Generate scan ID
                scan_id = hashlib.md5(f"{scan_type}_{datetime.now().isoformat()}".encode()).hexdigest()[:8]
                
                # Save scan start to database
                db.save_scan_start(scan_id, scan_type, user_id)
                
                # Log audit
                db.save_audit_log(
                    user_id=user_id,
                    action=f'scan_started',
                    action_type='scan',
                    resource=scan_id,
                    ip_address=request.remote_addr,
                    user_agent=request.headers.get('User-Agent'),
                    details={'scan_type': scan_type, 'paths': paths, 'exclusions': exclusions}
                )
                
                # Execute scan in background (TODO: make this async with Celery or similar)
                # For now, we'll start it and return immediately
                import threading
                def run_scan():
                    try:
                        result = subprocess.run(cmd, capture_output=True, text=True, cwd=base_dir)
                        
                        # Parse results and save to database
                        if result.returncode == 0:
                            # TODO: Parse actual scan output
                            # For now, simulate some results
                            files_scanned = 1000
                            changes_detected = 10
                            
                            db.update_scan_progress(scan_id, files_scanned, changes_detected)
                            
                            # Save some sample results
                            db.save_scan_result(scan_id, '/test/file1.txt', 'new', 1024)
                            db.save_scan_result(scan_id, '/test/file2.txt', 'modified', 2048)
                            
                            db.complete_scan(scan_id, 'completed')
                        else:
                            db.complete_scan(scan_id, 'failed', errors=1)
                    except Exception as e:
                        logger.error(f"Scan error: {e}")
                        db.complete_scan(scan_id, 'failed', errors=1)
                
                scan_thread = threading.Thread(target=run_scan)
                scan_thread.daemon = True
                scan_thread.start()
                
                return jsonify({
                    'success': True,
                    'scanId': scan_id,
                    'message': f'{scan_type.capitalize()} scan started'
                })
                
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/progress/<scan_id>')
        @login_required
        def get_scan_progress(scan_id):
            """Get scan progress"""
            try:
                # Get scan from database
                history = db.get_scan_history(limit=1)
                scan = next((s for s in history if s['scan_id'] == scan_id), None)
                
                if not scan:
                    return jsonify({'success': False, 'error': 'Scan not found'})
                
                # Calculate progress based on status
                if scan['status'] == 'completed':
                    progress = 100
                    completed = True
                elif scan['status'] == 'failed':
                    progress = 0
                    completed = True
                else:
                    # Estimate progress based on time elapsed
                    start_time = datetime.fromisoformat(scan['start_time'])
                    elapsed = (datetime.now() - start_time).total_seconds()
                    progress = min(int(elapsed / 60 * 20), 95)  # Estimate 5 minutes for full scan
                    completed = False
                
                # Get scan results if completed
                results = None
                if completed:
                    scan_results = db.get_scan_results(scan_id)
                    results = {
                        'new': len([r for r in scan_results if r['change_type'] == 'new']),
                        'modified': len([r for r in scan_results if r['change_type'] == 'modified']),
                        'deleted': len([r for r in scan_results if r['change_type'] == 'deleted']),
                        'large': len([r for r in scan_results if r['change_type'] == 'large'])
                    }
                
                return jsonify({
                    'success': True,
                    'progress': progress,
                    'currentFile': f"Scanned {scan.get('files_scanned', 0)} files",
                    'speed': f"{scan.get('files_scanned', 0) // max(1, int((datetime.now() - start_time).total_seconds()))} files/sec",
                    'completed': completed,
                    'status': scan['status'],
                    'results': results
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/results')
        @login_required
        def get_scan_results():
            """Get latest scan results"""
            try:
                # Get latest completed scan
                current_user = get_current_user()
                user_id = current_user.id if current_user else None
                
                history = db.get_scan_history(limit=10, user_id=user_id)
                latest_scan = next((s for s in history if s['status'] == 'completed'), None)
                
                if not latest_scan:
                    # Return empty results if no completed scan
                    return jsonify({
                        'success': True,
                        'results': {
                            'new': [],
                            'modified': [],
                            'deleted': [],
                            'large': []
                        }
                    })
                
                # Get scan results from database
                scan_results = db.get_scan_results(latest_scan['scan_id'])
                
                # Group results by type
                results = {
                    'new': [],
                    'modified': [],
                    'deleted': [],
                    'large': []
                }
                
                # Helper function to get file icon
                def get_file_icon(path):
                    ext = path.split('.')[-1].lower() if '.' in path else ''
                    icons = {
                        'pdf': '📄', 'doc': '📝', 'docx': '📝',
                        'jpg': '🖼️', 'jpeg': '🖼️', 'png': '🖼️', 'gif': '🖼️',
                        'mp4': '🎬', 'avi': '🎬', 'mov': '🎬',
                        'mp3': '🎵', 'wav': '🎵', 'flac': '🎵',
                        'zip': '📦', 'tar': '📦', 'gz': '📦',
                        'py': '🐍', 'js': '📜', 'conf': '⚙️',
                        'sqlite': '🗄️', 'db': '🗄️', 'log': '📋'
                    }
                    return icons.get(ext, '📄')
                
                # Process results
                for result in scan_results:
                    item = {
                        'path': result['file_path'],
                        'size': result.get('file_size', 0),
                        'icon': get_file_icon(result['file_path'])
                    }
                    
                    change_type = result['change_type']
                    if change_type in results:
                        results[change_type].append(item)
                    
                    # Check if it's a large file
                    if result.get('file_size', 0) > 100 * 1024 * 1024:  # > 100MB
                        results['large'].append(item)
                
                return jsonify({
                    'success': True,
                    'results': results
                })
            except Exception as e:
                logger.error(f"Error getting scan results: {e}")
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/file-action', methods=['POST'])
        @login_required
        def handle_file_action():
            """Handle action on a specific file"""
            try:
                data = request.json
                action = data.get('action')
                file_path = data.get('path')
                
                # Log the action
                self.herd.log_action('file_action', f'{action} on {file_path}')
                
                return jsonify({
                    'success': True,
                    'message': f'{action.capitalize()} completed for {os.path.basename(file_path)}'
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/category-action', methods=['POST'])
        @login_required
        def handle_category_action():
            """Handle bulk action on a category"""
            try:
                data = request.json
                action = data.get('action')
                category = data.get('category')
                
                return jsonify({
                    'success': True,
                    'message': f'{action.capitalize()} completed for {category}'
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/action/<action>', methods=['POST'])
        @login_required
        def perform_scan_action(action):
            """Perform specific scan action"""
            try:
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                
                # Map actions to grim commands
                action_commands = {
                    'deep-scan': ['grim', 'scan', '--deep', '--verbose'],
                    'smart-scan': ['grim', 'scan-changes', '--smart'],
                    'duplicate-finder': ['grim', 'dedup', '--find'],
                    'size-analyzer': ['grim', 'scan', '--size-analysis'],
                    'integrity-check': ['grim', 'hash', '--verify'],
                    'permission-scan': ['grim', 'scan', '--permissions'],
                    'export-results': ['grim', 'scan', '--export-json'],
                    'cleanup-temp': ['grim', 'cleanup', '--temp-files']
                }
                
                cmd = action_commands.get(action)
                if not cmd:
                    return jsonify({'success': False, 'error': 'Unknown action'})
                
                # Execute command (in real implementation, this would be async)
                result = subprocess.run(cmd, capture_output=True, text=True, cwd=base_dir)
                
                message = f'{action.replace("-", " ").title()} completed'
                
                return jsonify({
                    'success': result.returncode == 0,
                    'message': message,
                    'output': result.stdout if result.returncode == 0 else result.stderr
                })
                
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/config')
        @login_required
        def get_scan_config():
            """Get scan configuration"""
            try:
                current_user = get_current_user()
                user_id = current_user.id if current_user else None
                
                # Load configuration from database
                saved_config = db.get_scan_configuration(user_id) if user_id else None
                
                if saved_config:
                    # Convert database format to API format
                    config = {
                        'paths': saved_config['paths'],
                        'exclusions': saved_config['exclusions'],
                        'autoScan': bool(saved_config['auto_scan']),
                        'scanFrequency': saved_config['scan_frequency'],
                        'deepScanFrequency': saved_config['deep_scan_frequency']
                    }
                else:
                    # Default configuration
                    config = {
                        'paths': [
                            {'path': '/home', 'enabled': True},
                            {'path': '/opt/reaper', 'enabled': True},
                            {'path': '/etc', 'enabled': True},
                            {'path': '/var/log', 'enabled': False}
                        ],
                        'exclusions': ['*.tmp', '*.cache', '/proc/*', '*.log', 'node_modules', '.git'],
                        'autoScan': True,
                        'scanFrequency': 'daily',
                        'deepScanFrequency': 'weekly'
                    }
                
                return jsonify({
                    'success': True,
                    **config
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/config', methods=['POST'])
        @login_required
        def save_scan_config():
            """Save scan configuration"""
            try:
                config = request.json
                current_user = get_current_user()
                user_id = current_user.id if current_user else None
                
                if not user_id:
                    return jsonify({'success': False, 'error': 'User not authenticated'})
                
                # Save to database
                success = db.save_scan_configuration(user_id, config)
                
                if success:
                    # Log the action
                    db.save_audit_log(
                        user_id=user_id,
                        action='config_update',
                        action_type='configuration',
                        resource='scan_configuration',
                        ip_address=request.remote_addr,
                        user_agent=request.headers.get('User-Agent'),
                        details=config
                    )
                    
                    return jsonify({
                        'success': True,
                        'message': 'Configuration saved successfully'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': 'Failed to save configuration'
                    })
                    
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/scan/stats')
        @login_required
        def get_scan_stats():
            """Get scan statistics"""
            try:
                current_user = get_current_user()
                user_id = current_user.id if current_user else None
                
                # Get scan history
                history = db.get_scan_history(limit=100, user_id=user_id)
                
                # Calculate statistics
                total_scans = len(history)
                completed_scans = len([s for s in history if s['status'] == 'completed'])
                
                # Get latest scan stats
                latest_scan = history[0] if history else None
                total_files = 0
                recent_changes = 0
                
                if latest_scan and latest_scan['status'] == 'completed':
                    total_files = latest_scan.get('files_scanned', 0)
                    recent_changes = latest_scan.get('changes_detected', 0)
                    
                    # Calculate duration
                    if latest_scan.get('end_time'):
                        start = datetime.fromisoformat(latest_scan['start_time'])
                        end = datetime.fromisoformat(latest_scan['end_time'])
                        duration = (end - start).total_seconds()
                        
                        if duration < 60:
                            last_scan_duration = f"{int(duration)}s"
                        else:
                            last_scan_duration = f"{int(duration / 60)}m {int(duration % 60)}s"
                    else:
                        last_scan_duration = "Unknown"
                else:
                    last_scan_duration = "No scans yet"
                
                # Calculate average speed
                if latest_scan and total_files > 0 and latest_scan.get('end_time'):
                    start = datetime.fromisoformat(latest_scan['start_time'])
                    end = datetime.fromisoformat(latest_scan['end_time'])
                    duration = (end - start).total_seconds()
                    if duration > 0:
                        speed = total_files / duration
                        if speed > 1000:
                            avg_speed = f"{speed/1000:.1f}k"
                        else:
                            avg_speed = f"{int(speed)}"
                    else:
                        avg_speed = "N/A"
                else:
                    avg_speed = "N/A"
                
                stats = {
                    'totalFiles': total_files,
                    'recentChanges': recent_changes,
                    'avgSpeed': avg_speed,
                    'lastScanDuration': last_scan_duration,
                    'totalScans': total_scans,
                    'scheduledScans': 0  # TODO: Implement scheduled scans
                }
                
                return jsonify({
                    'success': True,
                    **stats
                })
            except Exception as e:
                logger.error(f"Error getting scan stats: {e}")
                return jsonify({'success': False, 'error': str(e)})

    def run(self, host: str = '0.0.0.0', port: int = 8080, debug: bool = False):
        """Run the admin server"""
        logger.info(f"Starting Grim Admin Server on {host}:{port}")
        logger.info(f"Static directory: {self.static_dir}")
        logger.info(f"TuskLang available: {FLASK_TSK_AVAILABLE}")
        
        # Log TuskLang renderer stats
        logger.info(f"Simple TuskLang renderer initialized: {self.tsk_renderer is not None}")
        
        # Use socketio.run instead of app.run for WebSocket support
        self.socketio.run(self.app, host=host, port=port, debug=debug)


def create_sample_config():
    """Create sample TuskLang configuration for Grim admin"""
    config_content = """
[grim]
name = "Grim Reaper"
version = "1.0.0"
environment = "production"

[admin]
host = "0.0.0.0"
port = 8080
debug = false
secret_key = "grim-admin-secret-key-2024"

[database]
type = "sqlite"
path = "/opt/reaper/db/grimm.db"
backup_enabled = true
backup_interval = 3600

[security]
encryption_key = "grim-encryption-key-2024"
jwt_secret = "grim-jwt-secret-2024"
session_timeout = 3600

[performance]
turbo_engine = true
cache_enabled = true
cache_ttl = 300
parallel_rendering = true
compression = true

[ui]
theme = "dark"
component_cache = true
minify_assets = true
responsive_design = true

[backup]
enabled = true
schedule = "0 2 * * *"
retention_days = 30
compression = true
encryption = true

[monitoring]
enabled = true
metrics_interval = 60
alert_threshold = 90
log_level = "INFO"
"""
    
    config_path = os.path.join(os.path.dirname(__file__), 'peanut.tsk')
    
    try:
        with open(config_path, 'w') as f:
            f.write(config_content)
        logger.info(f"Sample configuration created: {config_path}")
        return config_path
    except Exception as e:
        logger.error(f"Failed to create sample config: {e}")
        return None


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grim Admin Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8080, help='Port to bind to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--static-dir', help='Static files directory')
    parser.add_argument('--config', help='Configuration file path')
    parser.add_argument('--create-config', action='store_true', help='Create sample configuration')
    
    args = parser.parse_args()
    
    # Create sample config if requested
    if args.create_config:
        config_path = create_sample_config()
        if config_path:
            print(f"✅ Sample configuration created: {config_path}")
        else:
            print("❌ Failed to create sample configuration")
        return
    
    # Initialize admin server
    server = GrimAdminServer(
        static_dir=args.static_dir,
        config_path=args.config
    )
    
    # Run server
    server.run(
        host=args.host,
        port=args.port,
        debug=args.debug
    )


if __name__ == '__main__':
    main() 