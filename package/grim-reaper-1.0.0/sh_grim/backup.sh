#!/bin/bash
# Grimm Backup Module: Backs up files by smart frequency with verification

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/backup.log"
BACKUP_ROOT="${BACKUP_DIR:-$GRIM_ROOT/backups}"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Backup Module"
    echo "Usage: backup.sh <command> [options]"
    echo ""
    echo "Purpose: Creates intelligent backups with frequency-based scheduling,"
    echo "         verification, encryption, and deduplication capabilities."
    echo ""
    echo "Commands:"
    echo "  create <freq> [path]  - Create backup for specific frequency"
    echo "  verify <file>         - Verify backup integrity"
    echo "  list [freq]           - List available backups"
    echo "  help, -h, --help      - Show this help message"
    echo ""
    echo "Frequencies:"
    echo "  hourly                - Files that change frequently"
    echo "  daily                 - Regular daily backups"
    echo "  weekly                - Weekly backup cycle"
    echo "  monthly               - Monthly archive backups"
    echo "  all                   - Run all frequency backups"
    echo ""
    echo "Options:"
    echo "  --encrypt             - Encrypt backup files"
    echo "  --dedup               - Apply deduplication"
    echo "  --remote              - Upload to remote storage"
    echo ""
    echo "Examples:"
    echo "  ./backup.sh                           # Run all scheduled backups"
    echo "  ./backup.sh create daily              # Create daily backup"
    echo "  ./backup.sh create hourly /var/www    # Backup specific path hourly"
    echo "  ./backup.sh verify backup.tar.gz      # Verify backup integrity"
    echo "  ./backup.sh list daily                # List daily backups"
    echo "  ./backup.sh help                      # Show help"
}

# Create checksum for backup
create_checksum() {
    local file="$1"
    local checksum_file="${file}.sha256"
    sha256sum "$file" > "$checksum_file"
    log "Created checksum: $checksum_file"
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    local checksum_file="${backup_file}.sha256"
    
    if [ ! -f "$checksum_file" ]; then
        log_error "No checksum file found for $backup_file"
        return 1
    fi
    
    if sha256sum -c "$checksum_file" >/dev/null 2>&1; then
        log "Backup verification OK: $backup_file"
        echo "Backup is valid."
        return 0
    else
        log_error "Backup verification FAILED: $backup_file"
        echo "Backup verification failed!"
        return 1
    fi
}

# Show progress while creating backup
show_progress() {
    local current=0
    local total=$1
    while read line; do
        ((current++))
        printf "\rProgress: %d/%d files (%.1f%%)" $current $total $(echo "scale=1; $current*100/$total" | bc)
    done
    echo
}

# Create backup with frequency
backup_freq() {
    local freq="$1"
    local source_path="${2:-}"
    local outdir="$BACKUP_ROOT/$freq"
    mkdir -p "$outdir"
    local start_time=$(date +%s)
    
    if [ -n "$source_path" ]; then
        # Direct path backup
        create_backup_from_path "$freq" "$source_path"
    else
        # Database-driven backup
        local filelist="$outdir/filelist.txt"
        sqlite3 "$DB_PATH" "SELECT path FROM files WHERE backup_freq='$freq';" > "$filelist" 2>/dev/null || touch "$filelist"
        local count=$(wc -l < "$filelist")
        if [[ $count -eq 0 ]]; then
            log "No files to backup for $freq."
            return
        fi
        
        local archive="$outdir/${freq}-$(date +%Y%m%d-%H%M%S).tar.gz"
        log "Creating $freq backup of $count files..."
        
        # Create backup with progress indicator
        if command -v pv >/dev/null 2>&1; then
            tar cf - -T "$filelist" 2>/dev/null | pv -s $(du -cb $(cat "$filelist" 2>/dev/null) 2>/dev/null | tail -1 | awk '{print $1}') | gzip > "$archive"
        else
            tar -czf "$archive" -T "$filelist" 2>/dev/null
        fi
        
        local tar_exit_code=$?
        if [ $tar_exit_code -ne 0 ]; then
            log_error "Tar command failed with exit code: $tar_exit_code"
            "$NOTIFY_MODULE" send error "Backup Failed" "Failed to create $freq backup archive" "{\"frequency\": \"$freq\", \"error\": \"tar exit code $tar_exit_code\"}"
            return 1
        fi
        
        create_checksum "$archive"
        
        # Calculate backup size and duration
        local backup_size=$(stat -c%s "$archive" 2>/dev/null || echo 0)
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Check if backup is unusually large
        local size_gb=$((backup_size / 1024 / 1024 / 1024))
        if [ $size_gb -gt ${BACKUP_SIZE_WARNING_GB:-50} ]; then
            "$NOTIFY_MODULE" send warning "Large Backup Created" "$freq backup is ${size_gb}GB - larger than expected" "{\"frequency\": \"$freq\", \"size_bytes\": $backup_size, \"threshold_gb\": ${BACKUP_SIZE_WARNING_GB:-50}}"
        fi
        
        # Encrypt if enabled globally
        if [ "${ENCRYPT_BACKUPS:-false}" = "true" ]; then
            if "$GRIM_ROOT/modules/encrypt.sh" encrypt "$archive"; then
                rm -f "$archive" "${archive}.sha256"
                log "Backed up $count files to ${archive}.enc (encrypted)"
                "$NOTIFY_MODULE" send success "Backup Complete" "Successfully created encrypted $freq backup of $count files" "{\"frequency\": \"$freq\", \"file_count\": $count, \"size_bytes\": $backup_size, \"duration_seconds\": $duration, \"encrypted\": true}"
            else
                log "Backed up $count files to $archive (encryption failed)"
                "$NOTIFY_MODULE" send warning "Backup Encryption Failed" "$freq backup created but encryption failed" "{\"frequency\": \"$freq\", \"file_count\": $count, \"size_bytes\": $backup_size}"
            fi
        else
            log "Backed up $count files to $archive."
            "$NOTIFY_MODULE" send success "Backup Complete" "Successfully created $freq backup of $count files" "{\"frequency\": \"$freq\", \"file_count\": $count, \"size_bytes\": $backup_size, \"duration_seconds\": $duration, \"encrypted\": false}"
        fi
        
        # Check disk space after backup
        "$NOTIFY_MODULE" check-disk "$BACKUP_ROOT"
    fi
}

# Create backup from specific path
create_backup_from_path() {
    local freq="$1"
    local source_path="$2"
    local outdir="$BACKUP_ROOT/$freq"
    mkdir -p "$outdir"
    
    if [ ! -e "$source_path" ]; then
        log_error "Source path does not exist: $source_path"
        "$NOTIFY_MODULE" send error "Backup Failed" "Source path does not exist: $source_path" "{\"frequency\": \"$freq\", \"source_path\": \"$source_path\"}"
        return 1
    fi
    
    local start_time=$(date +%s)
    
    local archive="$outdir/${freq}-$(date +%Y%m%d-%H%M%S).tar.gz"
    log "Creating $freq backup of $source_path..."
    
    # Get exclusions from config
    local exclude_args=""
    for pattern in node_modules .git tmp cache vendor logs z_archive; do
        exclude_args="$exclude_args --exclude='$pattern'"
    done
    
    # Create backup with progress
    if command -v pv >/dev/null 2>&1; then
        eval "tar cf - $exclude_args '$source_path' 2>/dev/null" | pv -s $(du -sb "$source_path" 2>/dev/null | awk '{print $1}') | gzip > "$archive"
    else
        eval "tar -czf '$archive' $exclude_args '$source_path' 2>/dev/null"
    fi
    
    local tar_exit_code=$?
    if [ $tar_exit_code -ne 0 ]; then
        log_error "Tar command failed with exit code: $tar_exit_code"
        "$NOTIFY_MODULE" send error "Backup Failed" "Failed to create backup of $source_path" "{\"frequency\": \"$freq\", \"source_path\": \"$source_path\", \"error\": \"tar exit code $tar_exit_code\"}"
        return 1
    fi
    
    # Calculate backup metrics
    local backup_size=$(stat -c%s "$archive" 2>/dev/null || echo 0)
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Check if backup is unusually large
    local size_gb=$((backup_size / 1024 / 1024 / 1024))
    if [ $size_gb -gt ${BACKUP_SIZE_WARNING_GB:-50} ]; then
        "$NOTIFY_MODULE" send warning "Large Backup Created" "Backup of $source_path is ${size_gb}GB - larger than expected" "{\"frequency\": \"$freq\", \"source_path\": \"$source_path\", \"size_bytes\": $backup_size, \"threshold_gb\": ${BACKUP_SIZE_WARNING_GB:-50}}"
    fi
    
    # Apply deduplication if enabled
    if [ "${DEDUP_BACKUPS:-false}" = "true" ] || [ "${3:-}" = "--dedup" ]; then
        if "$GRIM_ROOT/modules/dedup.sh" dedup "$archive" "${archive}.dedup"; then
            local original_size=$(stat -c%s "$archive" 2>/dev/null)
            local dedup_size=$(stat -c%s "${archive}.dedup.manifest.gz" 2>/dev/null)
            local saved=$((original_size - dedup_size))
            log "Deduplication saved $(numfmt --to=iec-i --suffix=B $saved 2>/dev/null || echo "$saved bytes")"
            rm -f "$archive"  # Remove original, keep dedup version
            archive="${archive}.dedup"
        else
            log_error "Deduplication failed, keeping original backup"
        fi
    fi
    
    create_checksum "$archive"
    
    # Encrypt if requested
    if [ "${ENCRYPT_BACKUPS:-false}" = "true" ] || [ "${3:-}" = "--encrypt" ]; then
        if "$GRIM_ROOT/modules/encrypt.sh" encrypt "$archive"; then
            rm -f "$archive" "${archive}.sha256"  # Remove unencrypted version
            log "Backup created and encrypted: ${archive}.enc"
        else
            log_error "Encryption failed, keeping unencrypted backup"
        fi
    else
        log "Backup created: $archive"
    fi
    
    # Upload to remote if configured
    if [ "${REMOTE_BACKUP:-false}" = "true" ] || [ "${4:-}" = "--remote" ]; then
        if "$GRIM_ROOT/modules/remote.sh" upload "$archive${ENCRYPT_BACKUPS:+.enc}" 2>/dev/null; then
            log "Backup uploaded to remote storage"
        else
            log_error "Failed to upload to remote storage"
            "$NOTIFY_MODULE" send error "Remote Upload Failed" "Failed to upload backup to remote storage" "{\"frequency\": \"$freq\", \"file\": \"$archive${ENCRYPT_BACKUPS:+.enc}\"}"
        fi
    fi
    
    # Send success notification
    local encrypted=$( [ "${ENCRYPT_BACKUPS:-false}" = "true" ] || [ "${3:-}" = "--encrypt" ] && echo "true" || echo "false" )
    "$NOTIFY_MODULE" send success "Backup Complete" "Successfully created backup of $source_path" "{\"frequency\": \"$freq\", \"source_path\": \"$source_path\", \"size_bytes\": $backup_size, \"duration_seconds\": $duration, \"encrypted\": $encrypted}"
    
    # Check disk space after backup
    "$NOTIFY_MODULE" check-disk "$BACKUP_ROOT"
}

# List available backups
list_backups() {
    local freq="${1:-all}"
    
    if [ "$freq" = "all" ]; then
        for f in hourly daily weekly monthly; do
            echo -e "\n=== $f backups ==="
            ls -lh "$BACKUP_ROOT/$f"/*.tar.gz* 2>/dev/null | tail -5
        done
    else
        echo -e "\n=== $freq backups ==="
        ls -lh "$BACKUP_ROOT/$freq"/*.tar.gz* 2>/dev/null
    fi
}

# Main function with command support
main() {
    local command="${1:-backup}"
    shift
    
    case "$command" in
        create)
            local freq="${1:-all}"
            local path="${2:-}"
            if [ "$freq" = "all" ]; then
                for f in hourly daily weekly monthly; do
                    backup_freq "$f" "$path"
                done
            else
                backup_freq "$freq" "$path"
            fi
            log "Backup complete."
            # Check disk space after all backups
            "$NOTIFY_MODULE" check-disk "$BACKUP_ROOT"
            ;;
        verify)
            local backup_file="$1"
            if [ -z "$backup_file" ]; then
                log_error "Usage: backup.sh verify <backup_file>"
                exit 1
            fi
            
            # Handle encrypted backups
            if [[ "$backup_file" == *.enc ]]; then
                # Verify encrypted file first
                "$GRIM_ROOT/modules/encrypt.sh" verify "$backup_file"
                
                # Decrypt temporarily to verify contents
                local temp_file="$(mktemp)"
                if "$GRIM_ROOT/modules/encrypt.sh" decrypt "$backup_file" "$temp_file"; then
                    verify_backup "$temp_file"
                    local result=$?
                    rm -f "$temp_file"
                    exit $result
                else
                    log_error "Failed to decrypt for verification"
                    exit 1
                fi
            else
                verify_backup "$backup_file"
            fi
            ;;
        list)
            list_backups "$1"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            # Default behavior - run all backups
            local total_start=$(date +%s)
            local success_count=0
            local fail_count=0
            
            for freq in hourly daily weekly monthly; do
                if backup_freq "$freq"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
            done
            
            local total_end=$(date +%s)
            local total_duration=$((total_end - total_start))
            
            if [ $fail_count -eq 0 ]; then
                log "All backups completed successfully."
                "$NOTIFY_MODULE" send success "All Backups Complete" "Successfully completed all scheduled backups in ${total_duration}s" "{\"success_count\": $success_count, \"fail_count\": $fail_count, \"duration_seconds\": $total_duration}"
            else
                log "Backup complete with errors: $fail_count failed, $success_count succeeded."
                "$NOTIFY_MODULE" send warning "Backups Partially Failed" "$fail_count backups failed, $success_count succeeded" "{\"success_count\": $success_count, \"fail_count\": $fail_count, \"duration_seconds\": $total_duration}"
            fi
            
            # Check disk space after all backups
            "$NOTIFY_MODULE" check-disk "$BACKUP_ROOT"
            ;;
    esac
}

main "$@"