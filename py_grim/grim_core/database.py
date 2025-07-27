"""
Grim Core Database Manager
Simple database management for Grim framework
"""

import sqlite3
import logging
from pathlib import Path
from typing import Optional, Any
from contextlib import contextmanager

class DatabaseManager:
    """Simple database manager for Grim"""
    
    def __init__(self, config):
        self.config = config
        self.db_path = Path(config.get_database_path())
        self.logger = logging.getLogger("database_manager")
        
        # Ensure database directory exists
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize database
        self._initialize_database()
    
    def _initialize_database(self):
        """Initialize database tables"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                
                # Create metrics table
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS system_metrics (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp REAL NOT NULL,
                        cpu_percent REAL,
                        memory_percent REAL,
                        memory_used INTEGER,
                        memory_total INTEGER,
                        disk_usage_percent REAL,
                        disk_used INTEGER,
                        disk_total INTEGER,
                        network_sent INTEGER,
                        network_recv INTEGER,
                        load_average TEXT,
                        process_count INTEGER,
                        uptime REAL
                    )
                """)
                
                # Create alerts table
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS alerts (
                        id TEXT PRIMARY KEY,
                        level TEXT NOT NULL,
                        message TEXT NOT NULL,
                        timestamp REAL NOT NULL,
                        service TEXT,
                        metric TEXT,
                        value REAL,
                        threshold REAL,
                        resolved BOOLEAN DEFAULT FALSE
                    )
                """)
                
                conn.commit()
                self.logger.info("Database initialized successfully")
                
        except Exception as e:
            self.logger.error(f"Failed to initialize database: {e}")
    
    @contextmanager
    def get_connection(self):
        """Get database connection"""
        conn = sqlite3.connect(str(self.db_path))
        try:
            yield conn
        finally:
            conn.close()
    
    def execute_query(self, query: str, params: tuple = ()) -> Optional[Any]:
        """Execute a query and return results"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, params)
                return cursor.fetchall()
        except Exception as e:
            self.logger.error(f"Query execution failed: {e}")
            return None
    
    def execute_update(self, query: str, params: tuple = ()) -> bool:
        """Execute an update query"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, params)
                conn.commit()
                return True
        except Exception as e:
            self.logger.error(f"Update execution failed: {e}")
            return False 