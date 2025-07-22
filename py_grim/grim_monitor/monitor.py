#!/usr/bin/env python3
"""
Grim System Monitor

Comprehensive system monitoring and metrics collection for the Grim framework.
Provides real-time health monitoring, performance metrics, alerting, and dashboard capabilities.
"""

import asyncio
import json
import logging
import time
import psutil
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable
from pathlib import Path
from dataclasses import dataclass, asdict
from collections import defaultdict, deque
import threading
import signal
import sys

# Add the project root to the path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from grim_core.config import Config
from grim_core.logger import Logger
from grim_core.database import DatabaseManager

@dataclass
class SystemMetrics:
    """System metrics container"""
    timestamp: float
    cpu_percent: float
    memory_percent: float
    memory_used: int
    memory_total: int
    disk_usage_percent: float
    disk_used: int
    disk_total: int
    network_sent: int
    network_recv: int
    load_average: List[float]
    process_count: int
    uptime: float

@dataclass
class ServiceHealth:
    """Service health status"""
    service_name: str
    status: str  # 'healthy', 'degraded', 'unhealthy'
    response_time: float
    last_check: float
    error_count: int
    uptime: float
    version: str
    endpoints: List[str]

@dataclass
class Alert:
    """Alert container"""
    id: str
    level: str  # 'info', 'warning', 'critical'
    message: str
    timestamp: float
    service: str
    metric: str
    value: float
    threshold: float
    resolved: bool = False

class GrimMonitor:
    """Main monitoring system"""
    
    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config()
        self.logger = Logger("grim_monitor")
        self.db_manager = DatabaseManager(self.config)
        
        # Metrics storage
        self.system_metrics: deque = deque(maxlen=1000)  # Keep last 1000 metrics
        self.service_health: Dict[str, ServiceHealth] = {}
        self.alerts: List[Alert] = []
        
        # Monitoring state
        self.running = False
        self.monitoring_thread = None
        self.alert_callbacks: List[Callable] = []
        
        # Performance tracking
        self.performance_history: Dict[str, deque] = defaultdict(lambda: deque(maxlen=100))
        
        # Thresholds
        self.thresholds = {
            'cpu_percent': 80.0,
            'memory_percent': 85.0,
            'disk_usage_percent': 90.0,
            'response_time': 1000.0,  # ms
            'error_rate': 5.0  # percentage
        }
        
        # Initialize monitoring
        self._initialize_monitoring()
        
        self.logger.info("Grim Monitor initialized")
    
    def _initialize_monitoring(self):
        """Initialize monitoring components"""
        # Create metrics table
        self._create_metrics_table()
        
        # Register signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        # Initialize service health tracking
        self._initialize_service_health()
    
    def _create_metrics_table(self):
        """Create metrics table in database"""
        try:
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
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
                
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS service_health (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        service_name TEXT NOT NULL,
                        status TEXT NOT NULL,
                        response_time REAL,
                        last_check REAL,
                        error_count INTEGER,
                        uptime REAL,
                        version TEXT,
                        endpoints TEXT
                    )
                """)
                
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
                        resolved INTEGER DEFAULT 0
                    )
                """)
                
                conn.commit()
                self.logger.info("Metrics tables created successfully")
                
        except Exception as e:
            self.logger.error(f"Failed to create metrics tables: {e}")
    
    def _initialize_service_health(self):
        """Initialize service health tracking"""
        services = [
            "grim_gateway",
            "grim_web",
            "grim_backup",
            "go_compression",
            "go_deduplication"
        ]
        
        for service in services:
            self.service_health[service] = ServiceHealth(
                service_name=service,
                status="unknown",
                response_time=0.0,
                last_check=0.0,
                error_count=0,
                uptime=0.0,
                version="1.0.0",
                endpoints=[]
            )
    
    def start_monitoring(self):
        """Start the monitoring system"""
        if self.running:
            self.logger.warning("Monitoring already running")
            return
        
        self.running = True
        self.monitoring_thread = threading.Thread(target=self._monitoring_loop, daemon=True)
        self.monitoring_thread.start()
        
        self.logger.info("Monitoring system started")
    
    def stop_monitoring(self):
        """Stop the monitoring system"""
        self.running = False
        if self.monitoring_thread:
            self.monitoring_thread.join(timeout=5)
        
        self.logger.info("Monitoring system stopped")
    
    def _monitoring_loop(self):
        """Main monitoring loop"""
        while self.running:
            try:
                # Collect system metrics
                metrics = self._collect_system_metrics()
                self.system_metrics.append(metrics)
                
                # Store metrics in database
                self._store_metrics(metrics)
                
                # Check service health
                self._check_service_health()
                
                # Check for alerts
                self._check_alerts(metrics)
                
                # Update performance history
                self._update_performance_history(metrics)
                
                # Wait for next collection
                time.sleep(30)  # Collect every 30 seconds
                
            except Exception as e:
                self.logger.error(f"Error in monitoring loop: {e}")
                time.sleep(60)  # Wait longer on error
    
    def _collect_system_metrics(self) -> SystemMetrics:
        """Collect current system metrics"""
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            
            # Memory metrics
            memory = psutil.virtual_memory()
            
            # Disk metrics
            disk = psutil.disk_usage('/')
            
            # Network metrics
            network = psutil.net_io_counters()
            
            # Load average
            load_avg = psutil.getloadavg()
            
            # Process count
            process_count = len(psutil.pids())
            
            # Uptime
            uptime = time.time() - psutil.boot_time()
            
            return SystemMetrics(
                timestamp=time.time(),
                cpu_percent=cpu_percent,
                memory_percent=memory.percent,
                memory_used=memory.used,
                memory_total=memory.total,
                disk_usage_percent=disk.percent,
                disk_used=disk.used,
                disk_total=disk.total,
                network_sent=network.bytes_sent,
                network_recv=network.bytes_recv,
                load_average=list(load_avg),
                process_count=process_count,
                uptime=uptime
            )
            
        except Exception as e:
            self.logger.error(f"Error collecting system metrics: {e}")
            return SystemMetrics(
                timestamp=time.time(),
                cpu_percent=0.0,
                memory_percent=0.0,
                memory_used=0,
                memory_total=0,
                disk_usage_percent=0.0,
                disk_used=0,
                disk_total=0,
                network_sent=0,
                network_recv=0,
                load_average=[0.0, 0.0, 0.0],
                process_count=0,
                uptime=0.0
            )
    
    def _store_metrics(self, metrics: SystemMetrics):
        """Store metrics in database"""
        try:
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO system_metrics (
                        timestamp, cpu_percent, memory_percent, memory_used, memory_total,
                        disk_usage_percent, disk_used, disk_total, network_sent, network_recv,
                        load_average, process_count, uptime
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    metrics.timestamp, metrics.cpu_percent, metrics.memory_percent,
                    metrics.memory_used, metrics.memory_total, metrics.disk_usage_percent,
                    metrics.disk_used, metrics.disk_total, metrics.network_sent,
                    metrics.network_recv, json.dumps(metrics.load_average),
                    metrics.process_count, metrics.uptime
                ))
                conn.commit()
                
        except Exception as e:
            self.logger.error(f"Error storing metrics: {e}")
    
    def _check_service_health(self):
        """Check health of all services"""
        services_to_check = {
            "grim_gateway": "http://localhost:8000/health",
            "grim_web": "http://localhost:8001/health",
            "grim_backup": "http://localhost:8002/health"
        }
        
        for service_name, health_url in services_to_check.items():
            try:
                import requests
                start_time = time.time()
                response = requests.get(health_url, timeout=5)
                response_time = (time.time() - start_time) * 1000  # Convert to ms
                
                if response.status_code == 200:
                    health_data = response.json()
                    self.service_health[service_name] = ServiceHealth(
                        service_name=service_name,
                        status="healthy",
                        response_time=response_time,
                        last_check=time.time(),
                        error_count=0,
                        uptime=health_data.get("uptime", 0.0),
                        version=health_data.get("version", "1.0.0"),
                        endpoints=health_data.get("endpoints", [])
                    )
                else:
                    self._update_service_error(service_name, f"HTTP {response.status_code}")
                    
            except Exception as e:
                self._update_service_error(service_name, str(e))
    
    def _update_service_error(self, service_name: str, error: str):
        """Update service error status"""
        if service_name in self.service_health:
            health = self.service_health[service_name]
            health.error_count += 1
            health.last_check = time.time()
            
            if health.error_count > 3:
                health.status = "unhealthy"
            elif health.error_count > 1:
                health.status = "degraded"
            
            self.logger.warning(f"Service {service_name} error: {error}")
    
    def _check_alerts(self, metrics: SystemMetrics):
        """Check for alert conditions"""
        # CPU alert
        if metrics.cpu_percent > self.thresholds['cpu_percent']:
            self._create_alert(
                level="warning",
                message=f"High CPU usage: {metrics.cpu_percent:.1f}%",
                service="system",
                metric="cpu_percent",
                value=metrics.cpu_percent,
                threshold=self.thresholds['cpu_percent']
            )
        
        # Memory alert
        if metrics.memory_percent > self.thresholds['memory_percent']:
            self._create_alert(
                level="warning",
                message=f"High memory usage: {metrics.memory_percent:.1f}%",
                service="system",
                metric="memory_percent",
                value=metrics.memory_percent,
                threshold=self.thresholds['memory_percent']
            )
        
        # Disk alert
        if metrics.disk_usage_percent > self.thresholds['disk_usage_percent']:
            self._create_alert(
                level="critical",
                message=f"High disk usage: {metrics.disk_usage_percent:.1f}%",
                service="system",
                metric="disk_usage_percent",
                value=metrics.disk_usage_percent,
                threshold=self.thresholds['disk_usage_percent']
            )
        
        # Service health alerts
        for service_name, health in self.service_health.items():
            if health.status == "unhealthy":
                self._create_alert(
                    level="critical",
                    message=f"Service {service_name} is unhealthy",
                    service=service_name,
                    metric="status",
                    value=0.0,
                    threshold=1.0
                )
            elif health.status == "degraded":
                self._create_alert(
                    level="warning",
                    message=f"Service {service_name} is degraded",
                    service=service_name,
                    metric="status",
                    value=0.5,
                    threshold=1.0
                )
    
    def _create_alert(self, level: str, message: str, service: str, metric: str, value: float, threshold: float):
        """Create a new alert"""
        alert_id = f"{service}_{metric}_{int(time.time())}"
        
        # Check if alert already exists
        existing_alert = next((a for a in self.alerts if a.service == service and a.metric == metric and not a.resolved), None)
        if existing_alert:
            return  # Alert already exists
        
        alert = Alert(
            id=alert_id,
            level=level,
            message=message,
            timestamp=time.time(),
            service=service,
            metric=metric,
            value=value,
            threshold=threshold
        )
        
        self.alerts.append(alert)
        self._store_alert(alert)
        
        # Trigger alert callbacks
        for callback in self.alert_callbacks:
            try:
                callback(alert)
            except Exception as e:
                self.logger.error(f"Error in alert callback: {e}")
        
        self.logger.warning(f"Alert created: {message}")
    
    def _store_alert(self, alert: Alert):
        """Store alert in database"""
        try:
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT OR REPLACE INTO alerts (
                        id, level, message, timestamp, service, metric, value, threshold, resolved
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    alert.id, alert.level, alert.message, alert.timestamp,
                    alert.service, alert.metric, alert.value, alert.threshold, 0
                ))
                conn.commit()
                
        except Exception as e:
            self.logger.error(f"Error storing alert: {e}")
    
    def _update_performance_history(self, metrics: SystemMetrics):
        """Update performance history"""
        self.performance_history['cpu'].append(metrics.cpu_percent)
        self.performance_history['memory'].append(metrics.memory_percent)
        self.performance_history['disk'].append(metrics.disk_usage_percent)
        self.performance_history['processes'].append(metrics.process_count)
    
    def get_current_metrics(self) -> Dict[str, Any]:
        """Get current system metrics"""
        if not self.system_metrics:
            return {}
        
        latest = self.system_metrics[-1]
        return asdict(latest)
    
    def get_service_health(self) -> Dict[str, ServiceHealth]:
        """Get current service health status"""
        return {name: asdict(health) for name, health in self.service_health.items()}
    
    def get_alerts(self, resolved: bool = False) -> List[Alert]:
        """Get alerts"""
        return [alert for alert in self.alerts if alert.resolved == resolved]
    
    def get_performance_summary(self) -> Dict[str, Any]:
        """Get performance summary"""
        summary = {}
        
        for metric_name, history in self.performance_history.items():
            if history:
                summary[metric_name] = {
                    'current': history[-1],
                    'average': sum(history) / len(history),
                    'min': min(history),
                    'max': max(history),
                    'trend': 'up' if len(history) > 1 and history[-1] > history[-2] else 'down'
                }
        
        return summary
    
    def get_metrics_history(self, hours: int = 24) -> List[Dict[str, Any]]:
        """Get metrics history for specified hours"""
        try:
            cutoff_time = time.time() - (hours * 3600)
            
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT * FROM system_metrics 
                    WHERE timestamp > ? 
                    ORDER BY timestamp DESC
                """, (cutoff_time,))
                
                rows = cursor.fetchall()
                columns = [description[0] for description in cursor.description]
                
                return [dict(zip(columns, row)) for row in rows]
                
        except Exception as e:
            self.logger.error(f"Error getting metrics history: {e}")
            return []
    
    def resolve_alert(self, alert_id: str):
        """Resolve an alert"""
        for alert in self.alerts:
            if alert.id == alert_id:
                alert.resolved = True
                self._update_alert_resolution(alert_id, True)
                break
    
    def _update_alert_resolution(self, alert_id: str, resolved: bool):
        """Update alert resolution status in database"""
        try:
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE alerts SET resolved = ? WHERE id = ?
                """, (1 if resolved else 0, alert_id))
                conn.commit()
                
        except Exception as e:
            self.logger.error(f"Error updating alert resolution: {e}")
    
    def add_alert_callback(self, callback: Callable[[Alert], None]):
        """Add alert callback function"""
        self.alert_callbacks.append(callback)
    
    def set_threshold(self, metric: str, value: float):
        """Set alert threshold for a metric"""
        if metric in self.thresholds:
            self.thresholds[metric] = value
            self.logger.info(f"Threshold updated for {metric}: {value}")
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.stop_monitoring()
        sys.exit(0)

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grim System Monitor")
    parser.add_argument("--config", help="Configuration file path")
    parser.add_argument("--daemon", action="store_true", help="Run as daemon")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    
    args = parser.parse_args()
    
    # Setup logging
    logging.basicConfig(level=getattr(logging, args.log_level.upper()))
    
    # Create monitor
    monitor = GrimMonitor()
    
    # Add alert callback for logging
    def alert_callback(alert: Alert):
        print(f"[{alert.level.upper()}] {alert.message}")
    
    monitor.add_alert_callback(alert_callback)
    
    try:
        # Start monitoring
        monitor.start_monitoring()
        
        if args.daemon:
            # Run as daemon
            while True:
                time.sleep(1)
        else:
            # Run interactive
            print("Grim Monitor started. Press Ctrl+C to stop.")
            while True:
                time.sleep(1)
                
    except KeyboardInterrupt:
        print("\nShutting down...")
    finally:
        monitor.stop_monitoring()

if __name__ == "__main__":
    main() 