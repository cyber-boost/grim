"""
Grimm Integration - Connector Management
Comprehensive connector system for external integrations
"""

import json
import logging
import threading
from typing import Dict, List, Optional, Any, Type
from abc import ABC, abstractmethod
from datetime import datetime, timedelta
import time
import queue
from concurrent.futures import ThreadPoolExecutor, as_completed


class ConnectorBase(ABC):
    """Base class for all Grimm connectors"""
    
    def __init__(self, name: str, config: Dict):
        self.name = name
        self.config = config
        self.connected = False
        self.last_connection = None
        self.connection_attempts = 0
        self.error_count = 0
        self.logger = logging.getLogger(f'grimm.connector.{name}')
        
    @abstractmethod
    def connect(self) -> bool:
        """Connect to the external system"""
        pass
        
    @abstractmethod
    def disconnect(self) -> bool:
        """Disconnect from the external system"""
        pass
        
    @abstractmethod
    def is_connected(self) -> bool:
        """Check if connected"""
        pass
        
    @abstractmethod
    def send_data(self, data: Dict) -> bool:
        """Send data to the external system"""
        pass
        
    @abstractmethod
    def receive_data(self) -> Optional[Dict]:
        """Receive data from the external system"""
        pass
        
    def get_status(self) -> Dict:
        """Get connector status"""
        return {
            'name': self.name,
            'connected': self.connected,
            'last_connection': self.last_connection.isoformat() if self.last_connection else None,
            'connection_attempts': self.connection_attempts,
            'error_count': self.error_count,
            'type': self.__class__.__name__
        }


class DatabaseConnector(ConnectorBase):
    """Database connector for various database systems"""
    
    def __init__(self, name: str, config: Dict):
        super().__init__(name, config)
        self.connection = None
        self.db_type = config.get('type', 'sqlite')
        
    def connect(self) -> bool:
        """Connect to database"""
        try:
            if self.db_type == 'sqlite':
                import sqlite3
                self.connection = sqlite3.connect(self.config['database'])
            elif self.db_type == 'postgresql':
                import psycopg2
                self.connection = psycopg2.connect(
                    host=self.config.get('host', 'localhost'),
                    port=self.config.get('port', 5432),
                    database=self.config['database'],
                    user=self.config['username'],
                    password=self.config['password']
                )
            elif self.db_type == 'mysql':
                import mysql.connector
                self.connection = mysql.connector.connect(
                    host=self.config.get('host', 'localhost'),
                    port=self.config.get('port', 3306),
                    database=self.config['database'],
                    user=self.config['username'],
                    password=self.config['password']
                )
            else:
                raise ValueError(f"Unsupported database type: {self.db_type}")
                
            self.connected = True
            self.last_connection = datetime.utcnow()
            self.connection_attempts += 1
            self.logger.info(f"Connected to {self.db_type} database")
            return True
            
        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Failed to connect to database: {e}")
            return False
            
    def disconnect(self) -> bool:
        """Disconnect from database"""
        try:
            if self.connection:
                self.connection.close()
                self.connection = None
            self.connected = False
            self.logger.info("Disconnected from database")
            return True
        except Exception as e:
            self.logger.error(f"Failed to disconnect: {e}")
            return False
            
    def is_connected(self) -> bool:
        """Check if connected"""
        return self.connected and self.connection is not None
        
    def send_data(self, data: Dict) -> bool:
        """Execute SQL query"""
        try:
            if not self.is_connected():
                if not self.connect():
                    return False
                    
            cursor = self.connection.cursor()
            
            if data.get('type') == 'query':
                cursor.execute(data['sql'], data.get('params', ()))
                if data.get('fetch', False):
                    result = cursor.fetchall()
                    data['result'] = result
                else:
                    self.connection.commit()
                    
            return True
            
        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Failed to send data: {e}")
            return False
            
    def receive_data(self) -> Optional[Dict]:
        """Receive data from database (not applicable)"""
        return None


class APIConnector(ConnectorBase):
    """API connector for REST/GraphQL APIs"""
    
    def __init__(self, name: str, config: Dict):
        super().__init__(name, config)
        self.session = None
        self.base_url = config['base_url']
        self.auth_type = config.get('auth_type', 'none')
        
    def connect(self) -> bool:
        """Connect to API (validate endpoint)"""
        try:
            import requests
            self.session = requests.Session()
            
            # Setup authentication
            if self.auth_type == 'bearer':
                self.session.headers['Authorization'] = f"Bearer {self.config['token']}"
            elif self.auth_type == 'basic':
                import base64
                credentials = base64.b64encode(
                    f"{self.config['username']}:{self.config['password']}".encode()
                ).decode()
                self.session.headers['Authorization'] = f"Basic {credentials}"
                
            # Test connection
            response = self.session.get(f"{self.base_url}/health", timeout=10)
            if response.status_code < 400:
                self.connected = True
                self.last_connection = datetime.utcnow()
                self.connection_attempts += 1
                self.logger.info("Connected to API")
                return True
            else:
                raise Exception(f"API health check failed: {response.status_code}")
                
        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Failed to connect to API: {e}")
            return False
            
    def disconnect(self) -> bool:
        """Disconnect from API"""
        try:
            if self.session:
                self.session.close()
                self.session = None
            self.connected = False
            self.logger.info("Disconnected from API")
            return True
        except Exception as e:
            self.logger.error(f"Failed to disconnect: {e}")
            return False
            
    def is_connected(self) -> bool:
        """Check if connected"""
        return self.connected and self.session is not None
        
    def send_data(self, data: Dict) -> bool:
        """Send data to API"""
        try:
            if not self.is_connected():
                if not self.connect():
                    return False
                    
            method = data.get('method', 'POST')
            endpoint = data.get('endpoint', '')
            payload = data.get('data', {})
            
            url = f"{self.base_url}/{endpoint.lstrip('/')}"
            
            response = self.session.request(
                method=method,
                url=url,
                json=payload,
                timeout=self.config.get('timeout', 30)
            )
            
            data['response'] = {
                'status_code': response.status_code,
                'data': response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text
            }
            
            return response.status_code < 400
            
        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Failed to send data: {e}")
            return False
            
    def receive_data(self) -> Optional[Dict]:
        """Receive data from API (polling)"""
        try:
            if not self.is_connected():
                if not self.connect():
                    return None
                    
            endpoint = self.config.get('poll_endpoint', '')
            if not endpoint:
                return None
                
            url = f"{self.base_url}/{endpoint.lstrip('/')}"
            response = self.session.get(url, timeout=self.config.get('timeout', 30))
            
            if response.status_code == 200:
                return {
                    'data': response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text,
                    'timestamp': datetime.utcnow().isoformat()
                }
                
        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Failed to receive data: {e}")
            
        return None


class FileConnector(ConnectorBase):
    """File system connector for file-based integrations"""
    
    def __init__(self, name: str, config: Dict):
        super().__init__(name, config)
        self.file_path = config['file_path']
        self.file_mode = config.get('mode', 'read')
        self.file_handle = None
        
    def connect(self) -> bool:
        """Connect to file system"""
        try:
            # Ensure directory exists
            import os
            os.makedirs(os.path.dirname(self.file_path), exist_ok=True)
            
            # Test file access
            if self.file_mode == 'read':
                if not os.path.exists(self.file_path):
                    # Create empty file for reading
                    with open(self.file_path, 'w') as f:
                        f.write('')
                        
            self.connected = True
            self.last_connection = datetime.utcnow()
            self.connection_attempts += 1
            self.logger.info(f"Connected to file: {self.file_path}")
            return True
            
        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Failed to connect to file: {e}")
            return False
            
    def disconnect(self) -> bool:
        """Disconnect from file"""
        try:
            if self.file_handle:
                self.file_handle.close()
                self.file_handle = None
            self.connected = False
            self.logger.info("Disconnected from file")
            return True
        except Exception as e:
            self.logger.error(f"Failed to disconnect: {e}")
            return False
            
    def is_connected(self) -> bool:
        """Check if connected"""
        return self.connected
        
    def send_data(self, data: Dict) -> bool:
        """Write data to file"""
        try:
            if not self.is_connected():
                if not self.connect():
                    return False
                    
            mode = 'a' if self.config.get('append', False) else 'w'
            
            with open(self.file_path, mode) as f:
                if self.config.get('format') == 'json':
                    json.dump(data, f)
                    f.write('\n')
                else:
                    f.write(str(data) + '\n')
                    
            return True
            
        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Failed to send data: {e}")
            return False
            
    def receive_data(self) -> Optional[Dict]:
        """Read data from file"""
        try:
            if not self.is_connected():
                if not self.connect():
                    return None
                    
            if not os.path.exists(self.file_path):
                return None
                
            with open(self.file_path, 'r') as f:
                content = f.read().strip()
                
            if not content:
                return None
                
            if self.config.get('format') == 'json':
                return json.loads(content)
            else:
                return {'data': content, 'timestamp': datetime.utcnow().isoformat()}
                
        except Exception as e:
            self.error_count += 1
            self.logger.error(f"Failed to receive data: {e}")
            return None


class ConnectorManager:
    """Comprehensive connector management system"""
    
    def __init__(self, config: Optional[Dict] = None):
        self.config = config or {}
        self.connectors = {}
        self.connector_types = {
            'database': DatabaseConnector,
            'api': APIConnector,
            'file': FileConnector
        }
        self.logger = logging.getLogger('grimm.connectors')
        self._lock = threading.Lock()
        
    def register_connector(self, 
                          name: str, 
                          connector_type: str, 
                          config: Dict) -> bool:
        """Register a new connector"""
        try:
            with self._lock:
                if name in self.connectors:
                    self.logger.warning(f"Connector {name} already exists, replacing")
                    
                if connector_type not in self.connector_types:
                    raise ValueError(f"Unknown connector type: {connector_type}")
                    
                connector_class = self.connector_types[connector_type]
                connector = connector_class(name, config)
                
                self.connectors[name] = connector
                self.logger.info(f"Registered connector: {name} ({connector_type})")
                return True
                
        except Exception as e:
            self.logger.error(f"Failed to register connector {name}: {e}")
            return False
            
    def unregister_connector(self, name: str) -> bool:
        """Unregister a connector"""
        try:
            with self._lock:
                if name in self.connectors:
                    connector = self.connectors[name]
                    connector.disconnect()
                    del self.connectors[name]
                    self.logger.info(f"Unregistered connector: {name}")
                    return True
                return False
                
        except Exception as e:
            self.logger.error(f"Failed to unregister connector {name}: {e}")
            return False
            
    def get_connector(self, name: str) -> Optional[ConnectorBase]:
        """Get a connector by name"""
        return self.connectors.get(name)
        
    def connect_all(self) -> Dict[str, bool]:
        """Connect to all registered connectors"""
        results = {}
        
        with self._lock:
            for name, connector in self.connectors.items():
                try:
                    results[name] = connector.connect()
                except Exception as e:
                    self.logger.error(f"Failed to connect {name}: {e}")
                    results[name] = False
                    
        return results
        
    def disconnect_all(self) -> Dict[str, bool]:
        """Disconnect from all connectors"""
        results = {}
        
        with self._lock:
            for name, connector in self.connectors.items():
                try:
                    results[name] = connector.disconnect()
                except Exception as e:
                    self.logger.error(f"Failed to disconnect {name}: {e}")
                    results[name] = False
                    
        return results
        
    def get_all_connectors(self) -> List[Dict]:
        """Get status of all connectors"""
        return [connector.get_status() for connector in self.connectors.values()]
        
    def send_data_to_connector(self, 
                              connector_name: str, 
                              data: Dict) -> bool:
        """Send data to a specific connector"""
        connector = self.get_connector(connector_name)
        if not connector:
            self.logger.error(f"Connector {connector_name} not found")
            return False
            
        return connector.send_data(data)
        
    def receive_data_from_connector(self, 
                                   connector_name: str) -> Optional[Dict]:
        """Receive data from a specific connector"""
        connector = self.get_connector(connector_name)
        if not connector:
            self.logger.error(f"Connector {connector_name} not found")
            return None
            
        return connector.receive_data()
        
    def broadcast_data(self, data: Dict, connector_types: Optional[List[str]] = None) -> Dict[str, bool]:
        """Send data to multiple connectors"""
        results = {}
        
        with self._lock:
            for name, connector in self.connectors.items():
                if connector_types and connector.__class__.__name__.lower().replace('connector', '') not in connector_types:
                    continue
                    
                try:
                    results[name] = connector.send_data(data)
                except Exception as e:
                    self.logger.error(f"Failed to broadcast to {name}: {e}")
                    results[name] = False
                    
        return results
        
    def health_check(self) -> Dict[str, Dict]:
        """Perform health check on all connectors"""
        health = {}
        
        with self._lock:
            for name, connector in self.connectors.items():
                health[name] = {
                    'connected': connector.is_connected(),
                    'last_connection': connector.last_connection.isoformat() if connector.last_connection else None,
                    'error_count': connector.error_count,
                    'connection_attempts': connector.connection_attempts
                }
                
        return health
        
    def register_connector_type(self, 
                               type_name: str, 
                               connector_class: Type[ConnectorBase]) -> bool:
        """Register a new connector type"""
        try:
            if not issubclass(connector_class, ConnectorBase):
                raise ValueError("Connector class must inherit from ConnectorBase")
                
            self.connector_types[type_name] = connector_class
            self.logger.info(f"Registered connector type: {type_name}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to register connector type {type_name}: {e}")
            return False


def main():
    """CLI interface for connector management"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grimm Connector Manager CLI')
    parser.add_argument('action', choices=['register', 'unregister', 'connect', 'disconnect', 'list', 'send', 'receive', 'health'])
    parser.add_argument('--name', help='Connector name')
    parser.add_argument('--type', help='Connector type')
    parser.add_argument('--config', help='Configuration file (JSON)')
    parser.add_argument('--data', help='Data to send (JSON)')
    
    args = parser.parse_args()
    connector_manager = ConnectorManager()
    
    if args.action == 'register':
        if not all([args.name, args.type, args.config]):
            print("Error: name, type, and config required for registration")
            return
            
        try:
            with open(args.config, 'r') as f:
                config = json.load(f)
        except Exception as e:
            print(f"Error loading config: {e}")
            return
            
        success = connector_manager.register_connector(args.name, args.type, config)
        print(f"Connector registration: {'Success' if success else 'Failed'}")
        
    elif args.action == 'unregister':
        if not args.name:
            print("Error: name required for unregistration")
            return
            
        success = connector_manager.unregister_connector(args.name)
        print(f"Connector unregistration: {'Success' if success else 'Failed'}")
        
    elif args.action == 'connect':
        results = connector_manager.connect_all()
        print("Connection results:")
        for name, success in results.items():
            print(f"  {name}: {'Success' if success else 'Failed'}")
            
    elif args.action == 'disconnect':
        results = connector_manager.disconnect_all()
        print("Disconnection results:")
        for name, success in results.items():
            print(f"  {name}: {'Success' if success else 'Failed'}")
            
    elif args.action == 'list':
        connectors = connector_manager.get_all_connectors()
        print(json.dumps(connectors, indent=2))
        
    elif args.action == 'send':
        if not all([args.name, args.data]):
            print("Error: name and data required for sending")
            return
            
        try:
            data = json.loads(args.data)
        except json.JSONDecodeError:
            print("Error: Invalid JSON data")
            return
            
        success = connector_manager.send_data_to_connector(args.name, data)
        print(f"Data sending: {'Success' if success else 'Failed'}")
        
    elif args.action == 'receive':
        if not args.name:
            print("Error: name required for receiving")
            return
            
        data = connector_manager.receive_data_from_connector(args.name)
        if data:
            print(json.dumps(data, indent=2))
        else:
            print("No data received")
            
    elif args.action == 'health':
        health = connector_manager.health_check()
        print(json.dumps(health, indent=2))


if __name__ == "__main__":
    main() 