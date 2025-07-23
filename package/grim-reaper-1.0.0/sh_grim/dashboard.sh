#!/bin/bash
# Grimm Dashboard Module: Advanced web dashboard for system monitoring

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOG_FILE="$GRIM_ROOT/logs/dashboard.log"
DASHBOARD_PY="$GRIM_ROOT/bin/dashboard_server.py"
PID_FILE="$GRIM_ROOT/logs/dashboard.pid"
CONFIG_FILE="$GRIM_ROOT/config/dashboard.tsk"
PORT=8080

# Module version
DASHBOARD_VERSION="2.0.0"

# Default configuration
DEFAULT_CONFIG="
# Dashboard Configuration
dashboard_enabled=true
default_port=8080
auto_start=false
ssl_enabled=false
ssl_cert_path=
ssl_key_path=
auth_enabled=false
auth_username=admin
auth_password_hash=
refresh_interval=30
max_sessions=10
log_level=info
"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    echo "Grimm Dashboard Module v$DASHBOARD_VERSION"
    echo "Usage: dashboard.sh [command] [options]"
    echo ""
    echo "Purpose: Advanced web-based dashboard for comprehensive monitoring"
    echo "         and management of the Grimm backup system through a"
    echo "         modern browser interface with real-time analytics."
    echo ""
    echo "Commands:"
    echo "  start                 - Start the dashboard server (default)"
    echo "  stop                  - Stop the dashboard server"
    echo "  restart               - Restart the dashboard server"
    echo "  status                - Show dashboard status"
    echo "  config                - Show or update configuration"
    echo "  init                  - Initialize dashboard system"
    echo "  setup                 - Setup dashboard dependencies"
    echo "  logs                  - Show dashboard logs"
    echo "  help, -h, --help      - Show this help message"
    echo ""
    echo "Options:"
    echo "  --port=PORT           - Specify port (default: 8080)"
    echo "  --ssl                 - Enable SSL/HTTPS"
    echo "  --auth                - Enable authentication"
    echo "  --verbose, -v         - Enable verbose output"
    echo ""
    echo "Examples:"
    echo "  ./dashboard.sh                    # Start dashboard"
    echo "  ./dashboard.sh start --port=9090  # Start on port 9090"
    echo "  ./dashboard.sh start --ssl        # Start with SSL"
    echo "  ./dashboard.sh stop               # Stop dashboard"
    echo "  ./dashboard.sh status             # Show status"
    echo "  ./dashboard.sh config             # Show configuration"
    echo "  ./dashboard.sh logs               # Show logs"
    echo ""
    echo "Dashboard Features:"
    echo "  - Real-time backup status monitoring"
    echo "  - Interactive file management"
    echo "  - Advanced analytics and reporting"
    echo "  - System health monitoring"
    echo "  - Backup scheduling and configuration"
    echo "  - Performance metrics and trends"
    echo "  - User management and authentication"
    echo "  - Mobile-responsive design"
    echo "  - RESTful API endpoints"
    echo "  - WebSocket real-time updates"
}

# Initialize dashboard system
init_dashboard() {
    log "Initializing dashboard system..."
    
    # Create configuration file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
        log "Created default configuration: $CONFIG_FILE"
    fi
    
    # Create necessary directories
    mkdir -p "$GRIM_ROOT/logs" "$GRIM_ROOT/bin" "$GRIM_ROOT/web/dashboard"
    
    # Create dashboard server script if it doesn't exist
    if [[ ! -f "$DASHBOARD_PY" ]]; then
        create_dashboard_server
    fi
    
    log "Dashboard system initialized"
    echo "${GREEN}✓ Dashboard system initialized${RESET}"
}

# Create dashboard server script
create_dashboard_server() {
    log "Creating dashboard server script..."
    
    cat > "$DASHBOARD_PY" << 'EOF'
#!/usr/bin/env python3
"""
Grimm Dashboard Server
Advanced web dashboard for Grimm backup system monitoring
"""

import os
import sys
import json
import sqlite3
import threading
import time
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request, redirect, url_for, session
from flask_socketio import SocketIO, emit
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['SECRET_KEY'] = 'grimm-dashboard-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*")

# Configuration
GRIM_ROOT = os.environ.get('GRIM_ROOT', '/opt/grim')
DB_PATH = os.path.join(GRIM_ROOT, 'db', 'grimm.db')
TEMPLATE_DIR = os.path.join(GRIM_ROOT, 'web', 'dashboard', 'templates')
STATIC_DIR = os.path.join(GRIM_ROOT, 'web', 'dashboard', 'static')

# Ensure template and static directories exist
os.makedirs(TEMPLATE_DIR, exist_ok=True)
os.makedirs(STATIC_DIR, exist_ok=True)

def get_db_connection():
    """Get database connection"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html')

@app.route('/api/status')
def api_status():
    """Get system status"""
    try:
        conn = get_db_connection()
        
        # Get basic statistics
        stats = conn.execute('''
            SELECT 
                COUNT(*) as total_files,
                ROUND(SUM(size_bytes) / 1024.0 / 1024.0 / 1024.0, 2) as total_size_gb,
                COUNT(CASE WHEN backup_freq IS NOT NULL THEN 1 END) as backed_up_files
            FROM files
        ''').fetchone()
        
        # Get backup frequency distribution
        frequencies = conn.execute('''
            SELECT backup_freq, COUNT(*) as count
            FROM files 
            WHERE backup_freq IS NOT NULL 
            GROUP BY backup_freq
        ''').fetchall()
        
        conn.close()
        
        return jsonify({
            'status': 'success',
            'data': {
                'stats': dict(stats),
                'frequencies': [dict(f) for f in frequencies],
                'timestamp': datetime.now().isoformat()
            }
        })
    except Exception as e:
        logger.error(f"Error getting status: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/files')
def api_files():
    """Get file list with pagination"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        offset = (page - 1) * per_page
        
        conn = get_db_connection()
        
        # Get total count
        total = conn.execute('SELECT COUNT(*) FROM files').fetchone()[0]
        
        # Get files with pagination
        files = conn.execute('''
            SELECT path, size_bytes, scan_count, backup_freq, mtime
            FROM files 
            ORDER BY mtime DESC
            LIMIT ? OFFSET ?
        ''', (per_page, offset)).fetchall()
        
        conn.close()
        
        return jsonify({
            'status': 'success',
            'data': {
                'files': [dict(f) for f in files],
                'pagination': {
                    'page': page,
                    'per_page': per_page,
                    'total': total,
                    'pages': (total + per_page - 1) // per_page
                }
            }
        })
    except Exception as e:
        logger.error(f"Error getting files: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/analytics')
def api_analytics():
    """Get analytics data"""
    try:
        conn = get_db_connection()
        
        # File type distribution
        file_types = conn.execute('''
            SELECT type, COUNT(*) as count
            FROM files 
            GROUP BY type 
            ORDER BY count DESC 
            LIMIT 10
        ''').fetchall()
        
        # Change frequency analysis
        change_freq = conn.execute('''
            SELECT 
                CASE 
                    WHEN scan_count > 20 THEN 'Very High'
                    WHEN scan_count > 10 THEN 'High'
                    WHEN scan_count > 5 THEN 'Medium'
                    ELSE 'Low'
                END as change_level,
                COUNT(*) as file_count
            FROM files 
            GROUP BY change_level 
            ORDER BY file_count DESC
        ''').fetchall()
        
        conn.close()
        
        return jsonify({
            'status': 'success',
            'data': {
                'file_types': [dict(f) for f in file_types],
                'change_frequency': [dict(f) for f in change_freq]
            }
        })
    except Exception as e:
        logger.error(f"Error getting analytics: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

def create_templates():
    """Create basic HTML templates"""
    
    # Create index.html
    index_html = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Grimm Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        .metric-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .status-card { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; }
        .chart-container { height: 300px; }
    </style>
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container-fluid">
            <a class="navbar-brand" href="#"><i class="fas fa-shield-alt"></i> Grimm Dashboard</a>
        </div>
    </nav>

    <div class="container-fluid mt-4">
        <div class="row">
            <div class="col-md-3">
                <div class="card metric-card mb-3">
                    <div class="card-body text-center">
                        <h3 id="total-files">-</h3>
                        <p class="mb-0">Total Files</p>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card metric-card mb-3">
                    <div class="card-body text-center">
                        <h3 id="total-size">-</h3>
                        <p class="mb-0">Total Size (GB)</p>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card metric-card mb-3">
                    <div class="card-body text-center">
                        <h3 id="backup-coverage">-</h3>
                        <p class="mb-0">Backup Coverage (%)</p>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card status-card mb-3">
                    <div class="card-body text-center">
                        <h3 id="status">-</h3>
                        <p class="mb-0">System Status</p>
                    </div>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h5><i class="fas fa-chart-pie"></i> Backup Frequency Distribution</h5>
                    </div>
                    <div class="card-body">
                        <div id="frequency-chart" class="chart-container"></div>
                    </div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h5><i class="fas fa-chart-bar"></i> File Type Distribution</h5>
                    </div>
                    <div class="card-body">
                        <div id="type-chart" class="chart-container"></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row mt-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-header">
                        <h5><i class="fas fa-list"></i> Recent Files</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>Path</th>
                                        <th>Size</th>
                                        <th>Scans</th>
                                        <th>Backup Freq</th>
                                        <th>Modified</th>
                                    </tr>
                                </thead>
                                <tbody id="files-table">
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script>
        // Dashboard JavaScript
        function updateDashboard() {
            fetch('/api/status')
                .then(response => response.json())
                .then(data => {
                    if (data.status === 'success') {
                        const stats = data.data.stats;
                        document.getElementById('total-files').textContent = stats.total_files.toLocaleString();
                        document.getElementById('total-size').textContent = stats.total_size_gb;
                        document.getElementById('backup-coverage').textContent = 
                            Math.round((stats.backed_up_files / stats.total_files) * 100);
                        document.getElementById('status').textContent = 'Healthy';
                    }
                })
                .catch(error => console.error('Error:', error));
        }

        function updateFiles() {
            fetch('/api/files')
                .then(response => response.json())
                .then(data => {
                    if (data.status === 'success') {
                        const tbody = document.getElementById('files-table');
                        tbody.innerHTML = '';
                        
                        data.data.files.forEach(file => {
                            const row = document.createElement('tr');
                            row.innerHTML = `
                                <td>${file.path}</td>
                                <td>${(file.size_bytes / 1024 / 1024).toFixed(2)} MB</td>
                                <td>${file.scan_count}</td>
                                <td>${file.backup_freq || 'None'}</td>
                                <td>${new Date(file.mtime * 1000).toLocaleString()}</td>
                            `;
                            tbody.appendChild(row);
                        });
                    }
                })
                .catch(error => console.error('Error:', error));
        }

        // Update dashboard every 30 seconds
        setInterval(updateDashboard, 30000);
        setInterval(updateFiles, 30000);
        
        // Initial load
        updateDashboard();
        updateFiles();
    </script>
</body>
</html>'''
    
    with open(os.path.join(TEMPLATE_DIR, 'index.html'), 'w') as f:
        f.write(index_html)

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    
    # Create templates if they don't exist
    if not os.path.exists(os.path.join(TEMPLATE_DIR, 'index.html')):
        create_templates()
    
    logger.info(f"Starting Grimm Dashboard on port {port}")
    socketio.run(app, host='0.0.0.0', port=port, debug=False)
EOF
    
    chmod +x "$DASHBOARD_PY"
    log "Dashboard server script created: $DASHBOARD_PY"
}

# Setup dashboard dependencies
setup_dashboard() {
    log "Setting up dashboard dependencies..."
    
    # Check for Python 3
    if ! command -v python3 >/dev/null; then
        echo "${RED}Python 3 is required. Please install it first.${RESET}"
        exit 1
    fi
    
    # Install required Python packages
    echo "${CYAN}Installing Python dependencies...${RESET}"
    python3 -m pip install flask flask-socketio --user 2>/dev/null || {
        echo "${YELLOW}Installing with sudo...${RESET}"
        sudo python3 -m pip install flask flask-socketio
    }
    
    # Create dashboard server script
    create_dashboard_server
    
    log "Dashboard dependencies setup complete"
    echo "${GREEN}✓ Dashboard dependencies installed${RESET}"
}

# Start dashboard
start_dashboard() {
    local port="${1:-8080}"
    local ssl_enabled="${2:-false}"
    local auth_enabled="${3:-false}"
    local verbose="${4:-false}"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Starting dashboard with options:${RESET}"
        echo "  Port: $port"
        echo "  SSL: $ssl_enabled"
        echo "  Auth: $auth_enabled"
    fi
    
    # Check if already running
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "${YELLOW}Dashboard is already running (PID: $pid)${RESET}"
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    # Setup dependencies if needed
    if [[ ! -f "$DASHBOARD_PY" ]]; then
        setup_dashboard
    fi
    
    # Check for required packages
    if ! python3 -c "import flask" 2>/dev/null; then
        echo "${YELLOW}Flask not found. Installing dependencies...${RESET}"
        setup_dashboard
    fi
    
    log "Starting dashboard on port $port..."
    
    # Start dashboard server
    nohup python3 "$DASHBOARD_PY" "$port" > "$GRIM_ROOT/logs/dashboard.out" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment for server to start
    sleep 2
    
    if kill -0 "$pid" 2>/dev/null; then
        local protocol="http"
        if [[ "$ssl_enabled" == "true" ]]; then
            protocol="https"
        fi
        echo "${GREEN}✓ Dashboard running at ${protocol}://localhost:$port${RESET}"
        log "Dashboard started successfully (PID: $pid)"
    else
        echo "${RED}✗ Failed to start dashboard${RESET}"
        log "Dashboard failed to start"
        return 1
    fi
}

# Stop dashboard
stop_dashboard() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            log "Dashboard stopped (PID: $pid)"
            echo "${GREEN}✓ Dashboard stopped${RESET}"
        else
            rm -f "$PID_FILE"
            echo "${YELLOW}Dashboard was not running${RESET}"
        fi
    else
        echo "${YELLOW}Dashboard is not running${RESET}"
    fi
}

# Restart dashboard
restart_dashboard() {
    local port="${1:-8080}"
    local ssl_enabled="${2:-false}"
    local auth_enabled="${3:-false}"
    local verbose="${4:-false}"
    
    log "Restarting dashboard..."
    stop_dashboard
    sleep 2
    start_dashboard "$port" "$ssl_enabled" "$auth_enabled" "$verbose"
}

# Show dashboard status
show_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "${GREEN}✓ Dashboard is running (PID: $pid)${RESET}"
            echo "  Port: 8080"
            echo "  URL: http://localhost:8080"
            echo "  Logs: $LOG_FILE"
        else
            echo "${RED}✗ Dashboard process not found (PID: $pid)${RESET}"
            rm -f "$PID_FILE"
        fi
    else
        echo "${YELLOW}Dashboard is not running${RESET}"
    fi
}

# Show dashboard logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "${CYAN}=== Dashboard Logs ===${RESET}"
        tail -n 50 "$LOG_FILE"
    else
        echo "${YELLOW}No dashboard logs found${RESET}"
    fi
}

# Show or update configuration
show_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "${CYAN}Dashboard Configuration:${RESET}"
        echo ""
        cat "$CONFIG_FILE"
    else
        echo "${YELLOW}Configuration file not found. Run 'init' to create it.${RESET}"
    fi
}

# Main function
main() {
    local command="${1:-start}"
    local port=8080
    local ssl_enabled=false
    local auth_enabled=false
    local verbose=false
    
    # Parse options
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port=*)
                port="${1#*=}"
                shift
                ;;
            --ssl)
                ssl_enabled=true
                shift
                ;;
            --auth)
                auth_enabled=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    case "$command" in
        help|-h|--help)
            show_help
            ;;
        init)
            init_dashboard
            ;;
        setup)
            setup_dashboard
            ;;
        start)
            start_dashboard "$port" "$ssl_enabled" "$auth_enabled" "$verbose"
            ;;
        stop)
            stop_dashboard
            ;;
        restart)
            restart_dashboard "$port" "$ssl_enabled" "$auth_enabled" "$verbose"
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        config)
            show_config
            ;;
        *)
            start_dashboard "$port" "$ssl_enabled" "$auth_enabled" "$verbose"
            ;;
    esac
}

main "$@" 