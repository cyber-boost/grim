#!/bin/bash
# Grimm Transfer Module: Multi-protocol file transfer with resume capability

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
TRANSFER_BINARY="$GRIM_ROOT/go_grim/build/grim-transfer"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/transfer.log"
CONFIG_FILE="$GRIM_ROOT/config/transfer.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default configuration
DEFAULT_WORKERS=4
DEFAULT_TIMEOUT="30m"
DEFAULT_PROTOCOL="auto"
DEFAULT_RESUME=true
DEFAULT_VERIFY=true
DEFAULT_PROGRESS=true

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Load transfer configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Create default config
        cat > "$CONFIG_FILE" <<'EOF'
# Grimm Transfer Configuration

# Transfer Settings
DEFAULT_WORKERS=4
DEFAULT_TIMEOUT="30m"
DEFAULT_PROTOCOL="auto"
DEFAULT_RESUME=true
DEFAULT_VERIFY=true
DEFAULT_PROGRESS=true

# Security Settings
ALLOW_INSECURE_SSL=false
MAX_FILE_SIZE="10GB"
ALLOWED_PROTOCOLS="http,https,ftp,sftp,local"

# Performance Settings
BUFFER_SIZE="64KB"
CONCURRENT_TRANSFERS=4
RETRY_ATTEMPTS=3
RETRY_DELAY="5s"

# Authentication
# Set these via environment variables for security:
# TRANSFER_USERNAME
# TRANSFER_PASSWORD
# TRANSFER_SSH_KEY

# Logging
TRANSFER_LOG_LEVEL="info"
TRANSFER_LOG_RETENTION_DAYS=30
EOF
        log "Created default transfer config at $CONFIG_FILE"
    fi
}

# Check if transfer binary exists and build if needed
check_transfer_binary() {
    if [ ! -f "$TRANSFER_BINARY" ]; then
        echo -e "${YELLOW}Transfer binary not found. Building...${NC}"
        if [ -f "$GRIM_ROOT/go_grim/Makefile" ]; then
            cd "$GRIM_ROOT/go_grim"
            if make build-transfer; then
                echo -e "${GREEN}✅ Transfer binary built successfully${NC}"
                cd - >/dev/null
            else
                echo -e "${RED}❌ Failed to build transfer binary${NC}"
                echo "Please ensure Go is installed and run: cd $GRIM_ROOT/go_grim && make build-transfer"
                return 1
            fi
        else
            echo -e "${RED}❌ Makefile not found. Cannot build transfer binary.${NC}"
            return 1
        fi
    fi
    return 0
}

# Validate file paths and permissions
validate_paths() {
    local source="$1"
    local dest="$2"
    local operation="$3"
    
    case "$operation" in
        "upload")
            if [[ ! -e "$source" ]]; then
                log_error "Source file/directory does not exist: $source"
                return 1
            fi
            
            if [[ ! -r "$source" ]]; then
                log_error "Source file/directory is not readable: $source"
                return 1
            fi
            
            # Check if destination directory exists for local transfers
            if [[ "$dest" != http* && "$dest" != ftp* && "$dest" != sftp* ]]; then
                local dest_dir=$(dirname "$dest")
                if [[ ! -d "$dest_dir" ]]; then
                    echo -e "${YELLOW}Creating destination directory: $dest_dir${NC}"
                    mkdir -p "$dest_dir" || {
                        log_error "Failed to create destination directory: $dest_dir"
                        return 1
                    }
                fi
            fi
            ;;
        "download")
            # For downloads, we mainly validate the destination
            if [[ "$dest" != "-" ]]; then  # Allow stdout output
                local dest_dir=$(dirname "$dest")
                if [[ ! -d "$dest_dir" ]]; then
                    echo -e "${YELLOW}Creating destination directory: $dest_dir${NC}"
                    mkdir -p "$dest_dir" || {
                        log_error "Failed to create destination directory: $dest_dir"
                        return 1
                    }
                fi
                
                if [[ -e "$dest" && ! -w "$dest" ]]; then
                    log_error "Destination file is not writable: $dest"
                    return 1
                fi
            fi
            ;;
        "verify")
            # Both source and dest should exist for verification
            if [[ ! -e "$source" ]]; then
                log_error "Source file/directory does not exist: $source"
                return 1
            fi
            
            if [[ ! -e "$dest" ]]; then
                log_error "Destination file/directory does not exist: $dest"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Format arguments for the Go binary
format_transfer_args() {
    local operation="$1"
    local source="$2"
    local dest="$3"
    shift 3
    
    local args=()
    
    # Add source and destination
    args+=("-source" "$source")
    args+=("-dest" "$dest")
    
    # Parse additional options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --workers|-w)
                args+=("-workers" "$2")
                shift 2
                ;;
            --timeout|-t)
                args+=("-timeout" "$2")
                shift 2
                ;;
            --protocol|-p)
                args+=("-protocol" "$2")
                shift 2
                ;;
            --username|-u)
                args+=("-username" "$2")
                shift 2
                ;;
            --password)
                args+=("-password" "$2")
                shift 2
                ;;
            --output|-o)
                args+=("-output" "$2")
                shift 2
                ;;
            --resume|-r)
                args+=("-resume")
                shift
                ;;
            --no-resume)
                args+=("-resume=false")
                shift
                ;;
            --verify|-v)
                args+=("-verify")
                shift
                ;;
            --no-verify)
                args+=("-verify=false")
                shift
                ;;
            --progress)
                args+=("-progress")
                shift
                ;;
            --no-progress)
                args+=("-progress=false")
                shift
                ;;
            --verbose)
                args+=("-verbose")
                shift
                ;;
            --help|-h)
                show_help
                return 2
                ;;
            *)
                echo -e "${YELLOW}Warning: Unknown option $1${NC}"
                shift
                ;;
        esac
    done
    
    # Set defaults based on operation
    case "$operation" in
        "resume")
            args+=("-resume")
            ;;
        "verify")
            args+=("-verify")
            ;;
    esac
    
    # Add default values if not specified
    if [[ ! " ${args[*]} " =~ " -workers " ]]; then
        args+=("-workers" "$DEFAULT_WORKERS")
    fi
    
    if [[ ! " ${args[*]} " =~ " -timeout " ]]; then
        args+=("-timeout" "$DEFAULT_TIMEOUT")
    fi
    
    if [[ ! " ${args[*]} " =~ " -protocol " ]]; then
        args+=("-protocol" "$DEFAULT_PROTOCOL")
    fi
    
    if [[ ! " ${args[*]} " =~ " -progress" ]]; then
        args+=("-progress")
    fi
    
    # Add credentials from environment if available
    if [[ -n "${TRANSFER_USERNAME:-}" && ! " ${args[*]} " =~ " -username " ]]; then
        args+=("-username" "$TRANSFER_USERNAME")
    fi
    
    if [[ -n "${TRANSFER_PASSWORD:-}" && ! " ${args[*]} " =~ " -password " ]]; then
        args+=("-password" "$TRANSFER_PASSWORD")
    fi
    
    echo "${args[@]}"
}

# Upload files
transfer_upload() {
    local source="$1"
    local dest="$2"
    shift 2
    
    echo -e "${CYAN}📤 Uploading: $source → $dest${NC}"
    
    if ! validate_paths "$source" "$dest" "upload"; then
        return 1
    fi
    
    local args=($(format_transfer_args "upload" "$source" "$dest" "$@"))
    if [[ $? -eq 2 ]]; then return 0; fi  # Help was shown
    
    log "Starting upload: $source → $dest"
    
    if "$TRANSFER_BINARY" "${args[@]}"; then
        echo -e "${GREEN}✅ Upload completed successfully${NC}"
        log "Upload completed: $source → $dest"
        return 0
    else
        echo -e "${RED}❌ Upload failed${NC}"
        log_error "Upload failed: $source → $dest"
        return 1
    fi
}

# Download files
transfer_download() {
    local source="$1"
    local dest="$2"
    shift 2
    
    echo -e "${CYAN}📥 Downloading: $source → $dest${NC}"
    
    if ! validate_paths "$source" "$dest" "download"; then
        return 1
    fi
    
    local args=($(format_transfer_args "download" "$source" "$dest" "$@"))
    if [[ $? -eq 2 ]]; then return 0; fi  # Help was shown
    
    log "Starting download: $source → $dest"
    
    if "$TRANSFER_BINARY" "${args[@]}"; then
        echo -e "${GREEN}✅ Download completed successfully${NC}"
        log "Download completed: $source → $dest"
        return 0
    else
        echo -e "${RED}❌ Download failed${NC}"
        log_error "Download failed: $source → $dest"
        return 1
    fi
}

# Resume interrupted transfer
transfer_resume() {
    local source="$1"
    local dest="$2"
    shift 2
    
    echo -e "${CYAN}⏯️  Resuming transfer: $source → $dest${NC}"
    
    local args=($(format_transfer_args "resume" "$source" "$dest" "$@"))
    if [[ $? -eq 2 ]]; then return 0; fi  # Help was shown
    
    log "Resuming transfer: $source → $dest"
    
    if "$TRANSFER_BINARY" "${args[@]}"; then
        echo -e "${GREEN}✅ Transfer resumed and completed successfully${NC}"
        log "Transfer resumed and completed: $source → $dest"
        return 0
    else
        echo -e "${RED}❌ Transfer resume failed${NC}"
        log_error "Transfer resume failed: $source → $dest"
        return 1
    fi
}

# Verify transfer integrity
transfer_verify() {
    local source="$1"
    local dest="$2"
    shift 2
    
    echo -e "${CYAN}🔍 Verifying transfer: $source ↔ $dest${NC}"
    
    if ! validate_paths "$source" "$dest" "verify"; then
        return 1
    fi
    
    local args=($(format_transfer_args "verify" "$source" "$dest" "$@"))
    if [[ $? -eq 2 ]]; then return 0; fi  # Help was shown
    
    log "Verifying transfer: $source ↔ $dest"
    
    if "$TRANSFER_BINARY" "${args[@]}"; then
        echo -e "${GREEN}✅ Transfer verification successful${NC}"
        log "Transfer verification successful: $source ↔ $dest"
        return 0
    else
        echo -e "${RED}❌ Transfer verification failed${NC}"
        log_error "Transfer verification failed: $source ↔ $dest"
        return 1
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Transfer Module${NC}"
    echo "Usage: grim transfer <command> <source> <dest> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  upload <source> <dest>     - Upload files to destination"
    echo "  download <source> <dest>   - Download files from source"
    echo "  resume <source> <dest>     - Resume interrupted transfer"
    echo "  verify <source> <dest>     - Verify transfer integrity"
    echo "  help                       - Show this help"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --workers, -w <N>          - Number of concurrent workers (default: $DEFAULT_WORKERS)"
    echo "  --timeout, -t <duration>   - Transfer timeout (default: $DEFAULT_TIMEOUT)"
    echo "  --protocol, -p <protocol>  - Transfer protocol (default: $DEFAULT_PROTOCOL)"
    echo "  --username, -u <user>      - Username for authentication"
    echo "  --password <pass>          - Password for authentication"
    echo "  --output, -o <file>        - Output results to file (JSON format)"
    echo "  --resume, -r               - Enable resume capability"
    echo "  --no-resume                - Disable resume capability"
    echo "  --verify, -v               - Enable integrity verification"
    echo "  --no-verify                - Disable integrity verification"
    echo "  --progress                 - Show progress information (default: enabled)"
    echo "  --no-progress              - Hide progress information"
    echo "  --verbose                  - Enable verbose output"
    echo "  --help, -h                 - Show this help"
    echo ""
    echo -e "${YELLOW}Supported Protocols:${NC}"
    echo "  auto                       - Auto-detect protocol from URL"
    echo "  http                       - HTTP transfer"
    echo "  https                      - HTTPS transfer (secure)"
    echo "  ftp                        - FTP transfer"
    echo "  sftp                       - SFTP transfer (secure)"
    echo "  local                      - Local file system"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # Upload local file to remote server"
    echo "  grim transfer upload /local/file.txt https://server.com/upload/"
    echo ""
    echo "  # Download file with specific settings"
    echo "  grim transfer download https://server.com/file.zip /local/downloads/ --workers 8 --verify"
    echo ""
    echo "  # Resume interrupted download"
    echo "  grim transfer resume https://server.com/large-file.iso /local/downloads/"
    echo ""
    echo "  # Verify transfer integrity"
    echo "  grim transfer verify /local/original.txt /backup/copy.txt"
    echo ""
    echo "  # Transfer with authentication"
    echo "  grim transfer upload /data/ sftp://user@server.com/backup/ --username myuser --password mypass"
    echo ""
    echo "  # Local file copy with verification"
    echo "  grim transfer upload /source/data/ /backup/data/ --verify --progress"
    echo ""
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo "  TRANSFER_USERNAME          - Default username for authentication"
    echo "  TRANSFER_PASSWORD          - Default password for authentication"
    echo "  TRANSFER_SSH_KEY           - SSH key file for SFTP transfers"
    echo ""
    echo "Configuration: $CONFIG_FILE"
}

# Main function
main() {
    # Load configuration
    load_config
    
    # Create necessary directories
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Check if transfer binary exists
    if ! check_transfer_binary; then
        return 1
    fi
    
    local command="${1:-help}"
    
    case "$command" in
        "upload"|"send"|"put")
            if [[ $# -lt 3 ]]; then
                echo -e "${RED}Error: Source and destination are required${NC}"
                echo "Usage: grim transfer upload <source> <dest> [options]"
                return 1
            fi
            transfer_upload "$2" "$3" "${@:4}"
            ;;
        "download"|"get"|"fetch")
            if [[ $# -lt 3 ]]; then
                echo -e "${RED}Error: Source and destination are required${NC}"
                echo "Usage: grim transfer download <source> <dest> [options]"
                return 1
            fi
            transfer_download "$2" "$3" "${@:4}"
            ;;
        "resume"|"continue")
            if [[ $# -lt 3 ]]; then
                echo -e "${RED}Error: Source and destination are required${NC}"
                echo "Usage: grim transfer resume <source> <dest> [options]"
                return 1
            fi
            transfer_resume "$2" "$3" "${@:4}"
            ;;
        "verify"|"check")
            if [[ $# -lt 3 ]]; then
                echo -e "${RED}Error: Source and destination are required${NC}"
                echo "Usage: grim transfer verify <source> <dest> [options]"
                return 1
            fi
            transfer_verify "$2" "$3" "${@:4}"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}"
            echo "Use 'grim transfer help' for available commands"
            return 1
            ;;
    esac
}

# Run main function
main "$@" 