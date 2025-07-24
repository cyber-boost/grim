#!/bin/bash

# Grim Automatic Backup System
# Monitors file changes and creates intelligent compressed backups
# Integrates with Go compression engine for optimal performance

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAVEYARD_DIR="${GRAVEYARD_DIR:-/root/.graveyard}"
MONITOR_DIR="${MONITOR_DIR:-$(pwd)}"
GO_COMPRESSION_BIN="${GO_COMPRESSION_BIN:-$SCRIPT_DIR/../go_grim/build/grim-compression}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-300}"  # 5 minutes
MAX_BACKUPS="${MAX_BACKUPS:-50}"
MIN_FILE_SIZE="${MIN_FILE_SIZE:-1024}"  # 1KB minimum
LOG_FILE="${LOG_FILE:-/var/log/grim-auto-backup.log}"
PID_FILE="${PID_FILE:-/var/run/grim-auto-backup.pid}"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/auto_backup.conf}"

# File monitoring state
declare -A file_modifications=()
declare -A file_last_backup=()
declare -A hot_files=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "$*"; }
log_error() { log "ERROR" "$*"; }
log_debug() { log "DEBUG" "$*"; }

# Initialize system
init_system() {
    log_info "Initializing Grim Automatic Backup System"
    
    # Create necessary directories
    mkdir -p "$GRAVEYARD_DIR/auto_backups"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$PID_FILE")"
    
    # Check if Go compression binary exists
    if [[ ! -f "$GO_COMPRESSION_BIN" ]]; then
        log_error "Go compression binary not found at: $GO_COMPRESSION_BIN"
        log_info "Building Go compression engine..."
        build_go_compression
    fi
    
    # Load configuration
    load_config
    
    log_info "System initialized. Monitoring: $MONITOR_DIR"
    log_info "Graveyard directory: $GRAVEYARD_DIR"
}

# Build Go compression engine if needed
build_go_compression() {
    local go_dir="$SCRIPT_DIR/../go_grim"
    if [[ -d "$go_dir" ]]; then
        cd "$go_dir"
        if command -v make >/dev/null 2>&1; then
            make build
            log_info "Go compression engine built successfully"
        else
            log_error "Make not found. Please install build tools."
            exit 1
        fi
    else
        log_error "Go grim directory not found: $go_dir"
        exit 1
    fi
}

# Load configuration file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_info "No configuration file found, using defaults"
        create_default_config
    fi
}

# Create default configuration
create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Grim Auto Backup Configuration
GRAVEYARD_DIR="/root/.graveyard"
MONITOR_DIR="$(pwd)"
BACKUP_INTERVAL=300
MAX_BACKUPS=50
MIN_FILE_SIZE=1024
EXCLUDE_PATTERNS=("*.tmp" "*.log" "*.cache" ".git/*" "node_modules/*" "venv/*")
INCLUDE_PATTERNS=("*.py" "*.sh" "*.go" "*.js" "*.php" "*.ts" "*.tsk" "*.pnt")
COMPRESSION_ALGORITHM="zstd"
EOF
    log_info "Created default configuration: $CONFIG_FILE"
}

# Check if file should be monitored
should_monitor_file() {
    local file="$1"
    local filename=$(basename "$file")
    local dirname=$(dirname "$file")
    
    # Skip if file is too small
    if [[ ! -f "$file" ]] || [[ $(stat -c%s "$file" 2>/dev/null || echo 0) -lt $MIN_FILE_SIZE ]]; then
        return 1
    fi
    
    # Check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]:-()}"; do
        if [[ "$file" == *"$pattern"* ]] || [[ "$filename" == $pattern ]]; then
            return 1
        fi
    done
    
    # Check include patterns
    for pattern in "${INCLUDE_PATTERNS[@]:-()}"; do
        if [[ "$file" == *"$pattern"* ]] || [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done
    
    # If no include patterns specified, monitor all non-excluded files
    return 0
}

# Get file modification time
get_file_mtime() {
    stat -c%Y "$1" 2>/dev/null || echo 0
}

# Detect hot files (frequently modified)
detect_hot_files() {
    local current_time=$(date +%s)
    local threshold=$((current_time - 3600))  # 1 hour
    
    for file in "${!file_modifications[@]}"; do
        local mod_count=${file_modifications[$file]}
        local last_mod=${file_last_backup[$file]:-0}
        
        # Consider file "hot" if modified more than 3 times in the last hour
        if [[ $mod_count -ge 3 ]] && [[ $last_mod -gt $threshold ]]; then
            hot_files["$file"]=1
        else
            unset hot_files["$file"]
        fi
    done
}

# Create compressed backup
create_backup() {
    local source="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename=$(basename "$source")
    local dirname=$(dirname "$source")
    local relative_path="${dirname#$MONITOR_DIR/}"
    
    # Create backup directory structure
    local backup_dir="$GRAVEYARD_DIR/auto_backups/$relative_path"
    mkdir -p "$backup_dir"
    
    # Generate backup filename
    local backup_name="${filename}.${timestamp}.${COMPRESSION_ALGORITHM:-zstd}"
    local backup_path="$backup_dir/$backup_name"
    
    log_info "Creating backup: $source -> $backup_path"
    
    # Use Go compression engine
    if "$GO_COMPRESSION_BIN" -input "$source" -algorithm "${COMPRESSION_ALGORITHM:-zstd}" -output "$backup_path" >/dev/null 2>&1; then
        log_info "Backup created successfully: $backup_path"
        
        # Update last backup time
        file_last_backup["$source"]=$(date +%s)
        
        # Cleanup old backups
        cleanup_old_backups "$backup_dir"
        
        return 0
    else
        log_error "Failed to create backup: $source"
        return 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    local backup_dir="$1"
    local max_backups=${MAX_BACKUPS:-50}
    
    # Count existing backups
    local backup_count=$(find "$backup_dir" -name "*.${COMPRESSION_ALGORITHM:-zstd}" | wc -l)
    
    if [[ $backup_count -gt $max_backups ]]; then
        log_info "Cleaning up old backups in: $backup_dir"
        
        # Remove oldest backups
        find "$backup_dir" -name "*.${COMPRESSION_ALGORITHM:-zstd}" -printf '%T@ %p\n' | \
        sort -n | head -n $((backup_count - max_backups)) | \
        while read timestamp file; do
            rm -f "$file"
            log_debug "Removed old backup: $file"
        done
    fi
}

# Monitor file changes using inotify
monitor_files() {
    log_info "Starting file monitoring..."
    
    # Check if inotify-tools is available
    if ! command -v inotifywait >/dev/null 2>&1; then
        log_error "inotifywait not found. Installing inotify-tools..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y inotify-tools
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y inotify-tools
        else
            log_error "Cannot install inotify-tools. Please install manually."
            exit 1
        fi
    fi
    
    # Start monitoring
    inotifywait -m -r -e modify,create,move "$MONITOR_DIR" --format '%w%f %e' | while read file event; do
        if should_monitor_file "$file"; then
            local current_time=$(date +%s)
            local file_mtime=$(get_file_mtime "$file")
            
            # Update modification tracking
            file_modifications["$file"]=$((${file_modifications[$file]:-0} + 1))
            
            log_debug "File modified: $file ($event) - count: ${file_modifications[$file]}"
            
            # Check if backup is needed
            local last_backup=${file_last_backup[$file]:-0}
            local time_since_backup=$((current_time - last_backup))
            
            if [[ $time_since_backup -gt $BACKUP_INTERVAL ]] || [[ ${hot_files[$file]:-0} -eq 1 ]]; then
                create_backup "$file"
            fi
        fi
    done
}

# Periodic hot file detection
hot_file_detector() {
    while true; do
        sleep 60  # Check every minute
        detect_hot_files
        
        # Log hot files
        if [[ ${#hot_files[@]} -gt 0 ]]; then
            log_info "Hot files detected: ${!hot_files[*]}"
        fi
    done
}

# Health check
health_check() {
    local pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "Auto backup daemon is running (PID: $pid)"
        return 0
    else
        echo "Auto backup daemon is not running"
        return 1
    fi
}

# Start daemon
start_daemon() {
    if health_check >/dev/null 2>&1; then
        log_warn "Auto backup daemon is already running"
        return 1
    fi
    
    log_info "Starting auto backup daemon..."
    
    # Start background processes
    monitor_files &
    local monitor_pid=$!
    
    hot_file_detector &
    local detector_pid=$!
    
    # Save PIDs
    echo "$monitor_pid $detector_pid" > "$PID_FILE"
    
    log_info "Auto backup daemon started (Monitor PID: $monitor_pid, Detector PID: $detector_pid)"
}

# Stop daemon
stop_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local pids=$(cat "$PID_FILE")
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                log_info "Stopped process: $pid"
            fi
        done
        rm -f "$PID_FILE"
        log_info "Auto backup daemon stopped"
    else
        log_warn "No PID file found"
    fi
}

# Restart daemon
restart_daemon() {
    log_info "Restarting auto backup daemon..."
    stop_daemon
    sleep 2
    start_daemon
}

# Show status
show_status() {
    echo -e "${BLUE}=== Grim Auto Backup Status ===${NC}"
    
    if health_check; then
        echo -e "${GREEN}✓ Daemon is running${NC}"
    else
        echo -e "${RED}✗ Daemon is not running${NC}"
    fi
    
    echo "Configuration:"
    echo "  Monitor Directory: $MONITOR_DIR"
    echo "  Graveyard Directory: $GRAVEYARD_DIR"
    echo "  Backup Interval: $BACKUP_INTERVAL seconds"
    echo "  Max Backups: $MAX_BACKUPS"
    echo "  Compression: ${COMPRESSION_ALGORITHM:-zstd}"
    
    echo -e "\nHot Files:"
    # Only show hot files if daemon is running and arrays are populated
    if health_check >/dev/null 2>&1 && [[ ${#hot_files[@]} -gt 0 ]]; then
        for file in "${!hot_files[@]}"; do
            local mod_count=${file_modifications[$file]:-0}
            echo "  - $file ($mod_count modifications)"
        done
    else
        echo "  None detected (daemon not running)"
    fi
    
    echo -e "\nRecent Backups:"
    find "$GRAVEYARD_DIR/auto_backups" -name "*.${COMPRESSION_ALGORITHM:-zstd}" -printf '%T@ %p\n' 2>/dev/null | \
    sort -n | tail -5 | while read timestamp file; do
        local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
        echo "  - $date: $file"
    done
}

# Main function
main() {
    case "${1:-}" in
        start)
            init_system
            start_daemon
            ;;
        stop)
            stop_daemon
            ;;
        restart)
            restart_daemon
            ;;
        status)
            show_status
            ;;
        health)
            health_check
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status|health}"
            echo ""
            echo "Grim Automatic Backup System"
            echo "Monitors file changes and creates intelligent compressed backups"
            echo ""
            echo "Commands:"
            echo "  start   - Start the auto backup daemon"
            echo "  stop    - Stop the auto backup daemon"
            echo "  restart - Restart the auto backup daemon"
            echo "  status  - Show current status and configuration"
            echo "  health  - Check if daemon is running"
            echo ""
            echo "Environment variables:"
            echo "  GRAVEYARD_DIR     - Backup destination (default: /root/.graveyard)"
            echo "  MONITOR_DIR       - Directory to monitor (default: current directory)"
            echo "  BACKUP_INTERVAL   - Backup interval in seconds (default: 300)"
            echo "  MAX_BACKUPS       - Maximum backups per file (default: 50)"
            echo "  COMPRESSION_ALGORITHM - Compression algorithm (default: zstd)"
            exit 1
            ;;
    esac
}

# Handle signals
trap 'log_info "Received signal, shutting down..."; stop_daemon; exit 0' SIGTERM SIGINT

# Run main function
main "$@" 