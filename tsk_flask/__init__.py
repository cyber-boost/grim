#!/usr/bin/env python3
"""
Flask-TSK Extension
High-performance Flask integration with TuskLang for advanced template processing,
configuration management, and dynamic content generation.
"""

import os
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

# Import official TuskTsk package instead of custom implementation
try:
    from tusktsk import TSK, TuskLangEnhanced
    FLASK_TSK_AVAILABLE = True
    logging.info("Flask-TSK initialized with official TuskTsk package")
except ImportError as e:
    FLASK_TSK_AVAILABLE = False
    logging.warning(f"Official TuskTsk package not available: {e}")

# Import Flask components
try:
    from flask import Flask, render_template, jsonify, request, session, redirect, url_for
    FLASK_AVAILABLE = True
except ImportError:
    FLASK_AVAILABLE = False
    logging.warning("Flask not available")

# Configure logging
logger = logging.getLogger(__name__)

class FlaskTSK:
    """Flask-TSK Extension for TuskLang integration"""
    
    def __init__(self, app: Optional[Flask] = None):
        self.app = app
        self.tsk = None
        self.enhanced_tsk = None
        
        if app is not None:
            self.init_app(app)
    
    def init_app(self, app: Flask):
        """Initialize Flask-TSK with Flask app"""
        if not FLASK_AVAILABLE:
            raise ImportError("Flask is required for Flask-TSK")
        
        if not FLASK_TSK_AVAILABLE:
            logging.warning("Flask-TSK initialized without TuskTsk support")
            return
        
        # Initialize official TuskTsk components
        self.tsk = TSK()
        self.enhanced_tsk = TuskLangEnhanced()
        
        # Register template context processor
        app.context_processor(self._inject_tsk_context)
        
        # Register template filters
        app.template_filter('tsk_execute')(self._tsk_execute_filter)
        app.template_filter('tsk_value')(self._tsk_value_filter)
        
        logger.info("Flask-TSK initialized with official TuskTsk package")
    
    def _inject_tsk_context(self) -> Dict[str, Any]:
        """Inject TuskTsk context into templates"""
        return {
            'tsk': self.tsk,
            'enhanced_tsk': self.enhanced_tsk,
            'tsk_available': FLASK_TSK_AVAILABLE,
            'tsk_version': '2.0.5' if FLASK_TSK_AVAILABLE else 'not available'
        }
    
    def _tsk_execute_filter(self, tsk_code: str, context: Dict[str, Any] = None) -> Any:
        """Template filter to execute TuskTsk code"""
        if not FLASK_TSK_AVAILABLE or not self.tsk:
            return tsk_code
        
        try:
            context = context or {}
            # Use official TuskTsk execution
            result = self.tsk.execute_operators(tsk_code, context)
            return result
        except Exception as e:
            logger.error(f"TuskTsk execution failed: {e}")
            return tsk_code
    
    def _tsk_value_filter(self, key: str, section: str = None) -> Any:
        """Template filter to get TuskTsk value"""
        if not FLASK_TSK_AVAILABLE or not self.tsk:
            return key
        
        try:
            if section:
                return self.tsk.get_section(section).get(key, key)
            else:
                return self.tsk.get_value(key, key)
        except Exception as e:
            logger.error(f"TuskTsk value retrieval failed: {e}")
            return key
    
    def render_tsk_template(self, template_content: str, context: Dict[str, Any] = None) -> str:
        """Render template with official TuskTsk processing"""
        if not FLASK_TSK_AVAILABLE or not self.tsk:
            return template_content
        
        try:
            context = context or {}
            
            # Use official TuskTsk template processing
            # The official package handles TuskLang syntax automatically
            processed_content = self.tsk.execute_operators(template_content, context)
            
            return processed_content
        except Exception as e:
            logger.error(f"TuskTsk template rendering failed: {e}")
            return template_content
    
    def execute_tsk_function(self, section: str, func_name: str, *args) -> Any:
        """Execute TuskTsk function"""
        if not FLASK_TSK_AVAILABLE or not self.tsk:
            return None
        
        try:
            return self.tsk.execute_function(section, func_name, *args)
        except Exception as e:
            logger.error(f"TuskTsk function execution failed: {e}")
            return None
    
    def get_tsk_config(self, section: str = None) -> Dict[str, Any]:
        """Get TuskTsk configuration"""
        if not FLASK_TSK_AVAILABLE or not self.tsk:
            return {}
        
        try:
            if section:
                return self.tsk.get_section(section).to_dict()
            else:
                return self.tsk.to_dict()
        except Exception as e:
            logger.error(f"TuskTsk config retrieval failed: {e}")
            return {}

# Global Flask-TSK instance
flask_tsk = FlaskTSK()

# Convenience functions
def init_flask_tsk(app: Flask) -> FlaskTSK:
    """Initialize Flask-TSK with Flask app"""
    return flask_tsk.init_app(app)

def render_tsk_template(template_content: str, context: Dict[str, Any] = None) -> str:
    """Render template with TuskTsk processing"""
    return flask_tsk.render_tsk_template(template_content, context)

def execute_tsk_function(section: str, func_name: str, *args) -> Any:
    """Execute TuskTsk function"""
    return flask_tsk.execute_tsk_function(section, func_name, *args)

def get_tsk_config(section: str = None) -> Dict[str, Any]:
    """Get TuskTsk configuration"""
    return flask_tsk.get_tsk_config(section) 