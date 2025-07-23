#!/bin/bash
# Grimm Encryption Module: Handles backup encryption/decryption

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/encrypt.log"
KEY_FILE="$GRIM_ROOT/config/.grimm_key"

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

# Initialize encryption key
init_key() {
    if [ ! -f "$KEY_FILE" ]; then
        mkdir -p "$(dirname "$KEY_FILE")"
        log "Generating new encryption key..."
        openssl rand -base64 32 > "$KEY_FILE"
        chmod 600 "$KEY_FILE"
        log "Encryption key generated at $KEY_FILE"
        echo "⚠️  IMPORTANT: Back up your encryption key!"
        echo "Location: $KEY_FILE"
    fi
}

# Encrypt file
encrypt_file() {
    local input_file="$1"
    local output_file="${2:-${input_file}.enc}"
    
    if [ ! -f "$input_file" ]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    init_key
    
    log "Encrypting: $input_file -> $output_file"
    
    # Use AES-256-CBC encryption
    if openssl enc -aes-256-cbc -salt -pbkdf2 -in "$input_file" -out "$output_file" -pass file:"$KEY_FILE"; then
        log "Encryption successful: $output_file"
        # Create checksum of encrypted file
        sha256sum "$output_file" > "${output_file}.sha256"
        return 0
    else
        log_error "Encryption failed for: $input_file"
        return 1
    fi
}

# Decrypt file
decrypt_file() {
    local input_file="$1"
    local output_file="${2:-${input_file%.enc}}"
    
    if [ ! -f "$input_file" ]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    if [ ! -f "$KEY_FILE" ]; then
        log_error "Encryption key not found: $KEY_FILE"
        return 1
    fi
    
    log "Decrypting: $input_file -> $output_file"
    
    if openssl enc -aes-256-cbc -d -pbkdf2 -in "$input_file" -out "$output_file" -pass file:"$KEY_FILE"; then
        log "Decryption successful: $output_file"
        return 0
    else
        log_error "Decryption failed for: $input_file"
        return 1
    fi
}

# Verify encrypted file
verify_encrypted() {
    local enc_file="$1"
    local checksum_file="${enc_file}.sha256"
    
    if [ ! -f "$checksum_file" ]; then
        log_error "No checksum file found for: $enc_file"
        return 1
    fi
    
    if sha256sum -c "$checksum_file" >/dev/null 2>&1; then
        log "Encrypted file verification OK: $enc_file"
        return 0
    else
        log_error "Encrypted file verification FAILED: $enc_file"
        return 1
    fi
}

# Backup encryption key
backup_key() {
    if [ ! -f "$KEY_FILE" ]; then
        log_error "No encryption key found to backup"
        return 1
    fi
    
    local backup_dir="$GRIM_ROOT/backups/keys"
    mkdir -p "$backup_dir"
    
    local key_backup="$backup_dir/grimm_key_$(date +%Y%m%d_%H%M%S).bak"
    cp "$KEY_FILE" "$key_backup"
    chmod 600 "$key_backup"
    
    log "Key backed up to: $key_backup"
    echo "⚠️  Store this backup in a secure location!"
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Encryption Module${NC}"
    echo "Provides AES-256-CBC encryption for backup files with key management."
    echo "Ensures backup security through strong encryption and integrity verification."
    echo ""
    echo "Usage: grim encrypt <command> [options]"
    echo ""
    echo "Commands:"
    echo "  encrypt <file> [output]    - Encrypt a file with AES-256-CBC"
    echo "  decrypt <file> [output]    - Decrypt an encrypted file"
    echo "  verify <file>              - Verify encrypted file integrity"
    echo "  init                       - Initialize encryption key"
    echo "  backup-key                 - Create backup of encryption key"
    echo ""
    echo "Examples:"
    echo "  grim encrypt encrypt backup.tar.gz          # Encrypt backup"
    echo "  grim encrypt decrypt backup.tar.gz.enc      # Decrypt backup"
    echo "  grim encrypt verify backup.tar.gz.enc       # Verify integrity"
    echo ""
    echo "Configuration:"
    echo "  Algorithm: AES-256-CBC with PBKDF2"
    echo "  Key file: $KEY_FILE"
    echo "  ⚠️  IMPORTANT: Back up your encryption key!"
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
        init)
            init_key
            ;;
        backup-key)
            backup_key
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