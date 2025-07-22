#!/bin/bash
# Grimm Remote Backup Module: Handles S3, rsync, and other remote storage

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/remote.log"
CONFIG_FILE="$GRIM_ROOT/config/remote.conf"

# Colors for output
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

# Load remote configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Create default config
        cat > "$CONFIG_FILE" <<'EOF'
# Grimm Remote Backup Configuration

# S3 Settings (AWS CLI must be configured)
S3_BUCKET=""
S3_PREFIX="grimm-backups"
S3_STORAGE_CLASS="STANDARD_IA"  # STANDARD, STANDARD_IA, GLACIER

# Rsync Settings
RSYNC_HOST=""
RSYNC_USER=""
RSYNC_PATH="/backups/grimm"
RSYNC_PORT="22"
RSYNC_SSH_KEY=""

# General Settings
REMOTE_TYPE="none"  # none, s3, rsync
COMPRESS_BEFORE_UPLOAD="true"
VERIFY_AFTER_UPLOAD="true"
DELETE_LOCAL_AFTER_UPLOAD="false"
BANDWIDTH_LIMIT=""  # KB/s, empty for unlimited
EOF
        log "Created default config at $CONFIG_FILE"
        log_error "Please configure remote settings in $CONFIG_FILE"
        return 1
    fi
}

# Progress callback for uploads
show_upload_progress() {
    local file="$1"
    local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    local size_mb=$(echo "scale=2; $size/1048576" | bc)
    
    echo -ne "\rUploading: $(basename "$file") ($size_mb MB)"
}

# Upload to S3
upload_to_s3() {
    local file="$1"
    local remote_path="${2:-}"
    
    if [ -z "$S3_BUCKET" ]; then
        log_error "S3_BUCKET not configured"
        return 1
    fi
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Install with: pip install awscli"
        return 1
    fi
    
    local filename=$(basename "$file")
    if [ -z "$remote_path" ]; then
        remote_path="$S3_PREFIX/$(date +%Y/%m)/$filename"
    fi
    
    log "Uploading to S3: s3://$S3_BUCKET/$remote_path"
    
    # Build AWS command with options
    local aws_opts="--storage-class $S3_STORAGE_CLASS"
    if [ -n "$BANDWIDTH_LIMIT" ]; then
        aws_opts="$aws_opts --bandwidth-limit ${BANDWIDTH_LIMIT}KB/s"
    fi
    
    # Upload with progress
    if aws s3 cp "$file" "s3://$S3_BUCKET/$remote_path" $aws_opts --no-progress 2>&1 | \
       while read line; do
           echo -ne "\r$line"
       done; then
        echo  # New line after progress
        log "Successfully uploaded to S3: $remote_path"
        
        # Verify upload if enabled
        if [ "$VERIFY_AFTER_UPLOAD" = "true" ]; then
            verify_s3_upload "$file" "$remote_path"
        fi
        
        return 0
    else
        log_error "Failed to upload to S3"
        return 1
    fi
}

# Verify S3 upload
verify_s3_upload() {
    local local_file="$1"
    local remote_path="$2"
    
    log "Verifying S3 upload..."
    
    local local_size=$(stat -c%s "$local_file")
    local remote_size=$(aws s3api head-object --bucket "$S3_BUCKET" --key "$remote_path" --query 'ContentLength' --output text 2>/dev/null)
    
    if [ "$local_size" = "$remote_size" ]; then
        log "Verification passed: sizes match ($local_size bytes)"
        return 0
    else
        log_error "Verification failed: size mismatch (local: $local_size, remote: $remote_size)"
        return 1
    fi
}

# Upload via rsync
upload_rsync() {
    local file="$1"
    local remote_path="${2:-}"
    
    if [ -z "$RSYNC_HOST" ]; then
        log_error "RSYNC_HOST not configured"
        return 1
    fi
    
    # Build rsync command
    local rsync_opts="-avz --progress"
    if [ -n "$RSYNC_SSH_KEY" ]; then
        rsync_opts="$rsync_opts -e 'ssh -i $RSYNC_SSH_KEY -p $RSYNC_PORT'"
    else
        rsync_opts="$rsync_opts -e 'ssh -p $RSYNC_PORT'"
    fi
    
    if [ -n "$BANDWIDTH_LIMIT" ]; then
        rsync_opts="$rsync_opts --bwlimit=$BANDWIDTH_LIMIT"
    fi
    
    # Determine remote path
    if [ -z "$remote_path" ]; then
        remote_path="$RSYNC_PATH/$(date +%Y/%m)/$(basename "$file")"
    fi
    
    local remote_url="$RSYNC_USER@$RSYNC_HOST:$remote_path"
    
    log "Uploading via rsync to: $remote_url"
    
    # Create remote directory
    ssh -p "$RSYNC_PORT" ${RSYNC_SSH_KEY:+-i "$RSYNC_SSH_KEY"} "$RSYNC_USER@$RSYNC_HOST" "mkdir -p $(dirname "$remote_path")"
    
    # Upload file
    if eval "rsync $rsync_opts '$file' '$remote_url'"; then
        log "Successfully uploaded via rsync"
        
        # Verify if enabled
        if [ "$VERIFY_AFTER_UPLOAD" = "true" ]; then
            verify_rsync_upload "$file" "$remote_url"
        fi
        
        return 0
    else
        log_error "Failed to upload via rsync"
        return 1
    fi
}

# Verify rsync upload
verify_rsync_upload() {
    local local_file="$1"
    local remote_url="$2"
    
    log "Verifying rsync upload..."
    
    local local_checksum=$(sha256sum "$local_file" | awk '{print $1}')
    local remote_checksum=$(ssh -p "$RSYNC_PORT" ${RSYNC_SSH_KEY:+-i "$RSYNC_SSH_KEY"} "$RSYNC_USER@$RSYNC_HOST" \
        "sha256sum '$RSYNC_PATH/$(date +%Y/%m)/$(basename "$local_file")'" | awk '{print $1}')
    
    if [ "$local_checksum" = "$remote_checksum" ]; then
        log "Verification passed: checksums match"
        return 0
    else
        log_error "Verification failed: checksum mismatch"
        return 1
    fi
}

# List remote backups
list_remote() {
    case "$REMOTE_TYPE" in
        s3)
            log "Listing S3 backups..."
            aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/" --recursive --human-readable | tail -20
            ;;
        rsync)
            log "Listing rsync backups..."
            ssh -p "$RSYNC_PORT" ${RSYNC_SSH_KEY:+-i "$RSYNC_SSH_KEY"} "$RSYNC_USER@$RSYNC_HOST" \
                "find '$RSYNC_PATH' -type f -name '*.tar.gz*' -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort -r | head -20"
            ;;
        *)
            log_error "No remote type configured"
            ;;
    esac
}

# Download from remote
download_remote() {
    local remote_file="$1"
    local local_path="${2:-.}"
    
    case "$REMOTE_TYPE" in
        s3)
            log "Downloading from S3: $remote_file"
            aws s3 cp "s3://$S3_BUCKET/$remote_file" "$local_path/"
            ;;
        rsync)
            log "Downloading via rsync: $remote_file"
            eval "rsync -avz --progress '$RSYNC_USER@$RSYNC_HOST:$remote_file' '$local_path/'"
            ;;
        *)
            log_error "No remote type configured"
            return 1
            ;;
    esac
}

# Sync local backups to remote
sync_backups() {
    local backup_dir="${1:-$GRIM_ROOT/backups}"
    local age_days="${2:-7}"  # Only sync backups newer than X days
    
    log "Syncing backups newer than $age_days days..."
    
    find "$backup_dir" -name "*.tar.gz*" -type f -mtime -"$age_days" | while read -r file; do
        log "Processing: $file"
        
        case "$REMOTE_TYPE" in
            s3)
                upload_to_s3 "$file"
                ;;
            rsync)
                upload_rsync "$file"
                ;;
            *)
                log_error "No remote type configured"
                return 1
                ;;
        esac
        
        # Delete local file if configured and upload successful
        if [ $? -eq 0 ] && [ "$DELETE_LOCAL_AFTER_UPLOAD" = "true" ]; then
            log "Deleting local file: $file"
            rm -f "$file" "${file}.sha256" "${file}.enc.sha256"
        fi
    done
    
    log "Sync complete"
}

# Test remote connection
test_connection() {
    case "$REMOTE_TYPE" in
        s3)
            log "Testing S3 connection..."
            if aws s3 ls "s3://$S3_BUCKET/" &>/dev/null; then
                log "S3 connection successful"
                return 0
            else
                log_error "S3 connection failed"
                return 1
            fi
            ;;
        rsync)
            log "Testing rsync connection..."
            if ssh -p "$RSYNC_PORT" ${RSYNC_SSH_KEY:+-i "$RSYNC_SSH_KEY"} "$RSYNC_USER@$RSYNC_HOST" "echo 'Connection test'" &>/dev/null; then
                log "Rsync connection successful"
                return 0
            else
                log_error "Rsync connection failed"
                return 1
            fi
            ;;
        *)
            log_error "No remote type configured"
            return 1
            ;;
    esac
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Remote Backup Module${NC}"
    echo "Manages remote storage operations for backup files using S3 or rsync."
    echo "Provides secure, verified upload/download with automatic sync capabilities."
    echo ""
    echo "Usage: grim remote <command> [options]"
    echo ""
    echo "Commands:"
    echo "  upload <file>              - Upload single file to remote storage"
    echo "  sync [dir] [days]          - Sync recent backups to remote storage"
    echo "  list                       - List files in remote storage"
    echo "  download <file> [local_dir]- Download file from remote storage"
    echo "  test                       - Test remote connection and credentials"
    echo "  config                     - Display current remote configuration"
    echo ""
    echo "Examples:"
    echo "  grim remote upload backup.tar.gz          # Upload single file"
    echo "  grim remote sync /backups 7               # Sync last 7 days"
    echo "  grim remote test                          # Test connection"
    echo ""
    echo "Supported Remote Types:"
    echo "  S3     - Amazon S3 or compatible storage"
    echo "  rsync  - SSH-based file transfer"
    echo ""
    echo "Configuration: $CONFIG_FILE"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    load_config || return 1
    
    case "$command" in
        upload)
            local file="$1"
            if [ -z "$file" ] || [ ! -f "$file" ]; then
                log_error "Usage: grim remote upload <file>"
                exit 1
            fi
            
            case "$REMOTE_TYPE" in
                s3) upload_to_s3 "$file" ;;
                rsync) upload_rsync "$file" ;;
                *) log_error "Remote type not configured" ;;
            esac
            ;;
        
        sync)
            sync_backups "$@"
            ;;
        
        list)
            list_remote
            ;;
        
        download)
            download_remote "$@"
            ;;
        
        test)
            test_connection
            ;;
        
        config)
            echo "Remote configuration: $CONFIG_FILE"
            cat "$CONFIG_FILE"
            ;;
        
        help|-h|--help)
            show_help
            ;;
        
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"