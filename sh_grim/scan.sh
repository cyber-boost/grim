#!/bin/bash
# Grimm Scan Module: Scans filesystem with progress tracking, updates DB

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/scan.log"
CONFIG_FILE="$GRIM_ROOT/grimm.tusk"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$GRIM_ROOT/bin/tusk_parser.sh" "$CONFIG_FILE" 2>/dev/null || true
fi

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Scan Module"
    echo "Usage: scan.sh <command> [options]"
    echo ""
    echo "Purpose: Scans filesystem directories to index files and directories,"
    echo "         tracking metadata for intelligent backup scheduling."
    echo ""
    echo "Commands:"
    echo "  full [dirs...]         - Full scan of specified directories"
    echo "  quick [dir] [hours]    - Quick scan of recently modified files"
    echo "  stats                  - Show scan statistics"
    echo "  clean                  - Remove non-existent file entries"
    echo "  help, -h, --help       - Show this help message"
    echo ""
    echo "Options:"
    echo "  dirs                   - Directories to scan (default: /var/www /root /home)"
    echo "  hours                  - Hours for quick scan (default: 24)"
    echo ""
    echo "Scan Features:"
    echo "  - Progress tracking with visual indicators"
    echo "  - Automatic exclusion of common directories (node_modules, .git, etc.)"
    echo "  - Database storage of file metadata"
    echo "  - Batch processing for performance"
    echo "  - Notification system integration"
    echo ""
    echo "Examples:"
    echo "  ./scan.sh                      # Default scan of common directories"
    echo "  ./scan.sh full /var/www /home  # Full scan of specific directories"
    echo "  ./scan.sh quick /tmp 12        # Quick scan of /tmp (last 12 hours)"
    echo "  ./scan.sh stats                # Show scan statistics"
    echo "  ./scan.sh clean                # Clean database of missing files"
    echo "  ./scan.sh help                 # Show help"
    echo ""
    echo "Excluded Patterns:"
    echo "  node_modules, .git, tmp, cache, vendor, logs, z_archive, .cache, .npm, .composer"
}

# Ensure DB exists and schema is ready
init_db() {
    mkdir -p "$(dirname "$DB_PATH")"
    sqlite3 "$DB_PATH" <<'EOF'
CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY,
    path TEXT UNIQUE,
    type TEXT,
    size_bytes INTEGER,
    mtime INTEGER,
    scan_count INTEGER DEFAULT 0,
    last_seen INTEGER,
    backup_freq TEXT,
    user_action TEXT,
    importance INTEGER DEFAULT 5
);
CREATE INDEX IF NOT EXISTS idx_backup_freq ON files(backup_freq);
CREATE INDEX IF NOT EXISTS idx_last_seen ON files(last_seen);
EOF
}

# Progress bar function
show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' ' '
    printf "] %3d%% (%d/%d)" $percent $current $total
}

# Check if path should be excluded
should_exclude() {
    local path="$1"
    local exclusions=(node_modules .git tmp cache vendor logs z_archive .cache .npm .composer)
    
    for pattern in "${exclusions[@]}"; do
        if [[ "$path" == *"/$pattern/"* ]] || [[ "$path" == *"/$pattern" ]]; then
            return 0
        fi
    done
    return 1
}

# Scan directory with progress
scan_dir() {
    local dir="$1"
    local show_progress="${2:-true}"
    
    if [ ! -d "$dir" ]; then
        log_error "Directory not found: $dir"
        "$NOTIFY_MODULE" send error "Scan Failed" "Directory not found: $dir" "{\"directory\": \"$dir\"}"
        return 1
    fi
    
    log "Scanning directory: $dir"
    local scan_start=$(date +%s)
    
    # Count total files first for progress bar
    local total_files=0
    if [ "$show_progress" = "true" ]; then
        echo "Counting files..."
        if command -v pv >/dev/null 2>&1; then
            total_files=$(find "$dir" -type f 2>/dev/null | pv -l | wc -l)
        else
            total_files=$(find "$dir" -type f 2>/dev/null | wc -l)
        fi
        echo "Found $total_files files to scan"
    fi
    
    local count=0
    local skipped=0
    
    # Use a temp file for batch inserts
    local temp_sql=$(mktemp)
    echo "BEGIN TRANSACTION;" > "$temp_sql"
    
    find "$dir" -type f -o -type d 2>/dev/null | while read -r path; do
        [ -e "$path" ] || continue
        
        # Check exclusions
        if should_exclude "$path"; then
            ((skipped++))
            continue
        fi
        
        local type="file"
        [ -d "$path" ] && type="dir"
        local size=$( [ -f "$path" ] && stat -c %s "$path" 2>/dev/null || echo 0 )
        local mtime=$(stat -c %Y "$path" 2>/dev/null || echo 0)
        
        # Escape single quotes for SQL
        local escaped_path="${path//\'/\'\'}"
        
        echo "INSERT OR REPLACE INTO files (path, type, size_bytes, mtime, scan_count, last_seen) VALUES ('$escaped_path', '$type', $size, $mtime, COALESCE((SELECT scan_count FROM files WHERE path='$escaped_path'),0)+1, strftime('%s','now'));" >> "$temp_sql"
        
        ((count++))
        
        # Show progress
        if [ "$show_progress" = "true" ] && [ $total_files -gt 0 ]; then
            show_progress_bar $count $total_files
        elif [ $((count % 100)) -eq 0 ]; then
            echo -ne "\rScanned: $count files (skipped: $skipped)"
        fi
    done
    
    echo "COMMIT;" >> "$temp_sql"
    
    # Execute batch insert
    echo -e "\nApplying to database..."
    if ! sqlite3 "$DB_PATH" < "$temp_sql"; then
        log_error "Failed to update database"
        "$NOTIFY_MODULE" send error "Scan Database Error" "Failed to update database with scan results" "{\"directory\": \"$dir\", \"files_scanned\": $count}"
        rm -f "$temp_sql"
        return 1
    fi
    rm -f "$temp_sql"
    
    local scan_end=$(date +%s)
    local scan_duration=$((scan_end - scan_start))
    
    log "Scanned $count files/directories (skipped $skipped excluded items)"
    
    # Check if we found an unusually large number of new files
    local new_files_threshold=10000
    if [ $count -gt $new_files_threshold ]; then
        "$NOTIFY_MODULE" send warning "Large Number of Files Detected" "Scan found $count files in $dir - this is unusually high" "{\"directory\": \"$dir\", \"file_count\": $count, \"skipped_count\": $skipped, \"threshold\": $new_files_threshold, \"duration_seconds\": $scan_duration}"
    else
        "$NOTIFY_MODULE" send success "Scan Complete" "Successfully scanned $dir: $count files found, $skipped excluded" "{\"directory\": \"$dir\", \"file_count\": $count, \"skipped_count\": $skipped, \"duration_seconds\": $scan_duration}"
    fi
}

# Quick scan - only new/modified files
quick_scan() {
    local dir="$1"
    local since_hours="${2:-24}"
    
    log "Quick scan: files modified in last $since_hours hours"
    
    local count=0
    find "$dir" -type f -mmin -$((since_hours * 60)) 2>/dev/null | while read -r path; do
        if ! should_exclude "$path"; then
            local size=$(stat -c %s "$path" 2>/dev/null || echo 0)
            local mtime=$(stat -c %Y "$path" 2>/dev/null || echo 0)
            local escaped_path="${path//\'/\'\'}"
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO files (path, type, size_bytes, mtime, scan_count, last_seen) VALUES ('$escaped_path', 'file', $size, $mtime, COALESCE((SELECT scan_count FROM files WHERE path='$escaped_path'),0)+1, strftime('%s','now'));"
            ((count++))
            
            if [ $((count % 10)) -eq 0 ]; then
                echo -ne "\rQuick scan: $count files"
            fi
        fi
    done
    
    echo -e "\nQuick scan complete: $count files updated"
    
    if [ $count -gt 0 ]; then
        "$NOTIFY_MODULE" send info "Quick Scan Complete" "Updated $count files modified in last $since_hours hours" "{\"directory\": \"$dir\", \"file_count\": $count, \"hours\": $since_hours}"
    fi
}

# Show scan statistics
show_stats() {
    echo -e "\n=== Scan Statistics ==="
    
    local total_files=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM files WHERE type='file';")
    local total_size=$(sqlite3 "$DB_PATH" "SELECT SUM(size_bytes) FROM files WHERE type='file';")
    local total_size_human=$(numfmt --to=iec-i --suffix=B --format="%.1f" $total_size 2>/dev/null || echo "$total_size bytes")
    
    echo "Total files tracked: $total_files"
    echo "Total size: $total_size_human"
    
    echo -e "\nTop 10 largest files:"
    sqlite3 "$DB_PATH" -column -header "SELECT substr(path, -50) as file, printf('%.2f MB', size_bytes/1024.0/1024.0) as size FROM files WHERE type='file' ORDER BY size_bytes DESC LIMIT 10;"
    
    echo -e "\nFiles by backup frequency:"
    sqlite3 "$DB_PATH" -column -header "SELECT COALESCE(backup_freq, 'unassigned') as frequency, COUNT(*) as count FROM files WHERE type='file' GROUP BY backup_freq;"
}

# Main function
main() {
    local command="${1:-scan}"
    shift
    
    init_db
    
    case "$command" in
        full)
            local dirs=("$@")
            if [ ${#dirs[@]} -eq 0 ]; then
                # Default directories from config or hardcoded
                dirs=("/var/www" "/root" "/home")
            fi
            
            local total_start=$(date +%s)
            local total_files=0
            local failed_dirs=()
            
            for dir in "${dirs[@]}"; do
                if [ -d "$dir" ]; then
                    if scan_dir "$dir"; then
                        local dir_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM files WHERE path LIKE '$dir%' AND last_seen >= $total_start;" 2>/dev/null || echo 0)
                        total_files=$((total_files + dir_count))
                    else
                        failed_dirs+=("$dir")
                    fi
                else
                    failed_dirs+=("$dir")
                fi
            done
            
            local total_end=$(date +%s)
            local total_duration=$((total_end - total_start))
            
            if [ ${#failed_dirs[@]} -eq 0 ]; then
                "$NOTIFY_MODULE" send success "Full Scan Complete" "Successfully scanned all directories in ${total_duration}s" "{\"total_files\": $total_files, \"duration_seconds\": $total_duration}"
            else
                "$NOTIFY_MODULE" send warning "Scan Partially Failed" "Some directories could not be scanned: ${failed_dirs[*]}" "{\"total_files\": $total_files, \"failed_dirs\": \"${failed_dirs[*]}\", \"duration_seconds\": $total_duration}"
            fi
            
            show_stats
            ;;
        
        quick)
            local dir="${1:-/}"
            local hours="${2:-24}"
            quick_scan "$dir" "$hours"
            ;;
        
        stats)
            show_stats
            ;;
        
        clean)
            # Remove entries for files that no longer exist
            log "Cleaning database of non-existent files..."
            local cleaned=0
            sqlite3 "$DB_PATH" "SELECT path FROM files;" | while read -r path; do
                if [ ! -e "$path" ]; then
                    sqlite3 "$DB_PATH" "DELETE FROM files WHERE path='$path';"
                    ((cleaned++))
                fi
            done
            log "Cleaned $cleaned non-existent entries"
            if [ $cleaned -gt 0 ]; then
                "$NOTIFY_MODULE" send info "Database Cleaned" "Removed $cleaned non-existent file entries from database" "{\"cleaned_count\": $cleaned}"
            fi
            ;;
        
        help|-h|--help)
            show_help
            ;;
        
        *)
            # Default scan
            log "Starting scan..."
            local scan_start=$(date +%s)
            local success_count=0
            local fail_count=0
            
            if scan_dir "/var/www"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
            
            if scan_dir "/root"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
            
            local scan_end=$(date +%s)
            local scan_duration=$((scan_end - scan_start))
            local total_files=$(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM files;')
            
            log "Scan complete."
            echo "Scan complete. Files indexed: $total_files"
            
            if [ $fail_count -eq 0 ]; then
                "$NOTIFY_MODULE" send success "Default Scan Complete" "Successfully scanned default directories. Total files: $total_files" "{\"success_count\": $success_count, \"fail_count\": $fail_count, \"total_files\": $total_files, \"duration_seconds\": $scan_duration}"
            else
                "$NOTIFY_MODULE" send warning "Default Scan Partially Failed" "$fail_count scans failed, $success_count succeeded. Total files: $total_files" "{\"success_count\": $success_count, \"fail_count\": $fail_count, \"total_files\": $total_files, \"duration_seconds\": $scan_duration}"
            fi
            ;;
    esac
}

main "$@"