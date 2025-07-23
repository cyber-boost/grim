#!/usr/bin/env python3
"""
Flask Blueprint for TuskLang API endpoints
Provides REST API for TuskLang configuration and operations
"""

from flask import Blueprint, request, jsonify, current_app, g
from typing import Any, Dict, List, Optional
import logging

tsk_blueprint = Blueprint('tsk', __name__, url_prefix='/tsk')


@tsk_blueprint.route('/status', methods=['GET'])
def get_status():
    """Get TuskLang integration status"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk:
            return jsonify({
                'success': True,
                'data': tsk.get_status()
            })
        else:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/config/<section>', methods=['GET'])
def get_config_section(section: str):
    """Get entire configuration section"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk:
            data = tsk.get_section(section)
            return jsonify({
                'success': True,
                'data': {
                    'section': section,
                    'data': data
                }
            })
        else:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/config/<section>/<key>', methods=['GET'])
def get_config_value(section: str, key: str):
    """Get specific configuration value"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk:
            value = tsk.get_config(section, key)
            return jsonify({
                'success': True,
                'data': {
                    'section': section,
                    'key': key,
                    'value': value
                }
            })
        else:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/config/<section>/<key>', methods=['POST'])
def set_config_value(section: str, key: str):
    """Set configuration value"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk:
            value = request.get_json()
            success = tsk.set_config(section, key, value)
            return jsonify({
                'success': success,
                'data': {
                    'section': section,
                    'key': key,
                    'value': value,
                    'set': success
                }
            })
        else:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/function', methods=['POST'])
def execute_function():
    """Execute TuskLang function"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if not tsk:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
        
        data = request.get_json()
        if not data:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'No data provided'
            }), 400
        
        section = data.get('section')
        key = data.get('key')
        args = data.get('args', [])
        kwargs = data.get('kwargs', {})
        
        if not section or not key:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Section and key are required'
            }), 400
        
        result = tsk.execute_function(section, key, *args, **kwargs)
        return jsonify({
            'success': True,
            'data': {
                'section': section,
                'key': key,
                'args': args,
                'kwargs': kwargs,
                'result': result
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/database', methods=['GET'])
def get_database_config():
    """Get database configuration from TuskLang"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk:
            db_config = tsk.get_database_config()
            return jsonify({
                'success': True,
                'data': {
                    'database_config': db_config
                }
            })
        else:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/security', methods=['GET'])
def get_security_config():
    """Get security configuration from TuskLang"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk:
            security_config = tsk.get_security_config()
            return jsonify({
                'success': True,
                'data': {
                    'security_config': security_config
                }
            })
        else:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/ui', methods=['GET'])
def get_ui_config():
    """Get UI configuration from TuskLang"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk:
            ui_config = tsk.get_ui_config()
            return jsonify({
                'success': True,
                'data': {
                    'ui_config': ui_config
                }
            })
        else:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/save', methods=['POST'])
def save_config():
    """Save TuskLang configuration to file"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if not tsk:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
        
        data = request.get_json()
        if not data or 'filepath' not in data:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Filepath is required'
            }), 400
        
        filepath = data['filepath']
        success = tsk.save_config(filepath)
        return jsonify({
            'success': success,
            'data': {
                'filepath': filepath,
                'saved': success
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/load', methods=['POST'])
def load_config():
    """Load TuskLang configuration from file"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if not tsk:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Flask-TSK not initialized'
            })
        
        data = request.get_json()
        if not data or 'filepath' not in data:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'Filepath is required'
            }), 400
        
        filepath = data['filepath']
        success = tsk.load_config(filepath)
        return jsonify({
            'success': success,
            'data': {
                'filepath': filepath,
                'loaded': success
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/sections', methods=['GET'])
def list_sections():
    """List all available configuration sections"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk and tsk.tsk_instance:
            sections = list(tsk.tsk_instance.data.keys())
            return jsonify({
                'success': True,
                'data': {
                    'sections': sections
                }
            })
        else:
            return jsonify({
                'success': False,
                'data': {},
                'error': 'TuskLang not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {},
            'error': str(e)
        }), 500


@tsk_blueprint.route('/health', methods=['GET'])
def health_check():
    """Health check for TuskLang integration"""
    try:
        from . import get_tsk
        tsk = get_tsk()
        if tsk:
            status = tsk.get_status()
            is_healthy = status.get('available', False) and status.get('initialized', False)
            
            return jsonify({
                'success': is_healthy,
                'data': {
                    'status': 'healthy' if is_healthy else 'unhealthy',
                    'tsk_status': status
                }
            })
        else:
            return jsonify({
                'success': False,
                'data': {
                    'status': 'unhealthy'
                },
                'error': 'Flask-TSK not initialized'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': {
                'status': 'error'
            },
            'error': str(e)
        }), 500 