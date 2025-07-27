#!/bin/bash

# Grim Automatic Backup System
# Monitors file changes and creates intelligent compressed backups
# Integrates with Go compression engine for optimal performance

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAVEYARD_DIR="${GRAVEYARD_DIR:-/root/.graveyard}"
MONITOR_DIR="${MONITOR_DIR:-$(pwd)}"
GO_COMPRESSION_BIN="${GO_COMPRESSION_BIN:-$SCRIPT_DIR/../go_grim/build/grim-compression}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-300}"  # 5 minutes
MAX_BACKUPS="${MAX_BACKUPS:-50}"
MIN_FILE_SIZE="${MIN_FILE_SIZE:-1024}"  # 1KB minimum
LOG_FILE="${LOG_FILE:-/var/log/grim-auto-backup.log}"
PID_FILE="${PID_FILE:-/var/run/grim-auto-backup.pid}"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/auto_backup.conf}"

# File monitoring state
declare -A file_modifications=()
declare -A file_last_backup=()
declare -A hot_files=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Initialize system
init_system() {
    log_info "Initializing Grim Automatic Backup System"
    
    # Create necessary directories
    mkdir -p "$GRAVEYARD_DIR/auto_backups"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$PID_FILE")"
    
    # Check if Go compression binary exists
    if [[ ! -f "$GO_COMPRESSION_BIN" ]]; then
        log_error "Go compression binary not found at: $GO_COMPRESSION_BIN"
        log_info "Building Go compression engine..."
        build_go_compression
    fi
    
    # Load configuration
    load_config
    
    log_info "System initialized. Monitoring: $MONITOR_DIR"
    log_info "Graveyard directory: $GRAVEYARD_DIR"
}

# Build Go compression engine if needed
build_go_compression() {
    local go_dir="$SCRIPT_DIR/../go_grim"
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
    cat > "$CONFIG_FILE" << 'EOF'
# Grim Auto Backup Configuration
GRAVEYARD_DIR="/root/.graveyard"
MONITOR_DIR="$(pwd)"
BACKUP_INTERVAL=300
MAX_BACKUPS=50
MIN_FILE_SIZE=1024
EXCLUDE_PATTERNS=("*.tmp" "*.log" "*.cache" ".git/*" "node_modules/*" "venv/*")
INCLUDE_PATTERNS=("*.py" "*.sh" "*.go" "*.js" "*.php" "*.ts" "*.tsk" "*.pnt")
COMPRESSION_ALGORITHM="zstd"
EOF
    log_info "Created default configuration: $CONFIG_FILE"
}

# Check if file should be monitored
should_monitor_file() {
    local file="$1"
    local filename=$(basename "$file")
    local dirname=$(dirname "$file")
    
    # Skip if file is too small
    if [[ ! -f "$file" ]] || [[ $(stat -c%s "$file" 2>/dev/null || echo 0) -lt $MIN_FILE_SIZE ]]; then
        return 1
    fi
    
    # Check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]:-()}"; do
        if [[ "$file" == *"$pattern"* ]] || [[ "$filename" == $pattern ]]; then
            return 1
        fi
    done
    
    # Check include patterns
    for pattern in "${INCLUDE_PATTERNS[@]:-()}"; do
        if [[ "$file" == *"$pattern"* ]] || [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done
    
    # If no include patterns specified, monitor all non-excluded files
    return 0
}

# Get file modification time
get_file_mtime() {
    stat -c%Y "$1" 2>/dev/null || echo 0
}

# Detect hot files (frequently modified)
detect_hot_files() {
    local current_time=$(date +%s)
    local threshold=$((current_time - 3600))  # 1 hour
    
    for file in "${!file_modifications[@]}"; do
        local mod_count=${file_modifications[$file]}
        local last_mod=${file_last_backup[$file]:-0}
        
        # Consider file "hot" if modified more than 3 times in the last hour
        if [[ $mod_count -ge 3 ]] && [[ $last_mod -gt $threshold ]]; then
            hot_files["$file"]=1
        else
            unset hot_files["$file"]
        fi
    done
}

# Create compressed backup
create_backup() {
    local source="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename=$(basename "$source")
    local dirname=$(dirname "$source")
    local relative_path="${dirname#$MONITOR_DIR/}"
    
    # Check license tier for encryption requirement and AI features
    local needs_encryption=false
    local has_ai_features=false
    if ! check_license_tier; then
        needs_encryption=true
        log_info "FREE license detected - backup will be encrypted"
    else
        has_ai_features=true
        log_info "Premium license detected - AI features available"
    fi
    
    # Use AI decision making for premium users
    if [ "$has_ai_features" = true ]; then
        if ! should_backup_file_ai "$source"; then
            log_info "AI decision: Skipping backup of $source (not recommended)"
            return 0
        fi
        log_info "AI decision: Backup recommended for $source"
    fi
    
    # Create backup directory structure (encrypted folder for free users)
    local backup_dir
    if [ "$needs_encryption" = true ]; then
        backup_dir="$GRAVEYARD_DIR/auto_backups_encrypted/$relative_path"
        log_info "Using encrypted backup directory for FREE license"
    else
        backup_dir="$GRAVEYARD_DIR/auto_backups/$relative_path"
    fi
    mkdir -p "$backup_dir"
    
    # Generate backup filename
    local backup_name="${filename}.${timestamp}.${COMPRESSION_ALGORITHM:-zstd}"
    if [ "$needs_encryption" = true ]; then
        backup_name="${backup_name}.enc"
    fi
    local backup_path="$backup_dir/$backup_name"
    
    log_info "Creating backup: $source -> $backup_path"
    
    # Use Go compression engine
    local temp_compressed="/tmp/grim_temp_${timestamp}_$(basename "$source")"
    if "$GO_COMPRESSION_BIN" -input "$source" -algorithm "${COMPRESSION_ALGORITHM:-zstd}" -output "$temp_compressed" >/dev/null 2>&1; then
        
        if [ "$needs_encryption" = true ]; then
            # Encrypt the compressed file for free users
            local encryption_key="${GRIM_LICENSE_KEY:-FREE}_$(hostname)_grim_auto_backup"
            if command -v openssl >/dev/null 2>&1; then
                if openssl enc -aes-256-cbc -salt -in "$temp_compressed" -out "$backup_path" -k "$encryption_key" 2>/dev/null; then
                    log_info "Backup created and encrypted successfully: $backup_path"
                    rm -f "$temp_compressed"
                else
                    log_error "Encryption failed, saving unencrypted backup"
                    mv "$temp_compressed" "$backup_path"
                fi
            else
                log_warn "OpenSSL not available, saving unencrypted backup"
                mv "$temp_compressed" "$backup_path"
            fi
        else
            # Move compressed file directly for paid users
            mv "$temp_compressed" "$backup_path"
            log_info "Backup created successfully: $backup_path"
        fi
        
        # Update last backup time
        file_last_backup["$source"]=$(date +%s)
        
        # Cleanup old backups
        cleanup_old_backups "$backup_dir"
        
        return 0
    else
        log_error "Failed to create backup: $source"
        rm -f "$temp_compressed"
        return 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    local backup_dir="$1"
    local max_backups=${MAX_BACKUPS:-50}
    
    # Count existing backups
    local backup_count=$(find "$backup_dir" -name "*.${COMPRESSION_ALGORITHM:-zstd}" | wc -l)
    
    if [[ $backup_count -gt $max_backups ]]; then
        log_info "Cleaning up old backups in: $backup_dir"
        
        # Remove oldest backups
        find "$backup_dir" -name "*.${COMPRESSION_ALGORITHM:-zstd}" -printf '%T@ %p\n' | \
        sort -n | head -n $((backup_count - max_backups)) | \
        while read timestamp file; do
            rm -f "$file"
            log_debug "Removed old backup: $file"
        done
    fi
}

# Monitor file changes using inotify
monitor_files() {
    log_info "Starting file monitoring..."
    
    # Check if inotify-tools is available
    if ! command -v inotifywait >/dev/null 2>&1; then
        log_error "inotifywait not found. Installing inotify-tools..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y inotify-tools
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y inotify-tools
        else
            log_error "Cannot install inotify-tools. Please install manually."
            exit 1
        fi
    fi
    
    # Start monitoring
    inotifywait -m -r -e modify,create,move "$MONITOR_DIR" --format '%w%f %e' | while read file event; do
        if should_monitor_file "$file"; then
            local current_time=$(date +%s)
            local file_mtime=$(get_file_mtime "$file")
            
            # Update modification tracking
            file_modifications["$file"]=$((${file_modifications[$file]:-0} + 1))
            
            log_debug "File modified: $file ($event) - count: ${file_modifications[$file]}"
            
            # Check if backup is needed
            local last_backup=${file_last_backup[$file]:-0}
            local time_since_backup=$((current_time - last_backup))
            
            if [[ $time_since_backup -gt $BACKUP_INTERVAL ]] || [[ ${hot_files[$file]:-0} -eq 1 ]]; then
                create_backup "$file"
            fi
        fi
    done
}

# Periodic hot file detection
hot_file_detector() {
    while true; do
        sleep 60  # Check every minute
        detect_hot_files
        
        # Log hot files
        if [[ ${#hot_files[@]} -gt 0 ]]; then
            log_info "Hot files detected: ${!hot_files[*]}"
        fi
    done
}

# Health check
health_check() {
    local pid_file_content=$(cat "$PID_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$pid_file_content" ]]; then
        # PID file contains two PIDs: monitor_pid detector_pid
        local monitor_pid=$(echo "$pid_file_content" | cut -d' ' -f1)
        local detector_pid=$(echo "$pid_file_content" | cut -d' ' -f2)
        
        # Check if both processes are running
        if [[ -n "$monitor_pid" ]] && kill -0 "$monitor_pid" 2>/dev/null && \
           [[ -n "$detector_pid" ]] && kill -0 "$detector_pid" 2>/dev/null; then
            echo "Auto backup daemon is running (Monitor PID: $monitor_pid, Detector PID: $detector_pid)"
            return 0
        else
            # Clean up stale PID file
            rm -f "$PID_FILE" 2>/dev/null
        fi
    fi
    
    # Also check for processes by name as fallback
    local running_processes=$(pgrep -f "grim.*auto.*backup" 2>/dev/null | wc -l)
    if [[ $running_processes -gt 0 ]]; then
        echo "Auto backup daemon processes detected ($running_processes processes)"
        return 0
    fi
    
    echo "Auto backup daemon is not running"
    return 1
}

# Start daemon
start_daemon() {
    if health_check >/dev/null 2>&1; then
        log_warn "Auto backup daemon is already running"
        return 1
    fi
    
    log_info "Starting auto backup daemon..."
    
    # Start background processes
    monitor_files &
    local monitor_pid=$!
    
    hot_file_detector &
    local detector_pid=$!
    
    # Save PIDs
    echo "$monitor_pid $detector_pid" > "$PID_FILE"
    
    log_info "Auto backup daemon started (Monitor PID: $monitor_pid, Detector PID: $detector_pid)"
}

# Stop daemon
stop_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local pids=$(cat "$PID_FILE")
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                log_info "Stopped process: $pid"
            fi
        done
        rm -f "$PID_FILE"
        log_info "Auto backup daemon stopped"
    else
        log_warn "No PID file found"
    fi
}

# Restart daemon
restart_daemon() {
    log_info "Restarting auto backup daemon..."
    stop_daemon
    sleep 2
    start_daemon
}

# Show status
show_status() {
    echo -e "${BLUE}=== Grim Auto Backup Status ===${NC}"
    
    if health_check; then
        echo -e "${GREEN}✓ Daemon is running${NC}"
    else
        echo -e "${RED}✗ Daemon is not running${NC}"
    fi
    
    echo "Configuration:"
    echo "  Monitor Directory: $MONITOR_DIR"
    echo "  Graveyard Directory: $GRAVEYARD_DIR"
    echo "  Backup Interval: $BACKUP_INTERVAL seconds"
    echo "  Max Backups: $MAX_BACKUPS"
    echo "  Compression: ${COMPRESSION_ALGORITHM:-zstd}"
    
    echo -e "\nHot Files:"
    # Only show hot files if daemon is running and arrays are populated
    if health_check >/dev/null 2>&1 && [[ ${#hot_files[@]} -gt 0 ]]; then
        for file in "${!hot_files[@]}"; do
            local mod_count=${file_modifications[$file]:-0}
            echo "  - $file ($mod_count modifications)"
        done
    else
        echo "  None detected (daemon not running)"
    fi
    
    # Use protected file listing
    show_backup_files
    
    # Check for updates (free feature)
    check_for_updates
}

# License validation function
check_license_tier() {
    local license_key="${GRIM_LICENSE_KEY:-FREE}"
    
    # FREE license keys are explicitly free tier
    if [ "$license_key" = "FREE" ] || [ -z "$license_key" ]; then
        return 1  # Free tier
    fi
    
    # Check with up.grim.so for license validation
    local validation_response=""
    if command -v curl >/dev/null 2>&1; then
        validation_response=$(curl -s --connect-timeout 10 --max-time 30 \
            -H "Content-Type: application/json" \
            -H "User-Agent: Grim-CLI/1.0" \
            -d "{\"license_key\":\"$license_key\",\"action\":\"validate\"}" \
            "https://up.grim.so/license-check" 2>/dev/null || echo "")
    fi
    
    # Check response for valid license
    if [ -n "$validation_response" ]; then
        if echo "$validation_response" | grep -q '"status":"valid"' || \
           echo "$validation_response" | grep -q '"tier":"PRO"' || \
           echo "$validation_response" | grep -q '"tier":"MASTER"' || \
           echo "$validation_response" | grep -q '"tier":"REAPER"'; then
            return 0  # Paid tier
        fi
    fi
    
    # Fallback: Check with local license manager if available
    if [ -f "$GRIM_ROOT/tsk_flask/grim_license_manager.py" ]; then
        local result=$(python3 "$GRIM_ROOT/tsk_flask/grim_license_manager.py" validate --license-key "$license_key" 2>/dev/null || echo "")
        if echo "$result" | grep -q "✅ License valid"; then
            local tier=$(echo "$result" | grep "🎯 Tier:" | cut -d' ' -f3 2>/dev/null || echo "")
            if [ "$tier" != "FREE" ] && [ -n "$tier" ]; then
                return 0  # Paid tier
            fi
        fi
    fi
    
    return 1  # Default to free tier
}

# Show license upgrade prompt
show_upgrade_prompt() {
    echo -e "${YELLOW}🔒 PREMIUM FEATURE${NC}"
    echo "Auto-backup file listings require a Grim Pro license."
    echo ""
    echo "Current license: ${GRIM_LICENSE_KEY:-FREE}"
    echo ""
    echo "🚀 Upgrade options:"
    echo "  • Get license at: https://grim.so/pay"
    echo "  • Generate trial: grim license generate your@email.com"
    echo "  • Check status: grim license validate"
    echo ""
}

# Check for version updates (free feature)
check_for_updates() {
    if command -v curl >/dev/null 2>&1; then
        local current_version="1.0.0-20250726"
        local update_response=$(curl -s --connect-timeout 5 --max-time 15 \
            -H "User-Agent: Grim-CLI/$current_version" \
            -d "current_version=$current_version&license=${GRIM_LICENSE_KEY:-FREE}" \
            "https://up.grim.so/version-check" 2>/dev/null || echo "")
        
        if [ -n "$update_response" ] && echo "$update_response" | grep -q "update_available"; then
            echo -e "${CYAN}📦 Update available! Run: curl -sSL up.grim.so/install | bash${NC}"
        fi
    fi
}

# Protected file listing
show_backup_files() {
    if ! check_license_tier; then
        show_upgrade_prompt
        echo "Basic auto-backup is active but file listings are protected."
        return 1
    fi
    
    # Show actual backup files for paid users
    echo -e "\nRecent Backups:"
    find "$GRAVEYARD_DIR/auto_backups" -name "*.${COMPRESSION_ALGORITHM:-zstd}" -printf '%T@ %p\n' 2>/dev/null | \
    sort -n | tail -5 | while read timestamp file; do
        local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
        echo "  - $date: $file"
    done
}

# AI-powered backup decision making (premium feature)
should_backup_file_ai() {
    local file_path="$1"
    
    # Quick checks first
    if [ ! -f "$file_path" ]; then
        return 1  # Don't backup non-existent files
    fi
    
    local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
    if [ "$file_size" -lt "$MIN_FILE_SIZE" ]; then
        return 1  # Don't backup tiny files
    fi
    
    # Use grim analyze-decisions for intelligent backup decisions
    if command -v grim >/dev/null 2>&1 && [ -f "$GRIM_ROOT/py_grim/analyze_decisions.py" ]; then
        # Create temporary analysis request
        local temp_analysis="/tmp/grim_ai_analysis_$$"
        
        # Run AI analysis
        if python3 "$GRIM_ROOT/py_grim/analyze_decisions.py" analyze --path "$file_path" >/dev/null 2>&1; then
            # Query the database for the decision
            local db_path="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
            if [ -f "$db_path" ] && command -v sqlite3 >/dev/null 2>&1; then
                local decision=$(sqlite3 "$db_path" "SELECT decision_value FROM ai_decisions WHERE file_path='$file_path' ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo "")
                
                case "$decision" in
                    "high_priority"|"medium_priority")
                        log_info "AI recommends backing up: $file_path (priority: $decision)"
                        return 0
                        ;;
                    "low_priority")
                        # Still backup but log the low priority
                        log_info "AI suggests low priority for: $file_path"
                        return 0
                        ;;
                    "skip"|"ignore")
                        log_info "AI recommends skipping: $file_path"
                        return 1
                        ;;
                esac
            fi
        fi
    fi
    
    # Fallback to rule-based decisions if AI unavailable
    return $(should_backup_file_rules "$file_path")
}

# Rule-based backup decisions (fallback)
should_backup_file_rules() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    local extension="${filename##*.}"
    
    # Skip temporary files
    case "$filename" in
        .DS_Store|Thumbs.db|*.tmp|*.temp|*.swp|*.swo|*~)
            return 1
            ;;
    esac
    
    # Skip log files older than 1 day
    if [[ "$extension" == "log" ]]; then
        local file_age=$(($(date +%s) - $(stat -c%Y "$file_path" 2>/dev/null || echo "0")))
        if [ "$file_age" -gt 86400 ]; then  # 24 hours
            return 1
        fi
    fi
    
    # Prioritize important file types
    case "$extension" in
        # High priority files
        doc|docx|pdf|txt|md|conf|config|json|yaml|yml|xml|sql|db|sqlite)
            return 0
            ;;
        # Source code files
        py|js|ts|html|css|php|rb|go|rs|cpp|c|h|java|kt|swift)
            return 0
            ;;
        # Data files
        csv|xlsx|xls|json|xml|backup|bak)
            return 0
            ;;
        # Skip binary/media files by default unless recently modified
        jpg|jpeg|png|gif|mp4|avi|mov|mp3|wav|zip|tar|gz|exe|bin)
            local file_age=$(($(date +%s) - $(stat -c%Y "$file_path" 2>/dev/null || echo "0")))
            if [ "$file_age" -lt 3600 ]; then  # Modified in last hour
                return 0
            else
                return 1
            fi
            ;;
    esac
    
    # Default: backup if recently modified
    local file_age=$(($(date +%s) - $(stat -c%Y "$file_path" 2>/dev/null || echo "0")))
    if [ "$file_age" -lt 1800 ]; then  # Modified in last 30 minutes
        return 0
    fi
    
    return 1
}

# Decrypt backup file (for free users)
decrypt_backup() {
    local encrypted_file="$1"
    local output_file="${2:-}"
    
    if [ -z "$encrypted_file" ]; then
        echo "Usage: grim auto-backup decrypt <encrypted_file> [output_file]"
        echo ""
        echo "Decrypts auto-backup files created with FREE license"
        echo ""
        echo "Examples:"
        echo "  grim auto-backup decrypt /root/.graveyard/auto_backups_encrypted/file.txt.20250127_123456.zstd.enc"
        echo "  grim auto-backup decrypt backup.enc restored_file.txt"
        return 1
    fi
    
    if [ ! -f "$encrypted_file" ]; then
        log_error "Encrypted file not found: $encrypted_file"
        return 1
    fi
    
    # Generate output filename if not provided
    if [ -z "$output_file" ]; then
        output_file="${encrypted_file%.enc}"
        if [ "$output_file" = "$encrypted_file" ]; then
            output_file="${encrypted_file}.decrypted"
        fi
    fi
    
    # Generate decryption key (same as encryption key)
    local encryption_key="${GRIM_LICENSE_KEY:-FREE}_$(hostname)_grim_auto_backup"
    
    echo "🔓 Decrypting backup file..."
    if command -v openssl >/dev/null 2>&1; then
        if openssl enc -aes-256-cbc -d -in "$encrypted_file" -out "$output_file" -k "$encryption_key" 2>/dev/null; then
            log_info "File decrypted successfully: $output_file"
            echo "✅ Decrypted: $(basename "$encrypted_file") -> $(basename "$output_file")"
            echo "📁 Output file: $output_file"
            return 0
        else
            log_error "Decryption failed - wrong key or corrupted file"
            echo "❌ Decryption failed. Possible causes:"
            echo "   - File was encrypted on different hostname"
            echo "   - File is corrupted"
            echo "   - Different GRIM_LICENSE_KEY was used"
            return 1
        fi
    else
        log_error "OpenSSL not available for decryption"
        echo "❌ OpenSSL not found. Install with: apt-get install openssl"
        return 1
    fi
}

# List encrypted backups
list_encrypted() {
    local encrypted_dir="$GRAVEYARD_DIR/auto_backups_encrypted"
    
    echo "🔒 Encrypted Auto-Backups (FREE License):"
    echo ""
    
    if [ ! -d "$encrypted_dir" ]; then
        echo "No encrypted backups found"
        echo ""
        echo "ℹ️  Encrypted backups are stored in: $encrypted_dir"
        echo "   These are created automatically for FREE license users"
        return 0
    fi
    
    local file_count=0
    local total_size=0
    
    find "$encrypted_dir" -name "*.enc" -type f | sort | while read -r file; do
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        local date=$(stat -c%y "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        local rel_path="${file#$encrypted_dir/}"
        local size_mb=$((size / 1024 / 1024))
        
        if [ $size_mb -gt 0 ]; then
            echo "  📄 $date (${size_mb}MB) - $rel_path"
        else
            local size_kb=$((size / 1024))
            echo "  📄 $date (${size_kb}KB) - $rel_path"
        fi
        
        file_count=$((file_count + 1))
        total_size=$((total_size + size))
    done
    
    if [ $file_count -eq 0 ]; then
        echo "No encrypted backup files found"
    else
        local total_mb=$((total_size / 1024 / 1024))
        echo ""
        echo "📊 Total: $file_count encrypted files, ${total_mb}MB"
    fi
    
    echo ""
    echo "🔓 To decrypt a file:"
    echo "   grim auto-backup decrypt <encrypted_file> [output_file]"
    echo ""
    echo "💡 Upgrade to PRO/MASTER/REAPER license for unencrypted backups"
}

# Main function
main() {
    case "${1:-}" in
        start)
            init_system
            start_daemon
            ;;
        stop)
            stop_daemon
            ;;
        restart)
            restart_daemon
            ;;
        status)
            show_status
            ;;
        health)
            health_check
            ;;
        decrypt)
            shift
            decrypt_backup "$@"
            ;;
        list-encrypted)
            list_encrypted
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status|health|decrypt|list-encrypted}"
            echo ""
            echo "Grim Automatic Backup System"
            echo "Monitors file changes and creates intelligent compressed backups"
            echo ""
            echo "Commands:"
            echo "  start          - Start the auto backup daemon"
            echo "  stop           - Stop the auto backup daemon"
            echo "  restart        - Restart the auto backup daemon"
            echo "  status         - Show current status and configuration"
            echo "  health         - Check if daemon is running"
            echo "  decrypt        - Decrypt encrypted backup files (FREE license)"
            echo "  list-encrypted - List all encrypted backup files"
            echo ""
            echo "Environment variables:"
            echo "  GRAVEYARD_DIR     - Backup destination (default: /root/.graveyard)"
            echo "  MONITOR_DIR       - Directory to monitor (default: current directory)"
            echo "  BACKUP_INTERVAL   - Backup interval in seconds (default: 300)"
            echo "  MAX_BACKUPS       - Maximum backups per file (default: 50)"
            echo "  COMPRESSION_ALGORITHM - Compression algorithm (default: zstd)"
            exit 1
            ;;
    esac
}

# Handle signals
trap 'log_info "Received signal, shutting down..."; stop_daemon; exit 0' SIGTERM SIGINT

# Run main function
main "$@" 