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
        
        # Create backup with intelligent Go compression
        local temp_tar="${archive%.gz}"
        local go_compressed="${archive%.tar.gz}.grim"
        
        # Create uncompressed tar from file list
        tar -cf "$temp_tar" -T "$filelist" 2>/dev/null
        
        # Apply Go compression with benchmarking
        if [ -f "$GRIM_ROOT/go_grim/build/grim-compression" ]; then
            log "Applying intelligent compression to $count files..."
            "$GRIM_ROOT/go_grim/build/grim-compression" \
                -input "$temp_tar" \
                -output "$go_compressed" \
                -benchmark \
                -json > "${temp_tar}.compression_stats.json" 2>/dev/null
            
            if [ -f "$go_compressed" ]; then
                mv "$go_compressed" "$archive"
                rm -f "$temp_tar"
                
                # Log compression statistics and show user value
                if [ -f "${temp_tar}.compression_stats.json" ]; then
                    local compression_ratio=$(grep '"best_ratio"' "${temp_tar}.compression_stats.json" | head -1 || echo "unknown")
                    log "Go compression completed: $compression_ratio"
                    
                    # Record compression analytics for revenue tracking
                    "$GRIM_ROOT/sh_grim/compression_analytics.sh" record "$source_path" "${temp_tar}.compression_stats.json"
                    
                    # Show compression value to user
                    "$GRIM_ROOT/sh_grim/compression_analytics.sh" value "$archive" "${temp_tar}.compression_stats.json"
                fi
            else
                log "Go compression failed, using gzip fallback"
                gzip "$temp_tar"
                mv "${temp_tar}.gz" "$archive"
            fi
        else
            log "Go compression not available, using gzip"
            gzip "$temp_tar" 
            mv "${temp_tar}.gz" "$archive"
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
    
    # Use Go compression for superior compression ratios
    local temp_tar="${archive%.gz}"
    local go_compressed="${archive%.tar.gz}.grim"
    
    # First create uncompressed tar
    eval "tar -cf '$temp_tar' $exclude_args '$source_path' 2>/dev/null"
    
    # Use Go compression tool for intelligent compression
    if [ -f "$GRIM_ROOT/go_grim/build/grim-compression" ]; then
        log "Applying intelligent Go compression..."
        "$GRIM_ROOT/go_grim/build/grim-compression" \
            -input "$temp_tar" \
            -output "$go_compressed" \
            -benchmark \
            -json > "${temp_tar}.compression_stats.json" 2>/dev/null
        
        if [ -f "$go_compressed" ]; then
            # Use Go compressed version
            mv "$go_compressed" "$archive"
            rm -f "$temp_tar"
            log "Go compression applied successfully"
        else
            # Fallback to gzip
            log "Go compression failed, falling back to gzip"
            gzip "$temp_tar"
            mv "${temp_tar}.gz" "$archive"
        fi
    else
        # Fallback to traditional gzip
        log "Go compression not available, using gzip"
        gzip "$temp_tar"
        mv "${temp_tar}.gz" "$archive"
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
            local cloud_upload="${3:-auto}"
            
            if [ "$freq" = "all" ]; then
                for f in hourly daily weekly monthly; do
                    local backup_file=$(backup_freq "$f" "$path")
                    
                    # Auto-upload to cloud if backup was successful and cloud upload is enabled
                    if [ $? -eq 0 ] && [ -n "$backup_file" ] && [ "$cloud_upload" != "no" ]; then
                        log "Attempting to upload $f backup to cloud storage..."
                        
                        local provider="auto"
                        if [ "$cloud_upload" != "auto" ] && [ "$cloud_upload" != "yes" ]; then
                            provider="$cloud_upload"
                        fi
                        
                        if bash "$GRIM_ROOT/sh_grim/cloud_backup.sh" upload "$backup_file" "$provider" >/dev/null 2>&1; then
                            log "Cloud upload successful for $f backup"
                        else
                            log "Cloud upload failed for $f backup, but local backup is available"
                        fi
                    fi
                done
            else
                local backup_file=$(backup_freq "$freq" "$path")
                
                # Auto-upload to cloud if backup was successful and cloud upload is enabled
                if [ $? -eq 0 ] && [ -n "$backup_file" ] && [ "$cloud_upload" != "no" ]; then
                    log "Attempting to upload backup to cloud storage..."
                    
                    local provider="auto"
                    if [ "$cloud_upload" != "auto" ] && [ "$cloud_upload" != "yes" ]; then
                        provider="$cloud_upload"
                    fi
                    
                    if bash "$GRIM_ROOT/sh_grim/cloud_backup.sh" upload "$backup_file" "$provider" >/dev/null 2>&1; then
                        log "Cloud upload successful"
                    else
                        log "Cloud upload failed, but local backup is available at: $backup_file"
                    fi
                fi
            fi
            log "Backup complete."
            # Check disk space after all backups
            "$NOTIFY_MODULE" check-disk "$BACKUP_ROOT"
            ;;
        verify)
            local backup_file="$1"
            if [ -z "$backup_file" ]; then
                # If no backup file specified, verify latest backups from each frequency
                echo "No backup file specified. Verifying latest backups from each frequency..."
                local verification_failed=0
                
                for freq in hourly daily weekly monthly; do
                    local latest_backup=$(ls -t "$BACKUP_ROOT/$freq"/*.tar.gz* 2>/dev/null | head -1)
                    if [ -n "$latest_backup" ]; then
                        echo "Verifying latest $freq backup: $(basename "$latest_backup")"
                        if ! verify_backup "$latest_backup"; then
                            log_error "Verification failed for $latest_backup"
                            verification_failed=1
                        else
                            log "Verification successful for $latest_backup"
                        fi
                    else
                        log "No $freq backups found to verify"
                    fi
                done
                
                if [ $verification_failed -eq 0 ]; then
                    log "All backup verifications completed successfully"
                    exit 0
                else
                    log_error "Some backup verifications failed"
                    exit 1
                fi
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