#!/bin/bash

# Grim Scythe - Silent License Protection System
# The reaper that monitors software usage and protects developers' work

# Source reaper.sh for utilities and colors, but don't change working directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
GRIM_ROOT="${GRIM_ROOT:-$(dirname "$SCRIPT_DIR")}"
source "$GRIM_ROOT/reaper.sh" 2>/dev/null || source /opt/grim/reaper.sh 2>/dev/null

SCYTHE_VERSION="2.0.0"
SCYTHE_CONFIG="${GRIM_CONFIG_DIR}/scythe.tsk"
SCYTHE_DB="${GRIM_DB_DIR}/scythe.db"
SCYTHE_LOG="${GRIM_LOG_DIR}/scythe.log"
SCYTHE_PID="${GRIM_RUN_DIR}/scythe.pid"
MOTHER_DB_URL="${MOTHER_DB_URL:-https://api.grim.so/scythe}"
SCYTHE_CHECK_INTERVAL="${SCYTHE_CHECK_INTERVAL:-3600}" # 1 hour default

# Enhanced .tsk configuration parser
parse_tusk_config() {
    local config_file="$1"
    local section="$2"
    local key="$3"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Parse .tsk format with proper section/key handling
    local in_section=false
    local result=""
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Check for section start
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*): ]]; then
            local current_section="${BASH_REMATCH[1]}"
            if [[ "$current_section" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi
        
        # If in target section, look for key
        if [[ "$in_section" == "true" ]]; then
            if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*(.+)$ ]]; then
                local current_key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                if [[ "$current_key" == "$key" ]]; then
                    # Remove quotes if present
                    value="${value%\"}"
                    value="${value#\"}"
                    value="${value%\'}"
                    value="${value#\'}"
                    echo "$value"
                    return 0
                fi
            fi
        fi
    done < "$config_file"
    
    return 1
}

# Enhanced silent monitoring with stealth techniques
silent_monitor() {
    local software_id="$1"
    local config_file="$2"
    
    # Parse configuration
    local check_files=$(parse_tusk_config "$config_file" "protection" "check_files")
    local check_processes=$(parse_tusk_config "$config_file" "protection" "check_processes")
    local license_file=$(parse_tusk_config "$config_file" "protection" "license_file")
    local heartbeat_url=$(parse_tusk_config "$config_file" "protection" "heartbeat_url")
    local stealth_mode=$(parse_tusk_config "$config_file" "monitoring" "stealth")
    
    # Default values
    [[ -z "$license_file" ]] && license_file=".license"
    [[ -z "$stealth_mode" ]] && stealth_mode="true"
    
    # Stealth mode: disguise process name
    if [[ "$stealth_mode" == "true" ]]; then
        local stealth_name=$(basename "$(pwd)")_monitor
        exec -a "$stealth_name" bash -c "
            while true; do
                sleep $SCYTHE_CHECK_INTERVAL
                $0 _internal_check '$software_id' '$config_file'
            done
        " &
        echo $! > "$SCYTHE_PID"
    else
        # Standard monitoring
        while true; do
            sleep $SCYTHE_CHECK_INTERVAL
            internal_check "$software_id" "$config_file"
        done &
        echo $! > "$SCYTHE_PID"
    fi
}

# Internal check function (called by silent monitor)
internal_check() {
    local software_id="$1"
    local config_file="$2"
    
    # Parse configuration
    local license_file=$(parse_tusk_config "$config_file" "protection" "license_file")
    local check_files=$(parse_tusk_config "$config_file" "protection" "check_files")
    local check_processes=$(parse_tusk_config "$config_file" "protection" "check_processes")
    
    # Default values
    [[ -z "$license_file" ]] && license_file=".license"
    
    # Check if license exists and is valid
    local has_license=false
    if [[ -f "$license_file" ]]; then
        local license_key=$(cat "$license_file" 2>/dev/null | tr -d '\n\r')
        if [[ -n "$license_key" ]]; then
            has_license=true
        fi
    fi
    
    # Record check in database
    sqlite3 "$SCYTHE_DB" "UPDATE monitors SET last_check = CURRENT_TIMESTAMP, check_count = check_count + 1 WHERE software_id = '$software_id'"
    
    # If no license, record violation
    if [[ "$has_license" == "false" ]]; then
        record_violation "$software_id" "unlicensed" "No valid license key found in $license_file"
        return 1
    fi
    
    # Validate license with mother DB
    validate_license "$software_id" "$license_key"
    
    # Check for file modifications if specified
    if [[ -n "$check_files" ]]; then
        check_file_integrity "$software_id" "$check_files"
    fi
    
    # Check for process violations if specified
    if [[ -n "$check_processes" ]]; then
        check_process_violations "$software_id" "$check_processes"
    fi
}

# Check file integrity for modifications
check_file_integrity() {
    local software_id="$1"
    local check_files="$2"
    
    # Parse file list (comma-separated or newline-separated)
    local files=()
    while IFS= read -r -d ',' file; do
        files+=("$file")
    done <<< "$check_files"
    
    for file in "${files[@]}"; do
        file=$(echo "$file" | tr -d ' ')
        if [[ -f "$file" ]]; then
            # Check if file has been modified recently (last 24 hours)
            local mtime=$(stat -c %Y "$file" 2>/dev/null)
            local now=$(date +%s)
            local age=$((now - mtime))
            
            if [[ $age -lt 86400 ]]; then
                record_violation "$software_id" "file_modified" "Protected file modified: $file"
            fi
        else
            record_violation "$software_id" "file_missing" "Protected file missing: $file"
        fi
    done
}

# Check for unauthorized process usage
check_process_violations() {
    local software_id="$1"
    local check_processes="$2"
    
    # Parse process list
    local processes=()
    while IFS= read -r -d ',' process; do
        processes+=("$process")
    done <<< "$check_processes"
    
    for process in "${processes[@]}"; do
        process=$(echo "$process" | tr -d ' ')
        if pgrep -f "$process" >/dev/null 2>&1; then
            # Check if process is running without proper license
            local license_file=$(parse_tusk_config ".scythe.tsk" "protection" "license_file")
            [[ -z "$license_file" ]] && license_file=".license"
            
            if [[ ! -f "$license_file" ]]; then
                record_violation "$software_id" "unauthorized_process" "Process running without license: $process"
            fi
        fi
    done
}

# Initialize scythe database with enhanced schema
init_scythe_db() {
    sqlite3 "$SCYTHE_DB" <<EOF
CREATE TABLE IF NOT EXISTS monitors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    software_id TEXT NOT NULL UNIQUE,
    software_name TEXT NOT NULL,
    license_key TEXT,
    last_check TIMESTAMP,
    check_count INTEGER DEFAULT 0,
    violations INTEGER DEFAULT 0,
    status TEXT DEFAULT 'monitoring',
    stealth_mode BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS violations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    software_id TEXT NOT NULL,
    violation_type TEXT NOT NULL,
    details TEXT,
    severity TEXT DEFAULT 'medium',
    reported BOOLEAN DEFAULT FALSE,
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (software_id) REFERENCES monitors(software_id)
);

CREATE TABLE IF NOT EXISTS communications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    software_id TEXT NOT NULL,
    message_type TEXT NOT NULL,
    channel TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    response TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (software_id) REFERENCES monitors(software_id)
);

CREATE TABLE IF NOT EXISTS file_checksums (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    software_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    checksum TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (software_id) REFERENCES monitors(software_id)
);

CREATE INDEX IF NOT EXISTS idx_monitors_software_id ON monitors(software_id);
CREATE INDEX IF NOT EXISTS idx_violations_software_id ON violations(software_id);
CREATE INDEX IF NOT EXISTS idx_violations_type ON violations(violation_type);
CREATE INDEX IF NOT EXISTS idx_communications_status ON communications(status);
EOF
}

# Enhanced license validation with retry logic
validate_license() {
    local software_id="$1"
    local license_key="$2"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        # Send validation request to mother DB
        local response=$(curl -s -X POST "$MOTHER_DB_URL/validate" \
            -H "Content-Type: application/json" \
            -H "User-Agent: Grim-Scythe/2.0" \
            -d "{\"software_id\": \"$software_id\", \"license_key\": \"$license_key\"}" \
            --connect-timeout 10 \
            --max-time 30)
        
        local valid=$(echo "$response" | jq -r '.valid' 2>/dev/null)
        local error=$(echo "$response" | jq -r '.error' 2>/dev/null)
        
        if [[ "$valid" == "true" ]]; then
            # Update last successful validation
            sqlite3 "$SCYTHE_DB" "UPDATE monitors SET last_check = CURRENT_TIMESTAMP WHERE software_id = '$software_id'"
            return 0
        elif [[ "$error" == "rate_limited" ]]; then
            # Wait and retry
            sleep $((retry_count + 1))
            retry_count=$((retry_count + 1))
            continue
        else
            # Invalid license
            record_violation "$software_id" "invalid_license" "License validation failed: $error"
            return 1
        fi
    done
    
    # Max retries exceeded
    record_violation "$software_id" "validation_timeout" "License validation timeout after $max_retries attempts"
    return 1
}

# Enhanced violation recording with severity levels
record_violation() {
    local software_id="$1"
    local violation_type="$2"
    local details="$3"
    local severity="${4:-medium}"
    
    # Determine severity based on violation type
    case "$violation_type" in
        unlicensed|invalid_license)
            severity="critical"
            ;;
        file_modified|unauthorized_process)
            severity="high"
            ;;
        validation_timeout|file_missing)
            severity="medium"
            ;;
        *)
            severity="low"
            ;;
    esac
    
    sqlite3 "$SCYTHE_DB" <<EOF
INSERT INTO violations (software_id, violation_type, details, severity)
VALUES ('$software_id', '$violation_type', '$details', '$severity');

UPDATE monitors SET violations = violations + 1, updated_at = CURRENT_TIMESTAMP 
WHERE software_id = '$software_id';
EOF
    
    # Log violation
    log_action "SCYTHE_VIOLATION" "Software: $software_id, Type: $violation_type, Severity: $severity"
    
    # Queue notifications based on severity
    if [[ "$severity" == "critical" ]] || [[ "$severity" == "high" ]]; then
        queue_notifications "$software_id" "$violation_type" "$severity"
    fi
}

# Enhanced notification queuing with priority
queue_notifications() {
    local software_id="$1"
    local violation_type="$2"
    local severity="$3"
    
    # Queue Grim command notification (immediate)
    sqlite3 "$SCYTHE_DB" <<EOF
INSERT INTO communications (software_id, message_type, channel)
VALUES ('$software_id', '$violation_type', 'grim_command');
EOF
    
    # Queue email notification (high priority)
    if [[ "$severity" == "critical" ]]; then
        sqlite3 "$SCYTHE_DB" <<EOF
INSERT INTO communications (software_id, message_type, channel)
VALUES ('$software_id', '$violation_type', 'email');
EOF
    fi
    
    # Queue web dashboard notification
    sqlite3 "$SCYTHE_DB" <<EOF
INSERT INTO communications (software_id, message_type, channel)
VALUES ('$software_id', '$violation_type', 'web_dashboard');
EOF
}

# Enhanced notification checking with priority handling
check_grim_notifications() {
    local critical_notifications=$(sqlite3 "$SCYTHE_DB" "
        SELECT v.software_id, v.violation_type, v.severity, v.details 
        FROM violations v 
        JOIN communications c ON v.software_id = c.software_id 
        WHERE c.channel = 'grim_command' AND c.status = 'pending' 
        AND v.severity IN ('critical', 'high')
        ORDER BY v.created_at DESC
    ")
    
    local other_notifications=$(sqlite3 "$SCYTHE_DB" "
        SELECT v.software_id, v.violation_type, v.severity, v.details 
        FROM violations v 
        JOIN communications c ON v.software_id = c.software_id 
        WHERE c.channel = 'grim_command' AND c.status = 'pending' 
        AND v.severity IN ('medium', 'low')
        ORDER BY v.created_at DESC
        LIMIT 5
    ")
    
    if [[ -n "$critical_notifications" ]]; then
        echo
        echo "${RED}=== SCYTHE CRITICAL VIOLATIONS ===${RESET}"
        echo "$critical_notifications" | while IFS='|' read -r software_id violation_type severity details; do
            echo "${RED}🚨 $severity: $software_id - $violation_type${RESET}"
            echo "   Details: $details"
        done
        echo
    fi
    
    if [[ -n "$other_notifications" ]]; then
        echo "${YELLOW}=== SCYTHE NOTIFICATIONS ===${RESET}"
        echo "$other_notifications" | while IFS='|' read -r software_id violation_type severity details; do
            echo "${YELLOW}⚠ $severity: $software_id - $violation_type${RESET}"
        done
        echo
    fi
    
    # Mark as delivered
    if [[ -n "$critical_notifications" ]] || [[ -n "$other_notifications" ]]; then
        sqlite3 "$SCYTHE_DB" "UPDATE communications SET status = 'delivered' WHERE channel = 'grim_command' AND status = 'pending'"
    fi
}

# Enhanced protection installation with better configuration
install_protection() {
    local target_dir="$1"
    local software_id="$2"
    local software_name="$3"
    local stealth_mode="${4:-true}"
    
    # Validate parameters
    if [[ -z "$target_dir" ]] || [[ -z "$software_id" ]] || [[ -z "$software_name" ]]; then
        echo "${RED}Error: Missing required parameters${RESET}"
        echo "Usage: $0 install <target_dir> <software_id> <software_name> [stealth]"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Create enhanced scythe configuration
    cat > "$target_dir/.scythe.tsk" <<EOF
# Scythe Protection Configuration
software:
  id: "$software_id"
  name: "$software_name"
  version: "1.0.0"

protection:
  check_files:
    - "main.*"
    - "index.*"
    - "app.*"
    - "src/main.*"
  check_processes:
    - "$software_name"
    - "java.*$software_name"
    - "node.*$software_name"
  license_file: ".license"
  heartbeat_url: "$MOTHER_DB_URL/heartbeat"
  integrity_check: true

monitoring:
  interval: $SCYTHE_CHECK_INTERVAL
  silent: true
  background: true
  stealth: $stealth_mode
  retry_attempts: 3
  timeout: 30

notifications:
  channels:
    - grim_command
    - email
    - web_dashboard
  priority_levels:
    - critical
    - high
    - medium
    - low

security:
  obfuscate_process: true
  hide_files: true
  encrypt_communications: false
EOF
    
    # Create integration script based on language
    create_integration_script "$target_dir" "$software_id"
    
    # Register in local database
    sqlite3 "$SCYTHE_DB" <<EOF
INSERT OR REPLACE INTO monitors (software_id, software_name, stealth_mode, updated_at)
VALUES ('$software_id', '$software_name', '$stealth_mode', CURRENT_TIMESTAMP);
EOF
    
    echo "${GREEN}✓ Scythe protection installed for $software_name${RESET}"
    echo "  Configuration: $target_dir/.scythe.tsk"
    echo "  Monitor ID: $software_id"
    echo "  Stealth Mode: $stealth_mode"
    
    # Start monitoring if requested
    if [[ "$5" == "--start" ]]; then
        start_monitoring "$software_id" "$target_dir/.scythe.tsk"
    fi
}

# Start monitoring for a specific software
start_monitoring() {
    local software_id="$1"
    local config_file="$2"
    
    # Check if already monitoring
    if [[ -f "$SCYTHE_PID" ]]; then
        local pid=$(cat "$SCYTHE_PID" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            echo "${YELLOW}⚠ Scythe monitoring already running (PID: $pid)${RESET}"
            return 0
        fi
    fi
    
    # Start silent monitoring
    silent_monitor "$software_id" "$config_file"
    
    echo "${GREEN}✓ Scythe monitoring started for $software_id${RESET}"
}

# Stop monitoring
stop_monitoring() {
    if [[ -f "$SCYTHE_PID" ]]; then
        local pid=$(cat "$SCYTHE_PID" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$SCYTHE_PID"
            echo "${GREEN}✓ Scythe monitoring stopped${RESET}"
        else
            echo "${YELLOW}⚠ Scythe monitoring not running${RESET}"
        fi
    else
        echo "${YELLOW}⚠ No monitoring PID file found${RESET}"
    fi
}

# Generate comprehensive violation report
generate_report() {
    local report_type="${1:-summary}"
    local software_id="$2"
    
    case "$report_type" in
        summary)
            echo "${GREEN}=== Scythe Protection Summary ===${RESET}"
            sqlite3 "$SCYTHE_DB" "
                SELECT 
                    software_name,
                    status,
                    violations,
                    check_count,
                    last_check,
                    stealth_mode
                FROM monitors
                ORDER BY violations DESC, last_check DESC
            "
            ;;
        violations)
            echo "${RED}=== Recent Violations ===${RESET}"
            if [[ -n "$software_id" ]]; then
                sqlite3 "$SCYTHE_DB" "
                    SELECT 
                        violation_type,
                        severity,
                        details,
                        created_at
                    FROM violations 
                    WHERE software_id = '$software_id'
                    ORDER BY created_at DESC
                    LIMIT 20
                "
            else
                sqlite3 "$SCYTHE_DB" "
                    SELECT 
                        software_id,
                        violation_type,
                        severity,
                        details,
                        created_at
                    FROM violations 
                    ORDER BY created_at DESC
                    LIMIT 20
                "
            fi
            ;;
        communications)
            echo "${BLUE}=== Communication Queue ===${RESET}"
            sqlite3 "$SCYTHE_DB" "
                SELECT 
                    software_id,
                    message_type,
                    channel,
                    status,
                    retry_count,
                    created_at
                FROM communications
                ORDER BY created_at DESC
                LIMIT 20
            "
            ;;
        *)
            echo "${RED}Unknown report type: $report_type${RESET}"
            echo "Available types: summary, violations, communications"
            ;;
    esac
}

# Display enhanced help
help() {
    cat <<EOF
${GREEN}Grim Scythe v$SCYTHE_VERSION - Silent License Protection System${RESET}

Usage: $0 [command] [options]

Commands:
  install <dir> <id> <name> [stealth] [--start]  Install protection in software project
  start <software_id> [config_file]              Start monitoring a protected software
  stop                                           Stop all monitoring
  check                                          Check for violations and notifications
  validate <license>                             Validate a license key
  report [type] [software_id]                    Generate violation report
  status                                         Show protection status
  init                                           Initialize database
  
Report Types:
  summary        - Overview of all protected software
  violations     - Recent license violations
  communications - Notification queue status

Options:
  -h, --help                Show this help message
  -s, --silent              Run in silent mode
  -b, --background          Run in background
  --stealth                 Enable stealth mode (default)
  --no-stealth              Disable stealth mode

Examples:
  $0 install /app/myproject proj123 "My Project" true --start
  $0 start proj123
  $0 report violations proj123
  $0 check
  
Configuration:
  Main config: $SCYTHE_CONFIG
  Database: $SCYTHE_DB
  Log file: $SCYTHE_LOG
  
Protection Features:
  - Silent monitoring without user awareness
  - Stealth mode with process name obfuscation
  - Multi-channel notifications with priority
  - Mother DB synchronization with retry logic
  - File integrity checking
  - Process violation detection
  - Support for 9+ programming languages
  - Enhanced .tsk configuration parsing
  - Comprehensive violation tracking
EOF
}

# Main command handler with enhanced functionality
case "${1:-help}" in
    install)
        shift
        install_protection "$@"
        ;;
    start)
        shift
        start_monitoring "$@"
        ;;
    stop)
        stop_monitoring
        ;;
    monitor)
        shift
        silent_monitor "$@"
        ;;
    check)
        check_grim_notifications
        ;;
    validate)
        shift
        validate_license "manual" "$1"
        ;;
    report)
        shift
        generate_report "$@"
        ;;
    status)
        echo "${GREEN}=== Scythe Protection Status ===${RESET}"
        sqlite3 "$SCYTHE_DB" "
            SELECT 
                software_name, 
                status, 
                violations, 
                check_count,
                last_check,
                stealth_mode
            FROM monitors 
            ORDER BY violations DESC
        "
        
        # Show monitoring status
        if [[ -f "$SCYTHE_PID" ]]; then
            local pid=$(cat "$SCYTHE_PID" 2>/dev/null)
            if kill -0 "$pid" 2>/dev/null; then
                echo "${GREEN}✓ Monitoring active (PID: $pid)${RESET}"
            else
                echo "${RED}✗ Monitoring inactive${RESET}"
            fi
        else
            echo "${YELLOW}⚠ No monitoring PID file${RESET}"
        fi
        ;;
    init)
        init_scythe_db
        echo "${GREEN}✓ Scythe database initialized${RESET}"
        ;;
    _internal_check)
        shift
        internal_check "$@"
        ;;
    dashboard)
        echo "${GREEN}Opening Scythe Dashboard at http://localhost:8082${RESET}"
        xdg-open http://localhost:8082 2>/dev/null || open http://localhost:8082 2>/dev/null || echo "Please open http://localhost:8082 in your browser"
        ;;

    help|-h|--help)
        help
        ;;
    *)
        echo "${RED}Unknown command: $1${RESET}"
        help
        exit 1
        ;;
esac

# Create integration script based on language
create_integration_script() {
    local target_dir="$1"
    local software_id="$2"
    
    # Detect language
    local lang=""
    if [[ -f "$target_dir/package.json" ]]; then
        lang="node"
    elif [[ -f "$target_dir/requirements.txt" ]] || [[ -f "$target_dir/setup.py" ]]; then
        lang="python"
    elif [[ -f "$target_dir/go.mod" ]]; then
        lang="go"
    elif [[ -f "$target_dir/Cargo.toml" ]]; then
        lang="rust"
    elif [[ -f "$target_dir/composer.json" ]]; then
        lang="php"
    elif [[ -f "$target_dir/Gemfile" ]]; then
        lang="ruby"
    elif [[ -f "$target_dir/pom.xml" ]] || [[ -f "$target_dir/build.gradle" ]]; then
        lang="java"
    elif [[ -f "$target_dir/Project.toml" ]]; then
        lang="julia"
    elif [[ -f "$target_dir/rebar.config" ]] || [[ -f "$target_dir/mix.exs" ]]; then
        lang="elixir"
    fi
    
    # Create appropriate integration
    case "$lang" in
        node)
            create_node_integration "$target_dir" "$software_id"
            ;;
        python)
            create_python_integration "$target_dir" "$software_id"
            ;;
        go)
            create_go_integration "$target_dir" "$software_id"
            ;;
        rust)
            create_rust_integration "$target_dir" "$software_id"
            ;;
        php)
            create_php_integration "$target_dir" "$software_id"
            ;;
        ruby)
            create_ruby_integration "$target_dir" "$software_id"
            ;;
        java)
            create_java_integration "$target_dir" "$software_id"
            ;;
        julia)
            create_julia_integration "$target_dir" "$software_id"
            ;;
        elixir)
            create_elixir_integration "$target_dir" "$software_id"
            ;;
        *)
            create_generic_integration "$target_dir" "$software_id"
            ;;
    esac
}

# Node.js integration
create_node_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.js" <<'EOF'
const fs = require('fs');
const https = require('https');
const crypto = require('crypto');

class Scythe {
    constructor(config = '.scythe.tsk') {
        this.config = this.parseConfig(config);
        this.init();
    }
    
    init() {
        // Silent initialization
        setInterval(() => this.check(), this.config.monitoring.interval * 1000);
        this.check();
    }
    
    parseConfig(configFile) {
        // Parse .tsk format
        const content = fs.readFileSync(configFile, 'utf8');
        // Simple parser implementation
        return JSON.parse(content); // Simplified
    }
    
    check() {
        const licenseExists = fs.existsSync(this.config.protection.license_file);
        if (!licenseExists) {
            this.reportViolation('unlicensed');
        } else {
            this.validateLicense();
        }
    }
    
    validateLicense() {
        const license = fs.readFileSync(this.config.protection.license_file, 'utf8').trim();
        // Validate with mother DB
        const data = JSON.stringify({
            software_id: this.config.software.id,
            license_key: license
        });
        
        const options = {
            hostname: 'api.grim.so',
            path: '/scythe/validate',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': data.length
            }
        };
        
        const req = https.request(options, (res) => {
            if (res.statusCode !== 200) {
                this.reportViolation('invalid_license');
            }
        });
        
        req.write(data);
        req.end();
    }
    
    reportViolation(type) {
        // Silent reporting to mother DB
        const data = JSON.stringify({
            software_id: this.config.software.id,
            violation_type: type,
            timestamp: new Date().toISOString()
        });
        
        const options = {
            hostname: 'api.grim.so',
            path: '/scythe/violation',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': data.length
            }
        };
        
        const req = https.request(options);
        req.write(data);
        req.end();
    }
}

// Auto-initialize if imported
if (require.main !== module) {
    new Scythe();
}

module.exports = Scythe;
EOF
}

# Python integration
create_python_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.py" <<'EOF'
import os
import json
import time
import threading
import requests
from pathlib import Path

class Scythe:
    def __init__(self, config_file='.scythe.tsk'):
        self.config = self._parse_config(config_file)
        self._init()
    
    def _init(self):
        # Start silent monitoring in background
        thread = threading.Thread(target=self._monitor_loop, daemon=True)
        thread.start()
    
    def _parse_config(self, config_file):
        # Parse .tsk format (simplified for example)
        with open(config_file, 'r') as f:
            content = f.read()
        # Simple parser - in reality would parse .tsk format
        return {}  # Placeholder
    
    def _monitor_loop(self):
        while True:
            self._check()
            time.sleep(self.config.get('monitoring', {}).get('interval', 3600))
    
    def _check(self):
        license_file = self.config.get('protection', {}).get('license_file', '.license')
        if not os.path.exists(license_file):
            self._report_violation('unlicensed')
        else:
            self._validate_license()
    
    def _validate_license(self):
        license_file = self.config.get('protection', {}).get('license_file', '.license')
        with open(license_file, 'r') as f:
            license_key = f.read().strip()
        
        try:
            response = requests.post(
                'https://api.grim.so/scythe/validate',
                json={
                    'software_id': self.config['software']['id'],
                    'license_key': license_key
                }
            )
            if not response.json().get('valid'):
                self._report_violation('invalid_license')
        except:
            pass  # Silent failure
    
    def _report_violation(self, violation_type):
        try:
            requests.post(
                'https://api.grim.so/scythe/violation',
                json={
                    'software_id': self.config['software']['id'],
                    'violation_type': violation_type
                }
            )
        except:
            pass  # Silent failure

# Auto-initialize when imported
_scythe_instance = Scythe()
EOF
}

# Go integration
create_go_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.go" <<'EOF'
package scythe

import (
    "encoding/json"
    "fmt"
    "io/ioutil"
    "net/http"
    "os"
    "strings"
    "time"
)

type Config struct {
    Software struct {
        ID string `json:"id"`
    } `json:"software"`
    Protection struct {
        LicenseFile string `json:"license_file"`
    } `json:"protection"`
    Monitoring struct {
        Interval int `json:"interval"`
    } `json:"monitoring"`
}

type Scythe struct {
    config Config
}

func init() {
    // Auto-initialize when imported
    go New().Start()
}

func New() *Scythe {
    s := &Scythe{}
    s.config = s.loadConfig()
    return s
}

func (s *Scythe) Start() {
    ticker := time.NewTicker(time.Duration(s.config.Monitoring.Interval) * time.Second)
    defer ticker.Stop()
    
    // Initial check
    s.check()
    
    for {
        select {
        case <-ticker.C:
            s.check()
        }
    }
}

func (s *Scythe) loadConfig() Config {
    var config Config
    data, err := ioutil.ReadFile(".scythe.tsk")
    if err != nil {
        // Return default config
        config.Software.ID = "default"
        config.Protection.LicenseFile = ".license"
        config.Monitoring.Interval = 3600
        return config
    }
    
    // Simple JSON parsing (in reality would parse .tsk format)
    json.Unmarshal(data, &config)
    return config
}

func (s *Scythe) check() {
    defer func() {
        if r := recover(); r != nil {
            // Silent recovery
        }
    }()
    
    if !s.licenseExists() {
        s.reportViolation("unlicensed")
    } else {
        s.validateLicense()
    }
}

func (s *Scythe) licenseExists() bool {
    _, err := os.Stat(s.config.Protection.LicenseFile)
    return err == nil
}

func (s *Scythe) validateLicense() {
    data, err := ioutil.ReadFile(s.config.Protection.LicenseFile)
    if err != nil {
        s.reportViolation("invalid_license")
        return
    }
    
    licenseKey := strings.TrimSpace(string(data))
    
    payload := map[string]string{
        "software_id": s.config.Software.ID,
        "license_key": licenseKey,
    }
    
    jsonData, _ := json.Marshal(payload)
    
    resp, err := http.Post(
        "https://api.grim.so/scythe/validate",
        "application/json",
        strings.NewReader(string(jsonData)),
    )
    
    if err != nil || resp.StatusCode != 200 {
        s.reportViolation("invalid_license")
    }
}

func (s *Scythe) reportViolation(violationType string) {
    payload := map[string]string{
        "software_id":    s.config.Software.ID,
        "violation_type": violationType,
    }
    
    jsonData, _ := json.Marshal(payload)
    
    http.Post(
        "https://api.grim.so/scythe/violation",
        "application/json",
        strings.NewReader(string(jsonData)),
    )
}
EOF
}

# Rust integration
create_rust_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.rs" <<'EOF'
use std::fs;
use std::io::{self, Read};
use std::thread;
use std::time::Duration;
use serde_json::{json, Value};
use reqwest;

#[derive(serde::Deserialize)]
struct Config {
    software: Software,
    protection: Protection,
    monitoring: Monitoring,
}

#[derive(serde::Deserialize)]
struct Software {
    id: String,
}

#[derive(serde::Deserialize)]
struct Protection {
    license_file: String,
}

#[derive(serde::Deserialize)]
struct Monitoring {
    interval: u64,
}

struct Scythe {
    config: Config,
}

impl Scythe {
    fn new() -> Self {
        let config = Self::load_config();
        Self { config }
    }
    
    fn load_config() -> Config {
        let content = fs::read_to_string(".scythe.tsk").unwrap_or_default();
        // Simple JSON parsing (in reality would parse .tsk format)
        serde_json::from_str(&content).unwrap_or(Config {
            software: Software { id: "default".to_string() },
            protection: Protection { license_file: ".license".to_string() },
            monitoring: Monitoring { interval: 3600 },
        })
    }
    
    fn start(&self) {
        let config = self.config.clone();
        thread::spawn(move || {
            loop {
                Self::check(&config);
                thread::sleep(Duration::from_secs(config.monitoring.interval));
            }
        });
    }
    
    fn check(config: &Config) {
        if !Self::license_exists(&config.protection.license_file) {
            Self::report_violation(config, "unlicensed");
        } else {
            Self::validate_license(config);
        }
    }
    
    fn license_exists(license_file: &str) -> bool {
        fs::metadata(license_file).is_ok()
    }
    
    fn validate_license(config: &Config) {
        let license_key = match fs::read_to_string(&config.protection.license_file) {
            Ok(content) => content.trim().to_string(),
            Err(_) => {
                Self::report_violation(config, "invalid_license");
                return;
            }
        };
        
        let payload = json!({
            "software_id": config.software.id,
            "license_key": license_key,
        });
        
        let client = reqwest::blocking::Client::new();
        let response = client
            .post("https://api.grim.so/scythe/validate")
            .json(&payload)
            .send();
        
        if let Err(_) = response {
            Self::report_violation(config, "invalid_license");
        }
    }
    
    fn report_violation(config: &Config, violation_type: &str) {
        let payload = json!({
            "software_id": config.software.id,
            "violation_type": violation_type,
        });
        
        let client = reqwest::blocking::Client::new();
        let _ = client
            .post("https://api.grim.so/scythe/violation")
            .json(&payload)
            .send();
    }
}

// Auto-initialize when imported
lazy_static::lazy_static! {
    static ref SCYTHE: Scythe = {
        let scythe = Scythe::new();
        scythe.start();
        scythe
    };
}
EOF
}

# PHP integration
create_php_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.php" <<'EOF'
<?php
/**
 * Scythe Integration for PHP
 * Silent license protection system
 */

class Scythe {
    private $config;
    private $running = false;
    
    public function __construct($configFile = '.scythe.tsk') {
        $this->config = $this->loadConfig($configFile);
        $this->init();
    }
    
    private function init() {
        // Start background monitoring
        if (!$this->running) {
            $this->running = true;
            $this->startMonitor();
        }
    }
    
    private function loadConfig($configFile) {
        if (!file_exists($configFile)) {
            return [
                'software' => ['id' => 'default'],
                'protection' => ['license_file' => '.license'],
                'monitoring' => ['interval' => 3600]
            ];
        }
        
        $content = file_get_contents($configFile);
        // Simple JSON parsing (in reality would parse .tsk format)
        return json_decode($content, true) ?: [];
    }
    
    private function startMonitor() {
        // Use pcntl_fork for background process if available
        if (function_exists('pcntl_fork')) {
            $pid = pcntl_fork();
            if ($pid == 0) {
                // Child process
                $this->monitorLoop();
                exit(0);
            }
        } else {
            // Fallback to register_shutdown_function
            register_shutdown_function([$this, 'monitorLoop']);
        }
    }
    
    public function monitorLoop() {
        while ($this->running) {
            $this->check();
            sleep($this->config['monitoring']['interval'] ?? 3600);
        }
    }
    
    private function check() {
        $licenseFile = $this->config['protection']['license_file'] ?? '.license';
        
        if (!file_exists($licenseFile)) {
            $this->reportViolation('unlicensed');
        } else {
            $this->validateLicense();
        }
    }
    
    private function validateLicense() {
        $licenseFile = $this->config['protection']['license_file'] ?? '.license';
        $licenseKey = trim(file_get_contents($licenseFile));
        
        $payload = [
            'software_id' => $this->config['software']['id'],
            'license_key' => $licenseKey
        ];
        
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => 'Content-Type: application/json',
                'content' => json_encode($payload)
            ]
        ]);
        
        $response = @file_get_contents(
            'https://api.grim.so/scythe/validate',
            false,
            $context
        );
        
        if ($response === false) {
            $this->reportViolation('invalid_license');
        }
    }
    
    private function reportViolation($violationType) {
        $payload = [
            'software_id' => $this->config['software']['id'],
            'violation_type' => $violationType
        ];
        
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => 'Content-Type: application/json',
                'content' => json_encode($payload)
            ]
        ]);
        
        @file_get_contents(
            'https://api.grim.so/scythe/violation',
            false,
            $context
        );
    }
}

// Auto-initialize when included
if (!defined('SCYTHE_INITIALIZED')) {
    define('SCYTHE_INITIALIZED', true);
    new Scythe();
}
EOF
}

# Ruby integration
create_ruby_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.rb" <<'EOF'
require 'json'
require 'net/http'
require 'uri'
require 'thread'

class Scythe
  def initialize(config_file = '.scythe.tsk')
    @config = load_config(config_file)
    @running = true
    init
  end
  
  private
  
  def init
    # Start background monitoring thread
    Thread.new do
      monitor_loop
    end
  end
  
  def load_config(config_file)
    return default_config unless File.exist?(config_file)
    
    content = File.read(config_file)
    # Simple JSON parsing (in reality would parse .tsk format)
    JSON.parse(content) rescue default_config
  end
  
  def default_config
    {
      'software' => { 'id' => 'default' },
      'protection' => { 'license_file' => '.license' },
      'monitoring' => { 'interval' => 3600 }
    }
  end
  
  def monitor_loop
    while @running
      check
      sleep(@config['monitoring']['interval'] || 3600)
    end
  end
  
  def check
    license_file = @config['protection']['license_file'] || '.license'
    
    unless File.exist?(license_file)
      report_violation('unlicensed')
    else
      validate_license
    end
  end
  
  def validate_license
    license_file = @config['protection']['license_file'] || '.license'
    license_key = File.read(license_file).strip
    
    payload = {
      'software_id' => @config['software']['id'],
      'license_key' => license_key
    }
    
    uri = URI('https://api.grim.so/scythe/validate')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    begin
      response = http.request(request)
      report_violation('invalid_license') unless response.code == '200'
    rescue
      report_violation('invalid_license')
    end
  end
  
  def report_violation(violation_type)
    payload = {
      'software_id' => @config['software']['id'],
      'violation_type' => violation_type
    }
    
    uri = URI('https://api.grim.so/scythe/violation')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    begin
      http.request(request)
    rescue
      # Silent failure
    end
  end
end

# Auto-initialize when required
Scythe.new unless defined?(SCYTHE_INITIALIZED)
SCYTHE_INITIALIZED = true
EOF
}

# Java integration
create_java_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/Scythe.java" <<'EOF'
import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import org.json.*;

public class Scythe {
    private JSONObject config;
    private AtomicBoolean running;
    private ScheduledExecutorService scheduler;
    
    public Scythe() {
        this.config = loadConfig();
        this.running = new AtomicBoolean(true);
        this.scheduler = Executors.newScheduledThreadPool(1);
        init();
    }
    
    private void init() {
        // Start background monitoring
        scheduler.scheduleAtFixedRate(
            this::check,
            0,
            config.getJSONObject("monitoring").getInt("interval"),
            TimeUnit.SECONDS
        );
    }
    
    private JSONObject loadConfig() {
        try {
            String content = new String(Files.readAllBytes(Paths.get(".scythe.tsk")));
            return new JSONObject(content);
        } catch (Exception e) {
            // Return default config
            JSONObject config = new JSONObject();
            JSONObject software = new JSONObject();
            software.put("id", "default");
            config.put("software", software);
            
            JSONObject protection = new JSONObject();
            protection.put("license_file", ".license");
            config.put("protection", protection);
            
            JSONObject monitoring = new JSONObject();
            monitoring.put("interval", 3600);
            config.put("monitoring", monitoring);
            
            return config;
        }
    }
    
    private void check() {
        try {
            String licenseFile = config.getJSONObject("protection").getString("license_file");
            
            if (!Files.exists(Paths.get(licenseFile))) {
                reportViolation("unlicensed");
            } else {
                validateLicense();
            }
        } catch (Exception e) {
            // Silent failure
        }
    }
    
    private void validateLicense() {
        try {
            String licenseFile = config.getJSONObject("protection").getString("license_file");
            String licenseKey = new String(Files.readAllBytes(Paths.get(licenseFile))).trim();
            
            JSONObject payload = new JSONObject();
            payload.put("software_id", config.getJSONObject("software").getString("id"));
            payload.put("license_key", licenseKey);
            
            URL url = new URL("https://api.grim.so/scythe/validate");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setDoOutput(true);
            
            try (OutputStream os = conn.getOutputStream()) {
                byte[] input = payload.toString().getBytes("utf-8");
                os.write(input, 0, input.length);
            }
            
            if (conn.getResponseCode() != 200) {
                reportViolation("invalid_license");
            }
        } catch (Exception e) {
            reportViolation("invalid_license");
        }
    }
    
    private void reportViolation(String violationType) {
        try {
            JSONObject payload = new JSONObject();
            payload.put("software_id", config.getJSONObject("software").getString("id"));
            payload.put("violation_type", violationType);
            
            URL url = new URL("https://api.grim.so/scythe/violation");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setDoOutput(true);
            
            try (OutputStream os = conn.getOutputStream()) {
                byte[] input = payload.toString().getBytes("utf-8");
                os.write(input, 0, input.length);
            }
            
            conn.getResponseCode(); // Consume response
        } catch (Exception e) {
            // Silent failure
        }
    }
    
    public void shutdown() {
        running.set(false);
        scheduler.shutdown();
    }
}

// Auto-initialize when loaded
static {
    new Scythe();
}
EOF
}

# Julia integration
create_julia_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.jl" <<'EOF'
using JSON3
using HTTP
using Base.Threads

struct Software
    id::String
end

struct Protection
    license_file::String
end

struct Monitoring
    interval::Int
end

struct Config
    software::Software
    protection::Protection
    monitoring::Monitoring
end

mutable struct Scythe
    config::Config
    running::Bool
    
    function Scythe()
        config = load_config()
        scythe = new(config, true)
        init(scythe)
        scythe
    end
end

function load_config()
    try
        content = read(".scythe.tsk", String)
        # Simple JSON parsing (in reality would parse .tsk format)
        data = JSON3.read(content)
        Config(
            Software(data.software.id),
            Protection(data.protection.license_file),
            Monitoring(data.monitoring.interval)
        )
    catch
        # Default config
        Config(
            Software("default"),
            Protection(".license"),
            Monitoring(3600)
        )
    end
end

function init(scythe::Scythe)
    # Start background monitoring thread
    @spawn monitor_loop(scythe)
end

function monitor_loop(scythe::Scythe)
    while scythe.running
        check(scythe)
        sleep(scythe.config.monitoring.interval)
    end
end

function check(scythe::Scythe)
    try
        if !isfile(scythe.config.protection.license_file)
            report_violation(scythe, "unlicensed")
        else
            validate_license(scythe)
        end
    catch
        # Silent failure
    end
end

function validate_license(scythe::Scythe)
    try
        license_key = strip(read(scythe.config.protection.license_file, String))
        
        payload = Dict(
            "software_id" => scythe.config.software.id,
            "license_key" => license_key
        )
        
        response = HTTP.post(
            "https://api.grim.so/scythe/validate",
            ["Content-Type" => "application/json"],
            JSON3.write(payload)
        )
        
        if response.status != 200
            report_violation(scythe, "invalid_license")
        end
    catch
        report_violation(scythe, "invalid_license")
    end
end

function report_violation(scythe::Scythe, violation_type::String)
    try
        payload = Dict(
            "software_id" => scythe.config.software.id,
            "violation_type" => violation_type
        )
        
        HTTP.post(
            "https://api.grim.so/scythe/violation",
            ["Content-Type" => "application/json"],
            JSON3.write(payload)
        )
    catch
        # Silent failure
    end
end

# Auto-initialize when loaded
if !@isdefined(SCYTHE_INSTANCE)
    global SCYTHE_INSTANCE = Scythe()
end
EOF
}

# Elixir integration
create_elixir_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.ex" <<'EOF'
defmodule Scythe do
  use GenServer
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    config = load_config()
    schedule_check(config.monitoring.interval)
    {:ok, %{config: config}}
  end
  
  def handle_info(:check, state) do
    check(state.config)
    schedule_check(state.config.monitoring.interval)
    {:noreply, state}
  end
  
  defp load_config do
    case File.read(".scythe.tsk") do
      {:ok, content} ->
        # Simple JSON parsing (in reality would parse .tsk format)
        case Jason.decode(content) do
          {:ok, data} ->
            %{
              software: %{id: data["software"]["id"]},
              protection: %{license_file: data["protection"]["license_file"]},
              monitoring: %{interval: data["monitoring"]["interval"]}
            }
          _ ->
            default_config()
        end
      _ ->
        default_config()
    end
  end
  
  defp default_config do
    %{
      software: %{id: "default"},
      protection: %{license_file: ".license"},
      monitoring: %{interval: 3600}
    }
  end
  
  defp schedule_check(interval) do
    Process.send_after(self(), :check, interval * 1000)
  end
  
  defp check(config) do
    if File.exists?(config.protection.license_file) do
      validate_license(config)
    else
      report_violation(config, "unlicensed")
    end
  end
  
  defp validate_license(config) do
    case File.read(config.protection.license_file) do
      {:ok, license_key} ->
        license_key = String.trim(license_key)
        
        payload = %{
          "software_id" => config.software.id,
          "license_key" => license_key
        }
        
        case HTTPoison.post(
          "https://api.grim.so/scythe/validate",
          Jason.encode!(payload),
          [{"Content-Type", "application/json"}]
        ) do
          {:ok, %HTTPoison.Response{status_code: 200}} ->
            :ok
          _ ->
            report_violation(config, "invalid_license")
        end
      _ ->
        report_violation(config, "invalid_license")
    end
  end
  
  defp report_violation(config, violation_type) do
    payload = %{
      "software_id" => config.software.id,
      "violation_type" => violation_type
    }
    
    HTTPoison.post(
      "https://api.grim.so/scythe/violation",
      Jason.encode!(payload),
      [{"Content-Type", "application/json"}]
    )
  end
end

# Auto-initialize when loaded
Scythe.start_link()
EOF
}

# Generic integration for unknown languages
create_generic_integration() {
    local target_dir="$1"
    local software_id="$2"
    
    cat > "$target_dir/scythe.sh" <<EOF
#!/bin/bash
# Generic Scythe Integration for $software_id
# Auto-initializes when sourced

SCYTHE_CONFIG=".scythe.tsk"
SCYTHE_SOFTWARE_ID="$software_id"

# Parse .tsk configuration
parse_scythe_config() {
    local section="\$1"
    local key="\$2"
    
    if [[ ! -f "\$SCYTHE_CONFIG" ]]; then
        return 1
    fi
    
    local in_section=false
    while IFS= read -r line; do
        [[ "\$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "\${line// }" ]] && continue
        
        if [[ "\$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*): ]]; then
            local current_section="\${BASH_REMATCH[1]}"
            if [[ "\$current_section" == "\$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi
        
        if [[ "\$in_section" == "true" ]]; then
            if [[ "\$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*(.+)$ ]]; then
                local current_key="\${BASH_REMATCH[1]}"
                local value="\${BASH_REMATCH[2]}"
                
                if [[ "\$current_key" == "\$key" ]]; then
                    value="\${value%\"}"
                    value="\${value#\"}"
                    value="\${value%\'}"
                    value="\${value#\'}"
                    echo "\$value"
                    return 0
                fi
            fi
        fi
    done < "\$SCYTHE_CONFIG"
    
    return 1
}

# Check license
check_scythe_license() {
    local license_file=\$(parse_scythe_config "protection" "license_file")
    [[ -z "\$license_file" ]] && license_file=".license"
    
    if [[ ! -f "\$license_file" ]]; then
        report_scythe_violation "unlicensed"
        return 1
    fi
    
    local license_key=\$(cat "\$license_file" 2>/dev/null | tr -d '\n\r')
    if [[ -z "\$license_key" ]]; then
        report_scythe_violation "invalid_license"
        return 1
    fi
    
    # Validate with mother DB
    local response=\$(curl -s -X POST "https://api.grim.so/scythe/validate" \\
        -H "Content-Type: application/json" \\
        -d "{\\\"software_id\\\": \\\"\$SCYTHE_SOFTWARE_ID\\\", \\\"license_key\\\": \\\"\$license_key\\\"}" \\
        --connect-timeout 10 \\
        --max-time 30)
    
    local valid=\$(echo "\$response" | jq -r '.valid' 2>/dev/null)
    if [[ "\$valid" != "true" ]]; then
        report_scythe_violation "invalid_license"
        return 1
    fi
    
    return 0
}

# Report violation
report_scythe_violation() {
    local violation_type="\$1"
    
    curl -s -X POST "https://api.grim.so/scythe/violation" \\
        -H "Content-Type: application/json" \\
        -d "{\\\"software_id\\\": \\\"\$SCYTHE_SOFTWARE_ID\\\", \\\"violation_type\\\": \\\"\$violation_type\\\"}" \\
        --connect-timeout 5 \\
        --max-time 10 >/dev/null 2>&1
}

# Auto-initialize
if [[ "\${BASH_SOURCE[0]}" != "\${0}" ]]; then
    # Script is being sourced, start monitoring
    check_scythe_license
fi
EOF
    
    chmod +x "$target_dir/scythe.sh"
}