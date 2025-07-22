#!/bin/bash
# Lookouts Threat Detection System: Real-time security monitoring

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOOKOUTS_DB="$GRIM_ROOT/db/lookouts.db"
LOOKOUTS_LOG="$GRIM_ROOT/logs/lookouts.log"
AUDIT_LOG="$GRIM_ROOT/logs/security_audit.log"
THREAT_INTEL_DIR="$GRIM_ROOT/config/threat_intel"
SIGNATURES_DIR="$GRIM_ROOT/config/signatures"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Security configuration
SCAN_INTERVAL="${scan_interval:-30}"
THREAT_LEVEL="${threat_level:-medium}"
ENABLE_BEHAVIORAL="${enable_behavioral:-true}"
ENABLE_ANOMALY="${enable_anomaly:-true}"
ENABLE_SIGNATURES="${enable_signatures:-true}"
MAX_THREATS_PER_HOUR="${max_threats_per_hour:-100}"

# Secure logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOOKOUTS_LOG"
}

# Security audit logging
audit_log() {
    local event_type="$1"
    local message="$2"
    local user="${SUDO_USER:-$USER}"
    local session_id="${SSH_SESSION_ID:-$(who am i | awk '{print $2}' | sed 's/[()]//g')}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUDIT] [$event_type] [$user] [$session_id] $message" >> "$AUDIT_LOG"
}

# Initialize Lookouts database
init_lookouts_db() {
    sqlite3 "$LOOKOUTS_DB" <<EOF
CREATE TABLE IF NOT EXISTS threats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    threat_type TEXT NOT NULL,
    severity TEXT DEFAULT 'medium',
    source TEXT,
    target TEXT,
    signature TEXT,
    details TEXT,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'active',
    response_action TEXT,
    false_positive BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS threat_signatures (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    signature_name TEXT NOT NULL,
    signature_pattern TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    severity TEXT DEFAULT 'medium',
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS behavioral_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_name TEXT NOT NULL,
    pattern_type TEXT NOT NULL,
    baseline_data TEXT,
    threshold REAL,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS threat_intel (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ioc_type TEXT NOT NULL,
    ioc_value TEXT NOT NULL,
    threat_name TEXT,
    confidence REAL DEFAULT 0.8,
    source TEXT,
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS system_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    event_source TEXT,
    event_data TEXT,
    severity TEXT DEFAULT 'info',
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_threats_type ON threats(threat_type);
CREATE INDEX IF NOT EXISTS idx_threats_severity ON threats(severity);
CREATE INDEX IF NOT EXISTS idx_threats_status ON threats(status);
CREATE INDEX IF NOT EXISTS idx_signatures_name ON threat_signatures(signature_name);
CREATE INDEX IF NOT EXISTS idx_intel_ioc ON threat_intel(ioc_value);
CREATE INDEX IF NOT EXISTS idx_events_type ON system_events(event_type);
EOF
    log "Lookouts database initialized"
    audit_log "DB_INIT" "Lookouts database initialized"
}

# Load threat signatures
load_threat_signatures() {
    mkdir -p "$SIGNATURES_DIR"
    
    # Load default signatures
    sqlite3 "$LOOKOUTS_DB" <<EOF
INSERT OR IGNORE INTO threat_signatures (signature_name, signature_pattern, threat_type, severity) VALUES
('suspicious_process', '.*(nc|netcat|telnet|ssh-keygen).*', 'process_anomaly', 'high'),
('suspicious_file', '.*\.(exe|bat|cmd|ps1|vbs|js|py)$', 'file_anomaly', 'medium'),
('suspicious_network', '.*(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.).*', 'network_anomaly', 'low'),
('suspicious_user', '.*(root|admin|test|guest).*', 'user_anomaly', 'medium'),
('suspicious_command', '.*(rm -rf|dd if=|format|fdisk).*', 'command_anomaly', 'high'),
('suspicious_connection', '.*(22|23|3389|5900|5901).*', 'connection_anomaly', 'medium');
EOF
    
    log "Threat signatures loaded"
}

# Load threat intelligence
load_threat_intelligence() {
    mkdir -p "$THREAT_INTEL_DIR"
    
    # Load default threat intelligence
    sqlite3 "$LOOKOUTS_DB" <<EOF
INSERT OR IGNORE INTO threat_intel (ioc_type, ioc_value, threat_name, confidence, source) VALUES
('ip', '192.168.1.100', 'malware_c2', 0.9, 'default'),
('domain', 'malware.example.com', 'malware_c2', 0.8, 'default'),
('hash', 'd41d8cd98f00b204e9800998ecf8427e', 'suspicious_file', 0.7, 'default'),
('url', 'http://malware.example.com/payload', 'malware_download', 0.9, 'default');
EOF
    
    log "Threat intelligence loaded"
}

# Detect threats using signatures
detect_signature_threats() {
    if [[ "$ENABLE_SIGNATURES" != "true" ]]; then
        return 0
    fi
    
    log "Running signature-based threat detection"
    
    # Check running processes
    ps aux | while read -r line; do
        local process_info="$line"
        sqlite3 "$LOOKOUTS_DB" "SELECT signature_name, signature_pattern, threat_type, severity FROM threat_signatures WHERE enabled = 1 AND threat_type = 'process_anomaly'" | while IFS='|' read -r sig_name pattern threat_type severity; do
            if echo "$process_info" | grep -qE "$pattern"; then
                record_threat "$threat_type" "$severity" "process" "process" "$sig_name" "Suspicious process detected: $process_info"
            fi
        done
    done
    
    # Check network connections
    netstat -tuln 2>/dev/null | while read -r line; do
        local connection_info="$line"
        sqlite3 "$LOOKOUTS_DB" "SELECT signature_name, signature_pattern, threat_type, severity FROM threat_signatures WHERE enabled = 1 AND threat_type = 'connection_anomaly'" | while IFS='|' read -r sig_name pattern threat_type severity; do
            if echo "$connection_info" | grep -qE "$pattern"; then
                record_threat "$threat_type" "$severity" "network" "connection" "$sig_name" "Suspicious connection detected: $connection_info"
            fi
        done
    done
    
    # Check recent files
    find /tmp /var/tmp -type f -mtime -1 2>/dev/null | while read -r file; do
        local filename=$(basename "$file")
        sqlite3 "$LOOKOUTS_DB" "SELECT signature_name, signature_pattern, threat_type, severity FROM threat_signatures WHERE enabled = 1 AND threat_type = 'file_anomaly'" | while IFS='|' read -r sig_name pattern threat_type severity; do
            if echo "$filename" | grep -qE "$pattern"; then
                record_threat "$threat_type" "$severity" "file" "$file" "$sig_name" "Suspicious file detected: $file"
            fi
        done
    done
}

# Detect behavioral anomalies
detect_behavioral_threats() {
    if [[ "$ENABLE_BEHAVIORAL" != "true" ]]; then
        return 0
    fi
    
    log "Running behavioral threat detection"
    
    # Check for unusual process activity
    local process_count=$(ps aux | wc -l)
    local baseline_process_count=$(sqlite3 "$LOOKOUTS_DB" "SELECT baseline_data FROM behavioral_patterns WHERE pattern_name = 'process_count' LIMIT 1")
    
    if [[ -z "$baseline_process_count" ]]; then
        # Set baseline
        sqlite3 "$LOOKOUTS_DB" "INSERT INTO behavioral_patterns (pattern_name, pattern_type, baseline_data) VALUES ('process_count', 'numeric', '$process_count')"
    else
        # Check for anomaly
        local threshold=$(sqlite3 "$LOOKOUTS_DB" "SELECT threshold FROM behavioral_patterns WHERE pattern_name = 'process_count' LIMIT 1")
        local threshold=${threshold:-50}
        
        if [[ $process_count -gt $((baseline_process_count + threshold)) ]]; then
            record_threat "behavioral_anomaly" "medium" "system" "process_count" "process_spike" "Unusual number of processes: $process_count (baseline: $baseline_process_count)"
        fi
    fi
    
    # Check for unusual network activity
    local connection_count=$(netstat -an | wc -l)
    local baseline_connection_count=$(sqlite3 "$LOOKOUTS_DB" "SELECT baseline_data FROM behavioral_patterns WHERE pattern_name = 'connection_count' LIMIT 1")
    
    if [[ -z "$baseline_connection_count" ]]; then
        # Set baseline
        sqlite3 "$LOOKOUTS_DB" "INSERT INTO behavioral_patterns (pattern_name, pattern_type, baseline_data) VALUES ('connection_count', 'numeric', '$connection_count')"
    else
        # Check for anomaly
        local threshold=$(sqlite3 "$LOOKOUTS_DB" "SELECT threshold FROM behavioral_patterns WHERE pattern_name = 'connection_count' LIMIT 1")
        local threshold=${threshold:-100}
        
        if [[ $connection_count -gt $((baseline_connection_count + threshold)) ]]; then
            record_threat "behavioral_anomaly" "medium" "network" "connection_count" "network_spike" "Unusual number of connections: $connection_count (baseline: $baseline_connection_count)"
        fi
    fi
    
    # Check for unusual file activity
    local recent_files=$(find /tmp /var/tmp -type f -mtime -1 2>/dev/null | wc -l)
    local baseline_file_count=$(sqlite3 "$LOOKOUTS_DB" "SELECT baseline_data FROM behavioral_patterns WHERE pattern_name = 'recent_file_count' LIMIT 1")
    
    if [[ -z "$baseline_file_count" ]]; then
        # Set baseline
        sqlite3 "$LOOKOUTS_DB" "INSERT INTO behavioral_patterns (pattern_name, pattern_type, baseline_data) VALUES ('recent_file_count', 'numeric', '$recent_files')"
    else
        # Check for anomaly
        local threshold=$(sqlite3 "$LOOKOUTS_DB" "SELECT threshold FROM behavioral_patterns WHERE pattern_name = 'recent_file_count' LIMIT 1")
        local threshold=${threshold:-20}
        
        if [[ $recent_files -gt $((baseline_file_count + threshold)) ]]; then
            record_threat "behavioral_anomaly" "low" "file" "recent_file_count" "file_activity_spike" "Unusual file activity: $recent_files recent files (baseline: $baseline_file_count)"
        fi
    fi
}

# Detect anomaly threats
detect_anomaly_threats() {
    if [[ "$ENABLE_ANOMALY" != "true" ]]; then
        return 0
    fi
    
    log "Running anomaly threat detection"
    
    # Check for unusual CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if [[ $cpu_usage -gt 90 ]]; then
        record_threat "anomaly" "high" "system" "cpu" "high_cpu_usage" "Unusually high CPU usage: ${cpu_usage}%"
    fi
    
    # Check for unusual memory usage
    local memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ $memory_usage -gt 95 ]]; then
        record_threat "anomaly" "high" "system" "memory" "high_memory_usage" "Unusually high memory usage: ${memory_usage}%"
    fi
    
    # Check for unusual disk usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    if [[ $disk_usage -gt 90 ]]; then
        record_threat "anomaly" "medium" "system" "disk" "high_disk_usage" "Unusually high disk usage: ${disk_usage}%"
    fi
    
    # Check for unusual login attempts
    local failed_logins=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    if [[ $failed_logins -gt 10 ]]; then
        record_threat "anomaly" "high" "auth" "login" "failed_login_attempts" "Multiple failed login attempts: $failed_logins"
    fi
    
    # Check for unusual network connections
    local established_connections=$(netstat -an | grep ESTABLISHED | wc -l)
    if [[ $established_connections -gt 1000 ]]; then
        record_threat "anomaly" "medium" "network" "connection" "high_connection_count" "Unusually high number of established connections: $established_connections"
    fi
}

# Record threat
record_threat() {
    local threat_type="$1"
    local severity="$2"
    local source="$3"
    local target="$4"
    local signature="$5"
    local details="$6"
    
    # Check rate limiting
    local recent_threats=$(sqlite3 "$LOOKOUTS_DB" "SELECT COUNT(*) FROM threats WHERE detected_at > datetime('now', '-1 hour')")
    if [[ $recent_threats -gt $MAX_THREATS_PER_HOUR ]]; then
        log "Rate limit exceeded: $recent_threats threats in last hour"
        return 0
    fi
    
    # Check if this is a duplicate threat
    local duplicate_count=$(sqlite3 "$LOOKOUTS_DB" "SELECT COUNT(*) FROM threats WHERE threat_type = '$threat_type' AND target = '$target' AND detected_at > datetime('now', '-5 minutes')")
    if [[ $duplicate_count -gt 0 ]]; then
        return 0
    fi
    
    # Record the threat
    sqlite3 "$LOOKOUTS_DB" <<EOF
INSERT INTO threats (threat_type, severity, source, target, signature, details)
VALUES ('$threat_type', '$severity', '$source', '$target', '$signature', '$details');
EOF
    
    log "Threat detected: $threat_type ($severity) - $details"
    audit_log "THREAT_DETECTED" "Type: $threat_type, Severity: $severity, Target: $target"
    
    # Trigger alert
    trigger_alert "$threat_type" "$severity" "$details"
}

# Trigger alert
trigger_alert() {
    local threat_type="$1"
    local severity="$2"
    local details="$3"
    
    # Send to Herald alert system
    if [[ -f "$GRIM_ROOT/modules/herald.sh" ]]; then
        source "$GRIM_ROOT/modules/herald.sh"
        create_alert "lookouts" "$threat_type" "$severity" "$details"
    fi
    
    # Log to Scribe audit system
    if [[ -f "$GRIM_ROOT/modules/scribe.sh" ]]; then
        source "$GRIM_ROOT/modules/scribe.sh"
        log_security_event "threat_detected" "$threat_type" "$details"
    fi
}

# Check threat intelligence
check_threat_intelligence() {
    log "Checking threat intelligence"
    
    # Check network connections against threat intel
    netstat -tuln 2>/dev/null | grep -E "ESTABLISHED|LISTEN" | while read -r line; do
        local remote_ip=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
        if [[ -n "$remote_ip" ]] && [[ "$remote_ip" != "127.0.0.1" ]]; then
            local ioc_match=$(sqlite3 "$LOOKOUTS_DB" "SELECT threat_name, confidence FROM threat_intel WHERE ioc_type = 'ip' AND ioc_value = '$remote_ip' AND active = 1 LIMIT 1")
            if [[ -n "$ioc_match" ]]; then
                local threat_name=$(echo "$ioc_match" | cut -d'|' -f1)
                local confidence=$(echo "$ioc_match" | cut -d'|' -f2)
                record_threat "threat_intel" "high" "network" "$remote_ip" "ioc_match" "Threat intelligence match: $threat_name (confidence: $confidence)"
            fi
        fi
    done
    
    # Check files against threat intel
    find /tmp /var/tmp -type f -mtime -1 2>/dev/null | while read -r file; do
        if [[ -f "$file" ]]; then
            local file_hash=$(md5sum "$file" | cut -d' ' -f1)
            local ioc_match=$(sqlite3 "$LOOKOUTS_DB" "SELECT threat_name, confidence FROM threat_intel WHERE ioc_type = 'hash' AND ioc_value = '$file_hash' AND active = 1 LIMIT 1")
            if [[ -n "$ioc_match" ]]; then
                local threat_name=$(echo "$ioc_match" | cut -d'|' -f1)
                local confidence=$(echo "$ioc_match" | cut -d'|' -f2)
                record_threat "threat_intel" "high" "file" "$file" "ioc_match" "Threat intelligence match: $threat_name (confidence: $confidence)"
            fi
        fi
    done
}

# Run threat detection scan
run_threat_scan() {
    log "Starting threat detection scan"
    audit_log "THREAT_SCAN_START" "Threat detection scan initiated"
    
    # Run all detection methods
    detect_signature_threats
    detect_behavioral_threats
    detect_anomaly_threats
    check_threat_intelligence
    
    log "Threat detection scan completed"
    audit_log "THREAT_SCAN_COMPLETE" "Threat detection scan completed"
}

# Get threat statistics
get_threat_stats() {
    echo -e "${CYAN}=== Threat Detection Statistics ===${NC}"
    
    local total_threats=$(sqlite3 "$LOOKOUTS_DB" "SELECT COUNT(*) FROM threats")
    local active_threats=$(sqlite3 "$LOOKOUTS_DB" "SELECT COUNT(*) FROM threats WHERE status = 'active'")
    local high_severity=$(sqlite3 "$LOOKOUTS_DB" "SELECT COUNT(*) FROM threats WHERE severity = 'high'")
    local medium_severity=$(sqlite3 "$LOOKOUTS_DB" "SELECT COUNT(*) FROM threats WHERE severity = 'medium'")
    local low_severity=$(sqlite3 "$LOOKOUTS_DB" "SELECT COUNT(*) FROM threats WHERE severity = 'low'")
    
    echo "Total threats: $total_threats"
    echo "Active threats: $active_threats"
    echo "High severity: $high_severity"
    echo "Medium severity: $medium_severity"
    echo "Low severity: $low_severity"
    
    echo ""
    echo -e "${YELLOW}Recent Threats:${NC}"
    sqlite3 "$LOOKOUTS_DB" "SELECT threat_type, severity, target, detected_at FROM threats ORDER BY detected_at DESC LIMIT 10" | while IFS='|' read -r threat_type severity target detected_at; do
        echo "  $threat_type ($severity) - $target - $detected_at"
    done
    
    echo ""
    echo -e "${YELLOW}Threat Types:${NC}"
    sqlite3 "$LOOKOUTS_DB" "SELECT threat_type, COUNT(*) as count FROM threats GROUP BY threat_type ORDER BY count DESC" | while IFS='|' read -r threat_type count; do
        echo "  $threat_type: $count"
    done
}

# Show help
show_help() {
    echo -e "${CYAN}Lookouts Threat Detection System${NC}"
    echo "Real-time security monitoring and threat detection."
    echo ""
    echo "Usage: grim lookouts <command> [options]"
    echo ""
    echo "Commands:"
    echo "  scan                               - Run threat detection scan"
    echo "  threats [type]                     - List detected threats"
    echo "  stats                               - Show threat statistics"
    echo "  signatures [add|remove|list]       - Manage threat signatures"
    echo "  intel [add|remove|list]            - Manage threat intelligence"
    echo "  monitor [start|stop|status]        - Control continuous monitoring"
    echo "  init                                - Initialize threat detection"
    echo "  help                                - Show this help"
    echo ""
    echo "Examples:"
    echo "  grim lookouts scan"
    echo "  grim lookouts threats"
    echo "  grim lookouts signatures add"
    echo "  grim lookouts monitor start"
    echo ""
    echo "Configuration:"
    echo "  Scan interval: ${SCAN_INTERVAL}s"
    echo "  Threat level: $THREAT_LEVEL"
    echo "  Behavioral detection: $ENABLE_BEHAVIORAL"
    echo "  Anomaly detection: $ENABLE_ANOMALY"
    echo "  Signature detection: $ENABLE_SIGNATURES"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        scan)
            run_threat_scan
            ;;
        threats)
            if [[ $# -eq 1 ]]; then
                sqlite3 "$LOOKOUTS_DB" "SELECT threat_type, severity, target, detected_at FROM threats WHERE threat_type = '$1' ORDER BY detected_at DESC"
            else
                sqlite3 "$LOOKOUTS_DB" "SELECT threat_type, severity, target, detected_at FROM threats ORDER BY detected_at DESC LIMIT 20"
            fi
            ;;
        stats)
            get_threat_stats
            ;;
        signatures)
            case "$1" in
                add)
                    echo "Adding signature..."
                    ;;
                remove)
                    echo "Removing signature..."
                    ;;
                list)
                    sqlite3 "$LOOKOUTS_DB" "SELECT signature_name, threat_type, severity, enabled FROM threat_signatures ORDER BY signature_name"
                    ;;
                *)
                    echo "Usage: grim lookouts signatures [add|remove|list]"
                    ;;
            esac
            ;;
        intel)
            case "$1" in
                add)
                    echo "Adding threat intelligence..."
                    ;;
                remove)
                    echo "Removing threat intelligence..."
                    ;;
                list)
                    sqlite3 "$LOOKOUTS_DB" "SELECT ioc_type, ioc_value, threat_name, confidence FROM threat_intel WHERE active = 1 ORDER BY ioc_type"
                    ;;
                *)
                    echo "Usage: grim lookouts intel [add|remove|list]"
                    ;;
            esac
            ;;
        monitor)
            case "$1" in
                start)
                    echo "Starting continuous monitoring..."
                    ;;
                stop)
                    echo "Stopping continuous monitoring..."
                    ;;
                status)
                    echo "Monitoring status..."
                    ;;
                *)
                    echo "Usage: grim lookouts monitor [start|stop|status]"
                    ;;
            esac
            ;;
        init)
            init_lookouts_db
            load_threat_signatures
            load_threat_intelligence
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
init_lookouts_db
load_threat_signatures
load_threat_intelligence

# Only call main if this script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 