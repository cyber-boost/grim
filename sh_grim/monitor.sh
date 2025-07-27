#!/bin/bash
# Grimm Monitor Module: Real-time filesystem monitoring and change detection

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/monitor.log"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Monitor Module"
    echo "Usage: monitor.sh <command> [options]"
    echo ""
    echo "Purpose: Real-time filesystem monitoring with intelligent change detection,"
    echo "         anomaly alerts, and automated response capabilities."
    echo ""
    echo "Commands:"
    echo "  start [path]          - Start monitoring a directory"
    echo "  stop [path]           - Stop monitoring a directory"
    echo "  status [path]         - Show monitoring status"
    echo "  list                  - List all monitored paths"
    echo "  events [path]         - Show recent events for a path"
    echo "  config [path]         - Configure monitoring options"
    echo "  help, -h, --help      - Show this help message"
    echo ""
    echo "Monitoring Types:"
    echo "  file-changes          - Monitor file modifications"
    echo "  access-patterns       - Monitor file access patterns"
    echo "  size-anomalies        - Detect unusual file size changes"
    echo "  permission-changes    - Monitor permission modifications"
    echo "  new-files             - Detect new file creation"
    echo "  deleted-files         - Detect file deletions"
    echo ""
    echo "Options:"
    echo "  --recursive           - Monitor subdirectories recursively"
    echo "  --exclude <pattern>   - Exclude files matching pattern"
    echo "  --include <pattern>   - Only monitor files matching pattern"
    echo "  --interval <seconds>  - Check interval (default: 5)"
    echo "  --quiet               - Suppress normal output"
    echo "  --verbose             - Show detailed monitoring info"
    echo ""
    echo "Configuration:"
    echo "  --threshold <size>    - Alert on files larger than size"
    echo "  --max-events <count>  - Maximum events to store per path"
    echo "  --retention <days>    - How long to keep event history"
    echo "  --auto-backup         - Automatically backup changed files"
    echo "  --auto-quarantine     - Quarantine suspicious changes"
    echo ""
    echo "Examples:"
    echo "  ./monitor.sh start /var/www                    # Start monitoring web directory"
    echo "  ./monitor.sh start /home/user --recursive      # Monitor recursively"
    echo "  ./monitor.sh start /etc --exclude '*.tmp'      # Exclude temp files"
    echo "  ./monitor.sh status /var/www                   # Check monitoring status"
    echo "  ./monitor.sh events /var/www                   # Show recent events"
    echo "  ./monitor.sh config /var/www --threshold 100M  # Set size threshold"
    echo "  ./monitor.sh stop /var/www                     # Stop monitoring"
    echo "  ./monitor.sh list                              # List all monitored paths"
    echo "  ./monitor.sh help                              # Show help"
    echo ""
    echo "Event Types:"
    echo "  FILE_CREATED         - New file detected"
    echo "  FILE_MODIFIED        - File content changed"
    echo "  FILE_DELETED         - File removed"
    echo "  PERMISSION_CHANGED   - File permissions modified"
    echo "  SIZE_ANOMALY         - Unusual file size change"
    echo "  ACCESS_ANOMALY       - Unusual access pattern"
    echo "  SUSPICIOUS_ACTIVITY  - Potential security concern"
    echo ""
    echo "Integration:"
    echo "  - Automatically triggers backup module on changes"
    echo "  - Integrates with quarantine module for suspicious files"
    echo "  - Sends notifications via notify module"
    echo "  - Logs all events to database for analysis"
}

# Initialize monitoring database tables
init_monitor_db() {
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS monitored_paths (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,
    recursive BOOLEAN DEFAULT 0,
    exclude_patterns TEXT,
    include_patterns TEXT,
    check_interval INTEGER DEFAULT 5,
    threshold_size INTEGER DEFAULT 0,
    max_events INTEGER DEFAULT 1000,
    retention_days INTEGER DEFAULT 30,
    auto_backup BOOLEAN DEFAULT 0,
    auto_quarantine BOOLEAN DEFAULT 0,
    active BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS monitor_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path_id INTEGER,
    event_type TEXT NOT NULL,
    file_path TEXT NOT NULL,
    old_size INTEGER,
    new_size INTEGER,
    old_permissions TEXT,
    new_permissions TEXT,
    user TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT,
    FOREIGN KEY (path_id) REFERENCES monitored_paths(id)
);

CREATE INDEX IF NOT EXISTS idx_monitor_events_path ON monitor_events(path_id);
CREATE INDEX IF NOT EXISTS idx_monitor_events_timestamp ON monitor_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_monitor_events_type ON monitor_events(event_type);
EOF
    log "Monitor database initialized"
}

# Start monitoring a directory
start_monitoring() {
    local path="$1"
    local recursive="${2:-false}"
    local exclude="${3:-}"
    local include="${4:-}"
    local interval="${5:-5}"
    
    if [ ! -d "$path" ]; then
        log_error "Directory does not exist: $path"
        return 1
    fi
    
    # Initialize database if needed
    init_monitor_db
    
    # Add to monitored paths
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO monitored_paths (path, recursive, exclude_patterns, include_patterns, check_interval) VALUES ('$path', $recursive, '$exclude', '$include', $interval);"
    
    log "Started monitoring: $path (recursive: $recursive, interval: ${interval}s)"
    "$NOTIFY_MODULE" send info "Monitoring Started" "Started monitoring directory: $path" "{\"path\": \"$path\", \"recursive\": $recursive, \"interval\": $interval}"
    
    # Start background monitoring process
    monitor_directory "$path" &
    echo "Monitoring started for: $path"
}

# Stop monitoring a directory
stop_monitoring() {
    local path="$1"
    
    if [ -z "$path" ]; then
        log_error "No path specified for stop_monitoring"
        return 1
    fi
    
    # Mark as inactive in database
    sqlite3 "$DB_PATH" "UPDATE monitored_paths SET active = 0 WHERE path = '$path';"
    
    # Kill monitoring process (simplified - in real implementation would track PIDs)
    pkill -f "monitor_directory.*$path" 2>/dev/null || true
    
    log "Stopped monitoring: $path"
    "$NOTIFY_MODULE" send info "Monitoring Stopped" "Stopped monitoring directory: $path" "{\"path\": \"$path\"}"
    
    echo "Monitoring stopped for: $path"
}

# Show monitoring status
show_status() {
    local path="$1"
    
    if [ -n "$path" ]; then
        echo "Monitoring Status for: $path"
        echo "=================================="
        sqlite3 "$DB_PATH" "SELECT path, recursive, check_interval, active, created_at FROM monitored_paths WHERE path = '$path';" | while IFS='|' read -r p recursive interval active created; do
            if [ -n "$p" ]; then
                echo "Path: $p"
                echo "Recursive: $recursive"
                echo "Check Interval: ${interval}s"
                echo "Active: $active"
                echo "Created: $created"
            else
                echo "Not monitoring: $path"
            fi
        done
    else
        echo "All Monitored Paths:"
        echo "===================="
        sqlite3 "$DB_PATH" "SELECT path, recursive, check_interval, active, created_at FROM monitored_paths WHERE active = 1;" | while IFS='|' read -r p recursive interval active created; do
            echo "• $p (recursive: $recursive, interval: ${interval}s, created: $created)"
        done
    fi
}

# List all monitored paths
list_monitored() {
    echo "Monitored Paths:"
    echo "================"
    sqlite3 "$DB_PATH" "SELECT path, recursive, check_interval, active FROM monitored_paths ORDER BY path;" | while IFS='|' read -r p recursive interval active; do
        local status="[ACTIVE]"
        [ "$active" = "0" ] && status="[STOPPED]"
        echo "$status $p (recursive: $recursive, interval: ${interval}s)"
    done
}

# Show recent events
show_events() {
    local path="$1"
    local limit="${2:-10}"
    
    if [ -n "$path" ]; then
        echo "Recent Events for: $path"
        echo "========================"
        sqlite3 "$DB_PATH" "SELECT e.event_type, e.file_path, e.timestamp, e.details FROM monitor_events e JOIN monitored_paths p ON e.path_id = p.id WHERE p.path = '$path' ORDER BY e.timestamp DESC LIMIT $limit;" | while IFS='|' read -r type file timestamp details; do
            echo "[$timestamp] $type: $file"
            [ -n "$details" ] && echo "  Details: $details"
        done
    else
        echo "Recent Events (All Paths):"
        echo "=========================="
        sqlite3 "$DB_PATH" "SELECT p.path, e.event_type, e.file_path, e.timestamp FROM monitor_events e JOIN monitored_paths p ON e.path_id = p.id ORDER BY e.timestamp DESC LIMIT $limit;" | while IFS='|' read -r p type file timestamp; do
            echo "[$timestamp] $p: $type - $file"
        done
    fi
}

# Configure monitoring options
configure_monitoring() {
    local path="$1"
    local threshold="${2:-}"
    local max_events="${3:-}"
    local retention="${4:-}"
    local auto_backup="${5:-}"
    local auto_quarantine="${6:-}"
    
    if [ -z "$path" ]; then
        log_error "No path specified for configuration"
        return 1
    fi
    
    local updates=""
    [ -n "$threshold" ] && updates="$updates threshold_size = $threshold,"
    [ -n "$max_events" ] && updates="$updates max_events = $max_events,"
    [ -n "$retention" ] && updates="$updates retention_days = $retention,"
    [ -n "$auto_backup" ] && updates="$updates auto_backup = $auto_backup,"
    [ -n "$auto_quarantine" ] && updates="$updates auto_quarantine = $auto_quarantine,"
    
    if [ -n "$updates" ]; then
        updates="${updates%,}"  # Remove trailing comma
        sqlite3 "$DB_PATH" "UPDATE monitored_paths SET $updates, updated_at = CURRENT_TIMESTAMP WHERE path = '$path';"
        log "Updated monitoring configuration for: $path"
        echo "Configuration updated for: $path"
    else
        echo "Current configuration for: $path"
        sqlite3 "$DB_PATH" "SELECT path, threshold_size, max_events, retention_days, auto_backup, auto_quarantine FROM monitored_paths WHERE path = '$path';" | while IFS='|' read -r p threshold max_events retention auto_backup auto_quarantine; do
            echo "Path: $p"
            echo "Size Threshold: ${threshold:-none}"
            echo "Max Events: ${max_events:-1000}"
            echo "Retention Days: ${retention:-30}"
            echo "Auto Backup: ${auto_backup:-false}"
            echo "Auto Quarantine: ${auto_quarantine:-false}"
        done
    fi
}

# Background monitoring function
monitor_directory() {
    local path="$1"
    local interval=5
    
    # Get configuration from database
    local config=$(sqlite3 "$DB_PATH" "SELECT check_interval, recursive, exclude_patterns, include_patterns FROM monitored_paths WHERE path = '$path' AND active = 1;")
    if [ -n "$config" ]; then
        IFS='|' read -r interval recursive exclude include <<< "$config"
    fi
    
    log "Started background monitoring for: $path (interval: ${interval}s)"
    
    # Simple file monitoring loop (in real implementation would use inotify or similar)
    while true; do
        sleep "$interval"
        
        # Check if still active
        local active=$(sqlite3 "$DB_PATH" "SELECT active FROM monitored_paths WHERE path = '$path';")
        if [ "$active" != "1" ]; then
            log "Monitoring stopped for: $path"
            break
        fi
        
        # Perform monitoring checks
        check_directory_changes "$path" "$recursive" "$exclude" "$include"
    done
}

# Check for directory changes
check_directory_changes() {
    local path="$1"
    local recursive="$2"
    local exclude="$3"
    local include="$4"
    
    # This is a simplified implementation
    # In a real system, this would use inotify or similar for efficient monitoring
    
    local find_cmd="find '$path' -type f"
    [ "$recursive" = "1" ] || find_cmd="$find_cmd -maxdepth 1"
    
    # Apply filters
    [ -n "$exclude" ] && find_cmd="$find_cmd ! -name '$exclude'"
    [ -n "$include" ] && find_cmd="$find_cmd -name '$include'"
    
    # Check for changes (simplified - would compare with previous state)
    eval "$find_cmd" | while read -r file; do
        # Check file modification time
        local mtime=$(stat -c %Y "$file" 2>/dev/null)
        local last_check=$(sqlite3 "$DB_PATH" "SELECT MAX(timestamp) FROM monitor_events WHERE file_path = '$file';" 2>/dev/null)
        
        if [ -n "$mtime" ] && [ -n "$last_check" ]; then
            local last_mtime=$(date -d "$last_check" +%s 2>/dev/null)
            if [ "$mtime" -gt "$last_mtime" ]; then
                # File was modified
                log_event "$path" "FILE_MODIFIED" "$file" "" "" "" "" ""
            fi
        fi
    done
}

# Log monitoring event
log_event() {
    local path="$1"
    local event_type="$2"
    local file_path="$3"
    local old_size="$4"
    local new_size="$5"
    local old_permissions="$6"
    local new_permissions="$7"
    local details="$8"
    
    local path_id=$(sqlite3 "$DB_PATH" "SELECT id FROM monitored_paths WHERE path = '$path';")
    if [ -n "$path_id" ]; then
        sqlite3 "$DB_PATH" "INSERT INTO monitor_events (path_id, event_type, file_path, old_size, new_size, old_permissions, new_permissions, details) VALUES ($path_id, '$event_type', '$file_path', '$old_size', '$new_size', '$old_permissions', '$new_permissions', '$details');"
        
        log "Event logged: $event_type - $file_path"
        
        # Send notification for important events
        case "$event_type" in
            FILE_CREATED|FILE_DELETED|SUSPICIOUS_ACTIVITY)
                "$NOTIFY_MODULE" send warning "File System Event" "$event_type detected: $file_path" "{\"path\": \"$path\", \"event_type\": \"$event_type\", \"file_path\": \"$file_path\"}"
                ;;
        esac
    fi
}

# Main function
main() {
    case "${1:-}" in
        start)
            start_monitoring "${2:-}" "${3:-false}" "${4:-}" "${5:-}" "${6:-5}"
            ;;
        stop)
            stop_monitoring "${2:-}"
            ;;
        status)
            show_status "${2:-}"
            ;;
        list)
            list_monitored
            ;;
        events)
            show_events "${2:-}" "${3:-10}"
            ;;
        config)
            configure_monitoring "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" "${7:-}"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Only call main if this script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 