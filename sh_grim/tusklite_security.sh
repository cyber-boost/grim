#!/bin/bash
# TuskLite Security Module: Secure runtime environment and sandboxing

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
TUSKLITE_DB="$GRIM_ROOT/db/tusklite_security.db"
TUSKLITE_LOG="$GRIM_ROOT/logs/tusklite_security.log"
AUDIT_LOG="$GRIM_ROOT/logs/security_audit.log"
SANDBOX_DIR="$GRIM_ROOT/sandbox"
SECURE_ENV_DIR="$GRIM_ROOT/config/secure_env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Security configuration
ENABLE_SANDBOXING="${enable_sandboxing:-true}"
ENABLE_CODE_SIGNING="${enable_code_signing:-true}"
ENABLE_RUNTIME_INTEGRITY="${enable_runtime_integrity:-true}"
MAX_MEMORY_MB="${max_memory_mb:-512}"
MAX_CPU_PERCENT="${max_cpu_percent:-50}"
MAX_DISK_MB="${max_disk_mb:-100}"
NETWORK_RESTRICTIONS="${network_restrictions:-true}"
FILE_SYSTEM_RESTRICTIONS="${file_system_restrictions:-true}"

# Secure logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TUSKLITE_LOG"
}

# Security audit logging
audit_log() {
    local event_type="$1"
    local message="$2"
    local user="${SUDO_USER:-$USER}"
    local session_id="${SSH_SESSION_ID:-$(who am i | awk '{print $2}' | sed 's/[()]//g')}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUDIT] [$event_type] [$user] [$session_id] $message" >> "$AUDIT_LOG"
}

# Initialize TuskLite security database
init_tusklite_security_db() {
    sqlite3 "$TUSKLITE_DB" <<EOF
CREATE TABLE IF NOT EXISTS sandbox_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    user_id TEXT NOT NULL,
    sandbox_path TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    status TEXT DEFAULT 'active',
    resource_usage TEXT,
    security_violations INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS code_signatures (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    signature_hash TEXT NOT NULL,
    signature_type TEXT DEFAULT 'sha256',
    signed_by TEXT,
    signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,
    status TEXT DEFAULT 'valid'
);

CREATE TABLE IF NOT EXISTS runtime_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    check_type TEXT NOT NULL,
    target TEXT NOT NULL,
    expected_value TEXT,
    actual_value TEXT,
    check_result BOOLEAN,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT
);

CREATE TABLE IF NOT EXISTS security_violations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    violation_type TEXT NOT NULL,
    severity TEXT DEFAULT 'medium',
    details TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action_taken TEXT
);

CREATE TABLE IF NOT EXISTS secure_environment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    env_name TEXT NOT NULL,
    env_value TEXT,
    encrypted BOOLEAN DEFAULT FALSE,
    restricted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_id ON sandbox_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sandbox_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_signatures_file ON code_signatures(file_path);
CREATE INDEX IF NOT EXISTS idx_runtime_type ON runtime_checks(check_type);
CREATE INDEX IF NOT EXISTS idx_violations_session ON security_violations(session_id);
CREATE INDEX IF NOT EXISTS idx_environment_name ON secure_environment(env_name);
EOF
    log "TuskLite security database initialized"
    audit_log "DB_INIT" "TuskLite security database initialized"
}

# Create secure sandbox environment
create_sandbox() {
    local user_id="${1:-${SUDO_USER:-$USER}}"
    local session_id="${2:-$(uuidgen 2>/dev/null || echo "session_$(date +%s)")}"
    
    local sandbox_path="$SANDBOX_DIR/$session_id"
    
    # Create sandbox directory
    mkdir -p "$sandbox_path"
    
    # Set up sandbox environment
    local sandbox_env=""
    sandbox_env+="SANDBOX_PATH=$sandbox_path;"
    sandbox_env+="SANDBOX_SESSION_ID=$session_id;"
    sandbox_env+="SANDBOX_USER_ID=$user_id;"
    sandbox_env+="SANDBOX_RESTRICTED=true;"
    
    # Create restricted file system
    mkdir -p "$sandbox_path"/{tmp,home,proc,dev}
    chmod 755 "$sandbox_path"
    chmod 700 "$sandbox_path/home"
    chmod 1777 "$sandbox_path/tmp"
    
    # Mount restricted proc and dev
    mount --bind /proc "$sandbox_path/proc" 2>/dev/null || true
    mount --bind /dev "$sandbox_path/dev" 2>/dev/null || true
    
    # Record sandbox session
    sqlite3 "$TUSKLITE_DB" <<EOF
INSERT INTO sandbox_sessions (session_id, user_id, sandbox_path)
VALUES ('$session_id', '$user_id', '$sandbox_path');
EOF
    
    log "Sandbox created: $session_id at $sandbox_path"
    audit_log "SANDBOX_CREATED" "Session: $session_id, User: $user_id, Path: $sandbox_path"
    
    echo "$session_id"
}

# Destroy sandbox environment
destroy_sandbox() {
    local session_id="$1"
    
    # Get sandbox path
    local sandbox_path=$(sqlite3 "$TUSKLITE_DB" "SELECT sandbox_path FROM sandbox_sessions WHERE session_id = '$session_id' AND status = 'active'")
    
    if [[ -z "$sandbox_path" ]]; then
        log "Sandbox not found or already destroyed: $session_id"
        return 1
    fi
    
    # Unmount proc and dev
    umount "$sandbox_path/proc" 2>/dev/null || true
    umount "$sandbox_path/dev" 2>/dev/null || true
    
    # Kill any processes in sandbox
    pkill -f "$sandbox_path" 2>/dev/null || true
    
    # Remove sandbox directory
    rm -rf "$sandbox_path"
    
    # Update session record
    sqlite3 "$TUSKLITE_DB" <<EOF
UPDATE sandbox_sessions SET ended_at = CURRENT_TIMESTAMP, status = 'destroyed' WHERE session_id = '$session_id';
EOF
    
    log "Sandbox destroyed: $session_id"
    audit_log "SANDBOX_DESTROYED" "Session: $session_id, Path: $sandbox_path"
}

# Verify code signature
verify_code_signature() {
    local file_path="$1"
    
    if [[ "$ENABLE_CODE_SIGNING" != "true" ]]; then
        return 0
    fi
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    local current_hash=$(sha256sum "$file_path" | cut -d' ' -f1)
    local stored_hash=$(sqlite3 "$TUSKLITE_DB" "SELECT signature_hash FROM code_signatures WHERE file_path = '$file_path' AND status = 'valid' ORDER BY signed_at DESC LIMIT 1")
    
    if [[ -z "$stored_hash" ]]; then
        log "No signature found for: $file_path"
        return 1
    fi
    
    if [[ "$current_hash" == "$stored_hash" ]]; then
        log "Code signature verified: $file_path"
        return 0
    else
        log "Code signature verification failed: $file_path"
        return 1
    fi
}

# Add code signature
add_code_signature() {
    local file_path="$1"
    local signed_by="${2:-${SUDO_USER:-$USER}}"
    local valid_until="${3:-}"
    
    if [[ ! -f "$file_path" ]]; then
        log "File not found: $file_path"
        return 1
    fi
    
    local signature_hash=$(sha256sum "$file_path" | cut -d' ' -f1)
    
    sqlite3 "$TUSKLITE_DB" <<EOF
INSERT INTO code_signatures (file_path, signature_hash, signed_by, valid_until)
VALUES ('$file_path', '$signature_hash', '$signed_by', '$valid_until');
EOF
    
    log "Code signature added: $file_path by $signed_by"
    audit_log "CODE_SIGNATURE_ADDED" "File: $file_path, By: $signed_by, Hash: $signature_hash"
}

# Perform runtime integrity check
perform_runtime_check() {
    local check_type="$1"
    local target="$2"
    local expected_value="$3"
    local session_id="${4:-}"
    
    local actual_value=""
    local check_result=false
    
    case "$check_type" in
        file_exists)
            actual_value=$(test -f "$target" && echo "exists" || echo "missing")
            check_result=$([[ "$actual_value" == "$expected_value" ]] && echo "true" || echo "false")
            ;;
        file_hash)
            actual_value=$(sha256sum "$target" | cut -d' ' -f1 2>/dev/null || echo "error")
            check_result=$([[ "$actual_value" == "$expected_value" ]] && echo "true" || echo "false")
            ;;
        process_running)
            actual_value=$(pgrep -f "$target" >/dev/null && echo "running" || echo "not_running")
            check_result=$([[ "$actual_value" == "$expected_value" ]] && echo "true" || echo "false")
            ;;
        memory_usage)
            actual_value=$(ps -o rss= -p $$ | tr -d ' ')
            check_result=$([[ $actual_value -le $expected_value ]] && echo "true" || echo "false")
            ;;
        *)
            log "Unknown runtime check type: $check_type"
            return 1
            ;;
    esac
    
    # Record check result
    sqlite3 "$TUSKLITE_DB" <<EOF
INSERT INTO runtime_checks (check_type, target, expected_value, actual_value, check_result, session_id)
VALUES ('$check_type', '$target', '$expected_value', '$actual_value', $check_result, '$session_id');
EOF
    
    if [[ "$check_result" == "true" ]]; then
        log "Runtime check passed: $check_type $target"
        return 0
    else
        log "Runtime check failed: $check_type $target (expected: $expected_value, got: $actual_value)"
        return 1
    fi
}

# Execute command in sandbox
execute_in_sandbox() {
    local session_id="$1"
    local command="$2"
    local user_id="${3:-${SUDO_USER:-$USER}}"
    
    # Verify sandbox exists
    local sandbox_path=$(sqlite3 "$TUSKLITE_DB" "SELECT sandbox_path FROM sandbox_sessions WHERE session_id = '$session_id' AND status = 'active'")
    if [[ -z "$sandbox_path" ]]; then
        log "Sandbox not found: $session_id"
        return 1
    fi
    
    # Set up resource limits
    local ulimit_cmd=""
    ulimit_cmd+="ulimit -v $((MAX_MEMORY_MB * 1024));"  # Virtual memory
    ulimit_cmd+="ulimit -t $((MAX_CPU_PERCENT * 60));"  # CPU time
    ulimit_cmd+="ulimit -f $((MAX_DISK_MB * 1024));"    # File size
    
    # Set up network restrictions
    if [[ "$NETWORK_RESTRICTIONS" == "true" ]]; then
        ulimit_cmd+="ulimit -n 10;"  # File descriptors (network connections)
    fi
    
    # Set up file system restrictions
    if [[ "$FILE_SYSTEM_RESTRICTIONS" == "true" ]]; then
        ulimit_cmd+="cd $sandbox_path/home;"
    fi
    
    # Execute command with restrictions
    local full_command="$ulimit_cmd $command"
    
    log "Executing in sandbox: $session_id - $command"
    audit_log "SANDBOX_EXECUTE" "Session: $session_id, Command: $command, User: $user_id"
    
    # Execute with timeout and resource monitoring
    timeout 300 bash -c "$full_command" 2>&1
    
    local exit_code=$?
    
    # Record resource usage
    local resource_usage="{\"exit_code\": $exit_code, \"memory_limit\": $MAX_MEMORY_MB, \"cpu_limit\": $MAX_CPU_PERCENT}"
    sqlite3 "$TUSKLITE_DB" "UPDATE sandbox_sessions SET resource_usage = '$resource_usage' WHERE session_id = '$session_id'"
    
    return $exit_code
}

# Monitor sandbox for violations
monitor_sandbox() {
    local session_id="$1"
    
    # Get sandbox path
    local sandbox_path=$(sqlite3 "$TUSKLITE_DB" "SELECT sandbox_path FROM sandbox_sessions WHERE session_id = '$session_id' AND status = 'active'")
    if [[ -z "$sandbox_path" ]]; then
        return 1
    fi
    
    # Check for unauthorized file access
    local unauthorized_access=$(find "$sandbox_path" -type f -executable 2>/dev/null | grep -v "$sandbox_path" | head -1)
    if [[ -n "$unauthorized_access" ]]; then
        record_violation "$session_id" "unauthorized_file_access" "high" "Attempted to access: $unauthorized_access"
    fi
    
    # Check for network violations
    if [[ "$NETWORK_RESTRICTIONS" == "true" ]]; then
        local network_connections=$(netstat -tuln 2>/dev/null | grep -v "127.0.0.1" | wc -l)
        if [[ $network_connections -gt 5 ]]; then
            record_violation "$session_id" "excessive_network_connections" "medium" "Too many network connections: $network_connections"
        fi
    fi
    
    # Check for memory violations
    local memory_usage=$(ps -o rss= -p $$ | tr -d ' ')
    if [[ $memory_usage -gt $((MAX_MEMORY_MB * 1024)) ]]; then
        record_violation "$session_id" "memory_limit_exceeded" "high" "Memory usage exceeded: ${memory_usage}KB"
    fi
    
    # Check for CPU violations
    local cpu_usage=$(ps -o %cpu= -p $$ | tr -d ' ')
    if [[ $cpu_usage -gt $MAX_CPU_PERCENT ]]; then
        record_violation "$session_id" "cpu_limit_exceeded" "medium" "CPU usage exceeded: ${cpu_usage}%"
    fi
}

# Record security violation
record_violation() {
    local session_id="$1"
    local violation_type="$2"
    local severity="$3"
    local details="$4"
    
    sqlite3 "$TUSKLITE_DB" <<EOF
INSERT INTO security_violations (session_id, violation_type, severity, details)
VALUES ('$session_id', '$violation_type', '$severity', '$details');
UPDATE sandbox_sessions SET security_violations = security_violations + 1 WHERE session_id = '$session_id';
EOF
    
    log "Security violation recorded: $session_id - $violation_type ($severity)"
    audit_log "SECURITY_VIOLATION" "Session: $session_id, Type: $violation_type, Severity: $severity"
    
    # Take action based on severity
    case "$severity" in
        high)
            destroy_sandbox "$session_id"
            ;;
        medium)
            # Log and continue monitoring
            ;;
        low)
            # Just log
            ;;
    esac
}

# Create secure environment variable
create_secure_env() {
    local env_name="$1"
    local env_value="$2"
    local encrypted="${3:-false}"
    local restricted="${4:-false}"
    
    if [[ "$encrypted" == "true" ]]; then
        env_value=$(echo "$env_value" | openssl enc -aes-256-cbc -a -salt -pass pass:"$GRIM_ROOT" 2>/dev/null || echo "$env_value")
    fi
    
    sqlite3 "$TUSKLITE_DB" <<EOF
INSERT OR REPLACE INTO secure_environment (env_name, env_value, encrypted, restricted)
VALUES ('$env_name', '$env_value', $encrypted, $restricted);
EOF
    
    log "Secure environment variable created: $env_name"
    audit_log "SECURE_ENV_CREATED" "Name: $env_name, Encrypted: $encrypted, Restricted: $restricted"
}

# Get secure environment variable
get_secure_env() {
    local env_name="$1"
    
    local env_data=$(sqlite3 "$TUSKLITE_DB" "SELECT env_value, encrypted FROM secure_environment WHERE env_name = '$env_name' LIMIT 1")
    if [[ -z "$env_data" ]]; then
        return 1
    fi
    
    local env_value=$(echo "$env_data" | cut -d'|' -f1)
    local encrypted=$(echo "$env_data" | cut -d'|' -f2)
    
    if [[ "$encrypted" == "1" ]]; then
        env_value=$(echo "$env_value" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$GRIM_ROOT" 2>/dev/null || echo "$env_value")
    fi
    
    echo "$env_value"
}

# Get sandbox statistics
get_sandbox_stats() {
    echo -e "${CYAN}=== TuskLite Security Statistics ===${NC}"
    
    local total_sessions=$(sqlite3 "$TUSKLITE_DB" "SELECT COUNT(*) FROM sandbox_sessions")
    local active_sessions=$(sqlite3 "$TUSKLITE_DB" "SELECT COUNT(*) FROM sandbox_sessions WHERE status = 'active'")
    local total_violations=$(sqlite3 "$TUSKLITE_DB" "SELECT COUNT(*) FROM security_violations")
    local total_signatures=$(sqlite3 "$TUSKLITE_DB" "SELECT COUNT(*) FROM code_signatures")
    local total_runtime_checks=$(sqlite3 "$TUSKLITE_DB" "SELECT COUNT(*) FROM runtime_checks")
    
    echo "Total sandbox sessions: $total_sessions"
    echo "Active sandbox sessions: $active_sessions"
    echo "Total security violations: $total_violations"
    echo "Total code signatures: $total_signatures"
    echo "Total runtime checks: $total_runtime_checks"
    
    echo ""
    echo -e "${YELLOW}Recent Sandbox Sessions:${NC}"
    sqlite3 "$TUSKLITE_DB" "SELECT session_id, user_id, status, created_at FROM sandbox_sessions ORDER BY created_at DESC LIMIT 10" | while IFS='|' read -r session_id user_id status created_at; do
        echo "  $session_id ($user_id) - $status - $created_at"
    done
    
    echo ""
    echo -e "${YELLOW}Recent Security Violations:${NC}"
    sqlite3 "$TUSKLITE_DB" "SELECT session_id, violation_type, severity, timestamp FROM security_violations ORDER BY timestamp DESC LIMIT 10" | while IFS='|' read -r session_id violation_type severity timestamp; do
        echo "  $session_id: $violation_type ($severity) - $timestamp"
    done
}

# Show help
show_help() {
    echo -e "${CYAN}TuskLite Security Module${NC}"
    echo "Secure runtime environment and sandboxing system."
    echo ""
    echo "Usage: grim tusklite-security <command> [options]"
    echo ""
    echo "Commands:"
    echo "  sandbox create [user] [session_id]     - Create sandbox environment"
    echo "  sandbox destroy <session_id>           - Destroy sandbox environment"
    echo "  sandbox execute <session_id> <command> - Execute command in sandbox"
    echo "  sandbox monitor <session_id>           - Monitor sandbox for violations"
    echo "  signature add <file> [signer] [until]  - Add code signature"
    echo "  signature verify <file>                - Verify code signature"
    echo "  runtime check <type> <target> [value]  - Perform runtime integrity check"
    echo "  env set <name> <value> [encrypt]       - Set secure environment variable"
    echo "  env get <name>                         - Get secure environment variable"
    echo "  stats                                   - Show security statistics"
    echo "  init                                    - Initialize security system"
    echo "  help                                    - Show this help"
    echo ""
    echo "Examples:"
    echo "  grim tusklite-security sandbox create user123"
    echo "  grim tusklite-security sandbox execute session123 'ls -la'"
    echo "  grim tusklite-security signature add script.sh"
    echo "  grim tusklite-security env set API_KEY secret123 true"
    echo ""
    echo "Configuration:"
    echo "  Sandboxing: $ENABLE_SANDBOXING"
    echo "  Code signing: $ENABLE_CODE_SIGNING"
    echo "  Runtime integrity: $ENABLE_RUNTIME_INTEGRITY"
    echo "  Max memory: ${MAX_MEMORY_MB}MB"
    echo "  Max CPU: ${MAX_CPU_PERCENT}%"
    echo "  Max disk: ${MAX_DISK_MB}MB"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        sandbox)
            case "$1" in
                create)
                    create_sandbox "$2" "$3"
                    ;;
                destroy)
                    if [[ $# -lt 2 ]]; then
                        echo "Usage: grim tusklite-security sandbox destroy <session_id>"
                        return 1
                    fi
                    destroy_sandbox "$2"
                    ;;
                execute)
                    if [[ $# -lt 3 ]]; then
                        echo "Usage: grim tusklite-security sandbox execute <session_id> <command>"
                        return 1
                    fi
                    execute_in_sandbox "$2" "$3" "$4"
                    ;;
                monitor)
                    if [[ $# -lt 2 ]]; then
                        echo "Usage: grim tusklite-security sandbox monitor <session_id>"
                        return 1
                    fi
                    monitor_sandbox "$2"
                    ;;
                *)
                    echo "Usage: grim tusklite-security sandbox [create|destroy|execute|monitor]"
                    ;;
            esac
            ;;
        signature)
            case "$1" in
                add)
                    if [[ $# -lt 2 ]]; then
                        echo "Usage: grim tusklite-security signature add <file> [signer] [until]"
                        return 1
                    fi
                    add_code_signature "$2" "$3" "$4"
                    ;;
                verify)
                    if [[ $# -lt 2 ]]; then
                        echo "Usage: grim tusklite-security signature verify <file>"
                        return 1
                    fi
                    verify_code_signature "$2"
                    ;;
                *)
                    echo "Usage: grim tusklite-security signature [add|verify]"
                    ;;
            esac
            ;;
        runtime)
            if [[ $# -lt 3 ]]; then
                echo "Usage: grim tusklite-security runtime check <type> <target> [expected_value]"
                return 1
            fi
            perform_runtime_check "$2" "$3" "$4" "$5"
            ;;
        env)
            case "$1" in
                set)
                    if [[ $# -lt 3 ]]; then
                        echo "Usage: grim tusklite-security env set <name> <value> [encrypt] [restricted]"
                        return 1
                    fi
                    create_secure_env "$2" "$3" "$4" "$5"
                    ;;
                get)
                    if [[ $# -lt 2 ]]; then
                        echo "Usage: grim tusklite-security env get <name>"
                        return 1
                    fi
                    get_secure_env "$2"
                    ;;
                *)
                    echo "Usage: grim tusklite-security env [set|get]"
                    ;;
            esac
            ;;
        stats)
            get_sandbox_stats
            ;;
        init)
            init_tusklite_security_db
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
init_tusklite_security_db

# Only call main if this script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 