#!/bin/bash
# Scribe Audit Logging System: Comprehensive security event logging

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
SCRIBE_DB="$GRIM_ROOT/db/scribe.db"
SCRIBE_LOG="$GRIM_ROOT/logs/scribe.log"
AUDIT_LOG="$GRIM_ROOT/logs/security_audit.log"
FORENSICS_DIR="$GRIM_ROOT/forensics"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Audit configuration
LOG_RETENTION_DAYS="${log_retention_days:-90}"
ENABLE_LOG_ENCRYPTION="${enable_log_encryption:-true}"
ENABLE_LOG_INTEGRITY="${enable_log_integrity:-true}"
ENABLE_FORENSICS="${enable_forensics:-true}"
LOG_LEVEL="${log_level:-info}"

# Secure logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SCRIBE_LOG"
}

# Security audit logging
audit_log() {
    local event_type="$1"
    local message="$2"
    local user="${SUDO_USER:-$USER}"
    local session_id="${SSH_SESSION_ID:-$(who am i | awk '{print $2}' | sed 's/[()]//g')}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUDIT] [$event_type] [$user] [$session_id] $message" >> "$AUDIT_LOG"
}

# Initialize Scribe database
init_scribe_db() {
    sqlite3 "$SCRIBE_DB" <<EOF
CREATE TABLE IF NOT EXISTS security_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    event_category TEXT NOT NULL,
    severity TEXT DEFAULT 'info',
    source TEXT,
    target TEXT,
    user_id TEXT,
    session_id TEXT,
    ip_address TEXT,
    user_agent TEXT,
    details TEXT,
    metadata TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    encrypted BOOLEAN DEFAULT FALSE,
    integrity_hash TEXT
);

CREATE TABLE IF NOT EXISTS file_access_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    access_type TEXT NOT NULL,
    user_id TEXT,
    process_id INTEGER,
    success BOOLEAN,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    file_hash TEXT,
    file_size INTEGER
);

CREATE TABLE IF NOT EXISTS network_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_ip TEXT,
    destination_ip TEXT,
    source_port INTEGER,
    destination_port INTEGER,
    protocol TEXT,
    event_type TEXT,
    connection_status TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id TEXT,
    process_name TEXT
);

CREATE TABLE IF NOT EXISTS user_activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    action_type TEXT NOT NULL,
    target_resource TEXT,
    success BOOLEAN,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    ip_address TEXT,
    user_agent TEXT,
    details TEXT
);

CREATE TABLE IF NOT EXISTS system_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    component TEXT,
    severity TEXT DEFAULT 'info',
    message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    system_state TEXT
);

CREATE TABLE IF NOT EXISTS log_integrity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    log_file TEXT NOT NULL,
    hash_algorithm TEXT DEFAULT 'sha256',
    file_hash TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS forensics_evidence (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    evidence_type TEXT NOT NULL,
    evidence_source TEXT NOT NULL,
    collection_method TEXT,
    hash_value TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    preserved BOOLEAN DEFAULT TRUE,
    location TEXT
);

CREATE INDEX IF NOT EXISTS idx_events_type ON security_events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_category ON security_events(event_category);
CREATE INDEX IF NOT EXISTS idx_events_severity ON security_events(severity);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON security_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_file_access_path ON file_access_logs(file_path);
CREATE INDEX IF NOT EXISTS idx_network_source ON network_events(source_ip);
CREATE INDEX IF NOT EXISTS idx_user_activity_user ON user_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_system_events_type ON system_events(event_type);
CREATE INDEX IF NOT EXISTS idx_integrity_file ON log_integrity(log_file);
CREATE INDEX IF NOT EXISTS idx_forensics_type ON forensics_evidence(evidence_type);
EOF
    log "Scribe database initialized"
    audit_log "DB_INIT" "Scribe database initialized"
}

# Log security event
log_security_event() {
    local event_type="$1"
    local event_category="$2"
    local details="$3"
    local severity="${4:-info}"
    local source="${5:-}"
    local target="${6:-}"
    
    # Get user and session information
    local user_id="${SUDO_USER:-$USER}"
    local session_id="${SSH_SESSION_ID:-$(who am i | awk '{print $2}' | sed 's/[()]//g')}"
    local ip_address=$(who am i | awk '{print $5}' | sed 's/[()]//g' 2>/dev/null || echo "unknown")
    local user_agent="${HTTP_USER_AGENT:-unknown}"
    
    # Create metadata
    local metadata="{\"pid\": $$, \"ppid\": $PPID, \"uid\": $(id -u), \"gid\": $(id -g), \"cwd\": $(pwd)}"
    
    # Generate integrity hash if enabled
    local integrity_hash=""
    if [[ "$ENABLE_LOG_INTEGRITY" == "true" ]]; then
        integrity_hash=$(echo -n "${event_type}:${event_category}:${details}:${timestamp}" | sha256sum | cut -d' ' -f1)
    fi
    
    # Insert event
    sqlite3 "$SCRIBE_DB" <<EOF
INSERT INTO security_events (event_type, event_category, severity, source, target, user_id, session_id, ip_address, user_agent, details, metadata, integrity_hash)
VALUES ('$event_type', '$event_category', '$severity', '$source', '$target', '$user_id', '$session_id', '$ip_address', '$user_agent', '$details', '$metadata', '$integrity_hash');
EOF
    
    log "Security event logged: $event_type ($severity) - $details"
    audit_log "SECURITY_EVENT" "Type: $event_type, Category: $event_category, Severity: $severity"
}

# Log file access
log_file_access() {
    local file_path="$1"
    local access_type="$2"
    local success="${3:-true}"
    local user_id="${4:-${SUDO_USER:-$USER}}"
    
    # Get file information
    local file_hash=""
    local file_size="0"
    if [[ -f "$file_path" ]]; then
        file_hash=$(sha256sum "$file_path" | cut -d' ' -f1 2>/dev/null || echo "")
        file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
    fi
    
    sqlite3 "$SCRIBE_DB" <<EOF
INSERT INTO file_access_logs (file_path, access_type, user_id, process_id, success, file_hash, file_size)
VALUES ('$file_path', '$access_type', '$user_id', $$, $success, '$file_hash', $file_size);
EOF
    
    log "File access logged: $access_type $file_path (success: $success)"
}

# Log network event
log_network_event() {
    local source_ip="$1"
    local destination_ip="$2"
    local source_port="$3"
    local destination_port="$4"
    local protocol="$5"
    local event_type="$6"
    local connection_status="$7"
    local user_id="${8:-${SUDO_USER:-$USER}}"
    local process_name="${9:-$(ps -p $$ -o comm=)}"
    
    sqlite3 "$SCRIBE_DB" <<EOF
INSERT INTO network_events (source_ip, destination_ip, source_port, destination_port, protocol, event_type, connection_status, user_id, process_name)
VALUES ('$source_ip', '$destination_ip', $source_port, $destination_port, '$protocol', '$event_type', '$connection_status', '$user_id', '$process_name');
EOF
    
    log "Network event logged: $event_type $source_ip:$source_port -> $destination_ip:$destination_port ($protocol)"
}

# Log user activity
log_user_activity() {
    local user_id="$1"
    local action_type="$2"
    local target_resource="$3"
    local success="${4:-true}"
    local details="${5:-}"
    
    local session_id="${SSH_SESSION_ID:-$(who am i | awk '{print $2}' | sed 's/[()]//g')}"
    local ip_address=$(who am i | awk '{print $5}' | sed 's/[()]//g' 2>/dev/null || echo "unknown")
    local user_agent="${HTTP_USER_AGENT:-unknown}"
    
    sqlite3 "$SCRIBE_DB" <<EOF
INSERT INTO user_activity (user_id, action_type, target_resource, success, session_id, ip_address, user_agent, details)
VALUES ('$user_id', '$action_type', '$target_resource', $success, '$session_id', '$ip_address', '$user_agent', '$details');
EOF
    
    log "User activity logged: $user_id $action_type $target_resource (success: $success)"
}

# Log system event
log_system_event() {
    local event_type="$1"
    local component="$2"
    local message="$3"
    local severity="${4:-info}"
    local system_state="${5:-}"
    
    sqlite3 "$SCRIBE_DB" <<EOF
INSERT INTO system_events (event_type, component, severity, message, system_state)
VALUES ('$event_type', '$component', '$severity', '$message', '$system_state');
EOF
    
    log "System event logged: $event_type ($severity) - $message"
}

# Verify log integrity
verify_log_integrity() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        return 1
    fi
    
    local current_hash=$(sha256sum "$log_file" | cut -d' ' -f1)
    local stored_hash=$(sqlite3 "$SCRIBE_DB" "SELECT file_hash FROM log_integrity WHERE log_file = '$log_file' ORDER BY timestamp DESC LIMIT 1")
    
    if [[ -z "$stored_hash" ]]; then
        # First time checking this file
        sqlite3 "$SCRIBE_DB" "INSERT INTO log_integrity (log_file, file_hash) VALUES ('$log_file', '$current_hash')"
        return 0
    fi
    
    if [[ "$current_hash" == "$stored_hash" ]]; then
        return 0
    else
        log "Log integrity check failed: $log_file"
        sqlite3 "$SCRIBE_DB" "UPDATE log_integrity SET verified = 0 WHERE log_file = '$log_file'"
        return 1
    fi
}

# Collect forensics evidence
collect_forensics_evidence() {
    local evidence_type="$1"
    local evidence_source="$2"
    local collection_method="$3"
    
    if [[ "$ENABLE_FORENSICS" != "true" ]]; then
        return 0
    fi
    
    mkdir -p "$FORENSICS_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local evidence_file="$FORENSICS_DIR/${evidence_type}_${timestamp}.evidence"
    local hash_value=""
    
    case "$evidence_type" in
        process_list)
            ps aux > "$evidence_file"
            hash_value=$(sha256sum "$evidence_file" | cut -d' ' -f1)
            ;;
        network_connections)
            netstat -tuln > "$evidence_file"
            hash_value=$(sha256sum "$evidence_file" | cut -d' ' -f1)
            ;;
        file_system)
            find /tmp /var/tmp -type f -mtime -1 > "$evidence_file"
            hash_value=$(sha256sum "$evidence_file" | cut -d' ' -f1)
            ;;
        memory_dump)
            # Placeholder for memory dump
            echo "Memory dump would be collected here" > "$evidence_file"
            hash_value=$(sha256sum "$evidence_file" | cut -d' ' -f1)
            ;;
        *)
            log "Unknown evidence type: $evidence_type"
            return 1
            ;;
    esac
    
    sqlite3 "$SCRIBE_DB" <<EOF
INSERT INTO forensics_evidence (evidence_type, evidence_source, collection_method, hash_value, location)
VALUES ('$evidence_type', '$evidence_source', '$collection_method', '$hash_value', '$evidence_file');
EOF
    
    log "Forensics evidence collected: $evidence_type -> $evidence_file"
    audit_log "FORENSICS_COLLECTED" "Type: $evidence_type, Source: $evidence_source, File: $evidence_file"
}

# Analyze security events
analyze_security_events() {
    local time_period="${1:-24h}"
    local severity_filter="${2:-}"
    
    echo -e "${CYAN}=== Security Event Analysis (Last $time_period) ===${NC}"
    
    local where_clause="WHERE timestamp > datetime('now', '-$time_period')"
    if [[ -n "$severity_filter" ]]; then
        where_clause="$where_clause AND severity = '$severity_filter'"
    fi
    
    # Event count by type
    echo -e "${YELLOW}Events by Type:${NC}"
    sqlite3 "$SCRIBE_DB" "SELECT event_type, COUNT(*) as count FROM security_events $where_clause GROUP BY event_type ORDER BY count DESC" | while IFS='|' read -r event_type count; do
        echo "  $event_type: $count"
    done
    
    # Event count by severity
    echo -e "${YELLOW}Events by Severity:${NC}"
    sqlite3 "$SCRIBE_DB" "SELECT severity, COUNT(*) as count FROM security_events $where_clause GROUP BY severity ORDER BY count DESC" | while IFS='|' read -r severity count; do
        echo "  $severity: $count"
    done
    
    # Recent events
    echo -e "${YELLOW}Recent Events:${NC}"
    sqlite3 "$SCRIBE_DB" "SELECT event_type, severity, user_id, timestamp FROM security_events $where_clause ORDER BY timestamp DESC LIMIT 10" | while IFS='|' read -r event_type severity user_id timestamp; do
        echo "  $event_type ($severity) by $user_id at $timestamp"
    done
}

# Get audit statistics
get_audit_stats() {
    echo -e "${CYAN}=== Audit Logging Statistics ===${NC}"
    
    local total_events=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM security_events")
    local total_file_access=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM file_access_logs")
    local total_network_events=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM network_events")
    local total_user_activity=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM user_activity")
    local total_system_events=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM system_events")
    local total_forensics=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM forensics_evidence")
    
    echo "Total security events: $total_events"
    echo "Total file access logs: $total_file_access"
    echo "Total network events: $total_network_events"
    echo "Total user activity: $total_user_activity"
    echo "Total system events: $total_system_events"
    echo "Total forensics evidence: $total_forensics"
    
    # Check log integrity
    local integrity_failures=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM log_integrity WHERE verified = 0")
    if [[ $integrity_failures -gt 0 ]]; then
        echo -e "${RED}Log integrity failures: $integrity_failures${NC}"
    else
        echo -e "${GREEN}Log integrity: OK${NC}"
    fi
}

# Clean up old logs
cleanup_old_logs() {
    local days="${1:-$LOG_RETENTION_DAYS}"
    
    local deleted_events=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM security_events WHERE timestamp < datetime('now', '-$days days')")
    local deleted_file_access=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM file_access_logs WHERE timestamp < datetime('now', '-$days days')")
    local deleted_network=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM network_events WHERE timestamp < datetime('now', '-$days days')")
    local deleted_user_activity=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM user_activity WHERE timestamp < datetime('now', '-$days days')")
    local deleted_system=$(sqlite3 "$SCRIBE_DB" "SELECT COUNT(*) FROM system_events WHERE timestamp < datetime('now', '-$days days')")
    
    sqlite3 "$SCRIBE_DB" <<EOF
DELETE FROM security_events WHERE timestamp < datetime('now', '-$days days');
DELETE FROM file_access_logs WHERE timestamp < datetime('now', '-$days days');
DELETE FROM network_events WHERE timestamp < datetime('now', '-$days days');
DELETE FROM user_activity WHERE timestamp < datetime('now', '-$days days');
DELETE FROM system_events WHERE timestamp < datetime('now', '-$days days');
DELETE FROM log_integrity WHERE timestamp < datetime('now', '-$days days');
EOF
    
    local total_deleted=$((deleted_events + deleted_file_access + deleted_network + deleted_user_activity + deleted_system))
    log "Cleaned up $total_deleted old log entries (older than $days days)"
    audit_log "LOGS_CLEANUP" "Deleted: $total_deleted entries, Retention: $days days"
}

# Show help
show_help() {
    echo -e "${CYAN}Scribe Audit Logging System${NC}"
    echo "Comprehensive security event logging and forensics."
    echo ""
    echo "Usage: grim scribe <command> [options]"
    echo ""
    echo "Commands:"
    echo "  events [period] [severity]           - Analyze security events"
    echo "  file-access [file]                   - Log file access"
    echo "  network [src] [dst] [port] [proto]   - Log network event"
    echo "  user-activity [user] [action] [target] - Log user activity"
    echo "  system-event [type] [component] [msg] - Log system event"
    echo "  forensics [type] [source] [method]   - Collect forensics evidence"
    echo "  verify [log_file]                    - Verify log integrity"
    echo "  stats                                 - Show audit statistics"
    echo "  cleanup [days]                       - Clean up old logs"
    echo "  init                                  - Initialize audit system"
    echo "  help                                  - Show this help"
    echo ""
    echo "Examples:"
    echo "  grim scribe events 24h high"
    echo "  grim scribe file-access /etc/passwd read"
    echo "  grim scribe forensics process_list system manual"
    echo "  grim scribe stats"
    echo ""
    echo "Configuration:"
    echo "  Log retention: ${LOG_RETENTION_DAYS} days"
    echo "  Log encryption: $ENABLE_LOG_ENCRYPTION"
    echo "  Log integrity: $ENABLE_LOG_INTEGRITY"
    echo "  Forensics: $ENABLE_FORENSICS"
    echo "  Log level: $LOG_LEVEL"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        events)
            analyze_security_events "$1" "$2"
            ;;
        file-access)
            if [[ $# -lt 2 ]]; then
                echo "Usage: grim scribe file-access <file> <access_type> [success] [user]"
                return 1
            fi
            log_file_access "$1" "$2" "$3" "$4"
            ;;
        network)
            if [[ $# -lt 6 ]]; then
                echo "Usage: grim scribe network <src_ip> <dst_ip> <src_port> <dst_port> <protocol> <event_type> [status] [user] [process]"
                return 1
            fi
            log_network_event "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
            ;;
        user-activity)
            if [[ $# -lt 3 ]]; then
                echo "Usage: grim scribe user-activity <user> <action> <target> [success] [details]"
                return 1
            fi
            log_user_activity "$1" "$2" "$3" "$4" "$5"
            ;;
        system-event)
            if [[ $# -lt 3 ]]; then
                echo "Usage: grim scribe system-event <type> <component> <message> [severity] [state]"
                return 1
            fi
            log_system_event "$1" "$2" "$3" "$4" "$5"
            ;;
        forensics)
            if [[ $# -lt 3 ]]; then
                echo "Usage: grim scribe forensics <type> <source> <method>"
                return 1
            fi
            collect_forensics_evidence "$1" "$2" "$3"
            ;;
        verify)
            if [[ $# -lt 1 ]]; then
                echo "Usage: grim scribe verify <log_file>"
                return 1
            fi
            verify_log_integrity "$1"
            ;;
        stats)
            get_audit_stats
            ;;
        cleanup)
            cleanup_old_logs "$1"
            ;;
        init)
            init_scribe_db
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            return 1
            ;;
    esac
}

# Initialize on first run
init_scribe_db

# Only call main if this script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 