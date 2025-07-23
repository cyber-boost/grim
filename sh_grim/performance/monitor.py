#!/usr/bin/env python3
"""
Grimm Performance Monitor Module
Real-time performance monitoring and metrics collection
"""

import os
import sys
import time
import psutil
import threading
import json
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional, Callable
from dataclasses import dataclass, asdict
from datetime import datetime
import queue
import signal
from collections import deque

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class SystemMetrics:
    """System performance metrics"""
    timestamp: datetime
    cpu_percent: float
    memory_percent: float
    memory_used: int
    memory_available: int
    disk_usage_percent: float
    disk_read_bytes: int
    disk_write_bytes: int
    network_bytes_sent: int
    network_bytes_recv: int
    load_average: List[float]

@dataclass
class ProcessMetrics:
    """Process-specific performance metrics"""
    timestamp: datetime
    process_id: int
    cpu_percent: float
    memory_percent: float
    memory_rss: int
    memory_vms: int
    num_threads: int
    num_fds: int
    io_read_bytes: int
    io_write_bytes: int

@dataclass
class PerformanceAlert:
    """Performance alert data structure"""
    timestamp: datetime
    alert_type: str
    severity: str
    message: str
    metrics: Dict[str, Any]
    threshold: float
    current_value: float

class PerformanceMonitor:
    """Real-time performance monitoring system"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.monitoring_active = False
        self.monitoring_thread = None
        self.metrics_queue = queue.Queue()
        self.alerts_queue = queue.Queue()
        
        # Metrics storage
        self.system_metrics: deque = deque(maxlen=1000)  # Keep last 1000 measurements
        self.process_metrics: Dict[int, deque] = {}
        self.alerts: List[PerformanceAlert] = []
        
        # Monitoring intervals
        self.system_interval = self.config.get('system_interval', 1.0)  # seconds
        self.process_interval = self.config.get('process_interval', 5.0)  # seconds
        self.alert_interval = self.config.get('alert_interval', 10.0)  # seconds
        
        # Alert thresholds
        self.thresholds = self.config.get('thresholds', {
            'cpu_percent': 80.0,
            'memory_percent': 85.0,
            'disk_usage_percent': 90.0,
            'load_average': 5.0
        })
        
        # Callbacks
        self.alert_callbacks: List[Callable] = []
        self.metrics_callbacks: List[Callable] = []
        
        # Signal handling
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        logger.info("Performance monitor initialized")
    
    def start_monitoring(self):
        """Start performance monitoring"""
        if self.monitoring_active:
            logger.warning("Monitoring already active")
            return
        
        self.monitoring_active = True
        
        # Start monitoring threads
        self.monitoring_thread = threading.Thread(target=self._monitoring_loop, daemon=True)
        self.monitoring_thread.start()
        
        # Start alert processing thread
        self.alert_thread = threading.Thread(target=self._alert_processing_loop, daemon=True)
        self.alert_thread.start()
        
        logger.info("Performance monitoring started")
    
    def stop_monitoring(self):
        """Stop performance monitoring"""
        if not self.monitoring_active:
            return
        
        self.monitoring_active = False
        
        if self.monitoring_thread:
            self.monitoring_thread.join(timeout=5)
        
        if self.alert_thread:
            self.alert_thread.join(timeout=5)
        
        logger.info("Performance monitoring stopped")
    
    def add_process_monitoring(self, process_id: int, name: str = None):
        """Add a process to monitoring"""
        if process_id not in self.process_metrics:
            self.process_metrics[process_id] = deque(maxlen=1000)
            logger.info(f"Added process {process_id} ({name}) to monitoring")
    
    def remove_process_monitoring(self, process_id: int):
        """Remove a process from monitoring"""
        if process_id in self.process_metrics:
            del self.process_metrics[process_id]
            logger.info(f"Removed process {process_id} from monitoring")
    
    def add_alert_callback(self, callback: Callable):
        """Add alert callback function"""
        self.alert_callbacks.append(callback)
    
    def add_metrics_callback(self, callback: Callable):
        """Add metrics callback function"""
        self.metrics_callbacks.append(callback)
    
    def _monitoring_loop(self):
        """Main monitoring loop"""
        last_system_check = 0
        last_process_check = 0
        last_alert_check = 0
        
        while self.monitoring_active:
            current_time = time.time()
            
            # System metrics monitoring
            if current_time - last_system_check >= self.system_interval:
                self._collect_system_metrics()
                last_system_check = current_time
            
            # Process metrics monitoring
            if current_time - last_process_check >= self.process_interval:
                self._collect_process_metrics()
                last_process_check = current_time
            
            # Alert checking
            if current_time - last_alert_check >= self.alert_interval:
                self._check_alerts()
                last_alert_check = current_time
            
            # Small sleep to prevent excessive CPU usage
            time.sleep(0.1)
    
    def _alert_processing_loop(self):
        """Alert processing loop"""
        while self.monitoring_active:
            try:
                alert = self.alerts_queue.get(timeout=1)
                self._process_alert(alert)
            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"Error processing alert: {e}")
    
    def _collect_system_metrics(self):
        """Collect system-wide performance metrics"""
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=0.1)
            
            # Memory metrics
            memory = psutil.virtual_memory()
            
            # Disk metrics
            disk = psutil.disk_usage('/')
            disk_io = psutil.disk_io_counters()
            
            # Network metrics
            network = psutil.net_io_counters()
            
            # Load average
            load_avg = list(os.getloadavg()) if hasattr(os, 'getloadavg') else [0, 0, 0]
            
            metrics = SystemMetrics(
                timestamp=datetime.now(),
                cpu_percent=cpu_percent,
                memory_percent=memory.percent,
                memory_used=memory.used,
                memory_available=memory.available,
                disk_usage_percent=disk.percent,
                disk_read_bytes=disk_io.read_bytes if disk_io else 0,
                disk_write_bytes=disk_io.write_bytes if disk_io else 0,
                network_bytes_sent=network.bytes_sent,
                network_bytes_recv=network.bytes_recv,
                load_average=load_avg
            )
            
            self.system_metrics.append(metrics)
            
            # Notify callbacks
            for callback in self.metrics_callbacks:
                try:
                    callback('system', metrics)
                except Exception as e:
                    logger.error(f"Error in metrics callback: {e}")
            
            # Add to queue for processing
            self.metrics_queue.put(('system', metrics))
            
        except Exception as e:
            logger.error(f"Error collecting system metrics: {e}")
    
    def _collect_process_metrics(self):
        """Collect process-specific performance metrics"""
        for process_id in list(self.process_metrics.keys()):
            try:
                process = psutil.Process(process_id)
                
                # Check if process still exists
                if not process.is_running():
                    self.remove_process_monitoring(process_id)
                    continue
                
                # Collect process metrics
                with process.oneshot():
                    cpu_percent = process.cpu_percent()
                    memory_info = process.memory_info()
                    memory_percent = process.memory_percent()
                    num_threads = process.num_threads()
                    num_fds = process.num_fds() if hasattr(process, 'num_fds') else 0
                    io_counters = process.io_counters()
                
                metrics = ProcessMetrics(
                    timestamp=datetime.now(),
                    process_id=process_id,
                    cpu_percent=cpu_percent,
                    memory_percent=memory_percent,
                    memory_rss=memory_info.rss,
                    memory_vms=memory_info.vms,
                    num_threads=num_threads,
                    num_fds=num_fds,
                    io_read_bytes=io_counters.read_bytes if io_counters else 0,
                    io_write_bytes=io_counters.write_bytes if io_counters else 0
                )
                
                self.process_metrics[process_id].append(metrics)
                
                # Notify callbacks
                for callback in self.metrics_callbacks:
                    try:
                        callback('process', metrics)
                    except Exception as e:
                        logger.error(f"Error in metrics callback: {e}")
                
                # Add to queue for processing
                self.metrics_queue.put(('process', metrics))
                
            except psutil.NoSuchProcess:
                self.remove_process_monitoring(process_id)
            except Exception as e:
                logger.error(f"Error collecting metrics for process {process_id}: {e}")
    
    def _check_alerts(self):
        """Check for performance alerts"""
        if not self.system_metrics:
            return
        
        latest_metrics = self.system_metrics[-1]
        
        # CPU usage alert
        if latest_metrics.cpu_percent > self.thresholds['cpu_percent']:
            alert = PerformanceAlert(
                timestamp=datetime.now(),
                alert_type="high_cpu_usage",
                severity="warning" if latest_metrics.cpu_percent < 95 else "critical",
                message=f"High CPU usage: {latest_metrics.cpu_percent:.1f}%",
                metrics=asdict(latest_metrics),
                threshold=self.thresholds['cpu_percent'],
                current_value=latest_metrics.cpu_percent
            )
            self.alerts_queue.put(alert)
        
        # Memory usage alert
        if latest_metrics.memory_percent > self.thresholds['memory_percent']:
            alert = PerformanceAlert(
                timestamp=datetime.now(),
                alert_type="high_memory_usage",
                severity="warning" if latest_metrics.memory_percent < 95 else "critical",
                message=f"High memory usage: {latest_metrics.memory_percent:.1f}%",
                metrics=asdict(latest_metrics),
                threshold=self.thresholds['memory_percent'],
                current_value=latest_metrics.memory_percent
            )
            self.alerts_queue.put(alert)
        
        # Disk usage alert
        if latest_metrics.disk_usage_percent > self.thresholds['disk_usage_percent']:
            alert = PerformanceAlert(
                timestamp=datetime.now(),
                alert_type="high_disk_usage",
                severity="warning" if latest_metrics.disk_usage_percent < 95 else "critical",
                message=f"High disk usage: {latest_metrics.disk_usage_percent:.1f}%",
                metrics=asdict(latest_metrics),
                threshold=self.thresholds['disk_usage_percent'],
                current_value=latest_metrics.disk_usage_percent
            )
            self.alerts_queue.put(alert)
        
        # Load average alert
        if latest_metrics.load_average and latest_metrics.load_average[0] > self.thresholds['load_average']:
            alert = PerformanceAlert(
                timestamp=datetime.now(),
                alert_type="high_load_average",
                severity="warning" if latest_metrics.load_average[0] < 10 else "critical",
                message=f"High load average: {latest_metrics.load_average[0]:.2f}",
                metrics=asdict(latest_metrics),
                threshold=self.thresholds['load_average'],
                current_value=latest_metrics.load_average[0]
            )
            self.alerts_queue.put(alert)
    
    def _process_alert(self, alert: PerformanceAlert):
        """Process a performance alert"""
        self.alerts.append(alert)
        
        # Log alert
        logger.warning(f"Performance Alert [{alert.severity.upper()}]: {alert.message}")
        
        # Notify callbacks
        for callback in self.alert_callbacks:
            try:
                callback(alert)
            except Exception as e:
                logger.error(f"Error in alert callback: {e}")
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logger.info(f"Received signal {signum}, shutting down monitor")
        self.stop_monitoring()
    
    def get_current_metrics(self) -> Dict[str, Any]:
        """Get current performance metrics"""
        if not self.system_metrics:
            return {}
        
        latest_system = self.system_metrics[-1]
        
        current_metrics = {
            "system": asdict(latest_system),
            "processes": {}
        }
        
        for process_id, metrics_deque in self.process_metrics.items():
            if metrics_deque:
                current_metrics["processes"][process_id] = asdict(metrics_deque[-1])
        
        return current_metrics
    
    def get_metrics_history(self, duration_minutes: int = 60) -> Dict[str, Any]:
        """Get metrics history for the specified duration"""
        cutoff_time = datetime.now().timestamp() - (duration_minutes * 60)
        
        # Filter system metrics
        system_history = [
            asdict(metrics) for metrics in self.system_metrics
            if metrics.timestamp.timestamp() > cutoff_time
        ]
        
        # Filter process metrics
        process_history = {}
        for process_id, metrics_deque in self.process_metrics.items():
            process_history[process_id] = [
                asdict(metrics) for metrics in metrics_deque
                if metrics.timestamp.timestamp() > cutoff_time
            ]
        
        return {
            "system": system_history,
            "processes": process_history,
            "duration_minutes": duration_minutes
        }
    
    def get_alerts(self, severity: str = None) -> List[Dict[str, Any]]:
        """Get performance alerts, optionally filtered by severity"""
        alerts = self.alerts
        
        if severity:
            alerts = [alert for alert in alerts if alert.severity == severity]
        
        return [asdict(alert) for alert in alerts]
    
    def clear_alerts(self):
        """Clear all alerts"""
        self.alerts.clear()
        logger.info("All alerts cleared")
    
    def generate_report(self, output_file: str = None) -> str:
        """Generate performance monitoring report"""
        if output_file is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"performance_monitor_report_{timestamp}.json"
        
        report = {
            "current_metrics": self.get_current_metrics(),
            "metrics_history": self.get_metrics_history(60),  # Last hour
            "alerts": self.get_alerts(),
            "configuration": {
                "system_interval": self.system_interval,
                "process_interval": self.process_interval,
                "alert_interval": self.alert_interval,
                "thresholds": self.thresholds
            },
            "timestamp": datetime.now().isoformat()
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Performance monitor report generated: {output_file}")
        return output_file

def main():
    """Main entry point for performance monitoring"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grimm Performance Monitor")
    parser.add_argument("--config", help="Configuration file path")
    parser.add_argument("--duration", type=int, default=300, help="Monitoring duration in seconds")
    parser.add_argument("--output-file", help="Output file for monitoring report")
    
    args = parser.parse_args()
    
    # Load configuration
    config = {}
    if args.config and os.path.exists(args.config):
        with open(args.config, 'r') as f:
            config = json.load(f)
    
    # Initialize monitor
    monitor = PerformanceMonitor(config)
    
    # Add current process to monitoring
    monitor.add_process_monitoring(os.getpid(), "grimm_monitor")
    
    # Start monitoring
    monitor.start_monitoring()
    
    try:
        # Monitor for specified duration
        time.sleep(args.duration)
    except KeyboardInterrupt:
        print("\nMonitoring interrupted by user")
    finally:
        # Stop monitoring
        monitor.stop_monitoring()
        
        # Generate report
        report_file = monitor.generate_report(args.output_file)
        print(f"Performance monitoring report generated: {report_file}")

if __name__ == "__main__":
    main() 