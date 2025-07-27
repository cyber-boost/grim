#!/bin/bash
# Automatic Error Relay Daemon for Grim Reaper System
# Monitors mother.db for new errors and automatically relays them to the central system

set -euo pipefail

# ============================================================================
# CONFIGURATION AND SETUP
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASH_CENTRAL_DIR="$REAPER_ROOT/bash_central"

# Source bash_central utilities
if [[ -f "$BASH_CENTRAL_DIR/defaults.sh" ]]; then
    source "$BASH_CENTRAL_DIR/defaults.sh"
fi

if [[ -f "$BASH_CENTRAL_DIR/functions.sh" ]]; then
    source "$BASH_CENTRAL_DIR/functions.sh"
fi

if [[ -f "$BASH_CENTRAL_DIR/config.sh" ]]; then
    source "$BASH_CENTRAL_DIR/config.sh"
fi

# Source init.sh for API functions - only load the functions we need
if [[ -f "$SCRIPT_DIR/init.sh" ]]; then
    # Create temporary file with only the functions we need
    temp_init=$(mktemp)
    
    # Extract only the API functions from init.sh
    sed -n '/^call_api()/,/^}/p; /^relay_error_to_central()/,/^}/p; /^get_or_create_install_id()/,/^}/p' "$SCRIPT_DIR/init.sh" > "$temp_init"
    
    # Also extract the SH_GRIM_CONFIG array declaration and setup
    sed -n '/^declare -A SH_GRIM_CONFIG/,/^SH_GRIM_CONFIG\[api_key\]/p' "$SCRIPT_DIR/init.sh" >> "$temp_init"
    
    source "$temp_init" 2>/dev/null || true
    rm -f "$temp_init"
fi

# Set up basic SH_GRIM_CONFIG if not already set
if [[ -z "${SH_GRIM_CONFIG[api_endpoint]:-}" ]]; then
    declare -A SH_GRIM_CONFIG
    SH_GRIM_CONFIG[api_endpoint]="${GRIM_API_ENDPOINT:-http://localhost:4746}"
    SH_GRIM_CONFIG[api_key]="${GRIM_API_KEY:-default-api-key}"
    SH_GRIM_CONFIG[app_version]="1.0.0"
fi

# Daemon configuration
DAEMON_NAME="grim-error-relay"
RELAY_INTERVAL=${GRIM_ERROR_RELAY_INTERVAL:-300}  # 5 minutes by default
MAX_RETRY_ATTEMPTS=${GRIM_ERROR_RELAY_MAX_RETRIES:-3}
RETRY_DELAY=${GRIM_ERROR_RELAY_RETRY_DELAY:-60}   # 1 minute between retries
LOG_FILE="$REAPER_ROOT/logs/error_relay_daemon.log"
PID_FILE="$REAPER_ROOT/tmp/error_relay_daemon.pid"

# Database paths
GRAVEYARD_DIR="$REAPER_ROOT/.graveyard"
RIP_DIR="$GRAVEYARD_DIR/.rip"
MOTHER_DB="$RIP_DIR/mother.db"
INIT_INFO="$RIP_DIR/init-info.json"

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================
log_daemon() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also log to syslog if available
    if command_exists logger; then
        logger -t "$DAEMON_NAME" "[$level] $message"
    fi
}

log_info() {
    log_daemon "INFO" "$1"
}

log_error() {
    log_daemon "ERROR" "$1"
}

log_warning() {
    log_daemon "WARNING" "$1"
}

log_debug() {
    log_daemon "DEBUG" "$1"
}

# ============================================================================
# DATABASE FUNCTIONS
# ============================================================================
init_relay_tracking() {
    if [[ ! -f "$MOTHER_DB" ]]; then
        log_error "Mother database not found: $MOTHER_DB"
        return 1
    fi
    
    if ! command_exists sqlite3; then
        log_error "sqlite3 not available"
        return 1
    fi
    
    # Create error relay tracking table if it doesn't exist
    sqlite3 "$MOTHER_DB" <<EOF
CREATE TABLE IF NOT EXISTS error_relay_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    last_relay_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    errors_relayed INTEGER DEFAULT 0,
    relay_status TEXT DEFAULT 'success',
    retry_count INTEGER DEFAULT 0
);

-- Insert initial record if table is empty
INSERT OR IGNORE INTO error_relay_log (id, last_relay_timestamp, errors_relayed, relay_status)
SELECT 1, datetime('now', '-1 hour'), 0, 'initial'
WHERE NOT EXISTS (SELECT 1 FROM error_relay_log WHERE id = 1);
EOF
    
    if [[ $? -eq 0 ]]; then
        log_info "Error relay tracking initialized"
        return 0
    else
        log_error "Failed to initialize error relay tracking"
        return 1
    fi
}

get_last_relay_timestamp() {
    if [[ ! -f "$MOTHER_DB" ]]; then
        echo ""
        return 1
    fi
    
    local last_timestamp
    last_timestamp=$(sqlite3 "$MOTHER_DB" "SELECT last_relay_timestamp FROM error_relay_log WHERE id = 1;" 2>/dev/null || echo "")
    echo "$last_timestamp"
}

update_relay_timestamp() {
    local errors_count="$1"
    local status="$2"
    local retry_count="${3:-0}"
    
    if [[ ! -f "$MOTHER_DB" ]]; then
        return 1
    fi
    
    sqlite3 "$MOTHER_DB" <<EOF
UPDATE error_relay_log 
SET last_relay_timestamp = datetime('now'),
    errors_relayed = $errors_count,
    relay_status = '$status',
    retry_count = $retry_count
WHERE id = 1;
EOF
}

get_new_errors_since() {
    local since_timestamp="$1"
    
    if [[ ! -f "$MOTHER_DB" ]]; then
        return 1
    fi
    
    # Get errors that are newer than the last relay timestamp
    sqlite3 "$MOTHER_DB" <<EOF
SELECT id, timestamp, error_type, error_message, context 
FROM errors 
WHERE datetime(timestamp) > datetime('$since_timestamp')
ORDER BY timestamp ASC;
EOF
}

# ============================================================================
# ERROR RELAY FUNCTIONS
# ============================================================================
get_install_id() {
    if [[ ! -f "$INIT_INFO" ]]; then
        log_error "Init info not found: $INIT_INFO"
        return 1
    fi
    
    local install_id=""
    
    if command_exists jq; then
        install_id=$(jq -r '.install_id // empty' "$INIT_INFO" 2>/dev/null)
    elif command_exists python3; then
        install_id=$(python3 -c "
import json, sys
try:
    with open('$INIT_INFO') as f:
        data = json.load(f)
    print(data.get('install_id', ''))
except: pass
" 2>/dev/null)
    fi
    
    if [[ -z "$install_id" ]]; then
        log_error "Could not determine install_id"
        return 1
    fi
    
    echo "$install_id"
}

relay_single_error() {
    local install_id="$1"
    local error_id="$2"
    local timestamp="$3"
    local error_type="$4"
    local error_message="$5"
    local context="$6"
    
    # Determine severity based on error_type
    local severity="medium"
    case "$error_type" in
        *critical*|*fatal*|*fail*|*CRITICAL*|*FATAL*|*FAIL*) severity="high" ;;
        *warning*|*warn*|*WARNING*|*WARN*) severity="low" ;;
        *) severity="medium" ;;
    esac
    
    # Prepare error data for API call
    local hostname=$(hostname)
    local user=$(whoami)
    local platform=$(uname -s)
    local arch=$(uname -m)
    local api_key="${SH_GRIM_CONFIG[api_key]:-default-api-key}"
    local version="${SH_GRIM_CONFIG[app_version]:-1.0.0}"
    
    local error_data=$(cat <<EOF
{
  "install_id": "$install_id",
  "api_key": "$api_key",
  "error_type": "$error_type",
  "error_message": "$error_message",
  "error_details": "$context",
  "severity": "$severity",
  "version": "$version",
  "os": "$platform",
  "arch": "$arch",
  "hostname": "$hostname",
  "user": "$user",
  "local_error_id": $error_id,
  "local_timestamp": "$timestamp"
}
EOF
    )
    
    # Call the API
    if call_api "/cry_to_mom" "POST" "$error_data" >/dev/null 2>&1; then
        log_debug "Relayed error $error_id: $error_type"
        return 0
    else
        log_warning "Failed to relay error $error_id: $error_type"
        return 1
    fi
}

relay_new_errors() {
    local install_id="$1"
    local last_timestamp="$2"
    
    local error_count=0
    local relayed_count=0
    local failed_count=0
    
    log_info "Checking for new errors since: $last_timestamp"
    
    # Get new errors and relay them
    while IFS='|' read -r error_id timestamp error_type error_message context; do
        if [[ -n "$error_id" ]]; then
            ((error_count++))
            
            if relay_single_error "$install_id" "$error_id" "$timestamp" "$error_type" "$error_message" "$context"; then
                ((relayed_count++))
            else
                ((failed_count++))
            fi
        fi
    done < <(get_new_errors_since "$last_timestamp" 2>/dev/null)
    
    log_info "Error relay summary: $error_count found, $relayed_count relayed, $failed_count failed"
    
    # Update relay timestamp if we found any errors
    if [[ $error_count -gt 0 ]]; then
        if [[ $failed_count -eq 0 ]]; then
            update_relay_timestamp "$relayed_count" "success" 0
            log_info "All errors relayed successfully"
        else
            update_relay_timestamp "$relayed_count" "partial" 0
            log_warning "$failed_count errors failed to relay"
        fi
    fi
    
    return $failed_count
}

# ============================================================================
# DAEMON CONTROL FUNCTIONS
# ============================================================================
is_daemon_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # Stale PID file, remove it
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

stop_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]]; then
            if kill -TERM "$pid" 2>/dev/null; then
                log_info "Sent TERM signal to daemon (PID: $pid)"
                
                # Wait for graceful shutdown (up to 10 seconds)
                local count=0
                while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
                    sleep 1
                    ((count++))
                done
                
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    kill -KILL "$pid" 2>/dev/null
                    log_warning "Force killed daemon (PID: $pid)"
                else
                    log_info "Daemon stopped gracefully"
                fi
            fi
        fi
        rm -f "$PID_FILE"
    fi
}

start_daemon() {
    if is_daemon_running; then
        echo "Error relay daemon is already running (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    # Ensure required directories exist
    ensure_dir "$(dirname "$LOG_FILE")"
    ensure_dir "$(dirname "$PID_FILE")"
    
    # Initialize error relay tracking
    if ! init_relay_tracking; then
        echo "Failed to initialize error relay tracking"
        return 1
    fi
    
    # Start daemon in background
    echo "Starting error relay daemon..."
    nohup "$0" run-daemon > /dev/null 2>&1 &
    local daemon_pid=$!
    
    # Save PID
    echo "$daemon_pid" > "$PID_FILE"
    
    # Wait a moment to ensure it started successfully
    sleep 2
    
    if is_daemon_running; then
        echo "Error relay daemon started successfully (PID: $daemon_pid)"
        echo "Logs: $LOG_FILE"
        return 0
    else
        echo "Failed to start error relay daemon"
        rm -f "$PID_FILE"
        return 1
    fi
}

run_daemon() {
    log_info "Error relay daemon starting (PID: $$)"
    
    # Set up signal handlers for graceful shutdown
    trap 'log_info "Received TERM signal, shutting down..."; exit 0' TERM
    trap 'log_info "Received INT signal, shutting down..."; exit 0' INT
    
    # Main daemon loop
    while true; do
        # Get install_id
        local install_id
        if ! install_id=$(get_install_id); then
            log_error "Could not get install_id, skipping relay cycle"
            sleep "$RELAY_INTERVAL"
            continue
        fi
        
        # Get last relay timestamp
        local last_timestamp
        last_timestamp=$(get_last_relay_timestamp)
        if [[ -z "$last_timestamp" ]]; then
            log_error "Could not get last relay timestamp, skipping relay cycle"
            sleep "$RELAY_INTERVAL"
            continue
        fi
        
        # Relay new errors with retry logic
        local retry_count=0
        local relay_success=false
        
        while [[ $retry_count -lt $MAX_RETRY_ATTEMPTS ]] && [[ "$relay_success" == "false" ]]; do
            if relay_new_errors "$install_id" "$last_timestamp"; then
                relay_success=true
                break
            else
                ((retry_count++))
                if [[ $retry_count -lt $MAX_RETRY_ATTEMPTS ]]; then
                    log_warning "Relay attempt $retry_count failed, retrying in ${RETRY_DELAY}s"
                    sleep "$RETRY_DELAY"
                fi
            fi
        done
        
        if [[ "$relay_success" == "false" ]]; then
            log_error "All relay attempts failed, will retry in next cycle"
            update_relay_timestamp 0 "failed" "$retry_count"
        fi
        
        # Sleep until next relay cycle
        log_debug "Sleeping for ${RELAY_INTERVAL}s until next relay cycle"
        sleep "$RELAY_INTERVAL"
    done
}

show_daemon_status() {
    echo "=== Error Relay Daemon Status ==="
    
    if is_daemon_running; then
        local pid=$(cat "$PID_FILE")
        echo "Status: RUNNING (PID: $pid)"
        
        # Show last few log entries
        if [[ -f "$LOG_FILE" ]]; then
            echo ""
            echo "Recent log entries:"
            tail -n 5 "$LOG_FILE"
        fi
        
        # Show relay statistics from database
        if [[ -f "$MOTHER_DB" ]] && command_exists sqlite3; then
            echo ""
            echo "Relay statistics:"
            sqlite3 "$MOTHER_DB" <<EOF
SELECT 
    'Last relay: ' || last_relay_timestamp,
    'Errors relayed: ' || errors_relayed,
    'Status: ' || relay_status,
    'Retry count: ' || retry_count
FROM error_relay_log WHERE id = 1;
EOF
        fi
    else
        echo "Status: STOPPED"
    fi
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================
show_help() {
    echo "Grim Reaper Error Relay Daemon"
    echo ""
    echo "Usage: $0 {start|stop|restart|status|run-daemon}"
    echo ""
    echo "Commands:"
    echo "  start      - Start the error relay daemon"
    echo "  stop       - Stop the error relay daemon"
    echo "  restart    - Restart the error relay daemon"
    echo "  status     - Show daemon status and recent activity"
    echo "  run-daemon - Run daemon in foreground (internal use)"
    echo ""
    echo "Environment Variables:"
    echo "  GRIM_ERROR_RELAY_INTERVAL     - Relay interval in seconds (default: 300)"
    echo "  GRIM_ERROR_RELAY_MAX_RETRIES  - Max retry attempts (default: 3)"
    echo "  GRIM_ERROR_RELAY_RETRY_DELAY  - Delay between retries in seconds (default: 60)"
    echo ""
    echo "Log file: $LOG_FILE"
    echo "PID file: $PID_FILE"
}

main() {
    case "${1:-}" in
        start)
            start_daemon
            ;;
        stop)
            stop_daemon
            ;;
        restart)
            stop_daemon
            sleep 2
            start_daemon
            ;;
        status)
            show_daemon_status
            ;;
        run-daemon)
            run_daemon
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

main "$@"