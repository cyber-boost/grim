#!/usr/bin/env python3
"""
TuskLang Integration for Grim Core
Provides seamless integration between Grim and TuskLang configuration system
Uses the official tusktsk PyPI package
"""

import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Union
import asyncio
import json
import logging

# Try to import the official tusktsk package
try:
    import tusktsk
    from tusktsk import TSK, parse, stringify, load_from_peanut
    TUSK_AVAILABLE = True
    TUSK_VERSION = getattr(tusktsk, '__version__', 'unknown')
except ImportError:
    TUSK_AVAILABLE = False
    TUSK_VERSION = None
    logging.warning("tusktsk package not available. Install with: pip install tusktsk")

from .config import get_config
from .logger import get_logger


class GrimTuskIntegration:
    """Integration layer between Grim and TuskLang using official tusktsk package"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config = get_config(config_path)
        self.logger = get_logger('tusktsk')
        self.tsk_instance: Optional[TSK] = None
        self.peanut_loaded = False
        
        if TUSK_AVAILABLE:
            self._initialize_tusk()
        else:
            self.logger.warning("tusktsk package not available - using fallback configuration")
    
    def _initialize_tusk(self):
        """Initialize TuskLang integration"""
        try:
            # Try to load from peanut.tsk first
            self.tsk_instance = load_from_peanut()
            self.peanut_loaded = True
            self.logger.info(f"Successfully loaded TuskLang configuration from peanut.tsk (tusktsk v{TUSK_VERSION})")
        except Exception as e:
            self.logger.warning(f"Failed to load peanut.tsk: {e}")
            # Create empty TSK instance
            self.tsk_instance = TSK()
    
    def get_tusk_config(self, section: str, key: str, default: Any = None) -> Any:
        """Get configuration value from TuskLang"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return default
        
        try:
            return self.tsk_instance.get_value(section, key)
        except Exception as e:
            self.logger.warning(f"Failed to get TuskLang config {section}.{key}: {e}")
            return default
    
    def set_tusk_config(self, section: str, key: str, value: Any) -> bool:
        """Set configuration value in TuskLang"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return False
        
        try:
            self.tsk_instance.set_value(section, key, value)
            return True
        except Exception as e:
            self.logger.error(f"Failed to set TuskLang config {section}.{key}: {e}")
            return False
    
    def get_tusk_section(self, section: str) -> Optional[Dict[str, Any]]:
        """Get entire section from TuskLang"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return None
        
        try:
            return self.tsk_instance.get_section(section)
        except Exception as e:
            self.logger.warning(f"Failed to get TuskLang section {section}: {e}")
            return None
    
    def execute_tusk_function(self, section: str, key: str, *args, **kwargs) -> Any:
        """Execute a TuskLang function"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return None
        
        try:
            return self.tsk_instance.execute_fujsen(section, key, *args, **kwargs)
        except Exception as e:
            self.logger.error(f"Failed to execute TuskLang function {section}.{key}: {e}")
            return None
    
    async def execute_tusk_operator(self, operator: str, expression: str, context: Dict[str, Any] = None) -> Any:
        """Execute a TuskLang operator"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return None
        
        try:
            return await self.tsk_instance.execute_operator(operator, expression, context or {})
        except Exception as e:
            self.logger.error(f"Failed to execute TuskLang operator {operator}: {e}")
            return None
    
    def get_database_config(self) -> Dict[str, Any]:
        """Get database configuration from TuskLang"""
        db_config = self.get_tusk_section('database')
        if db_config:
            return db_config
        
        # Fallback to grim config
        return {
            'type': 'sqlite',
            'host': 'localhost',
            'port': 5432,
            'name': 'grim.db',
            'username': 'grim',
            'password': '',
            'charset': 'utf8mb4',
            'pool_size': 10
        }
    
    def get_security_config(self) -> Dict[str, Any]:
        """Get security configuration from TuskLang"""
        security_config = self.get_tusk_section('security')
        if security_config:
            return security_config
        
        # Fallback to grim config
        return {
            'encryption_key': self.config.security.encryption_key,
            'jwt_secret': self.config.security.jwt_secret,
            'app_key': self.config.security.app_key
        }
    
    def get_ui_config(self) -> Dict[str, Any]:
        """Get UI configuration from TuskLang"""
        ui_config = self.get_tusk_section('ui')
        if ui_config:
            return ui_config
        
        # Fallback to grim config
        return {
            'theme': 'grim_dark',
            'component_cache': True,
            'minify_assets': True,
            'responsive_design': True
        }
    
    def is_tusk_available(self) -> bool:
        """Check if TuskLang is available"""
        return TUSK_AVAILABLE and self.tsk_instance is not None
    
    def get_tusk_status(self) -> Dict[str, Any]:
        """Get TuskLang integration status"""
        return {
            'available': TUSK_AVAILABLE,
            'version': TUSK_VERSION,
            'initialized': self.tsk_instance is not None,
            'peanut_loaded': self.peanut_loaded,
            'package_source': 'PyPI' if TUSK_AVAILABLE else 'None'
        }
    
    def save_tusk_config(self, filepath: str) -> bool:
        """Save TuskLang configuration to file"""
        if not TUSK_AVAILABLE or not self.tsk_instance:
            return False
        
        try:
            self.tsk_instance.to_file(filepath)
            return True
        except Exception as e:
            self.logger.error(f"Failed to save TuskLang config to {filepath}: {e}")
            return False
    
    def load_tusk_config(self, filepath: str) -> bool:
        """Load TuskLang configuration from file"""
        if not TUSK_AVAILABLE:
            return False
        
        try:
            self.tsk_instance = TSK.from_file(filepath)
            return True
        except Exception as e:
            self.logger.error(f"Failed to load TuskLang config from {filepath}: {e}")
            return False
    
    def get_tusk_info(self) -> Dict[str, Any]:
        """Get detailed TuskLang information"""
        if not TUSK_AVAILABLE:
            return {'error': 'tusktsk package not available'}
        
        try:
            return {
                'version': TUSK_VERSION,
                'package_info': {
                    'name': 'tusktsk',
                    'source': 'PyPI',
                    'description': 'Official TuskLang Python SDK'
                },
                'features': {
                    'configuration_parsing': True,
                    'function_execution': True,
                    'operator_support': True,
                    'database_adapters': True,
                    'async_support': True
                },
                'status': self.get_tusk_status()
            }
        except Exception as e:
            return {'error': str(e)}


class GrimTuskAPI:
    """API wrapper for TuskLang operations in Grim"""
    
    def __init__(self, tusk_integration: GrimTuskIntegration):
        self.tusk = tusk_integration
        self.logger = get_logger('tusktsk_api')
    
    async def get_config(self, section: str, key: str = None) -> Dict[str, Any]:
        """Get configuration via API"""
        if key:
            value = self.tusk.get_tusk_config(section, key)
            return {'section': section, 'key': key, 'value': value}
        else:
            section_data = self.tusk.get_tusk_section(section)
            return {'section': section, 'data': section_data}
    
    async def set_config(self, section: str, key: str, value: Any) -> Dict[str, Any]:
        """Set configuration via API"""
        success = self.tusk.set_tusk_config(section, key, value)
        return {
            'section': section,
            'key': key,
            'value': value,
            'success': success
        }
    
    async def execute_function(self, section: str, key: str, args: List[Any] = None, kwargs: Dict[str, Any] = None) -> Dict[str, Any]:
        """Execute TuskLang function via API"""
        args = args or []
        kwargs = kwargs or {}
        
        result = self.tusk.execute_tusk_function(section, key, *args, **kwargs)
        return {
            'section': section,
            'key': key,
            'args': args,
            'kwargs': kwargs,
            'result': result
        }
    
    async def execute_operator(self, operator: str, expression: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Execute TuskLang operator via API"""
        result = await self.tusk.execute_tusk_operator(operator, expression, context or {})
        return {
            'operator': operator,
            'expression': expression,
            'context': context,
            'result': result
        }
    
    def get_status(self) -> Dict[str, Any]:
        """Get TuskLang integration status via API"""
        return self.tusk.get_tusk_status()
    
    def get_info(self) -> Dict[str, Any]:
        """Get detailed TuskLang information via API"""
        return self.tusk.get_tusk_info()


# Global instance for easy access
_tusk_integration: Optional[GrimTuskIntegration] = None
_tusk_api: Optional[GrimTuskAPI] = None


def get_tusk_integration(config_path: Optional[str] = None) -> GrimTuskIntegration:
    """Get or create TuskLang integration instance"""
    global _tusk_integration
    if _tusk_integration is None:
        _tusk_integration = GrimTuskIntegration(config_path)
    return _tusk_integration


def get_tusk_api(config_path: Optional[str] = None) -> GrimTuskAPI:
    """Get or create TuskLang API instance"""
    global _tusk_api
    if _tusk_api is None:
        tusk_integration = get_tusk_integration(config_path)
        _tusk_api = GrimTuskAPI(tusk_integration)
    return _tusk_api 