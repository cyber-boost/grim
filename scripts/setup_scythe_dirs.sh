#!/bin/bash
# Universal .scythe Directory Setup Function
# Used by all Grim Reaper installation scripts
# Creates the required .graveyard/.rip/.scythe directory structure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'  
CYAN='\033[0;36m'
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
    return 1
}

# Function to detect GRIM_ROOT dynamically
detect_grim_root() {
    local detected_root=""
    
    # Priority order for GRIM_ROOT detection:
    # 1. Environment variable GRIM_ROOT
    # 2. Current working directory if it contains grim files
    # 3. User's home .graveyard directory
    # 4. System-wide /root/.graveyard directory
    
    if [[ -n "${GRIM_ROOT:-}" ]]; then
        detected_root="$GRIM_ROOT"
        log "Using GRIM_ROOT from environment: $detected_root"
    elif [[ -f "$(pwd)/grim_throne.sh" ]] || [[ -f "$(pwd)/sh_grim/init.sh" ]]; then
        detected_root="$(pwd)"
        log "Detected GRIM_ROOT from current directory: $detected_root"
    elif [[ -d "$HOME/.graveyard" ]]; then
        # Check if there's an existing installation
        if [[ -d "$HOME/.graveyard/reaper" ]]; then
            detected_root="$HOME/.graveyard/reaper"
        else
            detected_root="$HOME/.graveyard"
        fi
        log "Using user graveyard directory: $detected_root"
    elif [[ -w "/root" ]] || mkdir -p "/root/.graveyard" 2>/dev/null; then
        # Check if there's an existing installation
        if [[ -d "/root/.graveyard/reaper" ]]; then
            detected_root="/root/.graveyard/reaper"
        else
            detected_root="/root/.graveyard"
        fi
        log "Using system graveyard directory: $detected_root"
    else
        # Fallback to home directory
        detected_root="${HOME}/.graveyard"
        log "Fallback to home graveyard directory: $detected_root"
    fi
    
    echo "$detected_root"
}

# Function to create .scythe directory structure
setup_scythe_directories() {
    local grim_root="${1:-}"
    local use_sudo="${2:-auto}"
    
    # Detect GRIM_ROOT if not provided
    if [[ -z "$grim_root" ]]; then
        grim_root=$(detect_grim_root)
    fi
    
    # Determine if we need sudo
    local sudo_cmd=""
    if [[ "$use_sudo" == "auto" ]]; then
        if [[ $EUID -ne 0 ]] && [[ "$grim_root" == /root/* ]] || [[ "$grim_root" == /opt/* ]] || [[ "$grim_root" == /usr/* ]]; then
            sudo_cmd="sudo"
        fi
    elif [[ "$use_sudo" == "yes" ]]; then
        sudo_cmd="sudo"
    fi
    
    log "Setting up .scythe directory structure in: $grim_root"
    
    # Create the full .scythe path
    local scythe_dir="$grim_root/.graveyard/.rip/.scythe"
    
    # Create directory structure
    $sudo_cmd mkdir -p "$scythe_dir"/{config,db,logs,run,integrations}
    
    # Set proper permissions
    if [[ -n "$sudo_cmd" ]]; then
        $sudo_cmd chown -R root:root "$grim_root/.graveyard" 2>/dev/null || true
        $sudo_cmd chmod -R 755 "$grim_root/.graveyard" 2>/dev/null || true
    else
        chmod -R 755 "$grim_root/.graveyard" 2>/dev/null || true
    fi
    
    # Create scythe configuration file
    local config_file="$scythe_dir/config/scythe.yaml"
    if [[ ! -f "$config_file" ]]; then
        $sudo_cmd tee "$config_file" > /dev/null << 'EOF'
# Scythe Configuration
# Central orchestrator settings for Grim Reaper System

scythe:
  version: "1.0.5"
  install_date: $(date -Iseconds)
  
database:
  path: "../db/scythe.db"
  auto_backup: true
  backup_interval: "24h"
  
logging:
  level: "info"
  path: "../logs"
  max_size: "100MB"
  max_files: 10
  
orchestration:
  enabled: true
  heartbeat_interval: "30s"
  max_concurrent_jobs: 5
  
integrations:
  enabled: true
  scan_interval: "5m"
  auto_discover: true
  
security:
  encryption: true
  key_rotation: "30d"
  audit_logs: true
EOF
        success "Created scythe configuration file"
    fi
    
    # Initialize scythe database
    local db_file="$scythe_dir/db/scythe.db"
    if [[ ! -f "$db_file" ]]; then
        log "Initializing scythe database..."
        $sudo_cmd sqlite3 "$db_file" << 'EOF'
-- Scythe Orchestrator Database Schema
-- Central coordination database for Grim Reaper System

-- System information table
CREATE TABLE IF NOT EXISTS system_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    value TEXT,
    metadata TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Job orchestration table
CREATE TABLE IF NOT EXISTS orchestration_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id TEXT UNIQUE NOT NULL,
    job_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    component TEXT NOT NULL,
    command TEXT,
    parameters TEXT,
    priority INTEGER DEFAULT 5,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT
);

-- Component status table
CREATE TABLE IF NOT EXISTS component_status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'unknown',
    version TEXT,
    last_heartbeat TIMESTAMP,
    metadata TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Integration registry
CREATE TABLE IF NOT EXISTS integrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'inactive',
    config TEXT,
    last_scan TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Event log table
CREATE TABLE IF NOT EXISTS event_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    component TEXT,
    message TEXT NOT NULL,
    severity TEXT DEFAULT 'info',
    metadata TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Performance metrics
CREATE TABLE IF NOT EXISTS performance_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_value REAL,
    component TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata TEXT
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_jobs_status ON orchestration_jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_created ON orchestration_jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_component_heartbeat ON component_status(last_heartbeat);
CREATE INDEX IF NOT EXISTS idx_events_type ON event_log(event_type);
CREATE INDEX IF NOT EXISTS idx_events_created ON event_log(created_at);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON performance_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON performance_metrics(timestamp);

-- Insert initial system information
INSERT OR REPLACE INTO system_info (key, value, metadata) VALUES 
    ('install_date', datetime('now'), 'ISO format timestamp'),
    ('version', '1.0.5', 'Scythe orchestrator version'),
    ('status', 'initialized', 'System initialization status'),
    ('grim_root', '${grim_root}', 'Grim installation root directory'),
    ('scythe_dir', '${scythe_dir}', 'Scythe directory path'),
    ('install_id', hex(randomblob(16)), 'Unique installation identifier'),
    ('api_key', hex(randomblob(32)), 'API authentication key');

-- Register core components
INSERT OR REPLACE INTO component_status (component, status, version) VALUES
    ('sh_grim', 'initialized', '1.0.5'),
    ('py_grim', 'initialized', '1.0.5'),
    ('go_grim', 'initialized', '1.0.5'),
    ('rb_grim', 'initialized', '1.0.5'),
    ('php_grim', 'initialized', '1.0.5'),
    ('js_grim', 'initialized', '1.0.5'),
    ('rs_grim', 'initialized', '1.0.5'),
    ('scythe', 'active', '1.0.5');

-- Log initialization event
INSERT INTO event_log (event_type, component, message, severity) VALUES
    ('initialization', 'scythe', 'Scythe orchestrator database initialized', 'info');
EOF
        success "Initialized scythe database with schema"
    fi
    
    # Create log directory structure
    $sudo_cmd mkdir -p "$scythe_dir/logs"/{orchestration,components,integrations,security}
    
    # Create run directory for PID files and sockets
    $sudo_cmd mkdir -p "$scythe_dir/run"
    
    # Create integrations directory for discovered components
    $sudo_cmd mkdir -p "$scythe_dir/integrations"/{discovered,configs,scripts}
    
    # Create initial integration discovery script
    local discovery_script="$scythe_dir/integrations/scripts/discover_components.sh"
    if [[ ! -f "$discovery_script" ]]; then
        $sudo_cmd tee "$discovery_script" > /dev/null << 'EOF'
#!/bin/bash
# Component Discovery Script
# Automatically discovers and registers Grim components

set -euo pipefail

SCYTHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB_FILE="$SCYTHE_DIR/db/scythe.db"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SCYTHE_DIR/logs/integrations/discovery.log"
}

# Discover Grim components
discover_components() {
    local grim_root="$(dirname "$(dirname "$(dirname "$SCYTHE_DIR")")")"
    
    # Check for language-specific components
    for component in sh_grim py_grim go_grim rb_grim php_grim js_grim rs_grim; do
        if [[ -d "$grim_root/$component" ]]; then
            log "Discovered component: $component"
            
            # Update component status in database
            sqlite3 "\$DB_FILE" << SQLEOF
INSERT OR REPLACE INTO component_status (component, status, last_heartbeat) 
VALUES ('$component', 'discovered', datetime('now'));

INSERT INTO event_log (event_type, component, message, severity) 
VALUES ('discovery', '$component', 'Component discovered during scan', 'info');
SQLEOF
        fi
    done
    
    # Check for additional integrations
    if command -v grim >/dev/null 2>&1; then
        log "Grim CLI detected"
        sqlite3 "\$DB_FILE" << SQLEOF
INSERT OR REPLACE INTO integrations (name, type, status, last_scan) 
VALUES ('grim_cli', 'command_interface', 'active', datetime('now'));
SQLEOF
    fi
    
    log "Component discovery completed"
}

# Run discovery
discover_components
EOF
        $sudo_cmd chmod +x "$discovery_script"
        success "Created component discovery script"
    fi
    
    # Set environment variables for the session
    export GRIM_ROOT="$grim_root"
    export SCYTHE_DIR="$scythe_dir"
    
    # Update shell configuration files to persist environment variables
    local bashrc_file profile_file
    if [[ "$grim_root" == "/root"* ]]; then
        bashrc_file="/root/.bashrc"
        profile_file="/root/.profile"
    else
        bashrc_file="$HOME/.bashrc"
        profile_file="$HOME/.profile"
    fi
    
    # Add SCYTHE_DIR environment variable
    if [[ -f "$bashrc_file" ]]; then
        if ! grep -q "SCYTHE_DIR" "$bashrc_file" 2>/dev/null; then
            echo "export SCYTHE_DIR=\"$scythe_dir\"" >> "$bashrc_file"
            log "Added SCYTHE_DIR to $bashrc_file"
        fi
    fi
    
    if [[ -f "$profile_file" ]]; then
        if ! grep -q "SCYTHE_DIR" "$profile_file" 2>/dev/null; then
            echo "export SCYTHE_DIR=\"$scythe_dir\"" >> "$profile_file"
            log "Added SCYTHE_DIR to $profile_file"
        fi
    fi
    
    success "✅ .scythe directory structure created successfully"
    log "Scythe directory: $scythe_dir"
    log "Database: $scythe_dir/db/scythe.db"
    log "Config: $scythe_dir/config/scythe.yaml"
    log "Logs: $scythe_dir/logs/"
    
    return 0
}

# Function to migrate existing installations
migrate_existing_installation() {
    local grim_root="${1:-}"
    
    if [[ -z "$grim_root" ]]; then
        grim_root=$(detect_grim_root)
    fi
    
    log "Checking for existing installation migration needs..."
    
    # Check if old structure exists without .scythe
    if [[ -d "$grim_root/.graveyard" ]] && [[ ! -d "$grim_root/.graveyard/.rip/.scythe" ]]; then
        warning "Found existing installation without .scythe structure"
        log "Migrating existing installation..."
        
        # Create new structure
        setup_scythe_directories "$grim_root"
        
        # Migrate existing data if any
        if [[ -f "$grim_root/db/grim.db" ]]; then
            log "Migrating existing database data..."
            cp "$grim_root/db/grim.db" "$grim_root/.graveyard/.rip/.scythe/db/grim_legacy.db"
        fi
        
        if [[ -d "$grim_root/logs" ]]; then
            log "Migrating existing logs..."
            cp -r "$grim_root/logs"/* "$grim_root/.graveyard/.rip/.scythe/logs/" 2>/dev/null || true
        fi
        
        success "Migration completed successfully"
    elif [[ -d "$grim_root/.graveyard/.rip/.scythe" ]]; then
        log ".scythe structure already exists - no migration needed"
    else
        log "No existing installation found - creating fresh structure"
        setup_scythe_directories "$grim_root"
    fi
}

# Function to verify .scythe installation
verify_scythe_installation() {
    local grim_root="${1:-}"
    
    if [[ -z "$grim_root" ]]; then
        grim_root=$(detect_grim_root)
    fi
    
    local scythe_dir="$grim_root/.graveyard/.rip/.scythe"
    
    log "Verifying .scythe installation..."
    
    # Check required directories
    local required_dirs=("config" "db" "logs" "run" "integrations")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$scythe_dir/$dir" ]]; then
            error "Missing required directory: $scythe_dir/$dir"
            return 1
        fi
    done
    
    # Check database
    if [[ ! -f "$scythe_dir/db/scythe.db" ]]; then
        error "Missing scythe database: $scythe_dir/db/scythe.db"
        return 1
    fi
    
    # Verify database schema
    if ! sqlite3 "$scythe_dir/db/scythe.db" "SELECT name FROM sqlite_master WHERE type='table' AND name='system_info';" | grep -q "system_info"; then
        error "Invalid database schema in scythe.db"
        return 1
    fi
    
    # Check configuration
    if [[ ! -f "$scythe_dir/config/scythe.yaml" ]]; then
        error "Missing scythe configuration: $scythe_dir/config/scythe.yaml"
        return 1
    fi
    
    success "✅ .scythe installation verified successfully"
    return 0
}

# Main function - can be called directly or sourced
main() {
    local action="${1:-setup}"
    local grim_root="${2:-}"
    local use_sudo="${3:-auto}"
    
    case "$action" in
        "setup")
            setup_scythe_directories "$grim_root" "$use_sudo"
            ;;
        "migrate")
            migrate_existing_installation "$grim_root"
            ;;
        "verify")
            verify_scythe_installation "$grim_root"
            ;;
        "detect-root")
            detect_grim_root
            ;;
        *)
            error "Unknown action: $action"
            echo "Usage: $0 {setup|migrate|verify|detect-root} [grim_root] [use_sudo]"
            return 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi