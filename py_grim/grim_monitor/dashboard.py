#!/usr/bin/env python3
"""
Grim Monitoring Dashboard

Web-based dashboard for real-time system monitoring and metrics visualization.
Provides interactive charts, alerts, and service health status.
"""

import asyncio
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from pathlib import Path
import threading

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
import uvicorn

# Add the project root to the path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from grim_core.config import Config
from grim_core.logger import Logger
from grim_monitor.monitor import GrimMonitor

class DashboardManager:
    """Manages WebSocket connections for real-time updates"""
    
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.logger = Logger("dashboard_manager")
    
    async def connect(self, websocket: WebSocket):
        """Connect a new WebSocket client"""
        await websocket.accept()
        self.active_connections.append(websocket)
        self.logger.info(f"New dashboard connection. Total: {len(self.active_connections)}")
    
    def disconnect(self, websocket: WebSocket):
        """Disconnect a WebSocket client"""
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        self.logger.info(f"Dashboard connection closed. Total: {len(self.active_connections)}")
    
    async def broadcast(self, message: Dict[str, Any]):
        """Broadcast message to all connected clients"""
        if not self.active_connections:
            return
        
        # Convert to JSON string
        message_str = json.dumps(message)
        
        # Send to all connections
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_text(message_str)
            except Exception as e:
                self.logger.error(f"Error sending to WebSocket: {e}")
                disconnected.append(connection)
        
        # Remove disconnected connections
        for connection in disconnected:
            self.disconnect(connection)

class GrimDashboard:
    """Main dashboard application"""
    
    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config()
        self.logger = Logger("grim_dashboard")
        self.monitor = GrimMonitor(self.config)
        self.dashboard_manager = DashboardManager()
        
        # Create FastAPI app
        self.app = FastAPI(
            title="Grim Monitoring Dashboard",
            description="Real-time system monitoring and metrics visualization",
            version="1.0.0"
        )
        
        # Setup routes
        self._setup_routes()
        
        # Start monitoring in background
        self.monitor.start_monitoring()
        
        # Start metrics broadcasting
        self._start_metrics_broadcast()
        
        self.logger.info("Grim Dashboard initialized")
    
    def _setup_routes(self):
        """Setup FastAPI routes"""
        
        @self.app.get("/", response_class=HTMLResponse)
        async def dashboard_home():
            """Main dashboard page"""
            return self._get_dashboard_html()
        
        @self.app.get("/api/metrics")
        async def get_current_metrics():
            """Get current system metrics"""
            return {
                "metrics": self.monitor.get_current_metrics(),
                "health": self.monitor.get_service_health(),
                "performance": self.monitor.get_performance_summary(),
                "timestamp": time.time()
            }
        
        @self.app.get("/api/metrics/history")
        async def get_metrics_history(hours: int = 24):
            """Get metrics history"""
            return {
                "history": self.monitor.get_metrics_history(hours),
                "hours": hours
            }
        
        @self.app.get("/api/alerts")
        async def get_alerts(resolved: bool = False):
            """Get alerts"""
            alerts = self.monitor.get_alerts(resolved)
            return {
                "alerts": [alert.__dict__ for alert in alerts],
                "count": len(alerts)
            }
        
        @self.app.post("/api/alerts/{alert_id}/resolve")
        async def resolve_alert(alert_id: str):
            """Resolve an alert"""
            self.monitor.resolve_alert(alert_id)
            return {"status": "resolved", "alert_id": alert_id}
        
        @self.app.get("/api/health")
        async def health_check():
            """Health check endpoint"""
            return {
                "status": "healthy",
                "timestamp": time.time(),
                "uptime": time.time() - self.monitor.start_time if hasattr(self.monitor, 'start_time') else 0
            }
        
        @self.app.websocket("/ws")
        async def websocket_endpoint(websocket: WebSocket):
            """WebSocket endpoint for real-time updates"""
            await self.dashboard_manager.connect(websocket)
            try:
                while True:
                    # Keep connection alive
                    await websocket.receive_text()
            except WebSocketDisconnect:
                self.dashboard_manager.disconnect(websocket)
    
    def _get_dashboard_html(self) -> str:
        """Get the dashboard HTML"""
        return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Grim Monitoring Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns/dist/chartjs-adapter-date-fns.bundle.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            color: #2c3e50;
            font-size: 2.5em;
            margin-bottom: 10px;
            text-align: center;
        }
        
        .header p {
            color: #7f8c8d;
            text-align: center;
            font-size: 1.1em;
        }
        
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-healthy { background-color: #27ae60; }
        .status-degraded { background-color: #f39c12; }
        .status-unhealthy { background-color: #e74c3c; }
        .status-unknown { background-color: #95a5a6; }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
            margin-bottom: 30px;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
        }
        
        .card h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 1.5em;
            display: flex;
            align-items: center;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 0;
            border-bottom: 1px solid #ecf0f1;
        }
        
        .metric:last-child {
            border-bottom: none;
        }
        
        .metric-label {
            font-weight: 500;
            color: #34495e;
        }
        
        .metric-value {
            font-weight: bold;
            color: #2c3e50;
        }
        
        .metric-unit {
            color: #7f8c8d;
            font-size: 0.9em;
            margin-left: 5px;
        }
        
        .chart-container {
            position: relative;
            height: 300px;
            margin-top: 20px;
        }
        
        .alerts-container {
            max-height: 400px;
            overflow-y: auto;
        }
        
        .alert {
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 10px;
            border-left: 4px solid;
        }
        
        .alert-info {
            background-color: #d1ecf1;
            border-left-color: #17a2b8;
        }
        
        .alert-warning {
            background-color: #fff3cd;
            border-left-color: #ffc107;
        }
        
        .alert-critical {
            background-color: #f8d7da;
            border-left-color: #dc3545;
        }
        
        .alert-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 5px;
        }
        
        .alert-level {
            font-weight: bold;
            text-transform: uppercase;
            font-size: 0.9em;
        }
        
        .alert-time {
            color: #6c757d;
            font-size: 0.8em;
        }
        
        .alert-message {
            color: #495057;
        }
        
        .service-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        
        .service-item {
            padding: 15px;
            border-radius: 10px;
            background: #f8f9fa;
            border: 1px solid #dee2e6;
        }
        
        .service-name {
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .service-status {
            display: flex;
            align-items: center;
            margin-bottom: 5px;
        }
        
        .service-metrics {
            font-size: 0.9em;
            color: #6c757d;
        }
        
        .refresh-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 10px;
            cursor: pointer;
            font-weight: bold;
            transition: transform 0.2s ease;
        }
        
        .refresh-button:hover {
            transform: scale(1.05);
        }
        
        .loading {
            text-align: center;
            padding: 20px;
            color: #7f8c8d;
        }
        
        @media (max-width: 768px) {
            .grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2em;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ Grim Monitoring Dashboard</h1>
            <p>Real-time system monitoring and performance metrics</p>
            <button class="refresh-button" onclick="refreshData()">🔄 Refresh</button>
        </div>
        
        <div class="grid">
            <!-- System Metrics -->
            <div class="card">
                <h2>📊 System Metrics</h2>
                <div id="system-metrics">
                    <div class="loading">Loading metrics...</div>
                </div>
            </div>
            
            <!-- Service Health -->
            <div class="card">
                <h2>🔧 Service Health</h2>
                <div id="service-health">
                    <div class="loading">Loading service status...</div>
                </div>
            </div>
            
            <!-- Performance Summary -->
            <div class="card">
                <h2>⚡ Performance Summary</h2>
                <div id="performance-summary">
                    <div class="loading">Loading performance data...</div>
                </div>
            </div>
            
            <!-- Alerts -->
            <div class="card">
                <h2>🚨 Active Alerts</h2>
                <div id="alerts">
                    <div class="loading">Loading alerts...</div>
                </div>
            </div>
        </div>
        
        <!-- Charts -->
        <div class="grid">
            <div class="card">
                <h2>📈 CPU Usage</h2>
                <div class="chart-container">
                    <canvas id="cpuChart"></canvas>
                </div>
            </div>
            
            <div class="card">
                <h2>💾 Memory Usage</h2>
                <div class="chart-container">
                    <canvas id="memoryChart"></canvas>
                </div>
            </div>
            
            <div class="card">
                <h2>💿 Disk Usage</h2>
                <div class="chart-container">
                    <canvas id="diskChart"></canvas>
                </div>
            </div>
            
            <div class="card">
                <h2>🌐 Network Activity</h2>
                <div class="chart-container">
                    <canvas id="networkChart"></canvas>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Global variables
        let ws = null;
        let charts = {};
        let lastUpdate = 0;
        
        // Initialize WebSocket connection
        function initWebSocket() {
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            const wsUrl = `${protocol}//${window.location.host}/ws`;
            
            ws = new WebSocket(wsUrl);
            
            ws.onopen = function() {
                console.log('WebSocket connected');
            };
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                updateDashboard(data);
            };
            
            ws.onclose = function() {
                console.log('WebSocket disconnected, reconnecting...');
                setTimeout(initWebSocket, 5000);
            };
            
            ws.onerror = function(error) {
                console.error('WebSocket error:', error);
            };
        }
        
        // Initialize charts
        function initCharts() {
            const chartOptions = {
                responsive: true,
                maintainAspectRatio: false,
                animation: {
                    duration: 750,
                    easing: 'easeInOutQuart'
                },
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'minute'
                        }
                    },
                    y: {
                        beginAtZero: true
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    }
                }
            };
            
            // CPU Chart
            charts.cpu = new Chart(document.getElementById('cpuChart'), {
                type: 'line',
                data: {
                    datasets: [{
                        label: 'CPU %',
                        data: [],
                        borderColor: '#667eea',
                        backgroundColor: 'rgba(102, 126, 234, 0.1)',
                        tension: 0.4
                    }]
                },
                options: chartOptions
            });
            
            // Memory Chart
            charts.memory = new Chart(document.getElementById('memoryChart'), {
                type: 'line',
                data: {
                    datasets: [{
                        label: 'Memory %',
                        data: [],
                        borderColor: '#764ba2',
                        backgroundColor: 'rgba(118, 75, 162, 0.1)',
                        tension: 0.4
                    }]
                },
                options: chartOptions
            });
            
            // Disk Chart
            charts.disk = new Chart(document.getElementById('diskChart'), {
                type: 'line',
                data: {
                    datasets: [{
                        label: 'Disk %',
                        data: [],
                        borderColor: '#f093fb',
                        backgroundColor: 'rgba(240, 147, 251, 0.1)',
                        tension: 0.4
                    }]
                },
                options: chartOptions
            });
            
            // Network Chart
            charts.network = new Chart(document.getElementById('networkChart'), {
                type: 'line',
                data: {
                    datasets: [{
                        label: 'Sent (MB)',
                        data: [],
                        borderColor: '#4facfe',
                        backgroundColor: 'rgba(79, 172, 254, 0.1)',
                        tension: 0.4
                    }, {
                        label: 'Received (MB)',
                        data: [],
                        borderColor: '#00f2fe',
                        backgroundColor: 'rgba(0, 242, 254, 0.1)',
                        tension: 0.4
                    }]
                },
                options: {
                    ...chartOptions,
                    plugins: {
                        legend: {
                            display: true
                        }
                    }
                }
            });
        }
        
        // Update dashboard with new data
        function updateDashboard(data) {
            if (data.timestamp <= lastUpdate) return;
            lastUpdate = data.timestamp;
            
            // Update system metrics
            if (data.metrics) {
                updateSystemMetrics(data.metrics);
                updateCharts(data.metrics);
            }
            
            // Update service health
            if (data.health) {
                updateServiceHealth(data.health);
            }
            
            // Update performance summary
            if (data.performance) {
                updatePerformanceSummary(data.performance);
            }
        }
        
        // Update system metrics display
        function updateSystemMetrics(metrics) {
            const container = document.getElementById('system-metrics');
            
            container.innerHTML = `
                <div class="metric">
                    <span class="metric-label">CPU Usage</span>
                    <span class="metric-value">${metrics.cpu_percent?.toFixed(1) || 'N/A'}<span class="metric-unit">%</span></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Memory Usage</span>
                    <span class="metric-value">${metrics.memory_percent?.toFixed(1) || 'N/A'}<span class="metric-unit">%</span></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Memory Used</span>
                    <span class="metric-value">${formatBytes(metrics.memory_used)}<span class="metric-unit">/ ${formatBytes(metrics.memory_total)}</span></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Disk Usage</span>
                    <span class="metric-value">${metrics.disk_usage_percent?.toFixed(1) || 'N/A'}<span class="metric-unit">%</span></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Disk Used</span>
                    <span class="metric-value">${formatBytes(metrics.disk_used)}<span class="metric-unit">/ ${formatBytes(metrics.disk_total)}</span></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Network Sent</span>
                    <span class="metric-value">${formatBytes(metrics.network_sent)}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Network Received</span>
                    <span class="metric-value">${formatBytes(metrics.network_recv)}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Process Count</span>
                    <span class="metric-value">${metrics.process_count || 'N/A'}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Uptime</span>
                    <span class="metric-value">${formatUptime(metrics.uptime)}</span>
                </div>
            `;
        }
        
        // Update service health display
        function updateServiceHealth(health) {
            const container = document.getElementById('service-health');
            
            let html = '<div class="service-grid">';
            
            for (const [serviceName, service] of Object.entries(health)) {
                const statusClass = `status-${service.status}`;
                const statusText = service.status.charAt(0).toUpperCase() + service.status.slice(1);
                
                html += `
                    <div class="service-item">
                        <div class="service-name">${serviceName}</div>
                        <div class="service-status">
                            <span class="status-indicator ${statusClass}"></span>
                            <span>${statusText}</span>
                        </div>
                        <div class="service-metrics">
                            Response: ${service.response_time?.toFixed(1) || 'N/A'}ms<br>
                            Uptime: ${formatUptime(service.uptime)}<br>
                            Version: ${service.version || 'N/A'}
                        </div>
                    </div>
                `;
            }
            
            html += '</div>';
            container.innerHTML = html;
        }
        
        // Update performance summary display
        function updatePerformanceSummary(performance) {
            const container = document.getElementById('performance-summary');
            
            let html = '';
            
            for (const [metricName, data] of Object.entries(performance)) {
                const trendIcon = data.trend === 'up' ? '📈' : '📉';
                
                html += `
                    <div class="metric">
                        <span class="metric-label">${metricName.charAt(0).toUpperCase() + metricName.slice(1)} ${trendIcon}</span>
                        <span class="metric-value">${data.current?.toFixed(1) || 'N/A'}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Average</span>
                        <span class="metric-value">${data.average?.toFixed(1) || 'N/A'}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Min/Max</span>
                        <span class="metric-value">${data.min?.toFixed(1) || 'N/A'} / ${data.max?.toFixed(1) || 'N/A'}</span>
                    </div>
                `;
            }
            
            container.innerHTML = html;
        }
        
        // Update charts with new data
        function updateCharts(metrics) {
            const timestamp = new Date(metrics.timestamp * 1000);
            
            // Update CPU chart
            if (charts.cpu && metrics.cpu_percent !== undefined) {
                charts.cpu.data.datasets[0].data.push({
                    x: timestamp,
                    y: metrics.cpu_percent
                });
                
                // Keep only last 50 points
                if (charts.cpu.data.datasets[0].data.length > 50) {
                    charts.cpu.data.datasets[0].data.shift();
                }
                
                charts.cpu.update('none');
            }
            
            // Update Memory chart
            if (charts.memory && metrics.memory_percent !== undefined) {
                charts.memory.data.datasets[0].data.push({
                    x: timestamp,
                    y: metrics.memory_percent
                });
                
                if (charts.memory.data.datasets[0].data.length > 50) {
                    charts.memory.data.datasets[0].data.shift();
                }
                
                charts.memory.update('none');
            }
            
            // Update Disk chart
            if (charts.disk && metrics.disk_usage_percent !== undefined) {
                charts.disk.data.datasets[0].data.push({
                    x: timestamp,
                    y: metrics.disk_usage_percent
                });
                
                if (charts.disk.data.datasets[0].data.length > 50) {
                    charts.disk.data.datasets[0].data.shift();
                }
                
                charts.disk.update('none');
            }
            
            // Update Network chart
            if (charts.network && metrics.network_sent !== undefined && metrics.network_recv !== undefined) {
                const sentMB = metrics.network_sent / (1024 * 1024);
                const recvMB = metrics.network_recv / (1024 * 1024);
                
                charts.network.data.datasets[0].data.push({
                    x: timestamp,
                    y: sentMB
                });
                
                charts.network.data.datasets[1].data.push({
                    x: timestamp,
                    y: recvMB
                });
                
                if (charts.network.data.datasets[0].data.length > 50) {
                    charts.network.data.datasets[0].data.shift();
                    charts.network.data.datasets[1].data.shift();
                }
                
                charts.network.update('none');
            }
        }
        
        // Load alerts
        async function loadAlerts() {
            try {
                const response = await fetch('/api/alerts?resolved=false');
                const data = await response.json();
                
                const container = document.getElementById('alerts');
                
                if (data.alerts.length === 0) {
                    container.innerHTML = '<div class="alert alert-info">No active alerts</div>';
                    return;
                }
                
                let html = '<div class="alerts-container">';
                
                for (const alert of data.alerts) {
                    const alertClass = `alert-${alert.level}`;
                    const time = new Date(alert.timestamp * 1000).toLocaleString();
                    
                    html += `
                        <div class="alert ${alertClass}">
                            <div class="alert-header">
                                <span class="alert-level">${alert.level}</span>
                                <span class="alert-time">${time}</span>
                            </div>
                            <div class="alert-message">${alert.message}</div>
                        </div>
                    `;
                }
                
                html += '</div>';
                container.innerHTML = html;
                
            } catch (error) {
                console.error('Error loading alerts:', error);
            }
        }
        
        // Refresh all data
        async function refreshData() {
            try {
                const response = await fetch('/api/metrics');
                const data = await response.json();
                updateDashboard(data);
                await loadAlerts();
            } catch (error) {
                console.error('Error refreshing data:', error);
            }
        }
        
        // Utility functions
        function formatBytes(bytes) {
            if (!bytes || bytes === 0) return '0 B';
            
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        
        function formatUptime(seconds) {
            if (!seconds || seconds === 0) return 'N/A';
            
            const days = Math.floor(seconds / 86400);
            const hours = Math.floor((seconds % 86400) / 3600);
            const minutes = Math.floor((seconds % 3600) / 60);
            
            if (days > 0) {
                return `${days}d ${hours}h ${minutes}m`;
            } else if (hours > 0) {
                return `${hours}h ${minutes}m`;
            } else {
                return `${minutes}m`;
            }
        }
        
        // Initialize dashboard
        document.addEventListener('DOMContentLoaded', function() {
            initCharts();
            initWebSocket();
            refreshData();
            
            // Refresh data every 30 seconds
            setInterval(refreshData, 30000);
        });
    </script>
</body>
</html>
        """
    
    def _start_metrics_broadcast(self):
        """Start broadcasting metrics to WebSocket clients"""
        def broadcast_loop():
            while True:
                try:
                    # Get current data
                    data = {
                        "metrics": self.monitor.get_current_metrics(),
                        "health": self.monitor.get_service_health(),
                        "performance": self.monitor.get_performance_summary(),
                        "timestamp": time.time()
                    }
                    
                    # Broadcast to all connected clients
                    asyncio.run(self.dashboard_manager.broadcast(data))
                    
                    # Wait 5 seconds before next broadcast
                    time.sleep(5)
                    
                except Exception as e:
                    self.logger.error(f"Error in metrics broadcast: {e}")
                    time.sleep(10)
        
        # Start broadcast thread
        broadcast_thread = threading.Thread(target=broadcast_loop, daemon=True)
        broadcast_thread.start()
    
    def run(self, host: str = "0.0.0.0", port: int = 8003):
        """Run the dashboard server"""
        self.logger.info(f"Starting Grim Dashboard on {host}:{port}")
        
        uvicorn.run(
            self.app,
            host=host,
            port=port,
            log_level="info"
        )

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grim Monitoring Dashboard")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8003, help="Port to bind to")
    parser.add_argument("--config", help="Configuration file path")
    
    args = parser.parse_args()
    
    # Create and run dashboard
    dashboard = GrimDashboard()
    dashboard.run(host=args.host, port=args.port)

if __name__ == "__main__":
    main() 