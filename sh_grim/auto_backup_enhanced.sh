#!/bin/bash

# Grim Enhanced Auto-Backup System
# Tier-aware backup system with proper access control
# Supports both free and paid tiers with appropriate limitations

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GRAVEYARD_DIR="${GRAVEYARD_DIR:-/root/.graveyard}"
MONITOR_DIR="${MONITOR_DIR:-$GRIM_ROOT}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-300}"  # 5 minutes
MAX_BACKUPS="${MAX_BACKUPS:-50}"
MIN_FILE_SIZE="${MIN_FILE_SIZE:-1024}"  # 1KB minimum
LOG_FILE="${LOG_FILE:-/var/log/grim-auto-backup.log}"
PID_FILE="${PID_FILE:-/var/run/grim-auto-backup.pid}"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/auto_backup.conf}"
TIER_CONFIG_FILE="${TIER_CONFIG_FILE:-$GRIM_ROOT/tiers/tier_definitions.py}"

# Tier configuration
FREE_TIER_BACKUP_LIMIT=10
FREE_TIER_RETENTION_DAYS=7
FREE_TIER_MAX_SIZE_MB=100
PRO_TIER_BACKUP_LIMIT=50
PRO_TIER_RETENTION_DAYS=30
PRO_TIER_MAX_SIZE_MB=1000
MASTER_TIER_BACKUP_LIMIT=200
MASTER_TIER_RETENTION_DAYS=90
MASTER_TIER_MAX_SIZE_MB=10000
REAPER_TIER_BACKUP_LIMIT=1000
REAPER_TIER_RETENTION_DAYS=365
REAPER_TIER_MAX_SIZE_MB=100000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Get user tier (defaults to FREE if not set)
get_user_tier() {
    local user_tier="${USER_TIER:-FREE}"
    echo "$user_tier"
}

# Get tier limits
get_tier_limits() {
    local tier=$(get_user_tier)
    case "$tier" in
        "FREE")
            echo "$FREE_TIER_BACKUP_LIMIT:$FREE_TIER_RETENTION_DAYS:$FREE_TIER_MAX_SIZE_MB"
            ;;
        "PRO")
            echo "$PRO_TIER_BACKUP_LIMIT:$PRO_TIER_RETENTION_DAYS:$PRO_TIER_MAX_SIZE_MB"
            ;;
        "MASTER")
            echo "$MASTER_TIER_BACKUP_LIMIT:$MASTER_TIER_RETENTION_DAYS:$MASTER_TIER_MAX_SIZE_MB"
            ;;
        "REAPER")
            echo "$REAPER_TIER_BACKUP_LIMIT:$REAPER_TIER_RETENTION_DAYS:$REAPER_TIER_MAX_SIZE_MB"
            ;;
        *)
            echo "$FREE_TIER_BACKUP_LIMIT:$FREE_TIER_RETENTION_DAYS:$FREE_TIER_MAX_SIZE_MB"
            ;;
    esac
}

# Check if user can access auto-backup
check_auto_backup_access() {
    local tier=$(get_user_tier)
    
    # Free tier users can access auto-backup but with limitations
    if [[ "$tier" == "FREE" ]]; then
        log_info "Free tier user - auto-backup access granted with limitations"
        return 0
    fi
    
    # All other tiers have full access
    log_info "$tier tier user - full auto-backup access"
    return 0
}

# Initialize system
init_system() {
    log_info "Initializing Grim Enhanced Auto-Backup System"
    
    # Check access
    if ! check_auto_backup_access; then
        log_error "Access denied for auto-backup"
        exit 1
    fi
    
    # Create necessary directories
    mkdir -p "$GRAVEYARD_DIR/auto_backups"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$PID_FILE")"
    
    # Load configuration
    load_config
    
    log_info "System initialized. Monitoring: $MONITOR_DIR"
    log_info "Graveyard directory: $GRAVEYARD_DIR"
    log_info "User tier: $(get_user_tier)"
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
    cat > "$CONFIG_FILE" << EOF
# Grim Auto Backup Configuration
GRAVEYARD_DIR="$GRAVEYARD_DIR"
MONITOR_DIR="$MONITOR_DIR"
BACKUP_INTERVAL=300
MAX_BACKUPS=50
MIN_FILE_SIZE=1024
EXCLUDE_PATTERNS=("*.tmp" "*.log" "*.cache" ".git/*" "node_modules/*" "venv/*" "*.pyc" "__pycache__/*")
INCLUDE_PATTERNS=("*.py" "*.sh" "*.go" "*.js" "*.php" "*.ts" "*.tsk" "*.pnt" "*.md" "*.txt" "*.json" "*.yaml" "*.yml")
COMPRESSION_ALGORITHM="zstd"
EOF
    log_info "Created default configuration: $CONFIG_FILE"
}

# Check if file should be monitored
should_monitor_file() {
    local file="$1"
    
    # Skip if file doesn't exist
    [[ -f "$file" ]] || return 1
    
    # Skip if file is too small
    local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    [[ $size -lt $MIN_FILE_SIZE ]] && return 1
    
    # Check include patterns
    local include_match=false
    for pattern in "${INCLUDE_PATTERNS[@]}"; do
        if [[ "$file" == *"${pattern//\*/}"* ]]; then
            include_match=true
            break
        fi
    done
    
    # Check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file" == *"${pattern//\*/}"* ]]; then
            return 1
        fi
    done
    
    [[ "$include_match" == "true" ]]
}

# Get file modification time
get_file_mtime() {
    local file="$1"
    stat -c%Y "$file" 2>/dev/null || echo 0
}

# Create backup with tier-aware compression
create_backup() {
    local file="$1"
    local tier=$(get_user_tier)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="auto_backup_${tier}_${timestamp}.${COMPRESSION_ALGORITHM:-zstd}"
    local backup_path="$GRAVEYARD_DIR/auto_backups/$backup_name"
    
    # Check tier limits
    local limits=$(get_tier_limits)
    IFS=':' read -r max_backups retention_days max_size_mb <<< "$limits"
    
    # Check current backup count
    local current_count=$(find "$GRAVEYARD_DIR/auto_backups" -name "auto_backup_${tier}_*" 2>/dev/null | wc -l)
    if [[ $current_count -ge $max_backups ]]; then
        log_warn "Backup limit reached for $tier tier ($max_backups). Cleaning up old backups..."
        cleanup_old_backups "$tier" "$retention_days"
    fi
    
    # Check file size limit
    local file_size_mb=$(( $(stat -c%s "$file" 2>/dev/null || echo 0) / 1024 / 1024 ))
    if [[ $file_size_mb -gt $max_size_mb ]]; then
        log_warn "File $file exceeds size limit for $tier tier (${file_size_mb}MB > ${max_size_mb}MB)"
        return 1
    fi
    
    # Create backup
    log_info "Creating backup: $backup_name"
    
    case "${COMPRESSION_ALGORITHM:-zstd}" in
        "zstd")
            zstd -q -c "$file" > "$backup_path"
            ;;
        "gzip")
            gzip -c "$file" > "$backup_path"
            ;;
        "xz")
            xz -c "$file" > "$backup_path"
            ;;
        *)
            zstd -q -c "$file" > "$backup_path"
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        log_info "Backup created successfully: $backup_path"
        file_last_backup["$file"]=$(date +%s)
        
        # Create metadata file
        cat > "${backup_path}.meta" << EOF
{
    "original_file": "$file",
    "backup_time": "$(date -Iseconds)",
    "file_size": "$(stat -c%s "$file" 2>/dev/null || echo 0)",
    "user_tier": "$tier",
    "compression": "${COMPRESSION_ALGORITHM:-zstd}",
    "checksum": "$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || echo 'unknown')"
}
EOF
    else
        log_error "Failed to create backup: $backup_path"
        return 1
    fi
}

# Cleanup old backups based on tier
cleanup_old_backups() {
    local tier="$1"
    local retention_days="$2"
    local cutoff_date=$(date -d "$retention_days days ago" +%s)
    
    log_info "Cleaning up old backups for $tier tier (older than $retention_days days)"
    
    find "$GRAVEYARD_DIR/auto_backups" -name "auto_backup_${tier}_*" -type f | while read -r backup_file; do
        local file_date=$(stat -c%Y "$backup_file" 2>/dev/null || echo 0)
        if [[ $file_date -lt $cutoff_date ]]; then
            rm -f "$backup_file" "${backup_file}.meta"
            log_debug "Removed old backup: $backup_file"
        fi
    done
}

# List auto-backups with tier information
list_auto_backups() {
    local tier=$(get_user_tier)
    local backup_dir="$GRAVEYARD_DIR/auto_backups"
    
    echo -e "${CYAN}=== Auto-Backup List for $tier Tier ===${NC}"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo "No auto-backup directory found"
        return 1
    fi
    
    local backups=($(find "$backup_dir" -name "auto_backup_${tier}_*" -type f | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "No auto-backups found for $tier tier"
        return 0
    fi
    
    printf "%-30s %-15s %-10s %-20s\n" "Backup File" "Size" "Original" "Created"
    echo "----------------------------------------------------------------"
    
    for backup in "${backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" 2>/dev/null | cut -f1 || echo "unknown")
        local created=$(stat -c%y "$backup" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
        
        # Try to get original filename from metadata
        local original="unknown"
        if [[ -f "${backup}.meta" ]]; then
            original=$(jq -r '.original_file' "${backup}.meta" 2>/dev/null | xargs basename 2>/dev/null || echo "unknown")
        fi
        
        printf "%-30s %-15s %-10s %-20s\n" "$filename" "$size" "$original" "$created"
    done
    
    # Show tier limits
    local limits=$(get_tier_limits)
    IFS=':' read -r max_backups retention_days max_size_mb <<< "$limits"
    echo ""
    echo -e "${YELLOW}Tier Limits:${NC}"
    echo "  Max Backups: $max_backups"
    echo "  Retention: $retention_days days"
    echo "  Max File Size: ${max_size_mb}MB"
}

# Restore from auto-backup
restore_auto_backup() {
    local backup_file="$1"
    local target_dir="${2:-.}"
    local tier=$(get_user_tier)
    
    # Verify backup exists and belongs to user's tier
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    if [[ "$backup_file" != *"auto_backup_${tier}_"* ]]; then
        log_error "Backup file does not belong to your tier ($tier)"
        return 1
    fi
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Determine compression type and decompress
    local compression="zstd"
    if [[ "$backup_file" == *.gz ]]; then
        compression="gzip"
    elif [[ "$backup_file" == *.xz ]]; then
        compression="xz"
    fi
    
    log_info "Restoring from auto-backup: $backup_file"
    
    case "$compression" in
        "zstd")
            zstd -d -c "$backup_file" > "$target_dir/restored_file"
            ;;
        "gzip")
            gunzip -c "$backup_file" > "$target_dir/restored_file"
            ;;
        "xz")
            xz -d -c "$backup_file" > "$target_dir/restored_file"
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        log_info "Restore completed successfully"
        echo "Restored file saved to: $target_dir/restored_file"
    else
        log_error "Restore failed"
        return 1
    fi
}

# Health check
health_check() {
    local pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}Auto backup daemon is running (PID: $pid)${NC}"
        return 0
    else
        echo -e "${RED}Auto backup daemon is not running${NC}"
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
    
    # Check access
    if ! check_auto_backup_access; then
        log_error "Access denied for auto-backup"
        exit 1
    fi
    
    # Initialize system
    init_system
    
    # Start monitoring in background
    (
        while true; do
            # Monitor for file changes
            find "$MONITOR_DIR" -type f -mmin -5 2>/dev/null | while read -r file; do
                if should_monitor_file "$file"; then
                    create_backup "$file"
                fi
            done
            
            # Cleanup old backups
            local tier=$(get_user_tier)
            local limits=$(get_tier_limits)
            IFS=':' read -r max_backups retention_days max_size_mb <<< "$limits"
            cleanup_old_backups "$tier" "$retention_days"
            
            sleep "$BACKUP_INTERVAL"
        done
    ) &
    
    local daemon_pid=$!
    echo "$daemon_pid" > "$PID_FILE"
    
    log_info "Auto backup daemon started (PID: $daemon_pid)"
    return 0
}

# Stop daemon
stop_daemon() {
    local pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        rm -f "$PID_FILE"
        log_info "Auto backup daemon stopped"
        return 0
    else
        log_warn "Auto backup daemon is not running"
        return 1
    fi
}

# Main command handler
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
    status|health)
        health_check
        ;;
    list)
        list_auto_backups
        ;;
    restore)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 restore <backup_file> [target_dir]"
            exit 1
        fi
        restore_auto_backup "$2" "${3:-.}"
        ;;
    *)
        echo -e "${CYAN}Grim Enhanced Auto-Backup System${NC}"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  start                    - Start auto-backup daemon"
        echo "  stop                     - Stop auto-backup daemon"
        echo "  restart                  - Restart auto-backup daemon"
        echo "  status|health            - Check daemon status"
        echo "  list                     - List auto-backups for current tier"
        echo "  restore <file> [dir]     - Restore from auto-backup"
        echo ""
        echo "Current tier: $(get_user_tier)"
        echo "Tier limits: $(get_tier_limits | tr ':' ' ')"
        ;;
esac 