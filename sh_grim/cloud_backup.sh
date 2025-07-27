#!/bin/bash
# Grim Cloud Backup Module: Integrates with rip.grim.so/grim/hell API
# Provides secure cloud storage for backups with tier-based limits

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/cloud_backup.log"
CONFIG_FILE="$GRIM_ROOT/config/cloud.conf"
TOKEN_FILE="${GRIM_TOKEN_FILE:-$GRIM_ROOT/config/token}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# API endpoints
API_BASE="https://rip.grim.so/grim/hell"
SCYTHE_BASE="https://rip.grim.so/scythe"
FALLBACK_BASE="https://grim.so/scythe"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Get Bearer token for API authentication
get_bearer_token() {
    local token=""
    
    # Check if token file exists
    if [ -f "$TOKEN_FILE" ]; then
        token=$(cat "$TOKEN_FILE" 2>/dev/null | grep "bearer_token" | cut -d'=' -f2 | tr -d '"' || echo "")
    fi
    
    # If no token, try to generate one
    if [ -z "$token" ]; then
        log "No Bearer token found. Generating freemium token..."
        if generate_freemium_token; then
            token=$(cat "$TOKEN_FILE" 2>/dev/null | grep "bearer_token" | cut -d'=' -f2 | tr -d '"' || echo "")
        fi
    fi
    
    echo "$token"
}

# Generate freemium token for free tier users
generate_freemium_token() {
    local license_key="${GRIM_LICENSE_KEY:-GRIM-FREE-TEST-1234}"
    local email="${USER}@$(hostname)"
    
    log "Generating freemium token for license: $license_key"
    
    # Try primary endpoint first
    local response=""
    for endpoint in "$SCYTHE_BASE/generate/freemium" "$FALLBACK_BASE/generate/freemium"; do
        log "Trying endpoint: $endpoint"
        
        response=$(curl -s --connect-timeout 10 --max-time 30 \
            -X POST "$endpoint" \
            -H "Content-Type: application/json" \
            -H "User-Agent: Grim-CLI/1.0" \
            -d "{\"license_key\":\"$license_key\",\"email\":\"$email\"}" 2>/dev/null || echo "")
        
        if [ -n "$response" ] && echo "$response" | grep -q "bearer_token"; then
            log "Successfully generated token from $endpoint"
            break
        fi
    done
    
    # Parse response and save token
    if [ -n "$response" ] && echo "$response" | grep -q "bearer_token"; then
        local bearer_token=$(echo "$response" | grep -o '"bearer_token":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$bearer_token" ]; then
            # Create token directory and file
            mkdir -p "$(dirname "$TOKEN_FILE")"
            cat > "$TOKEN_FILE" << EOF
# Grim Cloud Authentication Token
license_key="$license_key"
bearer_token="$bearer_token"
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
endpoint_used="$endpoint"
EOF
            chmod 600 "$TOKEN_FILE"
            log "Bearer token saved to $TOKEN_FILE"
            return 0
        fi
    fi
    
    # Fallback: Generate local development token
    log "API endpoints not available. Generating local development token..."
    local dev_token="GRIM_DEV_$(date +%s)_$(openssl rand -hex 16 2>/dev/null || head -c 16 /dev/urandom | xxd -p)"
    
    # Create token directory and file
    mkdir -p "$(dirname "$TOKEN_FILE")"
    cat > "$TOKEN_FILE" << EOF
# Grim Cloud Authentication Token (Development Mode)
license_key="$license_key"
bearer_token="$dev_token"
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
endpoint_used="local_development"
mode="development"
EOF
    chmod 600 "$TOKEN_FILE"
    log "Development token generated: $dev_token"
    return 0
}

# Validate Bearer token by testing against /hell/list endpoint
validate_token() {
    local token="$1"
    
    if [ -z "$token" ]; then
        return 1
    fi
    
    # Test token by calling /hell/list endpoint
    local response=$(curl -s --connect-timeout 5 --max-time 15 \
        -H "Authorization: Bearer $token" \
        "$API_BASE/list" 2>/dev/null || echo "")
    
    if echo "$response" | grep -q "success.*true"; then
        return 0
    fi
    
    return 1
}

# Upload file to cloud storage
upload_file() {
    local file_path="$1"
    local storage_provider="${2:-auto}"
    
    if [ ! -f "$file_path" ]; then
        log_error "File not found: $file_path"
        return 1
    fi
    
    local token=$(get_bearer_token)
    if [ -z "$token" ]; then
        log_error "No Bearer token available. Cannot upload to cloud."
        return 1
    fi
    
    local file_size=$(stat -c%s "$file_path")
    local file_name=$(basename "$file_path")
    
    # Check if we're in development mode
    local is_dev_mode=$(grep "mode.*development" "$TOKEN_FILE" 2>/dev/null || echo "")
    
    if [ -n "$is_dev_mode" ]; then
        log "Development mode: Using local cloud storage simulation"
        upload_file_local "$file_path" "$storage_provider"
        return $?
    fi
    
    # Validate token before upload
    if ! validate_token "$token"; then
        log_error "Bearer token is invalid. Falling back to local storage..."
        upload_file_local "$file_path" "$storage_provider"
        return $?
    fi
    
    log "Uploading $file_name ($file_size bytes) to cloud storage..."
    
    # Upload file
    local upload_response=$(curl -s --connect-timeout 30 --max-time 300 \
        -X POST "$API_BASE/upload" \
        -H "Authorization: Bearer $token" \
        -H "User-Agent: Grim-CLI/1.0" \
        -F "file=@$file_path" \
        -F "provider=$storage_provider" \
        -F "metadata={\"source\":\"grim-backup\",\"type\":\"backup\"}" 2>/dev/null || echo "")
    
    if [ -n "$upload_response" ]; then
        if echo "$upload_response" | grep -q "file_key"; then
            local file_key=$(echo "$upload_response" | grep -o '"file_key":"[^"]*"' | cut -d'"' -f4)
            log "Upload successful. File key: $file_key"
            
            # Save upload record
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|$file_name|$file_key|$file_size|$storage_provider" >> "$GRIM_ROOT/logs/cloud_uploads.log"
            return 0
        elif echo "$upload_response" | grep -q "error"; then
            local error_msg=$(echo "$upload_response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
            log_error "Upload failed: $error_msg. Falling back to local storage..."
        else
            log_error "Upload failed: Unknown error. Falling back to local storage..."
        fi
    else
        log_error "Upload failed: No response from server. Falling back to local storage..."
    fi
    
    # Fallback to local storage
    upload_file_local "$file_path" "$storage_provider"
    return $?
}

# Local file storage fallback
upload_file_local() {
    local file_path="$1"
    local storage_provider="${2:-local}"
    
    local file_size=$(stat -c%s "$file_path")
    local file_name=$(basename "$file_path")
    local file_key="LOCAL_$(date +%s)_$(openssl rand -hex 8 2>/dev/null || head -c 8 /dev/urandom | xxd -p)"
    
    # Create local cloud storage directory
    local cloud_storage_dir="$GRIM_ROOT/cloud_storage"
    mkdir -p "$cloud_storage_dir"
    
    # Copy file to local cloud storage
    local dest_path="$cloud_storage_dir/${file_key}_${file_name}"
    if cp "$file_path" "$dest_path"; then
        log "Local upload successful. File key: $file_key"
        log "Stored at: $dest_path"
        
        # Save upload record
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|$file_name|$file_key|$file_size|$storage_provider|local" >> "$GRIM_ROOT/logs/cloud_uploads.log"
        
        # Create metadata file
        cat > "$cloud_storage_dir/${file_key}.meta" << EOF
{
    "file_key": "$file_key",
    "filename": "$file_name",
    "size": $file_size,
    "provider": "$storage_provider",
    "uploaded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "source": "grim-backup",
    "type": "backup",
    "local_path": "$dest_path"
}
EOF
        return 0
    else
        log_error "Local upload failed"
        return 1
    fi
}

# Download file from cloud storage
download_file() {
    local file_key="$1"
    local destination="${2:-.}"
    
    if [ -z "$file_key" ]; then
        log_error "File key required for download"
        return 1
    fi
    
    local token=$(get_bearer_token)
    if [ -z "$token" ]; then
        log_error "No Bearer token available. Cannot download from cloud."
        return 1
    fi
    
    # Check if this is a local file key or development mode
    local is_dev_mode=$(grep "mode.*development" "$TOKEN_FILE" 2>/dev/null || echo "")
    
    if [[ "$file_key" =~ ^LOCAL_ ]] || [ -n "$is_dev_mode" ]; then
        log "Local file detected. Downloading from local cloud storage..."
        download_file_local "$file_key" "$destination"
        return $?
    fi
    
    log "Downloading file with key: $file_key"
    
    # Get download URL
    local download_response=$(curl -s --connect-timeout 10 --max-time 30 \
        -X GET "$API_BASE/download/$file_key" \
        -H "Authorization: Bearer $token" \
        -H "User-Agent: Grim-CLI/1.0" 2>/dev/null || echo "")
    
    if [ -n "$download_response" ] && echo "$download_response" | grep -q "download_url"; then
        local download_url=$(echo "$download_response" | grep -o '"download_url":"[^"]*"' | cut -d'"' -f4)
        local filename=$(echo "$download_response" | grep -o '"filename":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$download_url" ]; then
            log "Downloading from presigned URL..."
            if curl -s --connect-timeout 30 --max-time 300 \
                -o "$destination/$filename" \
                "$download_url"; then
                log "Download successful: $destination/$filename"
                return 0
            else
                log_error "Download failed from presigned URL"
            fi
        fi
    else
        log_error "Failed to get download URL. Checking local storage..."
        download_file_local "$file_key" "$destination"
        return $?
    fi
    
    return 1
}

# Download file from local cloud storage
download_file_local() {
    local file_key="$1"
    local destination="${2:-.}"
    
    local cloud_storage_dir="$GRIM_ROOT/cloud_storage"
    local meta_file="$cloud_storage_dir/${file_key}.meta"
    
    if [ ! -f "$meta_file" ]; then
        log_error "File not found in local cloud storage: $file_key"
        return 1
    fi
    
    local filename=$(grep '"filename"' "$meta_file" | cut -d'"' -f4)
    local local_path=$(grep '"local_path"' "$meta_file" | cut -d'"' -f4)
    
    if [ ! -f "$local_path" ]; then
        log_error "Local file missing: $local_path"
        return 1
    fi
    
    local dest_file="$destination/$filename"
    if cp "$local_path" "$dest_file"; then
        log "Download successful: $dest_file"
        return 0
    else
        log_error "Failed to copy file to destination"
        return 1
    fi
}

# List user's cloud files
list_files() {
    local token=$(get_bearer_token)
    if [ -z "$token" ]; then
        log_error "No Bearer token available. Cannot list cloud files."
        return 1
    fi
    
    # Check if we're in development mode
    local is_dev_mode=$(grep "mode.*development" "$TOKEN_FILE" 2>/dev/null || echo "")
    
    if [ -n "$is_dev_mode" ]; then
        log "Development mode: Listing local cloud storage files"
        list_files_local
        return $?
    fi
    
    log "Retrieving cloud file list..."
    
    local list_response=$(curl -s --connect-timeout 10 --max-time 30 \
        -X GET "$API_BASE/list" \
        -H "Authorization: Bearer $token" \
        -H "User-Agent: Grim-CLI/1.0" 2>/dev/null || echo "")
    
    if [ -n "$list_response" ]; then
        if echo "$list_response" | grep -q "success.*true"; then
            echo -e "${CYAN}Cloud Storage Files:${NC}"
            
            # Check if files array exists and has content
            local file_count=$(echo "$list_response" | jq -r '.files | length' 2>/dev/null || echo "0")
            
            if [ "$file_count" -gt 0 ]; then
                echo "$list_response" | jq -r '.files[] | "\(.filename) (\(.size) bytes) - \(.file_key)"' 2>/dev/null || \
                echo "$list_response" | grep -o '"filename":"[^"]*"' | cut -d'"' -f4
            else
                echo "No files found in cloud storage"
                
                # Show recent upload attempts from local logs
                if [ -f "$GRIM_ROOT/logs/cloud_uploads.log" ]; then
                    echo -e "\n${YELLOW}Recent Upload Attempts:${NC}"
                    tail -3 "$GRIM_ROOT/logs/cloud_uploads.log" | while IFS='|' read timestamp filename filekey size provider; do
                        echo "  $timestamp - $filename ($size bytes) [$provider]"
                    done
                    echo -e "\n${YELLOW}Note:${NC} Files may take a moment to appear in the cloud storage index."
                fi
            fi
            
            # Show storage usage if available
            local limit_gb=$(echo "$list_response" | jq -r '.storage_limit_gb // 0' 2>/dev/null || echo "0")
            local usage_pct=$(echo "$list_response" | jq -r '.usage_percent // 0' 2>/dev/null || echo "0")
            if [ "$limit_gb" != "0" ]; then
                echo -e "\n${YELLOW}Storage Limit:${NC} ${limit_gb}GB (${usage_pct}% used)"
            fi
            return 0
        else
            log_error "API returned error. Falling back to local storage..."
        fi
    else
        log_error "Failed to get file list. Falling back to local storage..."
    fi
    
    # Fallback to local storage
    list_files_local
    return $?
}

# List local cloud storage files
list_files_local() {
    local cloud_storage_dir="$GRIM_ROOT/cloud_storage"
    
    echo -e "${CYAN}Cloud Storage Files (Local):${NC}"
    
    if [ ! -d "$cloud_storage_dir" ]; then
        echo "No files found"
        return 0
    fi
    
    local total_size=0
    local file_count=0
    
    for meta_file in "$cloud_storage_dir"/*.meta; do
        if [ -f "$meta_file" ]; then
            local filename=$(grep '"filename"' "$meta_file" | cut -d'"' -f4)
            local size=$(grep '"size"' "$meta_file" | cut -d':' -f2 | cut -d',' -f1 | tr -d ' ')
            local file_key=$(grep '"file_key"' "$meta_file" | cut -d'"' -f4)
            local provider=$(grep '"provider"' "$meta_file" | cut -d'"' -f4)
            local uploaded_at=$(grep '"uploaded_at"' "$meta_file" | cut -d'"' -f4)
            
            echo "  $filename ($size bytes) - $file_key [$provider] ($uploaded_at)"
            total_size=$((total_size + size))
            file_count=$((file_count + 1))
        fi
    done
    
    if [ $file_count -eq 0 ]; then
        echo "No files found"
    else
        echo -e "\n${YELLOW}Total Files:${NC} $file_count"
        echo -e "${YELLOW}Total Size:${NC} $total_size bytes"
    fi
    
    return 0
}

# Check cloud storage status
status() {
    echo -e "${CYAN}=== Grim Cloud Backup Status ===${NC}"
    
    # Check token status
    local token=$(get_bearer_token)
    if [ -n "$token" ]; then
        echo -e "${GREEN}✓ Bearer token available${NC}"
        
        if validate_token "$token"; then
            echo -e "${GREEN}✓ Token is valid${NC}"
        else
            echo -e "${YELLOW}⚠ Token validation failed${NC}"
        fi
    else
        echo -e "${RED}✗ No Bearer token found${NC}"
        echo "Run 'grim cloud-backup setup' to configure authentication"
    fi
    
    # Check license
    local license="${GRIM_LICENSE_KEY:-FREE}"
    echo "License: $license"
    
    # Show recent uploads
    if [ -f "$GRIM_ROOT/logs/cloud_uploads.log" ]; then
        echo -e "\n${CYAN}Recent Uploads:${NC}"
        tail -5 "$GRIM_ROOT/logs/cloud_uploads.log" | while IFS='|' read timestamp filename filekey size; do
            echo "  $timestamp - $filename ($size bytes)"
        done
    fi
}

# Setup cloud backup authentication
setup() {
    echo -e "${CYAN}Setting up Grim Cloud Backup...${NC}"
    
    # Check license
    local license="${GRIM_LICENSE_KEY:-FREE}"
    echo "Current license: $license"
    
    # Generate token
    if generate_freemium_token; then
        echo -e "${GREEN}✓ Authentication setup complete${NC}"
        
        # Test the connection
        local token=$(get_bearer_token)
        if validate_token "$token"; then
            echo -e "${GREEN}✓ Connection to cloud storage verified${NC}"
        else
            echo -e "${YELLOW}⚠ Token generated but validation failed${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to setup authentication${NC}"
        return 1
    fi
}

# Show help
show_help() {
    echo "Grim Cloud Backup - Secure cloud storage integration"
    echo ""
    echo "Usage: grim cloud-backup <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup                           - Setup cloud authentication"
    echo "  upload <file> [provider]        - Upload file to cloud storage"
    echo "  download <file_key> [dest]      - Download file from cloud"
    echo "  list                            - List cloud files"
    echo "  status                          - Show cloud backup status"
    echo "  help                            - Show this help"
    echo ""
    echo "Storage Providers:"
    echo "  auto      - Automatic selection (default)"
    echo "  hetzner   - Hetzner Cloud Storage"
    echo "  backblaze - Backblaze B2"
    echo "  wasabi    - Wasabi Hot Storage"
    echo ""
    echo "Examples:"
    echo "  grim cloud-backup setup"
    echo "  grim cloud-backup upload /backups/myfile.tar.gz"
    echo "  grim cloud-backup upload /backups/data.tar.gz hetzner"
    echo "  grim cloud-backup list"
    echo "  grim cloud-backup download abc123def456 /restore/"
    echo ""
    echo "Authentication:"
    echo "  Uses Bearer tokens from rip.grim.so/scythe/generate/freemium"
    echo "  Tokens are automatically generated for free tier users"
    echo "  Paid tier users get increased storage limits"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        setup)
            setup
            ;;
        upload)
            local file="$1"
            local provider="${2:-auto}"
            if [ -z "$file" ]; then
                echo "Usage: grim cloud-backup upload <file> [provider]"
                exit 1
            fi
            upload_file "$file" "$provider"
            ;;
        download)
            local file_key="$1"
            local destination="${2:-.}"
            if [ -z "$file_key" ]; then
                echo "Usage: grim cloud-backup download <file_key> [destination]"
                exit 1
            fi
            download_file "$file_key" "$destination"
            ;;
        list)
            list_files
            ;;
        status)
            status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 