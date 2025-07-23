#!/bin/bash
# Grimm Cleanup Module: Comprehensive system maintenance and cleanup
# Handles backup retention, log rotation, temp cleanup, database optimization

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/cleanup.log"
BACKUP_ROOT="${BACKUP_DIR:-$GRIM_ROOT/backups}"
TEMP_DIR="${TEMP_DIR:-/tmp/grim}"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Load Tusk config
TUSK_FILE="$GRIM_ROOT/config/grimm.tusk"
TUSK_PARSER="$GRIM_ROOT/bin/tusk_parser.sh"
if [[ -f "$TUSK_PARSER" ]]; then
    source "$TUSK_PARSER" "$TUSK_FILE"
fi

# Default retention policies (can be overridden in config)
RETENTION_POLICIES=(
    "hourly:24"      # Keep 24 hourly backups
    "daily:7"        # Keep 7 daily backups  
    "weekly:4"       # Keep 4 weekly backups
    "monthly:12"     # Keep 12 monthly backups
    "yearly:5"       # Keep 5 yearly backups
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global variables
DRY_RUN=false
FORCE_CONFIRM=false
CLEANUP_REPORT=""
TOTAL_SPACE_SAVED=0
FILES_TO_DELETE=()
DIRS_TO_DELETE=()

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" | tee -a "$LOG_FILE"
}

# Safety confirmation function
confirm_action() {
    local prompt="$1"
    local confirm_word="REAP"
    
    if [[ "$FORCE_CONFIRM" == "true" || "$delete_without_conf" == "true" ]]; then
        return 0
    fi
    
    echo -ne "${RED}$prompt Type '$confirm_word' to confirm: ${NC}"
    read -t 30 input
    if [[ $? -ne 0 ]]; then
        echo -e "${YELLOW}Timeout - keeping files safe${NC}"
        return 1
    fi
    [[ "$input" == "$confirm_word" ]]
}

# Format file sizes
format_size() {
    local bytes=$1
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B $bytes
    else
        if [ $bytes -gt 1073741824 ]; then
            echo "$(echo "scale=1; $bytes/1073741824" | bc)GB"
        elif [ $bytes -gt 1048576 ]; then
            echo "$(echo "scale=1; $bytes/1048576" | bc)MB"
        elif [ $bytes -gt 1024 ]; then
            echo "$(echo "scale=1; $bytes/1024" | bc)KB"
        else
            echo "${bytes}B"
        fi
    fi
}

# Calculate directory size
get_dir_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | awk '{print $1}' || echo "0"
    else
        echo "0"
    fi
}

# Add to cleanup report
add_to_report() {
    local message="$1"
    CLEANUP_REPORT="${CLEANUP_REPORT}${message}\n"
}

# Clean old backup files based on retention policies
cleanup_backups() {
    local dry_run="${1:-false}"
    local space_saved=0
    local files_removed=0
    
    log "Starting backup cleanup..."
    add_to_report "=== BACKUP CLEANUP ===\n"
    
    for policy in "${RETENTION_POLICIES[@]}"; do
        local freq="${policy%:*}"
        local max_count="${policy#*:}"
        local backup_dir="$BACKUP_ROOT/$freq"
        
        if [ ! -d "$backup_dir" ]; then
            continue
        fi
        
        # Get list of backup files sorted by modification time (oldest first)
        local backup_files=($(find "$backup_dir" -name "*.tar.gz*" -o -name "*.enc" | sort -t- -k2,3 | head -n -$max_count 2>/dev/null))
        
        if [ ${#backup_files[@]} -eq 0 ]; then
            add_to_report "  $freq: No old backups to remove\n"
            continue
        fi
        
        local freq_space_saved=0
        local freq_files_removed=0
        
        for file in "${backup_files[@]}"; do
            if [ -f "$file" ]; then
                local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
                local checksum_file="${file}.sha256"
                
                if [ "$dry_run" = "true" ]; then
                    add_to_report "  Would remove: $file ($(format_size $file_size))\n"
                    freq_space_saved=$((freq_space_saved + file_size))
                    freq_files_removed=$((freq_files_removed + 1))
                else
                    if rm -f "$file" "$checksum_file" 2>/dev/null; then
                        add_to_report "  Removed: $file ($(format_size $file_size))\n"
                        freq_space_saved=$((freq_space_saved + file_size))
                        freq_files_removed=$((freq_files_removed + 1))
                        space_saved=$((space_saved + file_size))
                        files_removed=$((files_removed + 1))
                    else
                        log_error "Failed to remove: $file"
                    fi
                fi
            fi
        done
        
        if [ $freq_files_removed -gt 0 ]; then
            add_to_report "  $freq: Removed $freq_files_removed files, saved $(format_size $freq_space_saved)\n"
        fi
    done
    
    TOTAL_SPACE_SAVED=$((TOTAL_SPACE_SAVED + space_saved))
    add_to_report "Backup cleanup: Removed $files_removed files, saved $(format_size $space_saved)\n\n"
    
    if [ "$dry_run" = "false" ]; then
        log "Backup cleanup completed: $files_removed files removed, $(format_size $space_saved) saved"
        "$NOTIFY_MODULE" send info "Backup Cleanup Complete" "Removed $files_removed old backup files" "{\"files_removed\": $files_removed, \"space_saved_bytes\": $space_saved}"
    fi
}

# Clean temporary files
cleanup_temp() {
    local dry_run="${1:-false}"
    local space_saved=0
    local files_removed=0
    
    log "Starting temporary file cleanup..."
    add_to_report "=== TEMPORARY FILE CLEANUP ===\n"
    
    # Clean /tmp/grim
    if [ -d "$TEMP_DIR" ]; then
        local temp_files=($(find "$TEMP_DIR" -type f -mtime +1 2>/dev/null))
        local temp_dirs=($(find "$TEMP_DIR" -type d -empty -mtime +1 2>/dev/null))
        
        for file in "${temp_files[@]}"; do
            if [ -f "$file" ]; then
                local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
                if [ "$dry_run" = "true" ]; then
                    add_to_report "  Would remove temp file: $file ($(format_size $file_size))\n"
                    space_saved=$((space_saved + file_size))
                    files_removed=$((files_removed + 1))
                else
                    if rm -f "$file" 2>/dev/null; then
                        add_to_report "  Removed temp file: $file ($(format_size $file_size))\n"
                        space_saved=$((space_saved + file_size))
                        files_removed=$((files_removed + 1))
                    fi
                fi
            fi
        done
        
        for dir in "${temp_dirs[@]}"; do
            if [ -d "$dir" ]; then
                if [ "$dry_run" = "true" ]; then
                    add_to_report "  Would remove empty temp dir: $dir\n"
                else
                    if rmdir "$dir" 2>/dev/null; then
                        add_to_report "  Removed empty temp dir: $dir\n"
                    fi
                fi
            fi
        done
    fi
    
    # Clean work directories in Grim root
    local work_dirs=("$GRIM_ROOT/tmp" "$GRIM_ROOT/cache" "$GRIM_ROOT/work")
    for work_dir in "${work_dirs[@]}"; do
        if [ -d "$work_dir" ]; then
            local work_files=($(find "$work_dir" -type f -mtime +7 2>/dev/null))
            for file in "${work_files[@]}"; do
                if [ -f "$file" ]; then
                    local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
                    if [ "$dry_run" = "true" ]; then
                        add_to_report "  Would remove work file: $file ($(format_size $file_size))\n"
                        space_saved=$((space_saved + file_size))
                        files_removed=$((files_removed + 1))
                    else
                        if rm -f "$file" 2>/dev/null; then
                            add_to_report "  Removed work file: $file ($(format_size $file_size))\n"
                            space_saved=$((space_saved + file_size))
                            files_removed=$((files_removed + 1))
                        fi
                    fi
                fi
            done
        fi
    done
    
    TOTAL_SPACE_SAVED=$((TOTAL_SPACE_SAVED + space_saved))
    add_to_report "Temp cleanup: Removed $files_removed files, saved $(format_size $space_saved)\n\n"
    
    if [ "$dry_run" = "false" ]; then
        log "Temporary file cleanup completed: $files_removed files removed, $(format_size $space_saved) saved"
    fi
}

# Rotate and compress log files
cleanup_logs() {
    local dry_run="${1:-false}"
    local space_saved=0
    local files_processed=0
    
    log "Starting log rotation and compression..."
    add_to_report "=== LOG ROTATION ===\n"
    
    local logs_dir="$GRIM_ROOT/logs"
    if [ ! -d "$logs_dir" ]; then
        add_to_report "  Logs directory not found: $logs_dir\n"
        return
    fi
    
    # Find log files older than 1 day that aren't already compressed
    local log_files=($(find "$logs_dir" -name "*.log" -type f -mtime +1 2>/dev/null))
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            local log_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
            local compressed_file="${log_file}.gz"
            
            if [ "$dry_run" = "true" ]; then
                add_to_report "  Would compress: $log_file ($(format_size $log_size))\n"
                files_processed=$((files_processed + 1))
            else
                if gzip -f "$log_file" 2>/dev/null; then
                    local compressed_size=$(stat -c%s "$compressed_file" 2>/dev/null || echo 0)
                    local saved=$((log_size - compressed_size))
                    add_to_report "  Compressed: $log_file (saved $(format_size $saved))\n"
                    space_saved=$((space_saved + saved))
                    files_processed=$((files_processed + 1))
                else
                    log_error "Failed to compress: $log_file"
                fi
            fi
        fi
    done
    
    # Remove compressed logs older than 30 days
    local old_compressed=($(find "$logs_dir" -name "*.log.gz" -type f -mtime +30 2>/dev/null))
    for compressed_log in "${old_compressed[@]}"; do
        if [ -f "$compressed_log" ]; then
            local log_size=$(stat -c%s "$compressed_log" 2>/dev/null || echo 0)
            if [ "$dry_run" = "true" ]; then
                add_to_report "  Would remove old compressed log: $compressed_log ($(format_size $log_size))\n"
                space_saved=$((space_saved + log_size))
                files_processed=$((files_processed + 1))
            else
                if rm -f "$compressed_log" 2>/dev/null; then
                    add_to_report "  Removed old compressed log: $compressed_log ($(format_size $log_size))\n"
                    space_saved=$((space_saved + log_size))
                    files_processed=$((files_processed + 1))
                fi
            fi
        fi
    done
    
    TOTAL_SPACE_SAVED=$((TOTAL_SPACE_SAVED + space_saved))
    add_to_report "Log rotation: Processed $files_processed files, saved $(format_size $space_saved)\n\n"
    
    if [ "$dry_run" = "false" ]; then
        log "Log rotation completed: $files_processed files processed, $(format_size $space_saved) saved"
    fi
}

# Clean duplicate backup files
cleanup_duplicates() {
    local dry_run="${1:-false}"
    local space_saved=0
    local duplicates_removed=0
    
    log "Starting duplicate file cleanup..."
    add_to_report "=== DUPLICATE CLEANUP ===\n"
    
    # Find all backup files and calculate checksums
    local all_backups=($(find "$BACKUP_ROOT" -name "*.tar.gz*" -o -name "*.enc" 2>/dev/null))
    local checksums=()
    local duplicate_groups=()
    
    for backup in "${all_backups[@]}"; do
        if [ -f "$backup" ]; then
            local checksum=$(sha256sum "$backup" 2>/dev/null | cut -d' ' -f1)
            if [ -n "$checksum" ]; then
                checksums+=("$checksum:$backup")
            fi
        fi
    done
    
    # Group by checksum
    declare -A checksum_groups
    for item in "${checksums[@]}"; do
        local checksum="${item%:*}"
        local file="${item#*:}"
        checksum_groups["$checksum"]="${checksum_groups["$checksum"]} $file"
    done
    
    # Find duplicates (groups with more than one file)
    for checksum in "${!checksum_groups[@]}"; do
        local files=(${checksum_groups["$checksum"]})
        if [ ${#files[@]} -gt 1 ]; then
            # Sort by modification time, keep the newest
            local sorted_files=($(printf '%s\n' "${files[@]}" | xargs -I {} stat -c "%Y %n" {} 2>/dev/null | sort -n | awk '{print $2}'))
            local newest="${sorted_files[-1]}"
            
            for file in "${sorted_files[@]}"; do
                if [ "$file" != "$newest" ]; then
                    local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
                    local checksum_file="${file}.sha256"
                    
                    if [ "$dry_run" = "true" ]; then
                        add_to_report "  Would remove duplicate: $file (keeping: $newest)\n"
                        space_saved=$((space_saved + file_size))
                        duplicates_removed=$((duplicates_removed + 1))
                    else
                        if rm -f "$file" "$checksum_file" 2>/dev/null; then
                            add_to_report "  Removed duplicate: $file (keeping: $newest)\n"
                            space_saved=$((space_saved + file_size))
                            duplicates_removed=$((duplicates_removed + 1))
                        fi
                    fi
                fi
            done
        fi
    done
    
    TOTAL_SPACE_SAVED=$((TOTAL_SPACE_SAVED + space_saved))
    add_to_report "Duplicate cleanup: Removed $duplicates_removed duplicates, saved $(format_size $space_saved)\n\n"
    
    if [ "$dry_run" = "false" ]; then
        log "Duplicate cleanup completed: $duplicates_removed duplicates removed, $(format_size $space_saved) saved"
    fi
}

# Optimize SQLite databases
cleanup_database() {
    local dry_run="${1:-false}"
    local databases_optimized=0
    
    log "Starting database optimization..."
    add_to_report "=== DATABASE OPTIMIZATION ===\n"
    
    # Find all SQLite databases
    local db_files=($(find "$GRIM_ROOT" -name "*.db" -type f 2>/dev/null))
    
    for db_file in "${db_files[@]}"; do
        if [ -f "$db_file" ]; then
            local db_size_before=$(stat -c%s "$db_file" 2>/dev/null || echo 0)
            
            if [ "$dry_run" = "true" ]; then
                add_to_report "  Would optimize: $db_file ($(format_size $db_size_before))\n"
                databases_optimized=$((databases_optimized + 1))
            else
                if sqlite3 "$db_file" "VACUUM; ANALYZE;" 2>/dev/null; then
                    local db_size_after=$(stat -c%s "$db_file" 2>/dev/null || echo 0)
                    local saved=$((db_size_before - db_size_after))
                    add_to_report "  Optimized: $db_file (saved $(format_size $saved))\n"
                    databases_optimized=$((databases_optimized + 1))
                else
                    log_error "Failed to optimize database: $db_file"
                fi
            fi
        fi
    done
    
    add_to_report "Database optimization: Processed $databases_optimized databases\n\n"
    
    if [ "$dry_run" = "false" ]; then
        log "Database optimization completed: $databases_optimized databases optimized"
    fi
}

# Remove orphaned database entries
cleanup_orphans() {
    local dry_run="${1:-false}"
    local orphans_removed=0
    
    log "Starting orphaned entry cleanup..."
    add_to_report "=== ORPHANED ENTRIES CLEANUP ===\n"
    
    if [ ! -f "$DB_PATH" ]; then
        add_to_report "  Database not found: $DB_PATH\n"
        return
    fi
    
    # Remove file entries that no longer exist on disk
    local orphaned_files=$(sqlite3 "$DB_PATH" "SELECT path FROM files WHERE path NOT LIKE '%://%' AND path != '';" 2>/dev/null)
    for file_path in $orphaned_files; do
        if [ ! -e "$file_path" ]; then
            if [ "$dry_run" = "true" ]; then
                add_to_report "  Would remove orphaned entry: $file_path\n"
                orphans_removed=$((orphans_removed + 1))
            else
                if sqlite3 "$DB_PATH" "DELETE FROM files WHERE path='$file_path';" 2>/dev/null; then
                    add_to_report "  Removed orphaned entry: $file_path\n"
                    orphans_removed=$((orphans_removed + 1))
                fi
            fi
        fi
    done
    
    add_to_report "Orphaned entries cleanup: Removed $orphans_removed entries\n\n"
    
    if [ "$dry_run" = "false" ]; then
        log "Orphaned entries cleanup completed: $orphans_removed entries removed"
    fi
}

# Generate cleanup report
generate_report() {
    local dry_run="${1:-false}"
    
    echo -e "${CYAN}=== GRIMM CLEANUP REPORT ===${NC}"
    if [ "$dry_run" = "true" ]; then
        echo -e "${YELLOW}DRY RUN MODE - No files will be deleted${NC}\n"
    fi
    
    echo -e "$CLEANUP_REPORT"
    echo -e "${GREEN}Total space that would be saved: $(format_size $TOTAL_SPACE_SAVED)${NC}"
    
    if [ "$dry_run" = "false" ]; then
        log "Cleanup report generated"
        "$NOTIFY_MODULE" send info "Cleanup Complete" "Total space saved: $(format_size $TOTAL_SPACE_SAVED)" "{\"space_saved_bytes\": $TOTAL_SPACE_SAVED}"
    fi
}

# Show what would be cleaned (dry run)
show_cleanup_preview() {
    echo -e "${CYAN}🔍 Cleanup Preview - What would be cleaned:${NC}\n"
    
    CLEANUP_REPORT=""
    TOTAL_SPACE_SAVED=0
    
    cleanup_backups true
    cleanup_temp true
    cleanup_logs true
    cleanup_duplicates true
    cleanup_database true
    cleanup_orphans true
    
    generate_report true
}

# Main cleanup function
run_cleanup() {
    local task="${1:-all}"
    local dry_run="${2:-false}"
    
    # Initialize
    CLEANUP_REPORT=""
    TOTAL_SPACE_SAVED=0
    
    log "Starting cleanup task: $task (dry_run: $dry_run)"
    
    case "$task" in
        "all")
            if [ "$dry_run" = "false" ] && ! confirm_action "This will perform ALL cleanup tasks. "; then
                echo -e "${YELLOW}Cleanup cancelled by user${NC}"
                exit 0
            fi
            cleanup_backups "$dry_run"
            cleanup_temp "$dry_run"
            cleanup_logs "$dry_run"
            cleanup_duplicates "$dry_run"
            cleanup_database "$dry_run"
            cleanup_orphans "$dry_run"
            ;;
        "backups")
            if [ "$dry_run" = "false" ] && ! confirm_action "This will remove old backup files. "; then
                echo -e "${YELLOW}Backup cleanup cancelled by user${NC}"
                exit 0
            fi
            cleanup_backups "$dry_run"
            ;;
        "temp")
            if [ "$dry_run" = "false" ] && ! confirm_action "This will remove temporary files. "; then
                echo -e "${YELLOW}Temp cleanup cancelled by user${NC}"
                exit 0
            fi
            cleanup_temp "$dry_run"
            ;;
        "logs")
            if [ "$dry_run" = "false" ] && ! confirm_action "This will rotate and compress log files. "; then
                echo -e "${YELLOW}Log cleanup cancelled by user${NC}"
                exit 0
            fi
            cleanup_logs "$dry_run"
            ;;
        "database")
            if [ "$dry_run" = "false" ] && ! confirm_action "This will optimize databases. "; then
                echo -e "${YELLOW}Database cleanup cancelled by user${NC}"
                exit 0
            fi
            cleanup_database "$dry_run"
            cleanup_orphans "$dry_run"
            ;;
        "duplicates")
            if [ "$dry_run" = "false" ] && ! confirm_action "This will remove duplicate backup files. "; then
                echo -e "${YELLOW}Duplicate cleanup cancelled by user${NC}"
                exit 0
            fi
            cleanup_duplicates "$dry_run"
            ;;
        "report")
            show_cleanup_preview
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown cleanup task: $task${NC}"
            echo -e "${CYAN}Available tasks: all, backups, temp, logs, database, duplicates, report${NC}"
            exit 1
            ;;
    esac
    
    generate_report "$dry_run"
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Cleanup Module${NC}"
    echo "Usage: $0 <task> [options]"
    echo ""
    echo "Tasks:"
    echo "  all                    - Run all cleanup tasks"
    echo "  backups [--dry-run]    - Clean old backup files"
    echo "  temp [--dry-run]       - Remove temporary files"
    echo "  logs [--dry-run]       - Rotate and compress logs"
    echo "  database [--dry-run]   - Optimize databases and remove orphans"
    echo "  duplicates [--dry-run] - Remove duplicate backup files"
    echo "  report                 - Show what would be cleaned (dry run)"
    echo ""
    echo "Options:"
    echo "  --dry-run              - Show what would be done without making changes"
    echo "  --force                - Skip confirmation prompts"
    echo "  --help                 - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 all --dry-run       # Preview all cleanup operations"
    echo "  $0 backups             # Clean old backups with confirmation"
    echo "  $0 temp --force        # Clean temp files without confirmation"
}

# Parse command line arguments
main() {
    local task="${1:-help}"
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                FORCE_CONFIRM=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
            *)
                task="$1"
                shift
                ;;
        esac
    done
    
    # Create necessary directories
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$DB_PATH")" "$TEMP_DIR"
    
    # Handle help explicitly
    if [[ "$task" == "help" ]]; then
        show_help
        exit 0
    fi
    
    # Run cleanup
    run_cleanup "$task" "$dry_run"
}

main "$@" 