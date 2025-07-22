#!/bin/bash

# Scythe Orchestrator Setup Script
# Sets up the complete scythe directory structure and dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCYTHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="$(cd "$SCYTHE_DIR/.." && pwd)"
LOG_FILE="$SCYTHE_DIR/logs/setup.log"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Create necessary directories
create_directories() {
    log "Creating scythe directory structure..."
    
    mkdir -p "$SCYTHE_DIR"/{logs,data,backups,temp}
    mkdir -p "$SCYTHE_DIR"/config/keys
    mkdir -p "$SCYTHE_DIR"/tests/{unit,integration,performance}
    mkdir -p "$SCYTHE_DIR"/scripts/{maintenance,monitoring,backup}
    
    log "Directory structure created successfully"
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed"
    fi
    
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log "Python version: $python_version"
    
    # Check required Python packages
    required_packages=("yaml" "pathlib" "subprocess" "threading" "time" "json" "logging")
    missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! python3 -c "import $package" &> /dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        warning "Missing Python packages: ${missing_packages[*]}"
        log "Installing missing packages..."
        pip3 install "${missing_packages[@]}"
    fi
    
    # Check for required system tools
    required_tools=("curl" "wget" "tar" "gzip")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required tool '$tool' is not installed"
        fi
    done
    
    log "System requirements check completed"
}

# Install Python dependencies
install_dependencies() {
    log "Installing Python dependencies..."
    
    # Create requirements.txt if it doesn't exist
    if [ ! -f "$SCYTHE_DIR/requirements.txt" ]; then
        cat > "$SCYTHE_DIR/requirements.txt" << EOF
PyYAML>=6.0
psutil>=5.9.0
requests>=2.28.0
schedule>=1.2.0
colorama>=0.4.6
tabulate>=0.9.0
python-dotenv>=1.0.0
cryptography>=41.0.0
EOF
    fi
    
    # Install dependencies
    if command -v pip3 &> /dev/null; then
        pip3 install -r "$SCYTHE_DIR/requirements.txt"
    else
        error "pip3 is not available"
    fi
    
    log "Python dependencies installed successfully"
}

# Setup configuration files
setup_config() {
    log "Setting up configuration files..."
    
    # Create default configuration if it doesn't exist
    if [ ! -f "$SCYTHE_DIR/config/orchestrator.yaml" ]; then
        warning "Configuration file not found, creating default..."
        # The configuration file was already created in the main script
    fi
    
    # Create environment file
    if [ ! -f "$SCYTHE_DIR/.env" ]; then
        cat > "$SCYTHE_DIR/.env" << EOF
# Scythe Orchestrator Environment Variables
SCYTHE_ENV=development
SCYTHE_LOG_LEVEL=INFO
SCYTHE_CONFIG_PATH=config/orchestrator.yaml
SCYTHE_DATA_PATH=data
SCYTHE_LOG_PATH=logs
EOF
    fi
    
    log "Configuration files setup completed"
}

# Setup logging
setup_logging() {
    log "Setting up logging system..."
    
    # Create log rotation configuration
    cat > "$SCYTHE_DIR/config/logrotate.conf" << EOF
$SCYTHE_DIR/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload scythe-orchestrator 2>/dev/null || true
    endscript
}
EOF
    
    log "Logging system setup completed"
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "$SCYTHE_DIR/scripts/scythe-orchestrator.service" << EOF
[Unit]
Description=Scythe Orchestrator for Grim Reaper
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$SCYTHE_DIR
ExecStart=/usr/bin/python3 $SCYTHE_DIR/core/orchestrator.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=scythe-orchestrator

[Install]
WantedBy=multi-user.target
EOF
    
    log "Systemd service file created at $SCYTHE_DIR/scripts/scythe-orchestrator.service"
    info "To install the service, run: sudo cp $SCYTHE_DIR/scripts/scythe-orchestrator.service /etc/systemd/system/ && sudo systemctl enable scythe-orchestrator"
}

# Create utility scripts
create_utility_scripts() {
    log "Creating utility scripts..."
    
    # Health check script
    cat > "$SCYTHE_DIR/scripts/health_check.sh" << 'EOF'
#!/bin/bash
# Health check script for scythe orchestrator

SCYTHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$SCYTHE_DIR/logs/health_check.log"

# Check if orchestrator is running
if pgrep -f "orchestrator.py" > /dev/null; then
    echo "OK: Scythe orchestrator is running"
    exit 0
else
    echo "ERROR: Scythe orchestrator is not running"
    exit 1
fi
EOF
    chmod +x "$SCYTHE_DIR/scripts/health_check.sh"
    
    # Backup script
    cat > "$SCYTHE_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash
# Backup script for scythe orchestrator

SCYTHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$SCYTHE_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/scythe_backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

# Create backup
tar -czf "$BACKUP_FILE" \
    --exclude="$SCYTHE_DIR/logs/*.log" \
    --exclude="$SCYTHE_DIR/temp/*" \
    --exclude="$SCYTHE_DIR/backups/*" \
    -C "$SCYTHE_DIR" .

echo "Backup created: $BACKUP_FILE"

# Clean old backups (keep last 7 days)
find "$BACKUP_DIR" -name "scythe_backup_*.tar.gz" -mtime +7 -delete

echo "Old backups cleaned"
EOF
    chmod +x "$SCYTHE_DIR/scripts/backup.sh"
    
    # Start script
    cat > "$SCYTHE_DIR/scripts/start.sh" << 'EOF'
#!/bin/bash
# Start script for scythe orchestrator

SCYTHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$SCYTHE_DIR/logs/start.log"

echo "Starting Scythe Orchestrator..." | tee -a "$LOG_FILE"

# Check if already running
if pgrep -f "orchestrator.py" > /dev/null; then
    echo "Scythe orchestrator is already running"
    exit 0
fi

# Start the orchestrator
cd "$SCYTHE_DIR"
nohup python3 core/orchestrator.py > logs/orchestrator.log 2>&1 &

echo "Scythe Orchestrator started successfully"
echo "Check logs at: $SCYTHE_DIR/logs/orchestrator.log"
EOF
    chmod +x "$SCYTHE_DIR/scripts/start.sh"
    
    # Stop script
    cat > "$SCYTHE_DIR/scripts/stop.sh" << 'EOF'
#!/bin/bash
# Stop script for scythe orchestrator

SCYTHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$SCYTHE_DIR/logs/stop.log"

echo "Stopping Scythe Orchestrator..." | tee -a "$LOG_FILE"

# Find and kill orchestrator process
PIDS=$(pgrep -f "orchestrator.py")
if [ -n "$PIDS" ]; then
    echo "Found orchestrator processes: $PIDS"
    kill $PIDS
    sleep 2
    
    # Force kill if still running
    PIDS=$(pgrep -f "orchestrator.py")
    if [ -n "$PIDS" ]; then
        echo "Force killing processes: $PIDS"
        kill -9 $PIDS
    fi
    
    echo "Scythe Orchestrator stopped successfully"
else
    echo "No orchestrator processes found"
fi
EOF
    chmod +x "$SCYTHE_DIR/scripts/stop.sh"
    
    log "Utility scripts created successfully"
}

# Run tests
run_tests() {
    log "Running basic tests..."
    
    # Test Python imports
    if python3 -c "import yaml, json, logging, subprocess; print('Python imports OK')"; then
        log "Python imports test passed"
    else
        error "Python imports test failed"
    fi
    
    # Test configuration loading
    if python3 -c "import yaml; yaml.safe_load(open('$SCYTHE_DIR/config/orchestrator.yaml')); print('Config loading OK')"; then
        log "Configuration loading test passed"
    else
        error "Configuration loading test failed"
    fi
    
    # Test directory structure
    required_dirs=("core" "config" "scripts" "tests" "logs" "data" "backups")
    for dir in "${required_dirs[@]}"; do
        if [ -d "$SCYTHE_DIR/$dir" ]; then
            log "Directory $dir exists"
        else
            error "Required directory $dir is missing"
        fi
    done
    
    log "Basic tests completed successfully"
}

# Main setup function
main() {
    log "Starting Scythe Orchestrator setup..."
    log "Scythe directory: $SCYTHE_DIR"
    log "Base directory: $BASE_DIR"
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    create_directories
    check_requirements
    install_dependencies
    setup_config
    setup_logging
    create_systemd_service
    create_utility_scripts
    run_tests
    
    log "Scythe Orchestrator setup completed successfully!"
    log "Next steps:"
    log "1. Review configuration at $SCYTHE_DIR/config/orchestrator.yaml"
    log "2. Start the orchestrator: $SCYTHE_DIR/scripts/start.sh"
    log "3. Check status: $SCYTHE_DIR/scripts/health_check.sh"
    log "4. View logs: tail -f $SCYTHE_DIR/logs/orchestrator.log"
}

# Run main function
main "$@" 