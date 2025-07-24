#!/usr/bin/env python3
"""
Flask-TSK Extension
High-performance Flask integration with TuskLang using simple TSK renderer and performance engine.
No Django/Jinja2 dependencies - pure TuskLang template processing.
"""

import os
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

# Import our simple TSK renderer and performance engine
try:
    from simple_tsk_renderer import render_simple_tsk_template, SimpleTskRenderer
    from performance_engine import render_turbo_template, get_turbo_engine, optimize_flask_app
    TSK_RENDERER_AVAILABLE = True
    logging.info("Flask-TSK initialized with simple TSK renderer and performance engine")
except ImportError as e:
    TSK_RENDERER_AVAILABLE = False
    logging.warning(f"Simple TSK renderer not available: {e}")

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
    """Flask-TSK Extension for TuskLang integration using simple renderer"""
    
    def __init__(self, app: Optional[Flask] = None):
        self.app = app
        self.simple_renderer = None
        self.turbo_engine = None
        
        if app is not None:
            self.init_app(app)
    
    def init_app(self, app: Flask):
        """Initialize Flask-TSK with Flask app"""
        if not FLASK_AVAILABLE:
            raise ImportError("Flask is required for Flask-TSK")
        
        if not TSK_RENDERER_AVAILABLE:
            logging.warning("Flask-TSK initialized without TSK renderer support")
            return
        
        # Initialize simple TSK renderer
        self.simple_renderer = SimpleTskRenderer()
        
        # Initialize turbo performance engine
        try:
            self.turbo_engine = get_turbo_engine()
            # Optimize Flask app for performance
            optimize_flask_app(app)
            logger.info("Flask app optimized with turbo performance engine")
        except Exception as e:
            logger.warning(f"Turbo engine optimization failed: {e}")
        
        # Register template context processor
        app.context_processor(self._inject_tsk_context)
        
        # Register template filters
        app.template_filter('tsk_render')(self._tsk_render_filter)
        app.template_filter('tsk_value')(self._tsk_value_filter)
        
        # Override Flask's render_template to use TSK renderer
        self._override_render_template(app)
        
        logger.info("Flask-TSK initialized with simple TSK renderer")
    
    def _inject_tsk_context(self) -> Dict[str, Any]:
        """Inject TSK context into templates"""
        return {
            'tsk_renderer': self.simple_renderer,
            'tsk_available': TSK_RENDERER_AVAILABLE,
            'tsk_version': '2.0.5-simple' if TSK_RENDERER_AVAILABLE else 'not available',
            'turbo_engine': self.turbo_engine
        }
    
    def _tsk_render_filter(self, template_content: str, context: Dict[str, Any] = None) -> str:
        """Template filter to render TSK templates"""
        if not TSK_RENDERER_AVAILABLE or not self.simple_renderer:
            return template_content
        
        try:
            context = context or {}
            # Use simple TSK renderer
            result = self.simple_renderer.render(template_content, context)
            return result
        except Exception as e:
            logger.error(f"TSK rendering failed: {e}")
            return template_content
    
    def _tsk_value_filter(self, key: str, context: Dict[str, Any] = None) -> Any:
        """Template filter to get TSK value from context"""
        if not context:
            return key
        
        try:
            # Handle nested object access: key.subkey
            if '.' in key:
                parts = key.split('.')
                current = context
                for part in parts:
                    if isinstance(current, dict) and part in current:
                        current = current[part]
                    else:
                        return key
                return current
            else:
                return context.get(key, key)
        except Exception as e:
            logger.error(f"TSK value retrieval failed: {e}")
            return key
    
    def _override_render_template(self, app: Flask):
        """Override Flask's render_template to use TSK renderer"""
        original_render_template = app.jinja_env.get_template
        
        def tsk_render_template(template_name_or_list, **context):
            """Enhanced render_template that supports TSK templates"""
            try:
                # Check if template is a TSK template
                if isinstance(template_name_or_list, str) and template_name_or_list.endswith('.tsk'):
                    # Use TSK renderer for .tsk templates
                    template_path = os.path.join(app.template_folder, template_name_or_list)
                    if os.path.exists(template_path):
                        with open(template_path, 'r', encoding='utf-8') as f:
                            template_content = f.read()
                        
                        if self.turbo_engine:
                            # Use turbo engine for high performance
                            return self.turbo_engine.render_template(template_content, context)
                        else:
                            # Fallback to simple renderer
                            return self.simple_renderer.render(template_content, context)
                
                # For non-TSK templates, use original Flask rendering
                template = original_render_template(template_name_or_list)
                return template.render(**context)
                
            except Exception as e:
                logger.error(f"Template rendering failed: {e}")
                return f"<!-- Template Error: {e} -->"
        
        # Replace Flask's render_template
        app.jinja_env.get_template = tsk_render_template
    
    def render_tsk_template(self, template_content: str, context: Dict[str, Any] = None) -> str:
        """Render TSK template with high performance"""
        if not TSK_RENDERER_AVAILABLE:
            return template_content
        
        try:
            if self.turbo_engine:
                # Use turbo engine for maximum performance
                return self.turbo_engine.render_template(template_content, context or {})
            else:
                # Fallback to simple renderer
                return self.simple_renderer.render(template_content, context or {})
        except Exception as e:
            logger.error(f"TSK template rendering failed: {e}")
            return f"<!-- TSK Template Error: {e} -->"
    
    def execute_tsk_function(self, function_name: str, *args, context: Dict[str, Any] = None) -> Any:
        """Execute TSK function (placeholder for future implementation)"""
        logger.info(f"TSK function execution requested: {function_name}")
        return f"TSK Function: {function_name}"
    
    def get_tsk_config(self, section: str = None) -> Dict[str, Any]:
        """Get TSK configuration (placeholder for future implementation)"""
        return {
            'renderer': 'simple_tsk_renderer',
            'performance_engine': 'turbo_engine',
            'version': '2.0.5-simple'
        }

def init_flask_tsk(app: Flask) -> FlaskTSK:
    """Initialize Flask-TSK with Flask app"""
    return FlaskTSK(app)

def render_tsk_template(template_content: str, context: Dict[str, Any] = None) -> str:
    """Global function to render TSK templates"""
    if TSK_RENDERER_AVAILABLE:
        return render_simple_tsk_template(template_content, context)
    return template_content

def execute_tsk_function(function_name: str, *args, context: Dict[str, Any] = None) -> Any:
    """Global function to execute TSK functions"""
    logger.info(f"Global TSK function execution: {function_name}")
    return f"TSK Function: {function_name}"

def get_tsk_config(section: str = None) -> Dict[str, Any]:
    """Global function to get TSK configuration"""
    return {
        'renderer': 'simple_tsk_renderer',
        'performance_engine': 'turbo_engine',
        'version': '2.0.5-simple',
        'available': TSK_RENDERER_AVAILABLE
    } 