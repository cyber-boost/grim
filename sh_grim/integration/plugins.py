"""
Grimm Integration - Plugin Management
Comprehensive plugin system for extensible functionality
"""

import os
import sys
import importlib
import importlib.util
import inspect
import json
import logging
from typing import Dict, List, Optional, Any, Type, Callable
from pathlib import Path
import threading
from datetime import datetime
import yaml


class PluginBase:
    """Base class for all Grimm plugins"""
    
    def __init__(self, name: str, version: str, description: str = ""):
        self.name = name
        self.version = version
        self.description = description
        self.enabled = True
        self.loaded_at = datetime.utcnow()
        
    def initialize(self) -> bool:
        """Initialize the plugin - override in subclasses"""
        return True
        
    def cleanup(self) -> bool:
        """Cleanup the plugin - override in subclasses"""
        return True
        
    def get_info(self) -> Dict:
        """Get plugin information"""
        return {
            'name': self.name,
            'version': self.version,
            'description': self.description,
            'enabled': self.enabled,
            'loaded_at': self.loaded_at.isoformat(),
            'class': self.__class__.__name__
        }


class PluginManager:
    """Comprehensive plugin management system"""
    
    def __init__(self, config: Optional[Dict] = None):
        self.config = config or {}
        self.plugins = {}
        self.plugin_classes = {}
        self.logger = logging.getLogger('grimm.plugins')
        self.plugin_dirs = self.config.get('plugin_dirs', ['plugins', 'modules/plugins'])
        self.auto_load = self.config.get('plugin_auto_load', True)
        self._lock = threading.Lock()
        
    def discover_plugins(self) -> List[str]:
        """Discover available plugins in plugin directories"""
        discovered = []
        
        for plugin_dir in self.plugin_dirs:
            if not os.path.exists(plugin_dir):
                continue
                
            for item in os.listdir(plugin_dir):
                item_path = os.path.join(plugin_dir, item)
                
                # Check for plugin directories
                if os.path.isdir(item_path):
                    init_file = os.path.join(item_path, '__init__.py')
                    if os.path.exists(init_file):
                        discovered.append(item)
                        
                # Check for plugin files
                elif item.endswith('.py') and not item.startswith('_'):
                    discovered.append(item[:-3])
                    
        return discovered
        
    def load_plugin(self, plugin_name: str, plugin_path: Optional[str] = None) -> bool:
        """Load a plugin from file or directory"""
        try:
            with self._lock:
                # Determine plugin path
                if plugin_path:
                    full_path = plugin_path
                else:
                    full_path = self._find_plugin_path(plugin_name)
                    
                if not full_path:
                    self.logger.error(f"Plugin {plugin_name} not found")
                    return False
                    
                # Load plugin module
                if os.path.isdir(full_path):
                    # Plugin directory
                    spec = importlib.util.spec_from_file_location(
                        plugin_name,
                        os.path.join(full_path, '__init__.py')
                    )
                else:
                    # Plugin file
                    spec = importlib.util.spec_from_file_location(
                        plugin_name,
                        full_path
                    )
                    
                if not spec or not spec.loader:
                    self.logger.error(f"Failed to create spec for plugin {plugin_name}")
                    return False
                    
                module = importlib.util.module_from_spec(spec)
                sys.modules[plugin_name] = module
                spec.loader.exec_module(module)
                
                # Find plugin classes
                plugin_classes = self._find_plugin_classes(module)
                
                if not plugin_classes:
                    self.logger.error(f"No plugin classes found in {plugin_name}")
                    return False
                    
                # Instantiate and register plugins
                for class_name, plugin_class in plugin_classes.items():
                    if issubclass(plugin_class, PluginBase):
                        plugin_instance = plugin_class()
                        
                        # Initialize plugin
                        if plugin_instance.initialize():
                            self.plugins[plugin_instance.name] = plugin_instance
                            self.plugin_classes[class_name] = plugin_class
                            
                            self.logger.info(f"Plugin {plugin_instance.name} loaded successfully")
                        else:
                            self.logger.error(f"Failed to initialize plugin {plugin_instance.name}")
                            
                return True
                
        except Exception as e:
            self.logger.error(f"Failed to load plugin {plugin_name}: {e}")
            return False
            
    def _find_plugin_path(self, plugin_name: str) -> Optional[str]:
        """Find the path to a plugin"""
        for plugin_dir in self.plugin_dirs:
            if not os.path.exists(plugin_dir):
                continue
                
            # Check for plugin directory
            plugin_dir_path = os.path.join(plugin_dir, plugin_name)
            if os.path.isdir(plugin_dir_path):
                return plugin_dir_path
                
            # Check for plugin file
            plugin_file_path = os.path.join(plugin_dir, f"{plugin_name}.py")
            if os.path.exists(plugin_file_path):
                return plugin_file_path
                
        return None
        
    def _find_plugin_classes(self, module) -> Dict[str, Type]:
        """Find plugin classes in a module"""
        plugin_classes = {}
        
        for name, obj in inspect.getmembers(module):
            if (inspect.isclass(obj) and 
                issubclass(obj, PluginBase) and 
                obj != PluginBase):
                plugin_classes[name] = obj
                
        return plugin_classes
        
    def unload_plugin(self, plugin_name: str) -> bool:
        """Unload a plugin"""
        try:
            with self._lock:
                if plugin_name in self.plugins:
                    plugin = self.plugins[plugin_name]
                    
                    # Cleanup plugin
                    if plugin.cleanup():
                        del self.plugins[plugin_name]
                        
                        # Remove from module cache
                        if plugin_name in sys.modules:
                            del sys.modules[plugin_name]
                            
                        self.logger.info(f"Plugin {plugin_name} unloaded successfully")
                        return True
                    else:
                        self.logger.error(f"Failed to cleanup plugin {plugin_name}")
                        
                return False
                
        except Exception as e:
            self.logger.error(f"Failed to unload plugin {plugin_name}: {e}")
            return False
            
    def get_plugin(self, plugin_name: str) -> Optional[PluginBase]:
        """Get a plugin instance by name"""
        return self.plugins.get(plugin_name)
        
    def get_all_plugins(self) -> List[Dict]:
        """Get information about all loaded plugins"""
        return [plugin.get_info() for plugin in self.plugins.values()]
        
    def enable_plugin(self, plugin_name: str) -> bool:
        """Enable a plugin"""
        if plugin_name in self.plugins:
            self.plugins[plugin_name].enabled = True
            return True
        return False
        
    def disable_plugin(self, plugin_name: str) -> bool:
        """Disable a plugin"""
        if plugin_name in self.plugins:
            self.plugins[plugin_name].enabled = False
            return True
        return False
        
    def call_plugin_method(self, 
                          plugin_name: str, 
                          method_name: str, 
                          *args, 
                          **kwargs) -> Any:
        """Call a method on a plugin"""
        plugin = self.get_plugin(plugin_name)
        if not plugin:
            raise ValueError(f"Plugin {plugin_name} not found")
            
        if not plugin.enabled:
            raise ValueError(f"Plugin {plugin_name} is disabled")
            
        if not hasattr(plugin, method_name):
            raise ValueError(f"Method {method_name} not found in plugin {plugin_name}")
            
        method = getattr(plugin, method_name)
        if not callable(method):
            raise ValueError(f"{method_name} is not callable in plugin {plugin_name}")
            
        return method(*args, **kwargs)
        
    def get_plugin_methods(self, plugin_name: str) -> List[str]:
        """Get available methods for a plugin"""
        plugin = self.get_plugin(plugin_name)
        if not plugin:
            return []
            
        methods = []
        for name, obj in inspect.getmembers(plugin):
            if (inspect.ismethod(obj) or inspect.isfunction(obj)) and not name.startswith('_'):
                methods.append(name)
                
        return methods
        
    def auto_load_plugins(self) -> int:
        """Automatically load all discovered plugins"""
        if not self.auto_load:
            return 0
            
        discovered = self.discover_plugins()
        loaded_count = 0
        
        for plugin_name in discovered:
            if self.load_plugin(plugin_name):
                loaded_count += 1
                
        self.logger.info(f"Auto-loaded {loaded_count} plugins")
        return loaded_count
        
    def reload_plugin(self, plugin_name: str) -> bool:
        """Reload a plugin"""
        if self.unload_plugin(plugin_name):
            return self.load_plugin(plugin_name)
        return False
        
    def get_plugin_config(self, plugin_name: str) -> Optional[Dict]:
        """Get plugin configuration"""
        config_file = self._find_plugin_config(plugin_name)
        if not config_file:
            return None
            
        try:
            with open(config_file, 'r') as f:
                if config_file.endswith('.json'):
                    return json.load(f)
                elif config_file.endswith('.yaml') or config_file.endswith('.yml'):
                    return yaml.safe_load(f)
                else:
                    return None
        except Exception as e:
            self.logger.error(f"Failed to load config for plugin {plugin_name}: {e}")
            return None
            
    def _find_plugin_config(self, plugin_name: str) -> Optional[str]:
        """Find plugin configuration file"""
        for plugin_dir in self.plugin_dirs:
            if not os.path.exists(plugin_dir):
                continue
                
            # Check for config files
            config_files = [
                os.path.join(plugin_dir, f"{plugin_name}.json"),
                os.path.join(plugin_dir, f"{plugin_name}.yaml"),
                os.path.join(plugin_dir, f"{plugin_name}.yml"),
                os.path.join(plugin_dir, plugin_name, "config.json"),
                os.path.join(plugin_dir, plugin_name, "config.yaml"),
                os.path.join(plugin_dir, plugin_name, "config.yml")
            ]
            
            for config_file in config_files:
                if os.path.exists(config_file):
                    return config_file
                    
        return None
        
    def validate_plugin(self, plugin_name: str) -> Dict:
        """Validate a plugin"""
        result = {
            'valid': False,
            'errors': [],
            'warnings': []
        }
        
        # Check if plugin exists
        plugin_path = self._find_plugin_path(plugin_name)
        if not plugin_path:
            result['errors'].append("Plugin not found")
            return result
            
        # Check if plugin can be loaded
        try:
            # Try to load without initializing
            if os.path.isdir(plugin_path):
                spec = importlib.util.spec_from_file_location(
                    plugin_name,
                    os.path.join(plugin_path, '__init__.py')
                )
            else:
                spec = importlib.util.spec_from_file_location(
                    plugin_name,
                    plugin_path
                )
                
            if not spec or not spec.loader:
                result['errors'].append("Invalid plugin structure")
                return result
                
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            # Check for plugin classes
            plugin_classes = self._find_plugin_classes(module)
            if not plugin_classes:
                result['errors'].append("No plugin classes found")
                return result
                
            # Validate each plugin class
            for class_name, plugin_class in plugin_classes.items():
                if not issubclass(plugin_class, PluginBase):
                    result['errors'].append(f"{class_name} does not inherit from PluginBase")
                    
                # Check required methods
                required_methods = ['initialize', 'cleanup']
                for method in required_methods:
                    if not hasattr(plugin_class, method):
                        result['warnings'].append(f"{class_name} missing {method} method")
                        
            result['valid'] = len(result['errors']) == 0
            
        except Exception as e:
            result['errors'].append(f"Load error: {str(e)}")
            
        return result


def main():
    """CLI interface for plugin management"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grimm Plugin Manager CLI')
    parser.add_argument('action', choices=['discover', 'load', 'unload', 'list', 'info', 'validate'])
    parser.add_argument('--plugin-name', help='Plugin name')
    parser.add_argument('--plugin-path', help='Plugin path')
    parser.add_argument('--auto-load', action='store_true', help='Auto-load plugins')
    
    args = parser.parse_args()
    plugin_manager = PluginManager()
    
    if args.action == 'discover':
        plugins = plugin_manager.discover_plugins()
        print("Discovered plugins:")
        for plugin in plugins:
            print(f"  - {plugin}")
            
    elif args.action == 'load':
        if not args.plugin_name:
            print("Error: plugin-name required for loading")
            return
            
        success = plugin_manager.load_plugin(args.plugin_name, args.plugin_path)
        print(f"Plugin loading: {'Success' if success else 'Failed'}")
        
    elif args.action == 'unload':
        if not args.plugin_name:
            print("Error: plugin-name required for unloading")
            return
            
        success = plugin_manager.unload_plugin(args.plugin_name)
        print(f"Plugin unloading: {'Success' if success else 'Failed'}")
        
    elif args.action == 'list':
        plugins = plugin_manager.get_all_plugins()
        print(json.dumps(plugins, indent=2))
        
    elif args.action == 'info':
        if not args.plugin_name:
            print("Error: plugin-name required for info")
            return
            
        plugin = plugin_manager.get_plugin(args.plugin_name)
        if plugin:
            print(json.dumps(plugin.get_info(), indent=2))
        else:
            print("Plugin not found")
            
    elif args.action == 'validate':
        if not args.plugin_name:
            print("Error: plugin-name required for validation")
            return
            
        result = plugin_manager.validate_plugin(args.plugin_name)
        print(json.dumps(result, indent=2))
        
    elif args.action == 'auto-load':
        count = plugin_manager.auto_load_plugins()
        print(f"Auto-loaded {count} plugins")


if __name__ == "__main__":
    main() 