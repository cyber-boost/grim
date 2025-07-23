"""
Grimm Integration Module
Comprehensive integration framework for external systems and APIs
"""

from .api import APIManager
from .webhooks import WebhookManager
from .plugins import PluginManager
from .connectors import ConnectorManager

__version__ = "1.0.0"
__author__ = "Grimm Integration Team"

# Export main integration classes
__all__ = [
    'APIManager',
    'WebhookManager',
    'PluginManager',
    'ConnectorManager'
]

# Integration configuration
INTEGRATION_CONFIG = {
    'api_timeout': 30,
    'webhook_retry_attempts': 3,
    'webhook_retry_delay': 5,
    'plugin_auto_load': True,
    'connector_pool_size': 10,
    'rate_limit_requests': 100,
    'rate_limit_window': 60,
    'enable_ssl_verification': True,
    'default_user_agent': 'Grimm-Integration/1.0',
    'log_integration_events': True
}

def get_integration_manager():
    """Get configured integration manager instance"""
    return {
        'api': APIManager(),
        'webhooks': WebhookManager(),
        'plugins': PluginManager(),
        'connectors': ConnectorManager()
    } 