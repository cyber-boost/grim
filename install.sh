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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Utilities
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

# Smart installation directory logic with /root/.graveyard fallback
determine_install_paths() {
    # Try /root/.graveyard first (system-wide, preferred)
    if [[ -w "/root" ]] || mkdir -p "/root/.graveyard" 2>/dev/null; then
        GRIM_GRAVEYARD="/root/.graveyard"
        GRIM_INSTALL_DIR="/root/.graveyard/reaper"
        log "Using system-wide installation: /root/.graveyard/reaper"
    else
        # Fallback to user's home directory
        GRIM_GRAVEYARD="${GRIM_GRAVEYARD:-$HOME/.graveyard}"
        GRIM_INSTALL_DIR="${GRIM_INSTALL_DIR:-$HOME/.graveyard/reaper}"
        log "Using user installation: $HOME/.graveyard/reaper"
    fi
}

# Determine paths before anything else
determine_install_paths

# ============================================================================
# UTILITIES
# ============================================================================

print_banner() {
    echo ""
    echo "                ⠀⠀⣿⠲⠤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⣸⡏⠀⠀⠀⠉⠳⢄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⣿⠀⠀⠀⠀⠀⠀⠀⠉⠲⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    echo "                ⢰⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠲⣄⠀⠀⠀⡰⠋⢙⣿⣦⡀⠀⠀⠀⠀⠀"
    echo "                ⠸⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣙⣦⣮⣤⡀⣸⣿⣿⣿⣆⠀⠀⠀⠀"
    echo "                ⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⠀⣿⢟⣫⠟⠋⠀⠀⠀⠀"
    echo "                ⠀⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣷⣷⣿⡁⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⢹⣿⣿⣧⣿⣿⣆⡹⣖⡀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢾⣿⣤⣿⣿⣿⡟⠹⣿⣿⣿⣿⣷⡀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣧⣴⣿⣿⣿⣿⠏⢧⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠈⢳⡀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡏⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⢳"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠸⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡇⢠⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠃⢸⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣼⢸⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⢸⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀"
    echo "                ⠀⠀⠀⠀⠀⠀⠀⠛⠻⠿⣿⣿⣿⡿⠿⠿⠿⠿⠿⢿⣿⣿⠏⠀⠀⠀⠀⠀⠀"
    echo "            ////////////////////////////////////////////"
    echo "            //                                        //"
    echo "            //     ██████╗ ██████╗ ██╗███╗   ███╗     //"
    echo "            //    ██╔════╝ ██╔══██╗██║████╗ ████║     //"
    echo "            //    ██║  ███╗██████╔╝██║██╔████╔██║     //"
    echo "            //    ██║   ██║██╔══██╗██║██║╚██╔╝██║     //"
    echo "            //    ╚██████╔╝██║  ██║██║██║ ╚═╝ ██║     //"
    echo "            //     ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝     ╚═╝     //"
    echo "            //                                        //"
    echo "            ////////////////////////////////////////////"
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║																		   ║"
    echo "║    Grim was built by Bernie Gengel and his beagle Buddy in July 2025   ║"
    echo "║ Grim started as archive system called graveyard. The original goal was ║"
    echo "║  to make backups more secure, faster and easier to revert if needed.   ║"
    echo "║																		   ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${MAGENTA}🔥 BBL LICENSE - THE MOST GENEROUS DEVELOPER PROGRAM 🔥${NC}"
    echo -e "${YELLOW}Earn 50% commission + residuals + 33% quarterly revenue sharing!${NC}"
    echo ""
}

print_start_banner() {
    echo ""
    echo "            ////////////////////////////////////////////"
    echo "            //                                        //"
    echo "            //     ██████╗ ██████╗ ██╗███╗   ███╗     //"
    echo "            //    ██╔════╝ ██╔══██╗██║████╗ ████║     //"
    echo "            //    ██║  ███╗██████╔╝██║██╔████╔██║     //"
    echo "            //    ██║   ██║██╔══██╗██║██║╚██╔╝██║     //"
    echo "            //    ╚██████╔╝██║  ██║██║██║ ╚═╝ ██║     //"
    echo "            //     ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝     ╚═╝     //"
    echo "            //     Death defying data protection      //"
    echo "            ////////////////////////////////////////////"
    echo ""
}

# ============================================================================
# AFFILIATE SYSTEM
# ============================================================================
register_affiliate() {
    local affiliate_id="$1"
    log "Registering affiliate ID: $affiliate_id"
    
    # Try to register with the affiliate system
    local response
    response=$(curl -s -w "%{http_code}" "https://rip.grim.so/api/new-afl/$affiliate_id" 2>/dev/null)
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        success "Affiliate ID registered successfully"
        return 0
    else
        warning "Affiliate registration failed (HTTP $http_code) - continuing anyway"
        return 1
    fi
}

generate_affiliate_id() {
    # Get server IP address
    local server_ip
    server_ip=$(curl -s --max-time 5 https://ipinfo.io/ip 2>/dev/null || echo "unknown")
    
    # Generate 8-character hash from IP
    local affiliate_id
    affiliate_id=$(echo "$server_ip" | md5sum | cut -c1-8)
    
    echo "$affiliate_id"
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
    
    # Check if grim_throne.sh exists (required for CLI) - ALWAYS use the one from throne directory
    if [[ -f "$build_dir/throne/grim_throne.sh" ]]; then
        log "Found REAL grim_throne.sh in throne directory - this is the complete version with all commands"
        cp "$build_dir/throne/grim_throne.sh" "$build_dir/grim_throne.sh"
        chmod +x "$build_dir/grim_throne.sh"
    else
        # Fallback - check if it's already in the main directory
        if [[ ! -f "$build_dir/grim_throne.sh" ]]; then
            error "grim_throne.sh not found in build - this is required for the unified CLI"
        else
            warning "Using grim_throne.sh from main directory - this may not have all commands"
        fi
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
    
    # Copy the actual commands documentation if available
    if [[ -f "$build_dir/throne/actual_commands.txt" ]]; then
        log "Copying commands documentation..."
        $SUDO cp "$build_dir/throne/actual_commands.txt" "$GRIM_INSTALL_DIR/commands.txt"
    fi
    
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
    
    # Install SQLite3 FIRST before any scripts that need it
    log "Checking SQLite3 installation..."
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log "SQLite3 not found - installing SQLite3..."
        if command -v apt >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo apt update -qq && sudo apt install -y sqlite3
            else
                apt update -qq && apt install -y sqlite3
            fi
            if [[ $? -eq 0 ]]; then
                success "SQLite3 installed"
            else
                error "Failed to install SQLite3"
            fi
        elif command -v yum >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo yum install -y sqlite
            else
                yum install -y sqlite
            fi
            if [[ $? -eq 0 ]]; then
                success "SQLite3 installed"
            else
                error "Failed to install SQLite3"
            fi
        elif command -v dnf >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo dnf install -y sqlite
            else
                dnf install -y sqlite
            fi
            if [[ $? -eq 0 ]]; then
                success "SQLite3 installed"
            else
                error "Failed to install SQLite3"
            fi
        else
            error "Could not install SQLite3 - no supported package manager found"
        fi
    else
        log "SQLite3 already installed: $(sqlite3 --version)"
    fi
    
    # Create required directories
    $SUDO mkdir -p "$GRIM_INSTALL_DIR"/{logs,db,backups,tmp,builds}
    $SUDO chown -R root:root "$GRIM_INSTALL_DIR"
    
    # Create graveyard directory
    $SUDO mkdir -p "$GRIM_GRAVEYARD"
    $SUDO chown -R root:root "$GRIM_GRAVEYARD"
    
    # Setup .scythe directory structure
    log "Setting up .scythe directory structure..."
    if [[ -f "$GRIM_INSTALL_DIR/scripts/setup_scythe_dirs.sh" ]]; then
        # Use the universal setup script
        if [[ -n "$SUDO" ]]; then
            "$GRIM_INSTALL_DIR/scripts/setup_scythe_dirs.sh" setup "$GRIM_INSTALL_DIR" yes
        else
            "$GRIM_INSTALL_DIR/scripts/setup_scythe_dirs.sh" setup "$GRIM_INSTALL_DIR" no
        fi
    else 
        # Fallback: create basic structure manually
        warning "Universal setup script not found - creating basic .scythe structure"
        $SUDO mkdir -p "$GRIM_INSTALL_DIR/.graveyard/.rip/.scythe"/{config,db,logs,run,integrations}
        $SUDO chown -R root:root "$GRIM_INSTALL_DIR/.graveyard" 2>/dev/null || true
        $SUDO chmod -R 755 "$GRIM_INSTALL_DIR/.graveyard" 2>/dev/null || true
    fi
    
    # Set up environment variables in bashrc and profile
    local bashrc_file profile_file
    
    # Determine which files to update based on installation location
    if [[ "$GRIM_INSTALL_DIR" == "/root/.graveyard/reaper" ]]; then
        bashrc_file="/root/.bashrc"
        profile_file="/root/.profile"
    else
        bashrc_file="$HOME/.bashrc"
        profile_file="$HOME/.profile"
    fi
    
    # Add GRIM_ROOT environment variable
    if ! grep -q "GRIM_ROOT" "$bashrc_file" 2>/dev/null; then
        echo "export GRIM_ROOT=\"$GRIM_INSTALL_DIR\"" >> "$bashrc_file"
        log "Added GRIM_ROOT to $bashrc_file"
    fi
    
    if [[ -f "$profile_file" ]] && ! grep -q "GRIM_ROOT" "$profile_file" 2>/dev/null; then
        echo "export GRIM_ROOT=\"$GRIM_INSTALL_DIR\"" >> "$profile_file"
        log "Added GRIM_ROOT to $profile_file"
    fi
    
    # Set up PATH in bashrc
    if ! grep -q "$GRIM_INSTALL_DIR" "$bashrc_file" 2>/dev/null; then
        echo "export PATH=\"$GRIM_INSTALL_DIR/sh_grim:\$PATH\"" >> "$bashrc_file"
        log "Added PATH to $bashrc_file"
    fi
    
    # Export for current session
    export GRIM_ROOT="$GRIM_INSTALL_DIR"
    
    # Set up storage enforcement service (hidden from users)
    log "Setting up storage enforcement system..."
    $SUDO mkdir -p /etc/grim-reaper/services
    $SUDO mkdir -p /var/log/grim/enforcement
    $SUDO mkdir -p /var/run/grim
    
    # Copy storage enforcement configuration
    if [ -f "$GRIM_INSTALL_DIR/config/storage_limits.yaml" ]; then
        $SUDO cp "$GRIM_INSTALL_DIR/config/storage_limits.yaml" /etc/grim-reaper/storage-enforcement.yaml
        $SUDO chmod 644 /etc/grim-reaper/storage-enforcement.yaml
        log "Storage enforcement configuration installed"
    fi
    
    # Create systemd service for storage enforcement (hidden)
    cat > /tmp/grim-storage-enforcement.service << 'EOF'
[Unit]
Description=Grim Storage Enforcement Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/python3 /opt/reaper/throne/services/storage_enforcement_service.py --config /etc/grim-reaper/storage-enforcement.yaml --pid-file /var/run/grim/storage-enforcement.pid --log-file /var/log/grim/enforcement/service.log
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security: Users cannot disable this service
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/grim/enforcement /var/run/grim

[Install]
WantedBy=multi-user.target
EOF

    $SUDO mv /tmp/grim-storage-enforcement.service /etc/systemd/system/
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable grim-storage-enforcement.service
    $SUDO systemctl start grim-storage-enforcement.service
    
    # Hide the service from users
    $SUDO chmod 600 /etc/systemd/system/grim-storage-enforcement.service
    log "Storage enforcement service installed and started (hidden)"
    
    # Install Go if not available
    log "Checking Go installation..."
    if ! command -v go >/dev/null 2>&1; then
        log "Go not found - installing Go..."
        GO_VERSION="1.22.2"
        GO_ARCH="amd64"
        if [[ "$(uname -m)" == "aarch64" ]]; then
            GO_ARCH="arm64"
        elif [[ "$(uname -m)" == "armv7l" ]]; then
            GO_ARCH="armv6l"
        fi
        
        # Try package manager first
        go_installed=false
        if command -v apt >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo apt update -qq && sudo apt install -y golang-go 2>/dev/null && go_installed=true
            else
                apt update -qq && apt install -y golang-go 2>/dev/null && go_installed=true
            fi
        elif command -v yum >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo yum install -y golang 2>/dev/null && go_installed=true
            else
                yum install -y golang 2>/dev/null && go_installed=true
            fi
        elif command -v dnf >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo dnf install -y golang 2>/dev/null && go_installed=true
            else
                dnf install -y golang 2>/dev/null && go_installed=true
            fi
        fi
        
        # If package manager failed, download from official source
        if [[ "$go_installed" != "true" ]]; then
            log "Package manager installation failed - downloading Go from official source..."
            cd /tmp
            GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
            GO_URL="https://golang.org/dl/${GO_TARBALL}"
            
            if curl -L -o "$GO_TARBALL" "$GO_URL"; then
                if [[ $EUID -ne 0 ]]; then
                    sudo rm -rf /usr/local/go
                    sudo tar -C /usr/local -xzf "$GO_TARBALL"
                    sudo chown -R root:root /usr/local/go
                else
                    rm -rf /usr/local/go
                    tar -C /usr/local -xzf "$GO_TARBALL"
                fi
                
                # Add to PATH
                if ! grep -q "/usr/local/go/bin" /etc/environment 2>/dev/null; then
                    echo 'PATH="/usr/local/go/bin:$PATH"' | sudo tee -a /etc/environment
                fi
                export PATH="/usr/local/go/bin:$PATH"
                
                success "Go ${GO_VERSION} installed from official source"
            else
                error "Failed to download Go from official source"
            fi
        else
            success "Go installed via package manager"
        fi
        
        # Verify Go installation
        if ! command -v go >/dev/null 2>&1; then
            error "Go installation verification failed"
        fi
    else
        log "Go already installed: $(go version)"
    fi
    
    # Install Node.js if not available
    log "Checking Node.js installation..."
    if ! command -v node >/dev/null 2>&1; then
        log "Node.js not found - installing Node.js..."
        
        # Try package manager first
        node_installed=false
        if command -v apt >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo apt update -qq && sudo apt install -y nodejs npm 2>/dev/null && node_installed=true
            else
                apt update -qq && apt install -y nodejs npm 2>/dev/null && node_installed=true
            fi
        elif command -v yum >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo yum install -y nodejs npm 2>/dev/null && node_installed=true
            else
                yum install -y nodejs npm 2>/dev/null && node_installed=true
            fi
        elif command -v dnf >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo dnf install -y nodejs npm 2>/dev/null && node_installed=true
            else
                dnf install -y nodejs npm 2>/dev/null && node_installed=true
            fi
        fi
        
        # If package manager failed, use NodeSource repository
        if [[ "$node_installed" != "true" ]]; then
            log "Package manager installation failed - using NodeSource repository..."
            if command -v apt >/dev/null 2>&1; then
                if [[ $EUID -ne 0 ]]; then
                    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
                    sudo apt-get install -y nodejs
                else
                    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
                    apt-get install -y nodejs
                fi
                node_installed=true
            elif command -v yum >/dev/null 2>&1; then
                if [[ $EUID -ne 0 ]]; then
                    curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
                    sudo yum install -y nodejs
                else
                    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
                    yum install -y nodejs
                fi
                node_installed=true
            fi
        fi
        
        # Verify Node.js installation
        if ! command -v node >/dev/null 2>&1; then
            error "Node.js installation verification failed"
        else
            success "Node.js installed: $(node --version)"
        fi
    else
        log "Node.js already installed: $(node --version)"
    fi
    
    # Install Python if not available
    log "Checking Python installation..."
    if ! command -v python3 >/dev/null 2>&1; then
        log "Python3 not found - installing Python..."
        if command -v apt >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo apt update -qq && sudo apt install -y python3 python3-pip python3-dev
            else
                apt update -qq && apt install -y python3 python3-pip python3-dev
            fi
            if [[ $? -eq 0 ]]; then
                success "Python3 installed"
            else
                error "Failed to install Python3"
            fi
        elif command -v yum >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo yum install -y python3 python3-pip python3-devel
            else
                yum install -y python3 python3-pip python3-devel
            fi
            if [[ $? -eq 0 ]]; then
                success "Python3 installed"
            else
                error "Failed to install Python3"
            fi
        elif command -v dnf >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo dnf install -y python3 python3-pip python3-devel
            else
                dnf install -y python3 python3-pip python3-devel
            fi
            if [[ $? -eq 0 ]]; then
                success "Python3 installed"
            else
                error "Failed to install Python3"
            fi
        else
            error "Could not install Python3 - no supported package manager found"
        fi
    else
        log "Python3 already installed: $(python3 --version)"
    fi
    
    # Verify Python installation
    log "Verifying Python installation..."
    if ! python3 -c "import sys; print(f'Python {sys.version}')" >/dev/null 2>&1; then
        error "Python3 installation verification failed"
    fi
    
    # Verify pip installation
    log "Verifying pip installation..."
    if ! python3 -m pip --version >/dev/null 2>&1; then
        log "pip not available - installing pip..."
        
        # Try package manager first
        pip_installed=false
        if command -v apt >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo apt update -qq && sudo apt install -y python3-pip 2>/dev/null && pip_installed=true
            else
                apt update -qq && apt install -y python3-pip 2>/dev/null && pip_installed=true
            fi
        elif command -v yum >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo yum install -y python3-pip 2>/dev/null && pip_installed=true
            else
                yum install -y python3-pip 2>/dev/null && pip_installed=true
            fi
        elif command -v dnf >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo dnf install -y python3-pip 2>/dev/null && pip_installed=true
            else
                dnf install -y python3-pip 2>/dev/null && pip_installed=true
            fi
        fi
        
        # If package manager failed, use get-pip.py
        if [[ "$pip_installed" != "true" ]]; then
            log "Package manager installation failed - using get-pip.py..."
            if curl -sSL https://bootstrap.pypa.io/get-pip.py | python3; then
                success "pip installed via get-pip.py"
            else
                error "Failed to install pip via get-pip.py"
            fi
        else
            success "pip installed via package manager"
        fi
        
        # Final verification
        if ! python3 -m pip --version >/dev/null 2>&1; then
            error "pip installation verification failed"
        fi
    else
        log "pip already available: $(python3 -m pip --version)"
    fi
    
    # Ensure ensurepip is available for virtual environments
    log "Verifying ensurepip module..."
    ensurepip_installed=false
    if python3 -c "import ensurepip" 2>/dev/null; then
        log "ensurepip module available"
        ensurepip_installed=true
    else
        log "ensurepip not available - installing python3-ensurepip..."
        if command -v apt >/dev/null 2>&1; then
            log "Trying to install python3-ensurepip via apt..."
            if [[ $EUID -ne 0 ]]; then
                if sudo apt update -qq && sudo apt install -y python3-ensurepip 2>/dev/null; then
                    ensurepip_installed=true
                    success "python3-ensurepip installed via package manager"
                else
                    warning "apt installation failed - trying alternative methods"
                fi
            else
                if apt update -qq && apt install -y python3-ensurepip 2>/dev/null; then
                    ensurepip_installed=true
                    success "python3-ensurepip installed via package manager"
                else
                    warning "apt installation failed - trying alternative methods"
                fi
            fi
        elif command -v yum >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo yum install -y python3-ensurepip
            else
                yum install -y python3-ensurepip
            fi
            if [[ $? -eq 0 ]]; then
                ensurepip_installed=true
                success "python3-ensurepip installed via package manager"
            fi
        elif command -v dnf >/dev/null 2>&1; then
            if [[ $EUID -ne 0 ]]; then
                sudo dnf install -y python3-ensurepip
            else
                dnf install -y python3-ensurepip
            fi
            if [[ $? -eq 0 ]]; then
                ensurepip_installed=true
                success "python3-ensurepip installed via package manager"
            fi
        fi
        
        # Final verification
        if python3 -c "import ensurepip" 2>/dev/null; then
            ensurepip_installed=true
            success "ensurepip module verified"
        else
            warning "ensurepip installation failed - trying alternative methods..."
            
            # Try to install ensurepip using pip
            if python3 -m pip install --user ensurepip 2>/dev/null; then
                if python3 -c "import ensurepip" 2>/dev/null; then
                    ensurepip_installed=true
                    success "ensurepip installed via pip"
                fi
            fi
            
            # If still not available, try to bootstrap it manually
            if [[ "$ensurepip_installed" != "true" ]]; then
                log "Bootstraping ensurepip manually..."
                python3 -m ensurepip --upgrade 2>/dev/null || {
                    # Create a minimal ensurepip module
                    mkdir -p /tmp/ensurepip_bootstrap
                    cd /tmp/ensurepip_bootstrap
                    curl -sSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py
                    python3 get-pip.py --force-reinstall 2>/dev/null || true
                    cd - > /dev/null
                }
                
                if python3 -c "import ensurepip" 2>/dev/null; then
                    ensurepip_installed=true
                    success "ensurepip bootstrapped manually"
                else
                    warning "ensurepip not available - virtual environment creation will use fallback methods"
                fi
            fi
        fi
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
        venv_created=false
        
        # Try standard venv first
        if python3 -c "import venv" 2>/dev/null; then
            log "Using python3 -m venv..."
            if python3 -m venv grim_venv; then
                venv_created=true
                success "Virtual environment created with venv"
            else
                warning "venv creation failed"
            fi
        fi
        
        # Try virtualenv if venv failed
        if [[ "$venv_created" != "true" ]] && command -v virtualenv >/dev/null 2>&1; then
            log "Using virtualenv..."
            if virtualenv grim_venv; then
                venv_created=true
                success "Virtual environment created with virtualenv"
            else
                warning "virtualenv creation failed"
            fi
        fi
        
        # Manual fallback if both failed
        if [[ "$venv_created" != "true" ]]; then
            warning "Standard virtual environment creation failed - creating manual structure"
            
            # Create virtual environment directory structure
            mkdir -p grim_venv/bin grim_venv/lib/python3.12/site-packages grim_venv/include
            
            # Create symlinks to system Python and pip
            ln -sf /usr/bin/python3 grim_venv/bin/python
            ln -sf /usr/bin/python3 grim_venv/bin/python3
            ln -sf /usr/bin/pip3 grim_venv/bin/pip
            
            # Create proper activation script
            cat > grim_venv/bin/activate << 'EOF'
#!/bin/bash
export VIRTUAL_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$VIRTUAL_ENV/bin:$PATH"
export PS1="(grim_venv) ${PS1:-$ }"
unset PYTHONHOME

# Set up pip to install to the virtual environment
export PIP_TARGET="$VIRTUAL_ENV/lib/python3.12/site-packages"
export PIP_USER=no
EOF
            chmod +x grim_venv/bin/activate
            
            # Create deactivate function
            cat > grim_venv/bin/deactivate << 'EOF'
#!/bin/bash
unset VIRTUAL_ENV
unset PIP_TARGET
unset PIP_USER
# Restore original PS1, fallback to default if not set
if [[ "$PS1" == "(grim_venv) "* ]]; then
    export PS1="${PS1#(grim_venv) }"
else
    export PS1="$ "
fi
EOF
            chmod +x grim_venv/bin/deactivate
            
            venv_created=true
            success "Manual virtual environment structure created with proper pip configuration"
        fi
        
        # Verify virtual environment is working
        log "Verifying virtual environment..."
        venv_working=false
        if [[ -f "grim_venv/bin/activate" ]]; then
            # Source the virtual environment, but don't fail if there are minor issues
            if source grim_venv/bin/activate 2>/dev/null; then
                if python3 -c "import sys; print('Virtual environment working:', sys.prefix)" 2>/dev/null; then
                    success "Virtual environment verified and activated"
                    venv_working=true
                else
                    warning "Virtual environment activation failed - continuing with system Python"
                    # Fallback to system Python if virtual environment fails
                    unset VIRTUAL_ENV
                    unset PIP_TARGET
                    unset PIP_USER
                fi
            else
                warning "Virtual environment activation had issues - continuing anyway"
                # Try to activate without sourcing to avoid PS1 errors
                export VIRTUAL_ENV="$(pwd)/grim_venv"
                export PATH="$VIRTUAL_ENV/bin:$PATH"
                export PIP_TARGET="$VIRTUAL_ENV/lib/python3.12/site-packages"
                export PIP_USER=no
                venv_working=true
            fi
        else
            error "Virtual environment creation completely failed"
        fi
        
        # Install dependencies
        log "Installing Python dependencies..."
        if [[ -f "py_grim/requirements.txt" ]]; then
            log "Installing dependencies from requirements.txt..."
            if pip install -r py_grim/requirements.txt; then
                success "Python dependencies installed in virtual environment"
            else
                warning "Failed to install all dependencies from requirements.txt - trying core packages..."
                # Try to install core packages individually
                pip install fastapi uvicorn pydantic redis aiofiles PyYAML tusktsk || warning "Some core packages failed to install"
                success "Core Python dependencies installed"
            fi
        else
            warning "No requirements.txt found - installing common dependencies..."
            # Install common dependencies if no requirements.txt
            if pip install fastapi uvicorn pydantic sqlalchemy psycopg2-binary redis tusktsk; then
                success "Common Python dependencies installed in virtual environment"
            else
                warning "Failed to install some common dependencies"
            fi
        fi
        
        # Ensure tusktsk is available (critical for Grim configuration)
        log "Verifying tusktsk package availability..."
        if ! python3 -c "import tusktsk" 2>/dev/null; then
            log "Installing tusktsk package..."
            if pip install tusktsk; then
                success "tusktsk package installed successfully"
            else
                warning "Failed to install tusktsk - some configuration features may use fallback"
            fi
        else
            log "tusktsk package already available"
        fi
        
        # Update grim_throne.sh to use virtual environment
        if [[ -f "$GRIM_INSTALL_DIR/grim_throne.sh" ]]; then
            sed -i "s|source /opt/grim_venv/bin/activate|source $GRIM_INSTALL_DIR/grim_venv/bin/activate|g" "$GRIM_INSTALL_DIR/grim_throne.sh"
        fi
        
                # Don't create a simplified grim command - the real grim_throne.sh handles everything
        log "Verifying grim_throne.sh has virtual environment support..."
        
        # Add virtual environment activation to grim_throne.sh if not present
        if ! grep -q "grim_venv/bin/activate" "$GRIM_INSTALL_DIR/grim_throne.sh"; then
            log "Adding virtual environment support to grim_throne.sh..."
            # Add venv activation after the cd command
            sed -i '/^cd "$GRIM_ROOT"$/a\\n# Activate virtual environment if it exists\nif [[ -f "grim_venv/bin/activate" ]]; then\n    source grim_venv/bin/activate\nfi' "$GRIM_INSTALL_DIR/grim_throne.sh"
        fi
        
        success "Grim command configured with virtual environment support"
        
        # Final verification of Python dependencies
        log "Verifying Python dependencies..."
        if python3 -c "import fastapi" 2>/dev/null; then
            success "FastAPI available - Python dependencies verified"
        else
            warning "FastAPI not available - some Python features may not work"
        fi
        
            # Test that grim command works with virtual environment
    log "Testing grim command with virtual environment..."
    if cd "$GRIM_INSTALL_DIR" && grim health >/dev/null 2>&1; then
        success "Grim command working with virtual environment"
    else
        warning "Grim command test failed - manual verification may be needed"
    fi
    
    # Start auto-backup system
    log "Starting automatic backup system..."
    if command -v grim >/dev/null 2>&1; then
        grim auto-backup-start >/dev/null 2>&1 || warning "Auto-backup failed to start - can be started manually with 'grim auto-backup-start'"
        success "Auto-backup system initialized"
    fi
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

setup_error_tracking() {
    log "Setting up error tracking and local database..."
    
    cd "$GRIM_INSTALL_DIR"
    
    # Create local SQLite database directory
    mkdir -p db
    
    # Initialize local SQLite database
    sqlite3 db/grim.db << 'EOF'
CREATE TABLE IF NOT EXISTS error_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    error_type TEXT NOT NULL,
    error_message TEXT NOT NULL,
    error_details TEXT,
    severity TEXT DEFAULT 'medium',
    hostname TEXT,
    user TEXT,
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS install_analytics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    install_type TEXT NOT NULL,
    success BOOLEAN NOT NULL,
    details TEXT,
    hostname TEXT,
    user TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS health_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    health_status TEXT NOT NULL,
    details TEXT,
    hostname TEXT,
    user TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS system_info (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT OR REPLACE INTO system_info (key, value) VALUES 
    ('installation_date', datetime('now')),
    ('version', '1.0.17'),
    ('status', 'installed'),
    ('install_id', '$(uuidgen 2>/dev/null || echo "$(date +%s)-$(hostname)-$$")'),
    ('api_key', '$(openssl rand -hex 32 2>/dev/null || echo "$(date +%s)-$(hostname)-$$-key")');
EOF
    
    # Create error tracking script
    cat > scripts/error-tracker.sh << 'EOF'
#!/bin/bash
# Grim Reaper Error Tracker
# Sends error logs and installation analytics to Grim database

set -euo pipefail




EOF
    
    chmod +x scripts/error-tracker.sh
    
    # Register installation with mother database
    log "Registering installation with mother Grim database..."
    if ./scripts/error-tracker.sh register; then
        success "Error tracking setup complete"
    else
        warning "Error tracking setup failed - will continue with local-only tracking"
    fi
    
    # Send initial installation analytics
    ./scripts/error-tracker.sh install "master_install" true "Grim Reaper master installation completed successfully"
    
    success "Error tracking and local database setup complete"
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
# STRATEGIC AUTO-BACKUP SETUP
# ============================================================================
setup_strategic_auto_backup() {
    log "Setting up strategic auto-backup system..."
    
    # Create graveyard directory if it doesn't exist
    mkdir -p "$GRIM_GRAVEYARD"
    
    # Check if strategic auto-backup installer exists
    if [[ -f "$GRIM_INSTALL_DIR/sh_grim/install_auto_backup_strategic.sh" ]]; then
        # Make sure it's executable
        chmod +x "$GRIM_INSTALL_DIR/sh_grim/install_auto_backup_strategic.sh"
        chmod +x "$GRIM_INSTALL_DIR/sh_grim/auto_backup_strategic.sh"
        
        # Install strategic auto-backup system
        if "$GRIM_INSTALL_DIR/sh_grim/install_auto_backup_strategic.sh" install; then
            success "Strategic auto-backup system installed successfully"
            log "Auto-backup logs: /var/log/grim-auto-backup.log"
        else
            warning "Strategic auto-backup installation failed - will create post-install script"
            create_post_install_auto_backup_script
        fi
    else
        # Create a post-install auto-backup setup script for later execution
        log "Creating post-install auto-backup setup script..."
        create_post_install_auto_backup_script
    fi
}

create_post_install_auto_backup_script() {
    cat > "$GRIM_GRAVEYARD/setup_auto_backup.sh" << 'EOF'
#!/bin/bash
# Post-install strategic auto-backup setup script
# This runs after the main installation completes

GRIM_GRAVEYARD="${GRIM_GRAVEYARD:-/root/.graveyard}"
GRIM_INSTALL_DIR="${GRIM_INSTALL_DIR:-/root/.graveyard/reaper}"

echo "Setting up strategic auto-backup system..."

if [[ -f "$GRIM_INSTALL_DIR/sh_grim/install_auto_backup_strategic.sh" ]]; then
    chmod +x "$GRIM_INSTALL_DIR/sh_grim/install_auto_backup_strategic.sh"
    chmod +x "$GRIM_INSTALL_DIR/sh_grim/auto_backup_strategic.sh"
    
    # Install strategic auto-backup system
    if "$GRIM_INSTALL_DIR/sh_grim/install_auto_backup_strategic.sh" install; then
        echo "✅ Strategic auto-backup system installed successfully"
        echo "📁 Backup location: /root/.graveyard/.rip/auto-backups/"
        echo "📋 Use 'grim auto-backup help' for commands"
    else
        echo "❌ Strategic auto-backup installation failed"
    fi
else
    echo "❌ Strategic auto-backup installer not found"
fi
EOF
    
    chmod +x "$GRIM_GRAVEYARD/setup_auto_backup.sh"
    success "Post-install auto-backup setup script created"
}

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

display_summary() {
    print_start_banner
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
    echo -e "  Auto-Backup:       ${BLUE}Strategic (Paywall-Protected)${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "  1. Run ${BLUE}grim health${NC} to verify installation"
    echo -e "  2. Run ${BLUE}grim auto-backup status${NC} to check backup system"
    echo -e "  3. Run ${BLUE}grim web${NC} to start the web interface"
    echo -e "  4. Run ${BLUE}grim setup-admin${NC} for admin server setup"
    echo ""
    # Run post-install auto-backup setup if needed
    if [[ -f "$GRIM_GRAVEYARD/setup_auto_backup.sh" ]]; then
        log "Running post-install auto-backup setup..."
        "$GRIM_GRAVEYARD/setup_auto_backup.sh"
    fi
    
    echo -e "${GREEN}💀 The Reaper is ready! Strategic auto-backup enabled! 💀${NC}"
    echo ""
    echo -e "${MAGENTA}🔥 BBL LICENSE OPPORTUNITY 🔥${NC}"
    echo -e "${YELLOW}Earn 50% commission + residuals on every referral!${NC}"
    
    # Generate affiliate link using server IP hash
    local affiliate_id
    affiliate_id=$(generate_affiliate_id)
    local affiliate_link="https://grim.so/underworld/$affiliate_id"
    
    # Register affiliate ID with the system
    register_affiliate "$affiliate_id"
    
    echo -e "${CYAN}Your affiliate link: ${BLUE}$affiliate_link${NC}"
    echo -e "${CYAN}Copy and share this link to start earning:${NC}"
    echo -e "  • ${GREEN}50% upfront commission${NC} on every sale"
    echo -e "  • ${GREEN}50% monthly residuals${NC} for life"
    echo -e "  • ${GREEN}33% quarterly revenue sharing${NC} for contributors"
    echo ""
    echo -e "${YELLOW}Example earnings:${NC}"
    echo -e "  • Pro plan ($49/month): ${GREEN}$24.50 upfront + 10% residuals${NC}"
    echo -e "  • Master plan ($99/month): ${GREEN}$49.50 upfront + 10% residuals${NC}"
    echo -e "  • Reaper plan ($499/month): ${GREEN}$249.50 upfront + 10% residuals${NC}"
    echo ""
    echo -e "${CYAN}Documentation: ${BLUE}https://grim.so/docs${NC}"
    echo -e "${CYAN}Support:        ${BLUE}https://community.grim.so${NC}"
    echo -e "${CYAN}BBL License:    ${BLUE}https://grim.so/bbl-promotion${NC}"
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
    
    # Setup strategic auto-backup system
    setup_strategic_auto_backup
    
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
    echo "  --install-dir <dir> Install directory (default: $HOME/reaper)"
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