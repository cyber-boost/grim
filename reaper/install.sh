#!/bin/bash
# 🗡️ GRIM REAPER - MASTER INSTALLER
# This is the installer served by get.grim.so
# Downloads and installs the complete Grim system

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
GRIM_VERSION="${GRIM_VERSION:-latest}"
GRIM_DISTRIBUTION_URL="${GRIM_DISTRIBUTION_URL:-https://get.grim.so}"
GRIM_GPG_KEY_ID="${GRIM_GPG_KEY_ID:-grim-security@grim.so}"
GRIM_INSTALL_DIR="${GRIM_INSTALL_DIR:-/opt/reaper}"
GRIM_GRAVEYARD="${GRIM_GRAVEYARD:-/root/.graveyard}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# UTILITIES
# ============================================================================
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}" >&2
    exit 1
}

print_banner() {
    echo -e "${CYAN}"
    echo "  ██████  ██████  ██ ███    ███     ██████  ███████  █████  ██████  ███████ ██████  "
    echo " ██       ██   ██ ██ ████  ████     ██   ██ ██      ██   ██ ██   ██ ██      ██   ██ "
    echo " ██   ███ ██████  ██ ██ ████ ██     ██████  █████   ███████ ██████  █████   ██████  "
    echo " ██    ██ ██   ██ ██ ██  ██  ██     ██   ██ ██      ██   ██ ██      ██      ██   ██ "
    echo "  ██████  ██   ██ ██ ██      ██     ██   ██ ███████ ██   ██ ██      ███████ ██   ██ "
    echo ""
    echo "                          🗡️  MASTER INSTALLER  🗡️"
    echo -e "${NC}"
}

# ============================================================================
# SYSTEM DETECTION
# ============================================================================
detect_system() {
    log "Detecting system configuration..."
    
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        DISTRO="unknown"
        VERSION="unknown"
    fi
    
    log "System: $OS ($DISTRO $VERSION) on $ARCH"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        warning "Not running as root - some installations may require sudo"
        SUDO="sudo"
    else
        SUDO=""
    fi
}

# ============================================================================
# SECURITY VERIFICATION
# ============================================================================
verify_gpg_key() {
    log "Verifying GPG key..."
    
    if ! command -v gpg >/dev/null 2>&1; then
        warning "GPG not available - skipping signature verification"
        return 0
    fi
    
    # Import GPG key if not present
    if ! gpg --list-keys "$GRIM_GPG_KEY_ID" >/dev/null 2>&1; then
        log "Importing GPG key: $GRIM_GPG_KEY_ID"
        curl -s "$GRIM_DISTRIBUTION_URL/gpg-key.asc" | gpg --import 2>/dev/null || {
            warning "Failed to import GPG key - continuing without verification"
            return 0
        }
    fi
    
    success "GPG key verified"
}

# ============================================================================
# DOWNLOAD AND EXTRACT
# ============================================================================
download_grim() {
    log "Downloading Grim Reaper..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download the latest build
    if [[ "$GRIM_VERSION" == "latest" ]]; then
        log "Downloading latest build..."
        curl -L -o grim-reaper.tar.gz "$GRIM_DISTRIBUTION_URL/builds/latest.tar.gz"
    else
        log "Downloading version: $GRIM_VERSION"
        curl -L -o grim-reaper.tar.gz "$GRIM_DISTRIBUTION_URL/builds/grim-reaper-$GRIM_VERSION.tar.gz"
    fi
    
    # Verify download
    if [[ ! -f "grim-reaper.tar.gz" ]]; then
        error "Failed to download Grim Reaper"
    fi
    
    # Extract
    log "Extracting Grim Reaper..."
    tar -xzf grim-reaper.tar.gz
    
    # Find the extracted directory
    GRIM_BUILD_DIR=$(find . -maxdepth 1 -name "grim-reaper-*" -type d | head -1)
    if [[ -z "$GRIM_BUILD_DIR" ]]; then
        error "Could not find extracted Grim Reaper directory"
    fi
    
    success "Grim Reaper downloaded and extracted"
    echo "$TEMP_DIR/$GRIM_BUILD_DIR"
}

# ============================================================================
# INSTALLATION
# ============================================================================
install_grim() {
    local build_dir="$1"
    
    log "Installing Grim Reaper..."
    
    # Check if grim_throne.sh exists (required for CLI)
    if [[ ! -f "$build_dir/grim_throne.sh" ]]; then
        error "grim_throne.sh not found in build - this is required for the unified CLI"
    fi
    
    # Create installation directory
    $SUDO mkdir -p "$GRIM_INSTALL_DIR"
    
    # Copy files
    log "Copying files to $GRIM_INSTALL_DIR..."
    $SUDO cp -r "$build_dir"/* "$GRIM_INSTALL_DIR/"
    
    # Set permissions
    $SUDO chown -R root:root "$GRIM_INSTALL_DIR"
    $SUDO chmod -R 755 "$GRIM_INSTALL_DIR"
    $SUDO find "$GRIM_INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
    $SUDO find "$GRIM_INSTALL_DIR" -name "*.py" -exec chmod +x {} \;
    
    # Install grim command
    log "Installing grim command..."
    $SUDO ln -sf "$GRIM_INSTALL_DIR/grim_throne.sh" /usr/bin/grim
    $SUDO chmod +x /usr/bin/grim
    
    success "Grim Reaper installed to $GRIM_INSTALL_DIR"
}

# ============================================================================
# POST-INSTALLATION SETUP
# ============================================================================
setup_environment() {
    log "Setting up environment..."
    
    # Create required directories
    $SUDO mkdir -p "$GRIM_INSTALL_DIR"/{logs,db,backups,tmp,builds}
    $SUDO chown -R root:root "$GRIM_INSTALL_DIR"
    
    # Create graveyard directory
    $SUDO mkdir -p "$GRIM_GRAVEYARD"
    $SUDO chown -R root:root "$GRIM_GRAVEYARD"
    
    # Set up PATH in bashrc
    if ! grep -q "$GRIM_INSTALL_DIR" /root/.bashrc 2>/dev/null; then
        echo "export PATH=\"$GRIM_INSTALL_DIR/sh_grim:\$PATH\"" >> /root/.bashrc
    fi
    
    success "Environment configured"
}

run_installation_script() {
    log "Running Grim installation script..."
    
    cd "$GRIM_INSTALL_DIR"
    
    # Run the admin installer if available
    if [[ -f "admin/install.sh" ]]; then
        log "Running admin installer..."
        ./admin/install.sh
    elif [[ -f "install.sh" ]]; then
        log "Running main installer..."
        ./install.sh
    else
        warning "No installation script found - manual setup may be required"
    fi
}

# ============================================================================
# VALIDATION
# ============================================================================
validate_installation() {
    log "Validating installation..."
    
    # Check if grim command works
    if command -v grim >/dev/null 2>&1; then
        success "grim command available"
    else
        error "grim command not found in PATH"
    fi
    
    # Check if grim_throne.sh exists
    if [[ -f "$GRIM_INSTALL_DIR/grim_throne.sh" ]]; then
        success "grim_throne.sh found"
    else
        error "grim_throne.sh not found"
    fi
    
    # Test grim health
    if grim health >/dev/null 2>&1; then
        success "Grim health check passed"
    else
        warning "Grim health check failed - may need manual configuration"
    fi
    
    success "Installation validated"
}

# ============================================================================
# CLEANUP
# ============================================================================
cleanup() {
    local temp_dir="$1"
    
    log "Cleaning up temporary files..."
    rm -rf "$temp_dir"
    success "Cleanup complete"
}

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================
display_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}🎉 GRIM REAPER INSTALLATION COMPLETE! 🎉${NC}"
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                 QUICK START                     │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│  ${WHITE}grim health${NC}              Check system health   ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}grim backup /path${NC}        Create backup          ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}grim monitor /path${NC}       Start monitoring       ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}grim web${NC}                 Start web interface    ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}grim admin${NC}               Start admin server     ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${YELLOW}Installation Details:${NC}"
    echo -e "  Install Directory: ${BLUE}$GRIM_INSTALL_DIR${NC}"
    echo -e "  Graveyard:         ${BLUE}$GRIM_GRAVEYARD${NC}"
    echo -e "  Version:           ${BLUE}$GRIM_VERSION${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "  1. Run ${BLUE}grim health${NC} to verify installation"
    echo -e "  2. Run ${BLUE}grim web${NC} to start the web interface"
    echo -e "  3. Run ${BLUE}grim setup-admin${NC} for admin server setup"
    echo ""
    echo -e "${GREEN}💀 The Reaper is ready! 💀${NC}"
    echo ""
    echo -e "${CYAN}Documentation: ${BLUE}https://grim.so/docs${NC}"
    echo -e "${CYAN}Support:        ${BLUE}https://community.grim.so${NC}"
}

# ============================================================================
# MAIN FLOW
# ============================================================================
main() {
    print_banner
    
    log "Starting Grim Reaper master installation..."
    
    detect_system
    verify_gpg_key
    
    # Download and extract
    local build_dir=$(download_grim)
    
    # Install
    install_grim "$build_dir"
    setup_environment
    run_installation_script
    validate_installation
    
    # Cleanup
    cleanup "$(dirname "$build_dir")"
    
    # Display summary
    display_summary
}

# ============================================================================
# HELP
# ============================================================================
show_help() {
    echo "Grim Reaper Master Installer"
    echo ""
    echo "Usage: curl -sSL get.grim.so | bash"
    echo "       curl -sSL get.grim.so | bash -s -- [options]"
    echo ""
    echo "Options:"
    echo "  --version <ver>    Install specific version (default: latest)"
    echo "  --install-dir <dir> Install directory (default: /opt/reaper)"
    echo "  --help             Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  GRIM_VERSION       Version to install"
    echo "  GRIM_INSTALL_DIR   Installation directory"
    echo "  GRIM_GRAVEYARD     Graveyard directory"
    echo ""
    echo "Examples:"
    echo "  curl -sSL get.grim.so | bash"
    echo "  curl -sSL get.grim.so | bash -s -- --version v1.0.0"
    echo "  GRIM_INSTALL_DIR=/opt/grim curl -sSL get.grim.so | bash"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            GRIM_VERSION="$2"
            shift 2
            ;;
        --install-dir)
            GRIM_INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            warning "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main installation
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 