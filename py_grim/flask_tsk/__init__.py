#!/usr/bin/env python3
"""
Flask-TSK - Flask Extension for TuskLang Integration
Provides seamless TuskLang configuration and function execution in Flask applications
"""

from flask import Flask, current_app, g, request, jsonify
from typing import Any, Dict, List, Optional, Union
import logging

try:
    import tusktsk
    from tusktsk import TSK, parse, stringify, load_from_peanut
    TUSK_AVAILABLE = True
    TUSK_VERSION = getattr(tusktsk, '__version__', 'unknown')
except ImportError:
    TUSK_AVAILABLE = False
    TUSK_VERSION = None
    logging.warning("tusktsk package not available. Install with: pip install tusktsk")


class FlaskTSK:
    """Flask extension for TuskLang integration"""
    
    def __init__(self, app: Optional[Flask] = None):
        self.app = app
        self.tsk_instance: Optional[TSK] = None
        self.peanut_loaded = False
        
        if app is not None:
            self.init_app(app)
    
    def init_app(self, app: Flask):
        """Initialize the Flask extension"""
        self.app = app
        
        # Set default configuration
        app.config.setdefault('TSK_CONFIG_PATH', None)
        app.config.setdefault('TSK_AUTO_LOAD', True)
        app.config.setdefault('TSK_ENABLE_BLUEPRINT', True)
        app.config.setdefault('TSK_ENABLE_CONTEXT', True)
        
        # Initialize TuskLang if available
        if TUSK_AVAILABLE and app.config.get('TSK_AUTO_LOAD', True):
            self._initialize_tusk()
        
        # Register blueprint if enabled
        if app.config.get('TSK_ENABLE_BLUEPRINT', True):
            from flask_tsk.blueprint import tsk_blueprint
            app.register_blueprint(tsk_blueprint)
        
        # Register context processor if enabled
        if app.config.get('TSK_ENABLE_CONTEXT', True):
            app.context_processor(self._context_processor)
        
        # Register before_request handler
        app.before_request(self._before_request)
        
        # Register teardown_appcontext handler
        app.teardown_appcontext(self._teardown_appcontext)
        
        # Add extension to app
        app.extensions['flask-tsk'] = self
    
    def _initialize_tusk(self):
        """Initialize TuskLang integration"""
        try:
            # Try to load from peanut.tsk first
            self.tsk_instance = load_from_peanut()
            self.peanut_loaded = True
            current_app.logger.info(f"Flask-TSK: Successfully loaded TuskLang configuration (tusktsk v{TUSK_VERSION})")
        except Exception as e:
            current_app.logger.warning(f"Flask-TSK: Failed to load peanut.tsk: {e}")
            # Create empty TSK instance
            self.tsk_instance = TSK()
    
    def _context_processor(self):
        """Context processor to make TSK available in templates"""
        return {
            'tsk': self,
            'tsk_available': TUSK_AVAILABLE,
            'tsk_version': TUSK_VERSION
        }
    
    def _before_request(self):
        """Before request handler to set up TSK context"""
        if TUSK_AVAILABLE and self.tsk_instance:
            g.tsk = self.tsk_instance
        else:
            g.tsk = None
    
    def _teardown_appcontext(self, exception=None):
        """Teardown app context handler"""
        if hasattr(g, 'tsk'):
            del g.tsk
    
    def get_config(self, section: str, key: str, default: Any = None) -> Any:
        """Get configuration value from TuskLang"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return default
        
        try:
            return self.tsk_instance.get_value(section, key)
        except Exception as e:
            current_app.logger.warning(f"Flask-TSK: Failed to get config {section}.{key}: {e}")
            return default
    
    def set_config(self, section: str, key: str, value: Any) -> bool:
        """Set configuration value in TuskLang"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return False
        
        try:
            self.tsk_instance.set_value(section, key, value)
            return True
        except Exception as e:
            current_app.logger.error(f"Flask-TSK: Failed to set config {section}.{key}: {e}")
            return False
    
    def get_section(self, section: str) -> Optional[Dict[str, Any]]:
        """Get entire section from TuskLang"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return None
        
        try:
            return self.tsk_instance.get_section(section)
        except Exception as e:
            current_app.logger.warning(f"Flask-TSK: Failed to get section {section}: {e}")
            return None
    
    def execute_function(self, section: str, key: str, *args, **kwargs) -> Any:
        """Execute a TuskLang function"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return None
        
        try:
            return self.tsk_instance.execute_fujsen(section, key, *args, **kwargs)
        except Exception as e:
            current_app.logger.error(f"Flask-TSK: Failed to execute function {section}.{key}: {e}")
            return None
    
    def get_database_config(self) -> Dict[str, Any]:
        """Get database configuration from TuskLang"""
        db_config = self.get_section('database')
        if db_config:
            return db_config
        
        # Fallback to Flask config
        return {
            'type': 'sqlite',
            'host': current_app.config.get('DB_HOST', 'localhost'),
            'port': current_app.config.get('DB_PORT', 5432),
            'name': current_app.config.get('DB_NAME', 'app.db'),
            'username': current_app.config.get('DB_USERNAME', ''),
            'password': current_app.config.get('DB_PASSWORD', ''),
            'charset': 'utf8mb4',
            'pool_size': 10
        }
    
    def get_security_config(self) -> Dict[str, Any]:
        """Get security configuration from TuskLang"""
        security_config = self.get_section('security')
        if security_config:
            return security_config
        
        # Fallback to Flask config
        return {
            'encryption_key': current_app.config.get('SECRET_KEY', ''),
            'jwt_secret': current_app.config.get('JWT_SECRET_KEY', ''),
            'app_key': current_app.config.get('APP_KEY', '')
        }
    
    def get_ui_config(self) -> Dict[str, Any]:
        """Get UI configuration from TuskLang"""
        ui_config = self.get_section('ui')
        if ui_config:
            return ui_config
        
        # Fallback to Flask config
        return {
            'theme': current_app.config.get('UI_THEME', 'default'),
            'component_cache': current_app.config.get('UI_COMPONENT_CACHE', True),
            'minify_assets': current_app.config.get('UI_MINIFY_ASSETS', True),
            'responsive_design': current_app.config.get('UI_RESPONSIVE_DESIGN', True)
        }
    
    def is_available(self) -> bool:
        """Check if TuskLang is available"""
        return TUSK_AVAILABLE and self.tsk_instance is not None
    
    def get_status(self) -> Dict[str, Any]:
        """Get TuskLang integration status"""
        return {
            'available': TUSK_AVAILABLE,
            'version': TUSK_VERSION,
            'initialized': self.tsk_instance is not None,
            'peanut_loaded': self.peanut_loaded,
            'package_source': 'PyPI' if TUSK_AVAILABLE else 'None'
        }
    
    def save_config(self, filepath: str) -> bool:
        """Save TuskLang configuration to file"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return False
        
        try:
            self.tsk_instance.to_file(filepath)
            return True
        except Exception as e:
            current_app.logger.error(f"Flask-TSK: Failed to save config to {filepath}: {e}")
            return False
    
    def load_config(self, filepath: str) -> bool:
        """Load TuskLang configuration from file"""
        if not TUSK_AVAILABLE:
            return False
        
        try:
            self.tsk_instance = TSK.from_file(filepath)
            return True
        except Exception as e:
            current_app.logger.error(f"Flask-TSK: Failed to load config from {filepath}: {e}")
            return False


# Convenience function to get Flask-TSK instance
def get_tsk() -> FlaskTSK:
    """Get the Flask-TSK instance from current app"""
    return current_app.extensions.get('flask-tsk')


# Template helpers
def tsk_config(section: str, key: str, default: Any = None) -> Any:
    """Template helper to get TuskLang configuration"""
    tsk = get_tsk()
    if tsk:
        return tsk.get_config(section, key, default)
    return default


def tsk_section(section: str) -> Optional[Dict[str, Any]]:
    """Template helper to get TuskLang section"""
    tsk = get_tsk()
    if tsk:
        return tsk.get_section(section)
    return None


def tsk_function(section: str, key: str, *args, **kwargs) -> Any:
    """Template helper to execute TuskLang function"""
    tsk = get_tsk()
    if tsk:
        return tsk.execute_function(section, key, *args, **kwargs)
    return None 