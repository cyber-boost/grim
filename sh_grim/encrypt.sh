#!/bin/bash
# Grimm Encryption Module: Advanced encryption/decryption with multiple algorithms

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/encrypt.log"
KEY_FILE="$GRIM_ROOT/config/.grimm_key"
CONFIG_DIR="$GRIM_ROOT/config"
KEYS_DIR="$CONFIG_DIR/keys"

# Default encryption settings
DEFAULT_ALGORITHM="aes-256-cbc"
DEFAULT_KEY_SIZE="32"
DEFAULT_ITERATIONS="100000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a "$LOG_FILE"
}

# Create necessary directories
init_directories() {
    mkdir -p "$CONFIG_DIR" "$KEYS_DIR" "$(dirname "$LOG_FILE")"
    chmod 700 "$KEYS_DIR"
}

# Generate encryption key with options
init_key() {
    local key_name="${1:-default}"
    local algorithm="${2:-$DEFAULT_ALGORITHM}"
    local key_size="${3:-$DEFAULT_KEY_SIZE}"
    
    init_directories
    
    local key_file="$KEYS_DIR/${key_name}.key"
    
    if [[ -f "$key_file" ]]; then
        echo -e "${YELLOW}Key already exists: $key_file${NC}"
        read -p "Overwrite existing key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Key generation cancelled"
            return 0
        fi
    fi
    
    log "Generating new encryption key: $key_name"
    echo -e "${CYAN}Algorithm: $algorithm${NC}"
    echo -e "${CYAN}Key size: $key_size bytes${NC}"
    
    # Generate strong random key
    if openssl rand -base64 "$key_size" > "$key_file"; then
        chmod 600 "$key_file"
        log_success "Encryption key generated: $key_file"
        
        # Create symlink for default key
        if [[ "$key_name" == "default" ]]; then
            ln -sf "$key_file" "$KEY_FILE" 2>/dev/null || cp "$key_file" "$KEY_FILE"
        fi
        
        echo -e "${GREEN}✓ Key generated successfully${NC}"
        echo -e "${YELLOW}⚠️  IMPORTANT: Back up your encryption key!${NC}"
        echo -e "Location: $key_file"
        
        # Show key fingerprint
        local fingerprint=$(sha256sum "$key_file" | cut -d' ' -f1 | head -c 16)
        echo -e "Fingerprint: $fingerprint"
        
        return 0
    else
        log_error "Failed to generate encryption key"
        return 1
    fi
}

# List available keys
list_keys() {
    init_directories
    
    echo -e "${CYAN}Available Encryption Keys:${NC}"
    
    if [[ ! -d "$KEYS_DIR" ]] || [[ -z "$(ls -A "$KEYS_DIR" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No encryption keys found${NC}"
        echo "Generate a key with: grim encrypt key-gen"
        return 1
    fi
    
    local count=0
    for key_file in "$KEYS_DIR"/*.key; do
        if [[ -f "$key_file" ]]; then
            local key_name=$(basename "$key_file" .key)
            local created=$(stat -c %y "$key_file" 2>/dev/null | cut -d' ' -f1)
            local size=$(stat -c %s "$key_file" 2>/dev/null)
            local fingerprint=$(sha256sum "$key_file" | cut -d' ' -f1 | head -c 16)
            
            echo -e "  ${GREEN}$key_name${NC}"
            echo -e "    Created: $created"
            echo -e "    Size: $size bytes"
            echo -e "    Fingerprint: $fingerprint"
            
            # Check if it's the default key
            if [[ -L "$KEY_FILE" ]] && [[ "$(readlink "$KEY_FILE")" == "$key_file" ]]; then
                echo -e "    ${YELLOW}(Default)${NC}"
            elif [[ "$key_file" == "$KEY_FILE" ]]; then
                echo -e "    ${YELLOW}(Default)${NC}"
            fi
            
            echo
            ((count++))
        fi
    done
    
    echo -e "Total keys: $count"
}

# Enhanced encryption with algorithm options
encrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local key_name="${3:-default}"
    local algorithm="${4:-$DEFAULT_ALGORITHM}"
    local compression="${5:-false}"
    
    # Validate input
    if [[ -z "$input_file" ]]; then
        log_error "No input file specified"
        echo "Usage: grim encrypt encrypt <input_file> [output_file] [key_name] [algorithm] [compression]"
        return 1
    fi
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    # Set default output file
    if [[ -z "$output_file" ]]; then
        output_file="${input_file}.enc"
    fi
    
    # Determine key file
    local key_file
    if [[ "$key_name" == "default" ]]; then
        key_file="$KEY_FILE"
    else
        key_file="$KEYS_DIR/${key_name}.key"
    fi
    
    # Initialize key if it doesn't exist
    if [[ ! -f "$key_file" ]]; then
        echo -e "${YELLOW}Key not found, generating new key: $key_name${NC}"
        init_key "$key_name" "$algorithm"
    fi
    
    log "Encrypting: $input_file -> $output_file"
    echo -e "${CYAN}Algorithm: $algorithm${NC}"
    echo -e "${CYAN}Key: $key_name${NC}"
    echo -e "${CYAN}Compression: $compression${NC}"
    
    # Create temporary file for processing
    local temp_file="$input_file"
    
    # Apply compression if requested
    if [[ "$compression" == "true" ]]; then
        echo -e "${BLUE}Compressing file...${NC}"
        temp_file="${input_file}.tmp.gz"
        if ! gzip -c "$input_file" > "$temp_file"; then
            log_error "Compression failed"
            return 1
        fi
    fi
    
    # Perform encryption with enhanced options
    local encrypt_cmd="openssl enc -$algorithm -salt -pbkdf2 -iter $DEFAULT_ITERATIONS"
    
    if $encrypt_cmd -in "$temp_file" -out "$output_file" -pass file:"$key_file"; then
        log_success "Encryption successful: $output_file"
        
        # Create metadata file
        create_metadata "$output_file" "$algorithm" "$key_name" "$compression"
        
        # Create checksum
        sha256sum "$output_file" > "${output_file}.sha256"
        
        # Clean up temporary file
        if [[ "$compression" == "true" ]] && [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
        fi
        
        # Display file information
        local original_size=$(stat -c %s "$input_file")
        local encrypted_size=$(stat -c %s "$output_file")
        local ratio=$(( (original_size - encrypted_size) * 100 / original_size ))
        
        echo -e "${GREEN}✓ Encryption completed${NC}"
        echo -e "Original size: $(numfmt --to=iec "$original_size")"
        echo -e "Encrypted size: $(numfmt --to=iec "$encrypted_size")"
        if [[ "$compression" == "true" ]]; then
            echo -e "Compression ratio: ${ratio}%"
        fi
        
        return 0
    else
        log_error "Encryption failed for: $input_file"
        
        # Clean up on failure
        if [[ "$compression" == "true" ]] && [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
        fi
        [[ -f "$output_file" ]] && rm -f "$output_file"
        
        return 1
    fi
}

# Enhanced decryption
decrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local key_name="${3:-}"
    
    # Validate input
    if [[ -z "$input_file" ]]; then
        log_error "No input file specified"
        echo "Usage: grim encrypt decrypt <input_file> [output_file] [key_name]"
        return 1
    fi
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    # Read metadata if available
    local metadata_file="${input_file}.meta"
    local algorithm="$DEFAULT_ALGORITHM"
    local compression="false"
    local meta_key_name="default"
    
    if [[ -f "$metadata_file" ]]; then
        source "$metadata_file"
        algorithm="$ALGORITHM"
        compression="$COMPRESSION"
        meta_key_name="$KEY_NAME"
        echo -e "${BLUE}Using metadata from: $metadata_file${NC}"
    fi
    
    # Determine key name and file
    local use_key_name="${key_name:-$meta_key_name}"
    local key_file
    
    if [[ "$use_key_name" == "default" ]]; then
        key_file="$KEY_FILE"
    else
        key_file="$KEYS_DIR/${use_key_name}.key"
    fi
    
    if [[ ! -f "$key_file" ]]; then
        log_error "Encryption key not found: $key_file"
        echo "Available keys:"
        list_keys
        return 1
    fi
    
    # Set default output file
    if [[ -z "$output_file" ]]; then
        output_file="${input_file%.enc}"
        if [[ "$compression" == "true" ]]; then
            output_file="${output_file%.gz}"
        fi
    fi
    
    log "Decrypting: $input_file -> $output_file"
    echo -e "${CYAN}Algorithm: $algorithm${NC}"
    echo -e "${CYAN}Key: $use_key_name${NC}"
    echo -e "${CYAN}Compression: $compression${NC}"
    
    # Create temporary file for processing
    local temp_file="$output_file"
    if [[ "$compression" == "true" ]]; then
        temp_file="${output_file}.tmp.gz"
    fi
    
    # Perform decryption
    local decrypt_cmd="openssl enc -$algorithm -d -pbkdf2 -iter $DEFAULT_ITERATIONS"
    
    if $decrypt_cmd -in "$input_file" -out "$temp_file" -pass file:"$key_file"; then
        
        # Handle decompression if needed
        if [[ "$compression" == "true" ]]; then
            echo -e "${BLUE}Decompressing file...${NC}"
            if gunzip -c "$temp_file" > "$output_file"; then
                rm -f "$temp_file"
            else
                log_error "Decompression failed"
                rm -f "$temp_file"
                return 1
            fi
        fi
        
        log_success "Decryption successful: $output_file"
        
        # Display file information
        local encrypted_size=$(stat -c %s "$input_file")
        local decrypted_size=$(stat -c %s "$output_file")
        
        echo -e "${GREEN}✓ Decryption completed${NC}"
        echo -e "Encrypted size: $(numfmt --to=iec "$encrypted_size")"
        echo -e "Decrypted size: $(numfmt --to=iec "$decrypted_size")"
        
        return 0
    else
        log_error "Decryption failed for: $input_file"
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
        [[ -f "$output_file" ]] && rm -f "$output_file"
        return 1
    fi
}

# Create metadata file
create_metadata() {
    local encrypted_file="$1"
    local algorithm="$2"
    local key_name="$3"
    local compression="$4"
    
    local metadata_file="${encrypted_file}.meta"
    
    cat > "$metadata_file" <<EOF
# Grim Encryption Metadata
ALGORITHM="$algorithm"
KEY_NAME="$key_name"
COMPRESSION="$compression"
CREATED="$(date -Iseconds)"
VERSION="2.0"
EOF
    
    chmod 644 "$metadata_file"
}

# Enhanced verification
verify_encrypted() {
    local enc_file="$1"
    local checksum_file="${enc_file}.sha256"
    local metadata_file="${enc_file}.meta"
    
    if [[ -z "$enc_file" ]]; then
        log_error "No file specified for verification"
        echo "Usage: grim encrypt verify <encrypted_file>"
        return 1
    fi
    
    if [[ ! -f "$enc_file" ]]; then
        log_error "File not found: $enc_file"
        return 1
    fi
    
    echo -e "${CYAN}Verifying encrypted file: $enc_file${NC}"
    
    local verification_passed=true
    
    # Check file integrity
    if [[ -f "$checksum_file" ]]; then
        echo -e "${BLUE}Checking file integrity...${NC}"
        if sha256sum -c "$checksum_file" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ File integrity OK${NC}"
        else
            echo -e "${RED}✗ File integrity FAILED${NC}"
            verification_passed=false
        fi
    else
        echo -e "${YELLOW}⚠ No checksum file found${NC}"
    fi
    
    # Check metadata
    if [[ -f "$metadata_file" ]]; then
        echo -e "${BLUE}Checking metadata...${NC}"
        source "$metadata_file"
        echo -e "  Algorithm: $ALGORITHM"
        echo -e "  Key: $KEY_NAME"
        echo -e "  Compression: $COMPRESSION"
        echo -e "  Created: $CREATED"
        echo -e "  Version: $VERSION"
        echo -e "${GREEN}✓ Metadata OK${NC}"
    else
        echo -e "${YELLOW}⚠ No metadata file found${NC}"
    fi
    
    # Test decryption (without saving output)
    echo -e "${BLUE}Testing decryption...${NC}"
    local temp_test="/tmp/grim_verify_$$"
    
    if decrypt_file "$enc_file" "$temp_test" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Decryption test passed${NC}"
        rm -f "$temp_test"
    else
        echo -e "${RED}✗ Decryption test FAILED${NC}"
        verification_passed=false
        rm -f "$temp_test"
    fi
    
    # Final result
    if [[ "$verification_passed" == "true" ]]; then
        log_success "Verification passed for: $enc_file"
        echo -e "${GREEN}✓ Overall verification: PASSED${NC}"
        return 0
    else
        log_error "Verification failed for: $enc_file"
        echo -e "${RED}✗ Overall verification: FAILED${NC}"
        return 1
    fi
}

# Backup encryption key
backup_key() {
    local key_name="${1:-default}"
    local backup_location="${2:-}"
    
    init_directories
    
    local key_file
    if [[ "$key_name" == "default" ]]; then
        key_file="$KEY_FILE"
    else
        key_file="$KEYS_DIR/${key_name}.key"
    fi
    
    if [[ ! -f "$key_file" ]]; then
        log_error "Encryption key not found: $key_file"
        echo "Available keys:"
        list_keys
        return 1
    fi
    
    # Determine backup location
    local backup_dir
    if [[ -n "$backup_location" ]]; then
        backup_dir="$backup_location"
        mkdir -p "$backup_dir"
    else
        backup_dir="$GRIM_ROOT/backups/keys"
        mkdir -p "$backup_dir"
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local key_backup="$backup_dir/${key_name}_key_${timestamp}.bak"
    
    if cp "$key_file" "$key_backup"; then
        chmod 600 "$key_backup"
        log_success "Key backed up: $key_backup"
        
        echo -e "${GREEN}✓ Key backup created${NC}"
        echo -e "Source: $key_file"
        echo -e "Backup: $key_backup"
        echo -e "${YELLOW}⚠️  Store this backup in a secure location!${NC}"
        
        # Create backup metadata
        cat > "${key_backup}.info" <<EOF
# Grim Encryption Key Backup Info
KEY_NAME="$key_name"
ORIGINAL_PATH="$key_file"
BACKUP_DATE="$(date -Iseconds)"
FINGERPRINT="$(sha256sum "$key_file" | cut -d' ' -f1 | head -c 16)"
EOF
        
        return 0
    else
        log_error "Failed to backup key: $key_file"
        return 1
    fi
}

# Remove encryption key
remove_key() {
    local key_name="${1:-}"
    
    if [[ -z "$key_name" ]]; then
        log_error "No key name specified"
        echo "Usage: grim encrypt remove-key <key_name>"
        return 1
    fi
    
    if [[ "$key_name" == "default" ]]; then
        log_error "Cannot remove default key directly"
        echo "Use a specific key name instead"
        return 1
    fi
    
    local key_file="$KEYS_DIR/${key_name}.key"
    
    if [[ ! -f "$key_file" ]]; then
        log_error "Key not found: $key_name"
        return 1
    fi
    
    echo -e "${YELLOW}⚠️  WARNING: This will permanently delete the encryption key!${NC}"
    echo -e "Key: $key_name"
    echo -e "File: $key_file"
    echo
    read -p "Are you sure you want to delete this key? (type 'DELETE' to confirm): " -r
    
    if [[ "$REPLY" == "DELETE" ]]; then
        if rm -f "$key_file"; then
            log_success "Key removed: $key_name"
            echo -e "${GREEN}✓ Key deleted successfully${NC}"
            return 0
        else
            log_error "Failed to remove key: $key_name"
            return 1
        fi
    else
        log "Key removal cancelled"
        echo -e "${BLUE}Key removal cancelled${NC}"
        return 0
    fi
}

# Show detailed help
show_help() {
    echo -e "${CYAN}Grim Encryption Module v2.0${NC}"
    echo "Advanced encryption/decryption with multiple algorithms and key management"
    echo ""
    echo -e "${YELLOW}Usage:${NC} grim encrypt <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  encrypt <file> [output] [key] [algorithm] [compress]  - Encrypt a file"
    echo "  decrypt <file> [output] [key]                        - Decrypt a file"
    echo "  verify <file>                                        - Verify encrypted file"
    echo "  key-gen [name] [algorithm] [size]                    - Generate encryption key"
    echo "  list-keys                                            - List available keys"
    echo "  backup-key [name] [location]                         - Backup encryption key"
    echo "  remove-key <name>                                    - Remove encryption key"
    echo "  help                                                 - Show this help"
    echo ""
    echo -e "${YELLOW}Algorithms:${NC}"
    echo "  aes-256-cbc     - AES 256-bit CBC (default)"
    echo "  aes-256-gcm     - AES 256-bit GCM (authenticated)"
    echo "  aes-192-cbc     - AES 192-bit CBC"
    echo "  chacha20-poly1305 - ChaCha20-Poly1305 (modern)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # Generate a new key"
    echo "  grim encrypt key-gen mykey aes-256-cbc 32"
    echo ""
    echo "  # Encrypt with compression"
    echo "  grim encrypt encrypt backup.tar mykey.enc mykey aes-256-cbc true"
    echo ""
    echo "  # Simple encryption (uses default key)"
    echo "  grim encrypt encrypt document.pdf"
    echo ""
    echo "  # Decrypt with specific key"
    echo "  grim encrypt decrypt document.pdf.enc document.pdf mykey"
    echo ""
    echo "  # Verify encrypted file integrity"
    echo "  grim encrypt verify backup.tar.enc"
    echo ""
    echo "  # List all encryption keys"
    echo "  grim encrypt list-keys"
    echo ""
    echo "  # Backup encryption key"
    echo "  grim encrypt backup-key mykey /safe/location/"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Default algorithm: $DEFAULT_ALGORITHM"
    echo "  Default key size: $DEFAULT_KEY_SIZE bytes"
    echo "  PBKDF2 iterations: $DEFAULT_ITERATIONS"
    echo "  Key storage: $KEYS_DIR"
    echo "  Default key: $KEY_FILE"
    echo ""
    echo -e "${YELLOW}Security Features:${NC}"
    echo "  • PBKDF2 key derivation with 100,000 iterations"
    echo "  • Salt-based encryption for unique ciphertexts"
    echo "  • SHA-256 integrity verification"
    echo "  • Metadata tracking for algorithm and settings"
    echo "  • Optional compression before encryption"
    echo "  • Multiple encryption algorithms support"
    echo "  • Secure key storage with proper permissions"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT SECURITY NOTES:${NC}"
    echo "  • Always backup your encryption keys securely"
    echo "  • Keys are stored in $KEYS_DIR with 600 permissions"
    echo "  • Lost keys mean permanently lost data"
    echo "  • Use strong, unique keys for different purposes"
    echo "  • Verify encrypted files before deleting originals"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        encrypt)
            encrypt_file "$@"
            ;;
        decrypt)
            decrypt_file "$@"
            ;;
        verify)
            verify_encrypted "$1"
            ;;
        init|key-gen)
            init_key "$@"
            ;;
        list-keys)
            list_keys
            ;;
        backup-key)
            backup_key "$@"
            ;;
        remove-key)
            remove_key "$@"
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