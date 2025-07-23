#!/bin/bash
# Secure Installer Module: Secure download verification and installation

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
SECURE_LOG="$GRIM_ROOT/logs/secure_installer.log"
AUDIT_LOG="$GRIM_ROOT/logs/security_audit.log"
KEYS_DIR="$GRIM_ROOT/config/keys"
SIGNATURES_DIR="$GRIM_ROOT/config/signatures"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Security configuration
DISTRIBUTION_URL="${distribution_url:-https://get.grim.so}"
GPG_KEY_ID="${gpg_key_id:-grim-security@grim.so}"
VERIFY_SIGNATURES="${verify_signatures:-true}"
VERIFY_CHECKSUMS="${verify_checksums:-true}"
SECURE_DOWNLOAD="${secure_download:-true}"
INSTALL_TIMEOUT="${install_timeout:-300}"

# Secure logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SECURE_LOG"
}

# Security audit logging
audit_log() {
    local event_type="$1"
    local message="$2"
    local user="${SUDO_USER:-$USER}"
    local session_id="${SSH_SESSION_ID:-$(who am i | awk '{print $2}' | sed 's/[()]//g')}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUDIT] [$event_type] [$user] [$session_id] $message" >> "$AUDIT_LOG"
}

# Initialize secure installer
init_secure_installer() {
    mkdir -p "$KEYS_DIR" "$SIGNATURES_DIR" "$(dirname "$SECURE_LOG")" "$(dirname "$AUDIT_LOG")"
    
    # Import GPG key if not present
    if ! gpg --list-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
        log "Importing GPG key: $GPG_KEY_ID"
        curl -s "$DISTRIBUTION_URL/gpg-key.asc" | gpg --import 2>/dev/null || log "Failed to import GPG key"
    fi
    
    log "Secure installer initialized"
    audit_log "INSTALLER_INIT" "Secure installer initialized"
}

# Download file with security verification
secure_download() {
    local url="$1"
    local output_file="$2"
    local expected_checksum="${3:-}"
    local signature_file="${4:-}"
    
    log "Starting secure download: $url"
    audit_log "DOWNLOAD_START" "URL: $url, Output: $output_file"
    
    # Validate URL security
    if [[ "$SECURE_DOWNLOAD" == "true" ]] && [[ ! "$url" =~ ^https:// ]]; then
        log "ERROR: Insecure download URL (HTTPS required): $url"
        audit_log "INSECURE_URL" "URL: $url"
        return 1
    fi
    
    # Download with security headers
    local download_success=false
    if curl -s -L -o "$output_file" \
        -H "User-Agent: Grim-Secure-Installer/1.0" \
        -H "Accept: application/octet-stream" \
        --connect-timeout 30 \
        --max-time "$INSTALL_TIMEOUT" \
        --retry 3 \
        --retry-delay 5 \
        "$url"; then
        download_success=true
    fi
    
    if [[ "$download_success" != "true" ]]; then
        log "ERROR: Download failed: $url"
        audit_log "DOWNLOAD_FAILED" "URL: $url"
        return 1
    fi
    
    log "Download completed: $output_file"
    
    # Verify checksum if provided
    if [[ -n "$expected_checksum" ]] && [[ "$VERIFY_CHECKSUMS" == "true" ]]; then
        if ! verify_checksum "$output_file" "$expected_checksum"; then
            log "ERROR: Checksum verification failed: $output_file"
            audit_log "CHECKSUM_FAILED" "File: $output_file, Expected: $expected_checksum"
            rm -f "$output_file"
            return 1
        fi
        log "Checksum verification passed: $output_file"
    fi
    
    # Verify signature if provided
    if [[ -n "$signature_file" ]] && [[ "$VERIFY_SIGNATURES" == "true" ]]; then
        if ! verify_signature "$output_file" "$signature_file"; then
            log "ERROR: Signature verification failed: $output_file"
            audit_log "SIGNATURE_FAILED" "File: $output_file, Signature: $signature_file"
            rm -f "$output_file"
            return 1
        fi
        log "Signature verification passed: $output_file"
    fi
    
    audit_log "DOWNLOAD_SUCCESS" "File: $output_file, URL: $url"
    return 0
}

# Verify file checksum
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local actual_checksum=$(sha256sum "$file" | cut -d' ' -f1)
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        return 0
    else
        log "Checksum mismatch: Expected $expected_checksum, Got $actual_checksum"
        return 1
    fi
}

# Verify GPG signature
verify_signature() {
    local file="$1"
    local signature_file="$2"
    
    if [[ ! -f "$file" ]] || [[ ! -f "$signature_file" ]]; then
        return 1
    fi
    
    if gpg --verify "$signature_file" "$file" >/dev/null 2>&1; then
        return 0
    else
        log "GPG signature verification failed: $file"
        return 1
    fi
}

# Download and verify package
download_package() {
    local package_name="$1"
    local version="${2:-latest}"
    
    log "Downloading package: $package_name (version: $version)"
    audit_log "PACKAGE_DOWNLOAD" "Package: $package_name, Version: $version"
    
    local package_url="$DISTRIBUTION_URL/packages/$package_name-$version.tar.gz"
    local checksum_url="$DISTRIBUTION_URL/packages/$package_name-$version.sha256"
    local signature_url="$DISTRIBUTION_URL/packages/$package_name-$version.sig"
    
    local temp_dir=$(mktemp -d)
    local package_file="$temp_dir/$package_name-$version.tar.gz"
    local checksum_file="$temp_dir/$package_name-$version.sha256"
    local signature_file="$temp_dir/$package_name-$version.sig"
    
    # Download package
    if ! secure_download "$package_url" "$package_file"; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Download checksum
    local expected_checksum=""
    if curl -s -o "$checksum_file" "$checksum_url" 2>/dev/null; then
        expected_checksum=$(cat "$checksum_file" | cut -d' ' -f1)
    fi
    
    # Download signature
    local signature_downloaded=false
    if curl -s -o "$signature_file" "$signature_url" 2>/dev/null; then
        signature_downloaded=true
    fi
    
    # Verify package
    if [[ -n "$expected_checksum" ]] && ! verify_checksum "$package_file" "$expected_checksum"; then
        log "ERROR: Package checksum verification failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    if [[ "$signature_downloaded" == "true" ]] && ! verify_signature "$package_file" "$signature_file"; then
        log "ERROR: Package signature verification failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log "Package verification successful: $package_name"
    audit_log "PACKAGE_VERIFIED" "Package: $package_name, Version: $version"
    
    echo "$package_file"
}

# Secure installation process
secure_install() {
    local package_file="$1"
    local install_dir="${2:-/opt/grim}"
    
    log "Starting secure installation: $package_file"
    audit_log "INSTALL_START" "Package: $package_file, Target: $install_dir"
    
    # Create backup of existing installation
    local backup_dir=""
    if [[ -d "$install_dir" ]]; then
        backup_dir="$install_dir.backup.$(date +%Y%m%d_%H%M%S)"
        if cp -r "$install_dir" "$backup_dir" 2>/dev/null; then
            log "Backup created: $backup_dir"
            audit_log "BACKUP_CREATED" "Backup: $backup_dir"
        fi
    fi
    
    # Extract package
    local temp_dir=$(mktemp -d)
    if ! tar -xzf "$package_file" -C "$temp_dir" 2>/dev/null; then
        log "ERROR: Failed to extract package: $package_file"
        audit_log "EXTRACT_FAILED" "Package: $package_file"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Verify extracted contents
    local manifest_file="$temp_dir/manifest.json"
    if [[ -f "$manifest_file" ]]; then
        if ! verify_manifest "$manifest_file"; then
            log "ERROR: Package manifest verification failed"
            audit_log "MANIFEST_FAILED" "Manifest: $manifest_file"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Install package
    mkdir -p "$install_dir"
    if ! cp -r "$temp_dir"/* "$install_dir/" 2>/dev/null; then
        log "ERROR: Failed to install package to $install_dir"
        audit_log "INSTALL_FAILED" "Target: $install_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Set secure permissions
    chmod -R 755 "$install_dir"
    find "$install_dir" -type f -name "*.sh" -exec chmod +x {} \;
    
    # Verify installation
    if ! verify_installation "$install_dir"; then
        log "ERROR: Installation verification failed"
        audit_log "INSTALL_VERIFY_FAILED" "Target: $install_dir"
        # Rollback if backup exists
        if [[ -d "$backup_dir" ]]; then
            rm -rf "$install_dir"
            mv "$backup_dir" "$install_dir"
            log "Installation rolled back"
            audit_log "INSTALL_ROLLBACK" "Rollback to: $backup_dir"
        fi
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log "Secure installation completed: $install_dir"
    audit_log "INSTALL_SUCCESS" "Target: $install_dir"
    
    return 0
}

# Verify package manifest
verify_manifest() {
    local manifest_file="$1"
    
    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi
    
    # Check manifest format
    if ! jq -e . "$manifest_file" >/dev/null 2>&1; then
        log "Invalid manifest format: $manifest_file"
        return 1
    fi
    
    # Verify required fields
    local required_fields=("name" "version" "checksum")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$manifest_file" >/dev/null 2>&1; then
            log "Missing required field in manifest: $field"
            return 1
        fi
    done
    
    return 0
}

# Verify installation integrity
verify_installation() {
    local install_dir="$1"
    
    # Check for required files
    local required_files=("reaper.sh" "modules/" "config/")
    for file in "${required_files[@]}"; do
        if [[ ! -e "$install_dir/$file" ]]; then
            log "Missing required file: $file"
            return 1
        fi
    done
    
    # Check file permissions
    if [[ ! -x "$install_dir/reaper.sh" ]]; then
        log "reaper.sh is not executable"
        return 1
    fi
    
    # Verify module permissions
    find "$install_dir/modules" -name "*.sh" -exec test -x {} \; || {
        log "Some modules are not executable"
        return 1
    }
    
    return 0
}

# Update package securely
secure_update() {
    local package_name="$1"
    local current_version="$2"
    local target_version="${3:-latest}"
    
    log "Starting secure update: $package_name ($current_version -> $target_version)"
    audit_log "UPDATE_START" "Package: $package_name, From: $current_version, To: $target_version"
    
    # Download new version
    local package_file=$(download_package "$package_name" "$target_version")
    if [[ -z "$package_file" ]]; then
        log "ERROR: Failed to download update package"
        return 1
    fi
    
    # Install update
    if secure_install "$package_file" "/opt/grim"; then
        log "Secure update completed: $package_name"
        audit_log "UPDATE_SUCCESS" "Package: $package_name, Version: $target_version"
        return 0
    else
        log "ERROR: Secure update failed: $package_name"
        audit_log "UPDATE_FAILED" "Package: $package_name, Version: $target_version"
        return 1
    fi
}

# Verify system integrity
verify_system_integrity() {
    local install_dir="${1:-/opt/grim}"
    
    log "Verifying system integrity: $install_dir"
    audit_log "INTEGRITY_CHECK" "Target: $install_dir"
    
    local integrity_file="$install_dir/.integrity"
    if [[ ! -f "$integrity_file" ]]; then
        log "No integrity file found: $integrity_file"
        return 1
    fi
    
    local integrity_check_passed=true
    
    while IFS='|' read -r file_path expected_checksum; do
        if [[ -f "$install_dir/$file_path" ]]; then
            local actual_checksum=$(sha256sum "$install_dir/$file_path" | cut -d' ' -f1)
            if [[ "$actual_checksum" != "$expected_checksum" ]]; then
                log "Integrity check failed: $file_path"
                integrity_check_passed=false
            fi
        else
            log "Missing file: $file_path"
            integrity_check_passed=false
        fi
    done < "$integrity_file"
    
    if [[ "$integrity_check_passed" == "true" ]]; then
        log "System integrity verification passed"
        audit_log "INTEGRITY_PASS" "Target: $install_dir"
        return 0
    else
        log "System integrity verification failed"
        audit_log "INTEGRITY_FAIL" "Target: $install_dir"
        return 1
    fi
}

# Show installation status
show_status() {
    echo -e "${CYAN}=== Secure Installer Status ===${NC}"
    
    # Check GPG key
    if gpg --list-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ GPG Key: $GPG_KEY_ID${NC}"
    else
        echo -e "${RED}✗ GPG Key: $GPG_KEY_ID (not found)${NC}"
    fi
    
    # Check configuration
    echo "Distribution URL: $DISTRIBUTION_URL"
    echo "Verify signatures: $VERIFY_SIGNATURES"
    echo "Verify checksums: $VERIFY_CHECKSUMS"
    echo "Secure download: $SECURE_DOWNLOAD"
    echo "Install timeout: ${INSTALL_TIMEOUT}s"
    
    # Check system integrity
    if verify_system_integrity "/opt/grim" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ System integrity: OK${NC}"
    else
        echo -e "${RED}✗ System integrity: FAILED${NC}"
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}Secure Installer Module${NC}"
    echo "Secure download verification and installation system."
    echo ""
    echo "Usage: grim secure-installer <command> [options]"
    echo ""
    echo "Commands:"
    echo "  download <package> [version]     - Download and verify package"
    echo "  install <package_file> [dir]     - Install package securely"
    echo "  update <package> [version]       - Update package securely"
    echo "  verify [dir]                     - Verify system integrity"
    echo "  status                           - Show installer status"
    echo "  init                             - Initialize secure installer"
    echo "  help                             - Show this help"
    echo ""
    echo "Examples:"
    echo "  grim secure-installer download grim latest"
    echo "  grim secure-installer install grim-latest.tar.gz"
    echo "  grim secure-installer update grim 2.0.0"
    echo "  grim secure-installer verify"
    echo ""
    echo "Configuration:"
    echo "  Distribution URL: $DISTRIBUTION_URL"
    echo "  GPG Key ID: $GPG_KEY_ID"
    echo "  Verify signatures: $VERIFY_SIGNATURES"
    echo "  Verify checksums: $VERIFY_CHECKSUMS"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        download)
            if [[ $# -lt 1 ]]; then
                echo "Usage: grim secure-installer download <package> [version]"
                return 1
            fi
            download_package "$1" "$2"
            ;;
        install)
            if [[ $# -lt 1 ]]; then
                echo "Usage: grim secure-installer install <package_file> [dir]"
                return 1
            fi
            secure_install "$1" "$2"
            ;;
        update)
            if [[ $# -lt 1 ]]; then
                echo "Usage: grim secure-installer update <package> [current_version] [target_version]"
                return 1
            fi
            secure_update "$1" "$2" "$3"
            ;;
        verify)
            verify_system_integrity "$1"
            ;;
        status)
            show_status
            ;;
        init)
            init_secure_installer
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            return 1
            ;;
    esac
}

# Initialize on first run
init_secure_installer

# Only call main if this script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 