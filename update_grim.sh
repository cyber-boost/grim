#!/bin/bash
# Grim Reaper Update Script
# Fixes logger and config issues on existing installations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# Find Grim installation directory
if [[ -d "/root/.graveyard/reaper" ]]; then
    GRIM_ROOT="/root/.graveyard/reaper"
elif [[ -d "/opt/reaper" ]]; then
    GRIM_ROOT="/opt/reaper"
else
    error "Grim installation not found. Please ensure Grim is installed."
    exit 1
fi

log "Found Grim installation at: $GRIM_ROOT"

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]] && [[ -z "${SUDO_USER:-}" ]]; then
    warning "Not running as root. Some operations may require sudo."
fi

# Update logger.py
log "Updating logger.py..."
cat > "$GRIM_ROOT/py_grim/grim_core/logger.py" << 'EOF'
"""
Grim Core Logger - Simple logging functionality
"""
import logging
import sys
import time
import json

_initialized = False
_loggers = {}

def init_logger(level="INFO", log_file=None):
    """Initialize the logging system"""
    global _initialized
    if _initialized:
        return
    
    logging.basicConfig(
        level=getattr(logging, level.upper()),
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout),
            *([] if log_file is None else [logging.FileHandler(log_file)])
        ]
    )
    _initialized = True

def get_logger(name="grim"):
    """Get or create a logger instance"""
    if not _initialized:
        init_logger()
    
    if name not in _loggers:
        _loggers[name] = logging.getLogger(name)
    
    return _loggers[name]

def setup_logger(name="grim", level="INFO"):
    """Setup basic logger (legacy compatibility)"""
    if not _initialized:
        init_logger(level)
    return get_logger(name)

def log_event(event_type, data=None, logger_name="grim"):
    """Log a structured event"""
    logger = get_logger(logger_name)
    event_data = {
        "timestamp": time.time(),
        "event_type": event_type,
        "data": data or {}
    }
    logger.info(f"EVENT: {json.dumps(event_data)}")

def log_metric(metric_name, value, logger_name="grim"):
    """Log a metric"""
    logger = get_logger(logger_name)
    metric_data = {
        "timestamp": time.time(),
        "metric": metric_name,
        "value": value
    }
    logger.info(f"METRIC: {json.dumps(metric_data)}")
EOF

success "Updated logger.py with missing functions"

# Update get_config function signature
log "Updating config.py..."
CONFIG_FILE="$GRIM_ROOT/py_grim/grim_core/config.py"

if [[ -f "$CONFIG_FILE" ]]; then
    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update the get_config function signature
    sed -i 's/def get_config() -> Config:/def get_config(config_path: Optional[str] = None) -> Config:/' "$CONFIG_FILE"
    sed -i 's/_config = Config()/_config = Config(config_path)/' "$CONFIG_FILE"
    
    success "Updated config.py function signature"
else
    warning "config.py not found at $CONFIG_FILE"
fi

# Install tusktsk package if missing
log "Checking for tusktsk package..."
if [[ -d "$GRIM_ROOT/grim_venv" ]]; then
    source "$GRIM_ROOT/grim_venv/bin/activate"
    
    if ! python3 -c "import tusktsk" 2>/dev/null; then
        log "Installing tusktsk package..."
        pip install tusktsk --break-system-packages 2>/dev/null || pip install tusktsk
        success "Installed tusktsk package"
    else
        success "tusktsk package already installed"
    fi
    
    deactivate
else
    warning "Virtual environment not found. Please install tusktsk manually: pip install tusktsk"
fi

# Test the fix
log "Testing health check..."
cd "$GRIM_ROOT"

if [[ -f "scythe/scythe.py" ]]; then
    if [[ -d "grim_venv" ]]; then
        source "grim_venv/bin/activate"
        python3 scythe/scythe.py health
        deactivate
    else
        python3 scythe/scythe.py health
    fi
else
    warning "scythe.py not found. Please run 'grim health check' manually to test."
fi

success "Update completed! Please run 'grim health check' to verify the fix."
EOF