#!/bin/bash

# Grim Strategic Auto-Backup System
# Creates backups but restricts access until payment
# Uses password-protected compressed folders in .graveyard/.rip/auto-backups/

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Dynamic user detection - don't hard-code /root
CURRENT_USER="${SUDO_USER:-$USER}"
if [[ "$CURRENT_USER" == "root" ]]; then
    # If running as root, try to detect the actual user
    if [[ -n "${SUDO_USER:-}" ]]; then
        CURRENT_USER="$SUDO_USER"
    elif [[ -f /etc/passwd ]]; then
        # Find the first non-root user
        CURRENT_USER=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1; exit}' /etc/passwd)
    fi
fi

# Use user's home directory instead of hard-coded /root
USER_HOME=$(eval echo "~$CURRENT_USER")
GRAVEYARD_DIR="${GRAVEYARD_DIR:-$USER_HOME/.graveyard}"
RIP_DIR="$GRAVEYARD_DIR/.rip"
AUTO_BACKUP_DIR="$RIP_DIR/auto-backups"

# Tier-based backup locations
FREE_BACKUP_DIR="$RIP_DIR/auto-backups/free"
PRO_BACKUP_DIR="$RIP_DIR/auto-backups/pro"
MASTER_BACKUP_DIR="$RIP_DIR/auto-backups/master"
REAPER_BACKUP_DIR="$RIP_DIR/auto-backups/reaper"

MONITOR_DIR="${MONITOR_DIR:-$GRIM_ROOT}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-300}"  # 5 minutes
MAX_BACKUPS="${MAX_BACKUPS:-100}"
MIN_FILE_SIZE="${MIN_FILE_SIZE:-1024}"  # 1KB minimum
LOG_FILE="${LOG_FILE:-/var/log/grim-auto-backup.log}"
PID_FILE="${PID_FILE:-/var/run/grim-auto-backup.pid}"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/auto_backup.conf}"
GO_COMPRESSION_BIN="${GO_COMPRESSION_BIN:-$GRIM_ROOT/go_grim/build/grim-compression}"

# Persistent password storage
BACKUP_PASSWORD_FILE="$RIP_DIR/.backup_password"
ACCESS_KEY_FILE="$RIP_DIR/.access_key"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
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

# Get user tier using unified license manager with bulletproof fallback
get_user_tier() {
    local user_id="${CURRENT_USER:-$(whoami)}"
    local license_key="${GRIM_LICENSE_KEY:-}"
    
    # Try environment variable first
    if [[ -z "$license_key" ]] && [[ -f "$RIP_DIR/.license_key" ]]; then 
        license_key=$(cat "$RIP_DIR/.license_key")
    fi
    
    if [[ -n "$license_key" ]]; then
        # 1. Try unified license manager (API -> GRIMS_MOTHER -> Local Cache -> Export Cache)
        if [[ -f "$GRIM_ROOT/tsk_flask/grim_license_manager.py" ]]; then
            local result
            result=$(python3 "$GRIM_ROOT/tsk_flask/grim_license_manager.py" validate --license-key "$license_key" 2>/dev/null)
            
            if echo "$result" | grep -q "✅ License valid"; then
                local tier=$(echo "$result" | grep "🎯 Tier:" | cut -d' ' -f3)
                if [[ -n "$tier" ]]; then
                    echo "$tier"
                    return 0
                fi
            fi
        fi
        
        # 2. Fallback: Direct API call (if license manager fails)
        if command -v curl >/dev/null 2>&1; then
            local license_status=$(curl -s -X POST "https://rip.grim.so/grim/license/validate" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer grim-api-key-2025" \
                -d "{\"license_key\":\"$license_key\"}" 2>/dev/null || echo '{"valid":false,"tier":"FREE"}')
            
            if command -v jq >/dev/null 2>&1; then
                local valid=$(echo "$license_status" | jq -r '.valid // false')
                local tier=$(echo "$license_status" | jq -r '.tier // "FREE"')
            else
                local valid=$(echo "$license_status" | grep -o '"valid":[^,]*' | cut -d':' -f2 | tr -d '"')
                local tier=$(echo "$license_status" | grep -o '"tier":"[^"]*"' | cut -d'"' -f4)
            fi
            
            if [[ "$valid" == "true" ]] && [[ -n "$tier" ]]; then
                echo "$tier"
                return 0
            fi
        fi
        
        # 3. Fallback: Check local export cache
        if [[ -f "$RIP_DIR/.license_status" ]]; then
            local cached_tier=$(cat "$RIP_DIR/.license_status")
            if [[ -n "$cached_tier" ]]; then
                echo "$cached_tier"
                return 0
            fi
        fi
    fi
    
    # 4. Final fallback: FREE tier
    echo "FREE"
    return 0
}

# Check if user has paid tier access
has_paid_access() {
    local tier=$(get_user_tier)
    [[ "$tier" == "PRO" || "$tier" == "MASTER" || "$tier" == "REAPER" ]]
}

# Get tier-based backup directory
get_tier_backup_dir() {
    local tier=$(get_user_tier)
    case "$tier" in
        "FREE")
            echo "$FREE_BACKUP_DIR"
            ;;
        "PRO")
            echo "$PRO_BACKUP_DIR"
            ;;
        "MASTER")
            echo "$MASTER_BACKUP_DIR"
            ;;
        "REAPER")
            echo "$REAPER_BACKUP_DIR"
            ;;
        *)
            echo "$FREE_BACKUP_DIR"
            ;;
    esac
}

# Get or generate persistent backup password
get_backup_password() {
    if [[ -f "$BACKUP_PASSWORD_FILE" ]]; then
        cat "$BACKUP_PASSWORD_FILE"
    else
        # Generate new password and store it
        local password="grim_reaper_auto_backup_$(date +%s)_$(openssl rand -hex 8)"
        echo "$password" > "$BACKUP_PASSWORD_FILE"
        chmod 600 "$BACKUP_PASSWORD_FILE"
        echo "$password"
    fi
}

# Smart file selection - only backup important files
should_backup_file() {
    local file="$1"
    
    # Skip if file doesn't exist
    [[ -f "$file" ]] || return 1
    
    # Skip if file is too small
    local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    [[ $size -lt $MIN_FILE_SIZE ]] && return 1
    
    # Skip if file is in backup directories
    [[ "$file" == *"$RIP_DIR"* ]] && return 1
    [[ "$file" == *"/.git/"* ]] && return 1
    [[ "$file" == *"/node_modules/"* ]] && return 1
    [[ "$file" == *"/vendor/"* ]] && return 1
    [[ "$file" == *"/.cache/"* ]] && return 1
    [[ "$file" == *"/tmp/"* ]] && return 1
    
    # Only backup important file types
    local important_extensions=(
        ".sh" ".py" ".js" ".ts" ".php" ".rb" ".go" ".rs" ".cpp" ".c" ".h"
        ".json" ".yaml" ".yml" ".xml" ".csv" ".sql" ".md" ".txt" ".conf" ".config"
        ".env" ".ini" ".cfg" ".log" ".lock" ".key" ".pem" ".crt" ".p12"
        ".zip" ".tar" ".gz" ".bz2" ".xz" ".7z" ".rar"
        ".jpg" ".jpeg" ".png" ".gif" ".svg" ".ico" ".webp"
        ".mp4" ".avi" ".mov" ".mkv" ".wmv" ".flv" ".webm"
        ".mp3" ".wav" ".flac" ".aac" ".ogg" ".wma"
        ".pdf" ".doc" ".docx" ".xls" ".xlsx" ".ppt" ".pptx"
        ".html" ".css" ".scss" ".less" ".sass"
    )
    
    local file_ext="${file##*.}"
    for ext in "${important_extensions[@]}"; do
        if [[ ".$file_ext" == "$ext" ]]; then
            return 0
        fi
    done
    
    # Also backup files without extensions that are likely important
    if [[ ! "$file" =~ \. ]]; then
        # Check if it's an executable or important file
        if [[ -x "$file" ]] || [[ "$(basename "$file")" =~ ^[A-Z] ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Check if file was recently modified and is worth backing up
is_file_worth_backing_up() {
    local file="$1"
    
    # Check if file was modified in last 5 minutes
    local mtime=$(stat -c%Y "$file" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local time_diff=$((current_time - mtime))
    
    # Only backup files modified in last 5 minutes
    [[ $time_diff -le 300 ]] || return 1
    
    # Check if file is worth backing up
    should_backup_file "$file" || return 1
    
    # Check if we've already backed up this file recently (within 10 minutes)
    local file_hash=$(echo "$file" | sha256sum | cut -d' ' -f1)
    local last_backup_file="$RIP_DIR/.last_backup_$file_hash"
    
    if [[ -f "$last_backup_file" ]]; then
        local last_backup_time=$(cat "$last_backup_file" 2>/dev/null || echo 0)
        local backup_time_diff=$((current_time - last_backup_time))
        [[ $backup_time_diff -gt 600 ]] || return 1  # Skip if backed up within 10 minutes
    fi
    
    return 0
}

# Initialize system
init_system() {
    log_info "Initializing Grim Strategic Auto-Backup System for user: $CURRENT_USER"
    
    # Create necessary directories
    mkdir -p "$AUTO_BACKUP_DIR"
    mkdir -p "$FREE_BACKUP_DIR"
    mkdir -p "$PRO_BACKUP_DIR"
    mkdir -p "$MASTER_BACKUP_DIR"
    mkdir -p "$REAPER_BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$PID_FILE")"
    
    # Ensure RIP directory is hidden and secure
    chmod 700 "$RIP_DIR"
    chmod 700 "$AUTO_BACKUP_DIR"
    
    # Initialize backup password if not exists
    get_backup_password > /dev/null
    
    # Load configuration
    load_config
    
    log_info "System initialized. User: $CURRENT_USER, Tier: $(get_user_tier), Backup Dir: $(get_tier_backup_dir)"
}

# Build Go compression engine if needed
build_go_compression() {
    local go_dir="$GRIM_ROOT/go_grim"
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
    cat > "$CONFIG_FILE" << EOF
# Grim Strategic Auto Backup Configuration
GRAVEYARD_DIR="$GRAVEYARD_DIR"
RIP_DIR="$RIP_DIR"
AUTO_BACKUP_DIR="$AUTO_BACKUP_DIR"
MONITOR_DIR="$MONITOR_DIR"
BACKUP_INTERVAL=300
MAX_BACKUPS=100
MIN_FILE_SIZE=1024
EXCLUDE_PATTERNS=("*.tmp" "*.log" "*.cache" ".git/*" "node_modules/*" "venv/*" "*.pyc" "__pycache__/*")
INCLUDE_PATTERNS=("*.py" "*.sh" "*.go" "*.js" "*.php" "*.ts" "*.tsk" "*.pnt" "*.md" "*.txt" "*.json" "*.yaml" "*.yml")
COMPRESSION_ALGORITHM="zstd"
ENCRYPTION_ENABLED=true
EOF
    log_info "Created default configuration: $CONFIG_FILE"
}

# Create encrypted backup with Go compression
create_backup() {
    local file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local file_hash=$(echo "$file" | sha256sum | cut -d' ' -f1 | cut -c1-8)
    local backup_name="auto_backup_${timestamp}_${file_hash}.grim"
    local tier_backup_dir=$(get_tier_backup_dir)
    local backup_path="$tier_backup_dir/$backup_name"
    local temp_dir=$(mktemp -d)
    
    # Create backup metadata
    local metadata_file="$temp_dir/metadata.json"
    cat > "$metadata_file" << EOF
{
    "original_file": "$file",
    "backup_time": "$(date -Iseconds)",
    "file_size": "$(stat -c%s "$file" 2>/dev/null || echo 0)",
    "file_hash": "$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || echo 'unknown')",
    "compression": "grim-compression",
    "encryption": "AES-256",
    "access_required": "PAID",
    "created_by": "grim_auto_backup_strategic"
}
EOF
    
    # Create backup archive
    log_info "Creating strategic backup: $backup_name"
    
    # Use Go compression with encryption
    if [[ -f "$GO_COMPRESSION_BIN" ]]; then
        # Create temporary archive
        local temp_archive="$temp_dir/backup.tar"
        tar -cf "$temp_archive" -C "$(dirname "$file")" "$(basename "$file")" -C "$temp_dir" "metadata.json"
        
        # Compress and encrypt with Go compression
        "$GO_COMPRESSION_BIN" -input "$temp_archive" -output "$backup_path" -password "$(get_backup_password)" -encrypt
    else
        # Fallback to standard compression
        local temp_archive="$temp_dir/backup.tar.gz"
        tar -czf "$temp_archive" -C "$(dirname "$file")" "$(basename "$file")" -C "$temp_dir" "metadata.json"
        
        # Encrypt with openssl
        openssl enc -aes-256-cbc -salt -in "$temp_archive" -out "$backup_path" -pass pass:"$(get_backup_password)"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_info "Strategic backup created successfully: $backup_path"
        
        # Set restrictive permissions
        chmod 600 "$backup_path"
        
        # Clean up temp files
        rm -rf "$temp_dir"
        
        # Update backup tracking
        echo "$(date +%s)" > "$RIP_DIR/.last_backup_$file_hash"
    else
        log_error "Failed to create strategic backup: $backup_path"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    local max_backups=${MAX_BACKUPS:-100}
    local tier_backup_dir=$(get_tier_backup_dir)
    
    # Count existing backups
    local backup_count=$(find "$tier_backup_dir" -name "*.grim" 2>/dev/null | wc -l)
    
    if [[ $backup_count -gt $max_backups ]]; then
        log_info "Cleaning up old backups in: $tier_backup_dir"
        
        # Remove oldest backups
        find "$tier_backup_dir" -name "*.grim" -printf '%T@ %p\n' 2>/dev/null | \
        sort -n | head -n $((backup_count - max_backups)) | \
        while read timestamp file; do
            rm -f "$file"
            log_debug "Removed old backup: $file"
        done
    fi
}

# List backups (restricted access)
list_backups() {
    local user_tier=$(get_user_tier)
    local tier_backup_dir=$(get_tier_backup_dir)
    
    echo -e "${CYAN}=== Grim Strategic Auto-Backup List ===${NC}"
    echo -e "${PURPLE}User: $CURRENT_USER | Tier: $user_tier | Backup Dir: $tier_backup_dir${NC}"
    echo ""
    
    if [[ ! -d "$tier_backup_dir" ]]; then
        echo "No auto-backup directory found for tier: $user_tier"
        return 1
    fi
    
    local backups=($(find "$tier_backup_dir" -name "*.grim" 2>/dev/null | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "No auto-backups found"
        return 0
    fi
    
    if [[ "$user_tier" == "FREE" ]]; then
        echo -e "${YELLOW}⚠️  TIER UPGRADE REQUIRED TO ACCESS BACKUPS${NC}"
        echo ""
        echo "You have ${#backups[@]} auto-backups available, but a paid tier is required to access them."
        echo ""
        echo -e "${CYAN}Backup Summary:${NC}"
        echo "  Total Backups: ${#backups[@]}"
        echo "  Total Size: $(du -sh "$tier_backup_dir" 2>/dev/null | cut -f1 || echo 'unknown')"
        echo "  Oldest: $(stat -c%y "$(find "$tier_backup_dir" -name "*.grim" | sort | head -1)" 2>/dev/null | cut -d' ' -f1 || echo 'unknown')"
        echo "  Newest: $(stat -c%y "$(find "$tier_backup_dir" -name "*.grim" | sort -r | head -1)" 2>/dev/null | cut -d' ' -f1 || echo 'unknown')"
        echo ""
        echo -e "${YELLOW}To access your backups, upgrade to a paid tier:${NC}"
        echo "  grim scythe-tier upgrade PRO"
        echo "  grim scythe-tier upgrade MASTER"
        echo "  grim scythe-tier upgrade REAPER"
        echo ""
        echo -e "${RED}Backup files are encrypted and password-protected.${NC}"
        echo "Access will be granted after tier upgrade."
    else
        echo -e "${GREEN}✅ TIER ACCESS GRANTED (${user_tier})${NC}"
        echo ""
        printf "%-35s %-15s %-20s %-15s\n" "Backup File" "Size" "Created" "Status"
        echo "----------------------------------------------------------------"
        
        for backup in "${backups[@]}"; do
            local filename=$(basename "$backup")
            local size=$(du -h "$backup" 2>/dev/null | cut -f1 || echo "unknown")
            local created=$(stat -c%y "$backup" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
            
            printf "%-35s %-15s %-20s %-15s\n" "$filename" "$size" "$created" "ENCRYPTED"
        done
        
        echo ""
        echo -e "${GREEN}Use 'grim auto-backup restore <file>' to restore from backup${NC}"
    fi
}

# Restore from backup (requires paid tier)
restore_backup() {
    local backup_file="$1"
    local target_dir="${2:-.}"
    local user_tier=$(get_user_tier)
    
    # Verify backup exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Check tier access
    if [[ "$user_tier" == "FREE" ]]; then
        echo -e "${RED}❌ TIER UPGRADE REQUIRED TO RESTORE BACKUPS${NC}"
        echo ""
        echo "Your backups are encrypted and require a paid tier to access."
        echo "To restore your files, upgrade to a paid tier:"
        echo ""
        echo "  grim scythe-tier upgrade PRO"
        echo "  grim scythe-tier upgrade MASTER"
        echo "  grim scythe-tier upgrade REAPER"
        echo ""
        echo -e "${YELLOW}Your backups are safe and will be available after tier upgrade.${NC}"
        return 1
    fi
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Restore using Go compression
    log_info "Restoring from strategic backup: $backup_file"
    
    local temp_dir=$(mktemp -d)
    local restored_file="$target_dir/restored_file"
    
    if [[ -f "$GO_COMPRESSION_BIN" ]]; then
        # Use Go compression to decrypt and decompress
        "$GO_COMPRESSION_BIN" -input "$backup_file" -output "$temp_dir/backup.tar" -password "$(get_backup_password)" -decrypt
        tar -xf "$temp_dir/backup.tar" -C "$temp_dir"
        
        # Extract the original file
        if [[ -f "$temp_dir/$(basename "$backup_file" .grim)" ]]; then
            cp "$temp_dir/$(basename "$backup_file" .grim)" "$restored_file"
        else
            # Try to find the original file in the archive
            find "$temp_dir" -type f -not -name "metadata.json" -exec cp {} "$restored_file" \;
        fi
    else
        # Fallback to openssl decryption
        openssl enc -aes-256-cbc -d -in "$backup_file" -out "$temp_dir/backup.tar.gz" -pass pass:"$(get_backup_password)"
        tar -xzf "$temp_dir/backup.tar.gz" -C "$temp_dir"
        
        # Extract the original file
        find "$temp_dir" -type f -not -name "metadata.json" -exec cp {} "$restored_file" \;
    fi
    
    if [[ $? -eq 0 ]] && [[ -f "$restored_file" ]]; then
        log_info "Restore completed successfully"
        echo -e "${GREEN}✅ Restored file saved to: $restored_file${NC}"
    else
        log_error "Restore failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Clean up temp files
    rm -rf "$temp_dir"
}

# Create license using unified license manager
create_license() {
    local email="$1"
    if [[ -z "$email" ]]; then
        echo "❌ Email required for license creation" >&2
        return 1
    fi
    
    echo "🔑 Creating license for: $email"
    
    # Use unified license manager
    if [[ -f "$GRIM_ROOT/tsk_flask/grim_license_manager.py" ]]; then
        local result
        result=$(python3 "$GRIM_ROOT/tsk_flask/grim_license_manager.py" generate --email "$email" 2>/dev/null)
        
        if echo "$result" | grep -q "✅ License generated:"; then
            local license_key=$(echo "$result" | grep "✅ License generated:" | cut -d':' -f2 | tr -d ' ')
            local tier=$(echo "$result" | grep "🎯 Tier:" | cut -d' ' -f3)
            
            # Save to local files for auto-backup access
            echo "$license_key" > "$RIP_DIR/.license_key"
            echo "$tier" > "$RIP_DIR/.license_status"
            chmod 600 "$RIP_DIR/.license_key" "$RIP_DIR/.license_status"
            
            echo "✅ License created successfully"
            echo "🔑 License Key: $license_key"
            echo "🎯 Tier: $tier"
            echo "📁 Saved to: $RIP_DIR/.license_key"
            return 0
        else
            echo "❌ License creation failed: $result" >&2
            return 1
        fi
    else
        echo "❌ License manager not found" >&2
        return 1
    fi
}

# Update license status using unified license manager
update_license_status() {
    local license_key="${GRIM_LICENSE_KEY:-}"
    if [[ -z "$license_key" ]] && [[ -f "$RIP_DIR/.license_key" ]]; then
        license_key=$(cat "$RIP_DIR/.license_key")
    fi
    
    if [[ -z "$license_key" ]]; then
        echo "❌ No license key found" >&2
        return 1
    fi
    
    echo "🔄 Updating license status..."
    
    # Use unified license manager
    if [[ -f "$GRIM_ROOT/tsk_flask/grim_license_manager.py" ]]; then
        local result
        result=$(python3 "$GRIM_ROOT/tsk_flask/grim_license_manager.py" validate --license-key "$license_key" 2>/dev/null)
        
        if echo "$result" | grep -q "✅ License valid"; then
            local tier=$(echo "$result" | grep "🎯 Tier:" | cut -d' ' -f3)
            if [[ -n "$tier" ]]; then
                echo "$tier" > "$RIP_DIR/.license_status"
                chmod 600 "$RIP_DIR/.license_status"
                echo "✅ License status updated: $tier"
                return 0
            fi
        else
            echo "❌ License validation failed: $result" >&2
            return 1
        fi
    else
        echo "❌ License manager not found" >&2
        return 1
    fi
}

# Export all licenses for offline access
export_licenses() {
    echo "📦 Exporting licenses for offline access..."
    
    if [[ -f "$GRIM_ROOT/tsk_flask/grim_license_manager.py" ]]; then
        local result
        result=$(python3 "$GRIM_ROOT/tsk_flask/grim_license_manager.py" export 2>/dev/null)
        
        if echo "$result" | grep -q "✅ Exported"; then
            local count=$(echo "$result" | grep "✅ Exported" | grep -o '[0-9]*' | head -1)
            echo "✅ Exported $count licenses to $RIP_DIR"
            return 0
        else
            echo "❌ Export failed: $result" >&2
            return 1
        fi
    else
        echo "❌ License manager not found" >&2
        return 1
    fi
}

# Health check
health_check() {
    local pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}Strategic auto backup daemon is running (PID: $pid)${NC}"
        echo -e "${PURPLE}License Status: $(get_user_tier)${NC}"
        return 0
    else
        echo -e "${RED}Strategic auto backup daemon is not running${NC}"
        return 1
    fi
}

# Start daemon
start_daemon() {
    if health_check >/dev/null 2>&1; then
        log_warn "Strategic auto backup daemon is already running"
        return 1
    fi
    
    log_info "Starting strategic auto backup daemon..."
    
    # Initialize system
    init_system
    
    # Start monitoring in background
    (
        while true; do
            # Monitor for file changes
            find "$MONITOR_DIR" -type f -mmin -5 2>/dev/null | while read -r file; do
                if is_file_worth_backing_up "$file"; then
                    create_backup "$file"
                fi
            done
            
            # Cleanup old backups
            cleanup_old_backups
            
            sleep "$BACKUP_INTERVAL"
        done
    ) &
    
    local daemon_pid=$!
    echo "$daemon_pid" > "$PID_FILE"
    
    log_info "Strategic auto backup daemon started (PID: $daemon_pid)"
    return 0
}

# Stop daemon
stop_daemon() {
    local pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        rm -f "$PID_FILE"
        log_info "Strategic auto backup daemon stopped"
        return 0
    else
        log_warn "Strategic auto backup daemon is not running"
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
        list_backups
        ;;
    restore)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 restore <backup_file> [target_dir]"
            exit 1
        fi
        restore_backup "$2" "${3:-.}"
        ;;
    create-license)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 create-license <email> [name]"
            exit 1
        fi
        create_license "$2" "${3:-}"
        ;;
    update-license)
        update_license_status
        ;;
    export-licenses)
        export_licenses
        ;;
    license-status)
        local tier=$(get_user_tier)
        local license_key="${GRIM_LICENSE_KEY:-}"
        if [[ -z "$license_key" ]] && [[ -f "$RIP_DIR/.license_key" ]]; then
            license_key=$(cat "$RIP_DIR/.license_key")
        fi
        
        echo "🔑 License Status:"
        echo "   Key: ${license_key:-Not set}"
        echo "   Tier: $tier"
        echo "   Cache: $RIP_DIR/.license_status"
        echo "   Export: $RIP_DIR/.license_key"
        ;;
    help|--help|-h)
        echo -e "${CYAN}Grim Strategic Auto-Backup System${NC}"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  start                    - Start strategic auto-backup daemon"
        echo "  stop                     - Stop strategic auto-backup daemon"
        echo "  restart                  - Restart strategic auto-backup daemon"
        echo "  status|health            - Check daemon status"
        echo "  list                     - List auto-backups (license required)"
        echo "  restore <file> [dir]     - Restore from backup (license required)"
        echo "  create-license <email>   - Create new license via rip.grim.so"
        echo "  update-license           - Update license status from rip.grim.so"
        echo "  export-licenses          - Export all licenses for offline access"
        echo "  license-status           - Check current license status"
        echo ""
        echo -e "${PURPLE}License Status: $(get_user_tier)${NC}"
        echo ""
        echo -e "${YELLOW}Note: Backups are encrypted and require paid license to access.${NC}"
        echo "Auto-backup runs continuously to protect your files."
        ;;
    *)
        echo "❌ Unknown command: $1" >&2
        echo "Use: grim auto-backup help" >&2
        exit 1
        ;;
esac 