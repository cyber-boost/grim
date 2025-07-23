#!/bin/bash
# Grimm File Integrity Module: Monitor and verify file integrity

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/integrity.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/verify.log"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"
MONITOR_PID_FILE="$GRIM_ROOT/logs/verify-monitor.pid"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Initialize SQLite database
init_database() {
    mkdir -p "$(dirname "$DB_PATH")"
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS integrity_baselines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL UNIQUE,
    checksum TEXT NOT NULL,
    size INTEGER NOT NULL,
    mtime INTEGER NOT NULL,
    permissions TEXT NOT NULL,
    owner TEXT NOT NULL,
    "group" TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS integrity_violations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL,
    violation_type TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS monitor_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_baselines_path ON integrity_baselines(path);
CREATE INDEX IF NOT EXISTS idx_violations_path ON integrity_violations(path);
CREATE INDEX IF NOT EXISTS idx_violations_resolved ON integrity_violations(resolved);
EOF
    log "Database initialized: $DB_PATH"
}

# Calculate file checksum
calculate_checksum() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo ""
    fi
}

# Get file metadata
get_file_metadata() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        local mtime=$(stat -c%Y "$file" 2>/dev/null || echo "0")
        local permissions=$(stat -c%a "$file" 2>/dev/null || echo "000")
        local owner=$(stat -c%U "$file" 2>/dev/null || echo "unknown")
        local group=$(stat -c%G "$file" 2>/dev/null || echo "unknown")
        echo "$size|$mtime|$permissions|$owner|$group"
    else
        echo ""
    fi
}

# Create integrity baseline
create_baseline() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify create <path>"
        return 1
    fi
    
    if [[ ! -e "$path" ]]; then
        echo -e "${RED}Error: Path does not exist: $path${NC}"
        return 1
    fi
    
    init_database
    
    if [[ -f "$path" ]]; then
        # Single file
        create_file_baseline "$path"
    elif [[ -d "$path" ]]; then
        # Directory - recursive
        create_directory_baseline "$path"
    else
        echo -e "${RED}Error: Path is neither file nor directory${NC}"
        return 1
    fi
}

# Create baseline for single file
create_file_baseline() {
    local file="$1"
    local abs_path=$(readlink -f "$file")
    local checksum=$(calculate_checksum "$abs_path")
    local metadata=$(get_file_metadata "$abs_path")
    
    if [[ -z "$checksum" ]]; then
        echo -e "${RED}Error: Cannot calculate checksum for $file${NC}"
        return 1
    fi
    
    IFS='|' read -r size mtime permissions owner group <<< "$metadata"
    
    sqlite3 "$DB_PATH" << EOF
INSERT OR REPLACE INTO integrity_baselines 
(path, checksum, size, mtime, permissions, owner, "group", updated_at) 
VALUES ('$abs_path', '$checksum', $size, $mtime, '$permissions', '$owner', '$group', CURRENT_TIMESTAMP);
EOF
    
    echo -e "${GREEN}✓ Baseline created for: $file${NC}"
    log "Baseline created: $file (checksum: ${checksum:0:8}...)"
}

# Create baseline for directory recursively
create_directory_baseline() {
    local dir="$1"
    local abs_dir=$(readlink -f "$dir")
    local count=0
    local errors=0
    
    echo -e "${CYAN}Creating baseline for directory: $dir${NC}"
    
    # Find all files in directory
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            if create_file_baseline "$file" >/dev/null 2>&1; then
                ((count++))
                if [[ $((count % 100)) -eq 0 ]]; then
                    echo -e "${BLUE}Processed $count files...${NC}"
                fi
            else
                ((errors++))
            fi
        fi
    done < <(find "$abs_dir" -type f -print0 2>/dev/null)
    
    echo -e "${GREEN}✓ Baseline created for $count files${NC}"
    if [[ $errors -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  $errors files had errors${NC}"
    fi
    log "Directory baseline created: $dir ($count files, $errors errors)"
}

# Check file integrity
check_integrity() {
    local path="$1"
    local violations=0
    local checked=0
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify check <path>"
        return 1
    fi
    
    if [[ ! -e "$path" ]]; then
        echo -e "${RED}Error: Path does not exist: $path${NC}"
        return 1
    fi
    
    init_database
    
    if [[ -f "$path" ]]; then
        # Single file
        check_file_integrity "$path"
    elif [[ -d "$path" ]]; then
        # Directory - recursive
        check_directory_integrity "$path"
    else
        echo -e "${RED}Error: Path is neither file nor directory${NC}"
        return 1
    fi
}

# Check integrity of single file
check_file_integrity() {
    local file="$1"
    local abs_path=$(readlink -f "$file")
    
    # Get baseline from database
    local baseline=$(sqlite3 "$DB_PATH" "SELECT checksum, size, mtime, permissions, owner, \"group\" FROM integrity_baselines WHERE path='$abs_path';" 2>/dev/null)
    
    if [[ -z "$baseline" ]]; then
        echo -e "${YELLOW}⚠️  No baseline found for: $file${NC}"
        return 1
    fi
    
    IFS='|' read -r baseline_checksum baseline_size baseline_mtime baseline_permissions baseline_owner baseline_group <<< "$baseline"
    
    # Get current file state
    local current_checksum=$(calculate_checksum "$abs_path")
    local current_metadata=$(get_file_metadata "$abs_path")
    
    if [[ -z "$current_checksum" ]]; then
        echo -e "${RED}✗ File missing: $file${NC}"
        record_violation "$abs_path" "file_missing" "$baseline_checksum" ""
        return 1
    fi
    
    IFS='|' read -r current_size current_mtime current_permissions current_owner current_group <<< "$current_metadata"
    
    local has_violations=false
    
    # Check checksum
    if [[ "$current_checksum" != "$baseline_checksum" ]]; then
        echo -e "${RED}✗ Checksum mismatch: $file${NC}"
        record_violation "$abs_path" "checksum_mismatch" "$baseline_checksum" "$current_checksum"
        has_violations=true
    fi
    
    # Check size
    if [[ "$current_size" != "$baseline_size" ]]; then
        echo -e "${RED}✗ Size changed: $file${NC}"
        record_violation "$abs_path" "size_changed" "$baseline_size" "$current_size"
        has_violations=true
    fi
    
    # Check permissions
    if [[ "$current_permissions" != "$baseline_permissions" ]]; then
        echo -e "${YELLOW}⚠️  Permissions changed: $file${NC}"
        record_violation "$abs_path" "permissions_changed" "$baseline_permissions" "$current_permissions"
        has_violations=true
    fi
    
    # Check owner
    if [[ "$current_owner" != "$baseline_owner" ]]; then
        echo -e "${YELLOW}⚠️  Owner changed: $file${NC}"
        record_violation "$abs_path" "owner_changed" "$baseline_owner" "$current_owner"
        has_violations=true
    fi
    
    # Check group
    if [[ "$current_group" != "$baseline_group" ]]; then
        echo -e "${YELLOW}⚠️  Group changed: $file${NC}"
        record_violation "$abs_path" "group_changed" "$baseline_group" "$current_group"
        has_violations=true
    fi
    
    if [[ "$has_violations" == "false" ]]; then
        echo -e "${GREEN}✓ Integrity OK: $file${NC}"
    fi
    
    return $([[ "$has_violations" == "true" ]] && echo 1 || echo 0)
}

# Check integrity of directory recursively
check_directory_integrity() {
    local dir="$1"
    local abs_dir=$(readlink -f "$dir")
    local violations=0
    local checked=0
    
    echo -e "${CYAN}Checking integrity for directory: $dir${NC}"
    
    # Get all baselines for this directory
    local baselines=$(sqlite3 "$DB_PATH" "SELECT path FROM integrity_baselines WHERE path LIKE '$abs_dir/%' OR path='$abs_dir';" 2>/dev/null)
    
    if [[ -z "$baselines" ]]; then
        echo -e "${YELLOW}⚠️  No baselines found for directory: $dir${NC}"
        return 1
    fi
    
    while IFS= read -r baseline_path; do
        if [[ -n "$baseline_path" ]]; then
            if check_file_integrity "$baseline_path" >/dev/null 2>&1; then
                ((checked++))
            else
                ((violations++))
            fi
            
            if [[ $((checked + violations)) -eq 100 ]]; then
                echo -e "${BLUE}Checked $((checked + violations)) files...${NC}"
            fi
        fi
    done <<< "$baselines"
    
    echo -e "${CYAN}Integrity check complete:${NC}"
    echo -e "  ${GREEN}✓ OK: $checked files${NC}"
    echo -e "  ${RED}✗ Violations: $violations files${NC}"
    
    if [[ $violations -gt 0 ]]; then
        echo -e "${YELLOW}Run 'grim verify report' to see detailed violations${NC}"
        return 1
    fi
    
    return 0
}

# Record integrity violation
record_violation() {
    local path="$1"
    local violation_type="$2"
    local old_value="$3"
    local new_value="$4"
    
    sqlite3 "$DB_PATH" << EOF
INSERT INTO integrity_violations (path, violation_type, old_value, new_value)
VALUES ('$path', '$violation_type', '$old_value', '$new_value');
EOF
    
    # Send notification
    "$NOTIFY_MODULE" send warning "File Integrity Violation" "File $path has $violation_type violation" "{\"path\": \"$path\", \"type\": \"$violation_type\", \"old_value\": \"$old_value\", \"new_value\": \"$new_value\"}"
}

# Start real-time monitoring
start_monitoring() {
    local watch_paths="${1:-/etc /var/log /opt/grim}"
    local interval="${2:-30}"
    
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠️  Monitoring already running (PID: $pid)${NC}"
            return 1
        else
            rm -f "$MONITOR_PID_FILE"
        fi
    fi
    
    echo -e "${CYAN}Starting file integrity monitoring...${NC}"
    echo -e "Watching: $watch_paths"
    echo -e "Interval: ${interval}s"
    
    # Start monitoring in background
    (
        while true; do
            for path in $watch_paths; do
                if [[ -e "$path" ]]; then
                    check_integrity "$path" >/dev/null 2>&1
                fi
            done
            sleep "$interval"
        done
    ) &
    
    local monitor_pid=$!
    echo "$monitor_pid" > "$MONITOR_PID_FILE"
    
    echo -e "${GREEN}✓ Monitoring started (PID: $monitor_pid)${NC}"
    log "File monitoring started (PID: $monitor_pid, paths: $watch_paths, interval: ${interval}s)"
    
    # Store monitoring config
    sqlite3 "$DB_PATH" << EOF
INSERT OR REPLACE INTO monitor_config (key, value, updated_at)
VALUES ('watch_paths', '$watch_paths', CURRENT_TIMESTAMP),
       ('interval', '$interval', CURRENT_TIMESTAMP),
       ('monitor_pid', '$monitor_pid', CURRENT_TIMESTAMP);
EOF
}

# Stop real-time monitoring
stop_monitoring() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$MONITOR_PID_FILE"
            echo -e "${GREEN}✓ Monitoring stopped (PID: $pid)${NC}"
            log "File monitoring stopped (PID: $pid)"
        else
            echo -e "${YELLOW}⚠️  Monitoring process not running${NC}"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        echo -e "${YELLOW}⚠️  No monitoring PID file found${NC}"
    fi
}

# Show integrity violations report
show_report() {
    local resolved_only="${1:-false}"
    
    init_database
    
    echo -e "${CYAN}File Integrity Violations Report${NC}"
    echo "======================================"
    
    if [[ "$resolved_only" == "true" ]]; then
        local violations=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM integrity_violations WHERE resolved=1;" 2>/dev/null)
        echo -e "Resolved violations: $violations"
        echo ""
        
        sqlite3 "$DB_PATH" "SELECT path, violation_type, old_value, new_value, detected_at, resolved_at FROM integrity_violations WHERE resolved=1 ORDER BY detected_at DESC LIMIT 20;" 2>/dev/null | while IFS='|' read -r path type old_val new_val detected resolved; do
            echo -e "${GREEN}✓ $path${NC}"
            echo -e "  Type: $type"
            echo -e "  Old: $old_val"
            echo -e "  New: $new_val"
            echo -e "  Detected: $detected"
            echo -e "  Resolved: $resolved"
            echo ""
        done
    else
        local total_violations=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM integrity_violations;" 2>/dev/null)
        local unresolved_violations=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM integrity_violations WHERE resolved=0;" 2>/dev/null)
        
        echo -e "Total violations: $total_violations"
        echo -e "Unresolved violations: $unresolved_violations"
        echo ""
        
        if [[ $unresolved_violations -gt 0 ]]; then
            echo -e "${RED}Unresolved Violations:${NC}"
            sqlite3 "$DB_PATH" "SELECT path, violation_type, old_value, new_value, detected_at FROM integrity_violations WHERE resolved=0 ORDER BY detected_at DESC;" 2>/dev/null | while IFS='|' read -r path type old_val new_val detected; do
                echo -e "${RED}✗ $path${NC}"
                echo -e "  Type: $type"
                echo -e "  Old: $old_val"
                echo -e "  New: $new_val"
                echo -e "  Detected: $detected"
                echo ""
            done
        fi
    fi
}

# Update baseline for legitimate changes
update_baseline() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify update <path>"
        return 1
    fi
    
    if [[ ! -e "$path" ]]; then
        echo -e "${RED}Error: Path does not exist: $path${NC}"
        return 1
    fi
    
    init_database
    
    # Update baseline
    if create_baseline "$path"; then
        # Mark violations as resolved
        local abs_path=$(readlink -f "$path")
        sqlite3 "$DB_PATH" << EOF
UPDATE integrity_violations 
SET resolved=1, resolved_at=CURRENT_TIMESTAMP, notes='Baseline updated'
WHERE path='$abs_path' AND resolved=0;
EOF
        
        echo -e "${GREEN}✓ Baseline updated and violations resolved for: $path${NC}"
        log "Baseline updated: $path"
    else
        echo -e "${RED}Error: Failed to update baseline for: $path${NC}"
        return 1
    fi
}

# Show monitoring status
show_monitor_status() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓ Monitoring is running (PID: $pid)${NC}"
            
            # Get monitoring config
            local config=$(sqlite3 "$DB_PATH" "SELECT key, value FROM monitor_config WHERE key IN ('watch_paths', 'interval');" 2>/dev/null)
            if [[ -n "$config" ]]; then
                echo -e "${CYAN}Configuration:${NC}"
                echo "$config" | while IFS='|' read -r key value; do
                    echo -e "  $key: $value"
                done
            fi
        else
            echo -e "${YELLOW}⚠️  Monitoring PID file exists but process not running${NC}"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        echo -e "${YELLOW}⚠️  Monitoring is not running${NC}"
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm File Integrity Module${NC}"
    echo "Usage: grim verify <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create <path>     - Create integrity baseline for file/directory"
    echo "  check <path>      - Check file integrity against baseline"
    echo "  monitor [paths]   - Start real-time monitoring (default: /etc /var/log /opt/grim)"
    echo "  stop-monitor      - Stop real-time monitoring"
    echo "  status            - Show monitoring status"
    echo "  report            - Show integrity violations report"
    echo "  update <path>     - Update baseline for legitimate changes"
    echo "  help              - Show this help"
    echo ""
    echo "Examples:"
    echo "  grim verify create /etc/passwd"
    echo "  grim verify create /opt/grim"
    echo "  grim verify check /etc"
    echo "  grim verify monitor /etc /var/log"
    echo "  grim verify report"
    echo ""
    echo "Database: $DB_PATH"
}

# Main function
main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "${1:-}" in
        "create")
            create_baseline "${2:-}"
            ;;
        "check")
            check_integrity "${2:-}"
            ;;
        "monitor")
            start_monitoring "${2:-}" "${3:-}"
            ;;
        "stop-monitor")
            stop_monitoring
            ;;
        "status")
            show_monitor_status
            ;;
        "report")
            show_report "${2:-}"
            ;;
        "update")
            update_baseline "${2:-}"
            ;;
        "help"|"")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@" 