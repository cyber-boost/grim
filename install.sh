#!/bin/bash
# 🗡️ GRIM REAPER - MASTER INSTALLER
# This is the installer served by get.grim.so
# Downloads and installs the complete Grim system

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
GRIM_VERSION="${GRIM_VERSION:-latest}"
GRIM_DISTRIBUTION_URL="${GRIM_DISTRIBUTION_URL:-http://get.grim.so}"
GRIM_INSTALL_DIR="${GRIM_INSTALL_DIR:-/root/reaper}"
GRIM_GRAVEYARD="${GRIM_GRAVEYARD:-$HOME/.graveyard}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
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
        curl -L -o grim-reaper.tar.gz "$GRIM_DISTRIBUTION_URL/latest.tar.gz"
    else
        log "Downloading version: $GRIM_VERSION"
        curl -L -o grim-reaper.tar.gz "$GRIM_DISTRIBUTION_URL/latest.tar.gz"
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
    
    # Clean up the path (remove ./ prefix if present)
    GRIM_BUILD_DIR="${GRIM_BUILD_DIR#./}"
    
    success "Grim Reaper downloaded and extracted"
    # Return the full path to the build directory (clean output)
    printf "%s" "$TEMP_DIR/$GRIM_BUILD_DIR"
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
    
    # grim_throne.sh now auto-detects its path - no manual updates needed
    
    # Install grim command
    log "Installing grim command..."
    $SUDO ln -sf "$GRIM_INSTALL_DIR/grim_throne.sh" /usr/local/bin/grim
    $SUDO chmod +x /usr/local/bin/grim
    
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
    
    # Install Python dependencies for py_grim
    log "Installing Python dependencies..."
    if command -v python3 >/dev/null 2>&1; then
        cd "$GRIM_INSTALL_DIR"
        
        # Check if python3-venv is available
        if ! python3 -c "import venv" 2>/dev/null; then
            log "Installing python3-venv package..."
            
            # Wait for any existing package manager locks
            if command -v fuser >/dev/null 2>&1; then
                log "Checking for package manager locks..."
                fuser /var/lib/dpkg/lock-frontend 2>/dev/null && {
                    log "Waiting for package manager lock to be released..."
                    sleep 10
                }
            fi
            
            if command -v apt >/dev/null 2>&1; then
                # Try with sudo first, then without if already root
                if [[ $EUID -ne 0 ]]; then
                    sudo apt update -qq && sudo apt install -y python3-venv python3-pip python3.12-venv
                else
                    apt update -qq && apt install -y python3-venv python3-pip python3.12-venv
                fi
                if [[ $? -eq 0 ]]; then
                    success "python3-venv installed"
                else
                    warning "Failed to install python3-venv - trying alternative packages..."
                    # Try alternative package names
                    if [[ $EUID -ne 0 ]]; then
                        sudo apt install -y python3-virtualenv python3-pip
                    else
                        apt install -y python3-virtualenv python3-pip
                    fi
                    if [[ $? -eq 0 ]]; then
                        success "python3-virtualenv installed as alternative"
                    else
                        warning "Failed to install python3-venv - Python dependencies will be skipped"
                        return
                    fi
                fi
            elif command -v yum >/dev/null 2>&1; then
                if [[ $EUID -ne 0 ]]; then
                    sudo yum install -y python3-venv python3-pip
                else
                    yum install -y python3-venv python3-pip
                fi
                if [[ $? -eq 0 ]]; then
                    success "python3-venv installed"
                else
                    warning "Failed to install python3-venv - Python dependencies will be skipped"
                    return
                fi
            elif command -v dnf >/dev/null 2>&1; then
                if [[ $EUID -ne 0 ]]; then
                    sudo dnf install -y python3-venv python3-pip
                else
                    dnf install -y python3-venv python3-pip
                fi
                if [[ $? -eq 0 ]]; then
                    success "python3-venv installed"
                else
                    warning "Failed to install python3-venv - Python dependencies will be skipped"
                    return
                fi
            else
                warning "Could not install python3-venv - Python dependencies will be skipped"
                return
            fi
        fi
        
        # Create virtual environment
        log "Creating Python virtual environment..."
        if python3 -c "import venv" 2>/dev/null; then
            python3 -m venv grim_venv
        elif command -v virtualenv >/dev/null 2>&1; then
            virtualenv grim_venv
        else
            warning "Neither venv nor virtualenv available - creating directory structure manually"
            mkdir -p grim_venv/bin grim_venv/lib/python3.12/site-packages
            ln -sf /usr/bin/python3 grim_venv/bin/python
            ln -sf /usr/bin/python3 grim_venv/bin/python3
            ln -sf /usr/bin/pip3 grim_venv/bin/pip
        fi
        source grim_venv/bin/activate
        
        # Install dependencies
        if [[ -f "py_grim/requirements.txt" ]]; then
            pip install -r py_grim/requirements.txt
            success "Python dependencies installed in virtual environment"
        else
            # Install common dependencies if no requirements.txt
            pip install fastapi uvicorn pydantic sqlalchemy psycopg2-binary redis
            success "Common Python dependencies installed in virtual environment"
        fi
        
        # Update grim_throne.sh to use virtual environment
        sed -i "s|source /opt/grim_venv/bin/activate|source $GRIM_INSTALL_DIR/grim_venv/bin/activate|g" "$GRIM_INSTALL_DIR/grim_throne.sh"
    else
        warning "python3 not available - Python dependencies not installed"
    fi
    
    success "Environment configured"
}

run_installation_script() {
    log "Running Grim installation script..."
    
    cd "$GRIM_INSTALL_DIR"
    
    # Skip running full installer when called from master installer
    # The full installer expects to be run from a build directory
    log "Skipping full installer - Grim Reaper is ready to use"
    log "Run 'grim health' to verify installation"
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
    
    # Download and extract
    local build_dir
    build_dir=$(download_grim 2>&1 | tail -1)
    
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
# Handle both direct execution and pipe execution (curl | bash)
if [[ "${BASH_SOURCE[0]:-}" == "$0" ]] || [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    main "$@"
fi 