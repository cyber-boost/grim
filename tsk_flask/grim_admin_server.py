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
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime

from flask import Flask, render_template_string, request, jsonify, send_from_directory, redirect, url_for, session, flash, get_flashed_messages
from flask_cors import CORS
import asyncio

# Import simple TuskLang renderer
from simple_tsk_renderer import render_simple_tsk_template

# Import Grim command executor
from grim_executor import grim_executor

# Import Herd authentication system
from herd_auth import get_herd, init_herd, login_required, admin_required, get_current_user, is_authenticated

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
        
        # Configure Flask
        self.app.config.update({
            'SECRET_KEY': os.environ.get('GRIM_SECRET_KEY', secrets.token_hex(32)),
            'DEBUG': True,
            'TEMPLATES_AUTO_RELOAD': False,  # Disabled for performance
            'SEND_FILE_MAX_AGE_DEFAULT': 0
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
        
        # Authentication routes
        @self.app.route('/login', methods=['GET', 'POST'])
        def login():
            """Login page with Herd authentication"""
            if request.method == 'POST':
                email = request.form.get('email')
                password = request.form.get('password')
                
                # Authenticate with Herd
                result = self.herd.authenticate(email, password)
                
                if result['success']:
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
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'license',
                'page_title': 'License Management'
            })
        
        @self.app.route('/admin/audit')
        @login_required
        def audit_page():
            """Audit content page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'audit',
                'page_title': 'Audit Management'
            })
        
        @self.app.route('/admin/scan')
        @login_required
        def scan_page():
            """Scan content page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'scan',
                'page_title': 'Scan Management'
            })
        
        @self.app.route('/admin/settings')
        @login_required
        def settings_page():
            """Settings page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
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
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
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
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'logs',
                'page_title': 'Logs Management'
            })

        @self.app.route('/admin/scythe')
        @login_required
        def scythe_page():
            """Scythe orchestrator page"""
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
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
            """Terminal page"""
            return render_template('admin/terminal.html', page_title='Terminal - Server Access')

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
            return self._render_admin_page('admin/grim_admin_dashboard.html', {
                'current_page': 'alerts',
                'page_title': 'Alerts Management'
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
        
        @self.app.route('/public/comparison')
        def comparison_chart():
            """Comparison chart"""
            return send_from_directory('.', 'grim-comparison-chart.html')
        
        @self.app.route('/grim-architecture')
        def grim_architecture():
            """Grim architecture page"""
            return self._render_public_page('architecture.html', {
                'page_title': 'Grim Architecture',
                'page_description': 'The Architecture of Immortality - Four specialized subsystems, one unified interface'
            })
        
        @self.app.route('/grim-command-reference')
        def grim_command_reference():
            """Grim command reference page"""
            return self._render_public_page('command-reference.html', {
                'page_title': 'Grim Command Reference',
                'page_description': 'Complete guide to the unified command system - Everything through grim'
            })
        
        @self.app.route('/grim-comparison-chart')
        def grim_comparison_chart():
            """Grim comparison chart page"""
            return send_from_directory('.', 'grim-comparison-chart.html')
        
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
        def execute_command():
            """Execute command via web interface"""
            try:
                data = request.get_json()
                command_type = data.get('type', 'system')
                command_args = data.get('args', {})
                
                # Execute command asynchronously
                command_id = asyncio.run(grim_executor.execute_command_async(command_type, command_args))
                
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
    
    def run(self, host: str = '0.0.0.0', port: int = 8080, debug: bool = False):
        """Run the admin server"""
        logger.info(f"Starting Grim Admin Server on {host}:{port}")
        logger.info(f"Static directory: {self.static_dir}")
        logger.info(f"TuskLang available: {FLASK_TSK_AVAILABLE}")
        
        # Log TuskLang renderer stats
        logger.info(f"Simple TuskLang renderer initialized: {self.tsk_renderer is not None}")
        
        self.app.run(host=host, port=port, debug=debug)


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