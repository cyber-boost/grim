"""
Configuration Management for Grim Core
Environment-aware configuration with validation and defaults
"""

import os
import json
import yaml
from pathlib import Path
from typing import Dict, Any, Optional, Union
from dataclasses import dataclass, field
import logging

@dataclass
class DatabaseConfig:
    """Database configuration settings"""
    type: str = "sqlite"
    url: str = "./grim.db"
    host: str = "localhost"
    port: int = 5432
    username: str = ""
    password: str = ""
    database: str = "grim"
    pool_size: int = 20
    max_overflow: int = 30
    echo: bool = False

@dataclass
class LoggingConfig:
    """Logging configuration settings"""
    level: str = "INFO"
    format: str = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
    file: Optional[str] = None
    max_size: int = 100 * 1024 * 1024  # 100MB
    backup_count: int = 10
    enable_console: bool = True
    enable_file: bool = True
    enable_json: bool = False

@dataclass
class WebConfig:
    """Web server configuration settings"""
    host: str = "0.0.0.0"
    port: int = 8000
    workers: int = 4
    reload: bool = False
    access_log: bool = True
    cors_origins: list = field(default_factory=list)
    cors_methods: list = field(default_factory=lambda: ["GET", "POST", "PUT", "DELETE"])
    cors_headers: list = field(default_factory=lambda: ["*"])

@dataclass
class SecurityConfig:
    """Security configuration settings"""
    secret_key: str = ""
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    bcrypt_rounds: int = 12
    enable_rate_limiting: bool = True
    rate_limit_requests: int = 100
    rate_limit_window: int = 60

@dataclass
class BackupConfig:
    """Backup configuration settings"""
    enabled: bool = True
    directory: str = "./backups"
    retention_days: int = 30
    compression: bool = True
    encryption: bool = False
    encryption_key: str = ""
    schedule: str = "0 2 * * *"  # Daily at 2 AM
    max_backups: int = 100

@dataclass
class PerformanceConfig:
    """Performance configuration settings"""
    chunk_size: int = 8192
    buffer_size: int = 65536
    max_workers: int = 4
    timeout: int = 30
    cache_size: int = 1000
    cache_ttl: int = 3600
    enable_profiling: bool = False

@dataclass
class MonitoringConfig:
    """Monitoring configuration settings"""
    enabled: bool = True
    metrics_port: int = 9090
    health_check_interval: int = 30
    alert_thresholds: Dict[str, float] = field(default_factory=dict)
    enable_prometheus: bool = True
    enable_health_endpoints: bool = True

class Config:
    """Main configuration class for Grim"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config_path = config_path
        self._load_config()
        self._load_environment()
        self._validate_config()
    
    def _load_config(self):
        """Load configuration from file"""
        if not self.config_path:
            # Try to find config file in common locations
            config_locations = [
                "grim_config.json",
                "grim_config.yaml",
                "grim_config.yml",
                "config/grim_config.json",
                "config/grim_config.yaml",
                "config/grim_config.yml"
            ]
            
            for location in config_locations:
                if Path(location).exists():
                    self.config_path = location
                    break
        
        if self.config_path and Path(self.config_path).exists():
            self._load_from_file()
        else:
            # Use default configuration
            self._set_defaults()
    
    def _load_from_file(self):
        """Load configuration from file"""
        try:
            path = Path(self.config_path)
            if path.suffix.lower() in ['.yaml', '.yml']:
                with open(path, 'r') as f:
                    config_data = yaml.safe_load(f)
            else:
                with open(path, 'r') as f:
                    config_data = json.load(f)
            
            self._parse_config_data(config_data)
        except Exception as e:
            logging.warning(f"Failed to load config file {self.config_path}: {e}")
            self._set_defaults()
    
    def _parse_config_data(self, data: Dict[str, Any]):
        """Parse configuration data into dataclasses"""
        # Database configuration
        db_data = data.get('database', {})
        self.database = DatabaseConfig(**db_data)
        
        # Logging configuration
        log_data = data.get('logging', {})
        self.logging = LoggingConfig(**log_data)
        
        # Web configuration
        web_data = data.get('web', {})
        self.web = WebConfig(**web_data)
        
        # Security configuration
        sec_data = data.get('security', {})
        self.security = SecurityConfig(**sec_data)
        
        # Backup configuration
        backup_data = data.get('backup', {})
        self.backup = BackupConfig(**backup_data)
        
        # Performance configuration
        perf_data = data.get('performance', {})
        self.performance = PerformanceConfig(**perf_data)
        
        # Monitoring configuration
        monitor_data = data.get('monitoring', {})
        self.monitoring = MonitoringConfig(**monitor_data)
    
    def _set_defaults(self):
        """Set default configuration values"""
        self.database = DatabaseConfig()
        self.logging = LoggingConfig()
        self.web = WebConfig()
        self.security = SecurityConfig()
        self.backup = BackupConfig()
        self.performance = PerformanceConfig()
        self.monitoring = MonitoringConfig()
    
    def _load_environment(self):
        """Load configuration from environment variables"""
        # Database environment variables
        if os.getenv('GRIM_DB_TYPE'):
            self.database.type = os.getenv('GRIM_DB_TYPE')
        if os.getenv('GRIM_DB_URL'):
            self.database.url = os.getenv('GRIM_DB_URL')
        if os.getenv('GRIM_DB_HOST'):
            self.database.host = os.getenv('GRIM_DB_HOST')
        if os.getenv('GRIM_DB_PORT'):
            self.database.port = int(os.getenv('GRIM_DB_PORT'))
        
        # Logging environment variables
        if os.getenv('GRIM_LOG_LEVEL'):
            self.logging.level = os.getenv('GRIM_LOG_LEVEL')
        if os.getenv('GRIM_LOG_FILE'):
            self.logging.file = os.getenv('GRIM_LOG_FILE')
        
        # Web environment variables
        if os.getenv('GRIM_WEB_HOST'):
            self.web.host = os.getenv('GRIM_WEB_HOST')
        if os.getenv('GRIM_WEB_PORT'):
            self.web.port = int(os.getenv('GRIM_WEB_PORT'))
        if os.getenv('GRIM_WEB_WORKERS'):
            self.web.workers = int(os.getenv('GRIM_WEB_WORKERS'))
        
        # Security environment variables
        if os.getenv('GRIM_SECRET_KEY'):
            self.security.secret_key = os.getenv('GRIM_SECRET_KEY')
        
        # Backup environment variables
        if os.getenv('GRIM_BACKUP_DIR'):
            self.backup.directory = os.getenv('GRIM_BACKUP_DIR')
        if os.getenv('GRIM_BACKUP_RETENTION'):
            self.backup.retention_days = int(os.getenv('GRIM_BACKUP_RETENTION'))
        
        # Performance environment variables
        if os.getenv('GRIM_CHUNK_SIZE'):
            self.performance.chunk_size = int(os.getenv('GRIM_CHUNK_SIZE'))
        if os.getenv('GRIM_MAX_WORKERS'):
            self.performance.max_workers = int(os.getenv('GRIM_MAX_WORKERS'))
        
        # Monitoring environment variables
        if os.getenv('GRIM_METRICS_PORT'):
            self.monitoring.metrics_port = int(os.getenv('GRIM_METRICS_PORT'))
    
    def _validate_config(self):
        """Validate configuration values"""
        # Validate database configuration
        if self.database.port < 1 or self.database.port > 65535:
            raise ValueError("Database port must be between 1 and 65535")
        
        # Validate web configuration
        if self.web.port < 1 or self.web.port > 65535:
            raise ValueError("Web port must be between 1 and 65535")
        if self.web.workers < 1:
            raise ValueError("Web workers must be at least 1")
        
        # Validate security configuration
        if not self.security.secret_key:
            # Generate a random secret key if not provided
            import secrets
            self.security.secret_key = secrets.token_urlsafe(32)
        
        # Validate performance configuration
        if self.performance.chunk_size < 1:
            raise ValueError("Chunk size must be at least 1")
        if self.performance.max_workers < 1:
            raise ValueError("Max workers must be at least 1")
        
        # Validate monitoring configuration
        if self.monitoring.metrics_port < 1 or self.monitoring.metrics_port > 65535:
            raise ValueError("Metrics port must be between 1 and 65535")
    
    def get_database_url(self) -> str:
        """Get database URL based on configuration"""
        if self.database.type == "sqlite":
            return f"sqlite:///{self.database.url}"
        elif self.database.type == "postgresql":
            return f"postgresql://{self.database.username}:{self.database.password}@{self.database.host}:{self.database.port}/{self.database.database}"
        elif self.database.type == "mysql":
            return f"mysql://{self.database.username}:{self.database.password}@{self.database.host}:{self.database.port}/{self.database.database}"
        else:
            return self.database.url
    
    def get_database_path(self, name: str = "grim") -> str:
        """Get database file path for SQLite"""
        if self.database.type == "sqlite":
            return self.database.url
        else:
            return f"{name}.db"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary"""
        return {
            'database': self.database.__dict__,
            'logging': self.logging.__dict__,
            'web': self.web.__dict__,
            'security': self.security.__dict__,
            'backup': self.backup.__dict__,
            'performance': self.performance.__dict__,
            'monitoring': self.monitoring.__dict__
        }
    
    def save(self, path: Optional[str] = None):
        """Save configuration to file"""
        if not path:
            path = self.config_path or "grim_config.json"
        
        config_data = self.to_dict()
        
        if path.endswith(('.yaml', '.yml')):
            with open(path, 'w') as f:
                yaml.dump(config_data, f, default_flow_style=False, indent=2)
        else:
            with open(path, 'w') as f:
                json.dump(config_data, f, indent=2)
    
    def get_log_level(self) -> int:
        """Get logging level as integer"""
        level_map = {
            'DEBUG': logging.DEBUG,
            'INFO': logging.INFO,
            'WARNING': logging.WARNING,
            'ERROR': logging.ERROR,
            'CRITICAL': logging.CRITICAL
        }
        return level_map.get(self.logging.level.upper(), logging.INFO)

# Global configuration instance
_config = None

def get_config(config_path: Optional[str] = None) -> Config:
    """Get global configuration instance"""
    global _config
    if _config is None:
        _config = Config(config_path)
    return _config

def set_config(config: Config):
    """Set global configuration instance"""
    global _config
    _config = config 