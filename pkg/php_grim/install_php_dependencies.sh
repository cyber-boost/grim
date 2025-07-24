#!/bin/bash
# Grim Reaper PHP Package Dependency Installation Script
# Handles system dependencies, Go installation, and binary building for PHP package

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Auto-detect GRIM_ROOT based on script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$SCRIPT_DIR"

error() {
    echo -e "${RED}❌ $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        warning "Running as root - this is fine for system-wide installation"
    else
        warning "Not running as root - some operations may require sudo"
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        OS_ID=$ID
    else
        error "Cannot detect operating system"
    fi
}

check_php_requirements() {
    info "Checking PHP requirements..."
    
    # Check PHP version
    if ! command -v php &> /dev/null; then
        error "PHP is not installed. Please install PHP 8.1 or higher."
    fi
    
    PHP_VERSION=$(php -r "echo PHP_VERSION;")
    if [[ ! "$PHP_VERSION" =~ ^8\.[1-9] ]] && [[ ! "$PHP_VERSION" =~ ^[9-9] ]]; then
        error "PHP 8.1 or higher is required. Current version: $PHP_VERSION"
    fi
    
    success "PHP version: $PHP_VERSION"
    
    # Check required extensions
    REQUIRED_EXTENSIONS=("json" "curl" "openssl" "zip")
    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        if php -m | grep -q "^$ext$"; then
            success "PHP extension: $ext"
        else
            error "Required PHP extension not loaded: $ext"
        fi
    done
}

install_system_dependencies() {
    info "Installing system dependencies..."
    
    case $OS_ID in
        "ubuntu"|"debian")
            sudo apt update
            sudo apt install -y \
                rsync tar gzip bzip2 xz-utils openssl \
                curl wget ssh-client scp findutils \
                build-essential git python3 python3-pip \
                php-cli php-json php-curl php-openssl php-zip
            ;;
        "centos"|"rhel"|"fedora")
            sudo yum update -y
            sudo yum install -y \
                rsync tar gzip bzip2 xz openssl \
                curl wget openssh-clients findutils \
                gcc gcc-c++ make git python3 python3-pip \
                php-cli php-json php-curl php-openssl php-zip
            ;;
        *)
            warning "Unknown OS: $OS - please install dependencies manually"
            echo "Required packages: rsync tar gzip bzip2 xz openssl curl wget ssh scp find du df php-cli php-json php-curl php-openssl php-zip"
            ;;
    esac
    
    success "System dependencies installed"
}

install_go() {
    info "Checking Go installation..."
    
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}')
        info "Go is already installed: $GO_VERSION"
        return 0
    fi
    
    info "Installing Go..."
    
    # Download and install Go
    GO_VERSION="1.21.0"
    GO_ARCH="linux-amd64"
    GO_URL="https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz"
    
    cd /tmp
    curl -LO "$GO_URL"
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.${GO_ARCH}.tar.gz"
    
    # Add Go to PATH
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    success "Go installed successfully"
}

setup_grim_directory() {
    info "Setting up Grim Reaper directory..."
    
    # Create necessary directories
    DIRS=(
        "$GRIM_ROOT/bin"
        "$GRIM_ROOT/config"
        "$GRIM_ROOT/logs"
        "$GRIM_ROOT/backups"
        "$GRIM_ROOT/temp"
        "$GRIM_ROOT/throne"
    )
    
    for dir in "${DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            success "Created directory: $dir"
        fi
    done
    
    success "Grim directory structure created"
}

build_go_binaries() {
    info "Building Go binaries..."
    
    if [[ ! -d "$GRIM_ROOT/go_grim" ]]; then
        warning "Go source directory not found: $GRIM_ROOT/go_grim"
        warning "Go binaries will not be available"
        return 0
    fi
    
    cd "$GRIM_ROOT/go_grim"
    
    # Ensure Go modules are downloaded
    if [[ -f "go.mod" ]]; then
        go mod download
    fi
    
    # Build binaries
    if [[ -f Makefile ]]; then
        make build
    elif [[ -d "cmd/compression" ]]; then
        mkdir -p build
        go build -o build/grim-compression ./cmd/compression
    else
        warning "No build configuration found for Go binaries"
    fi
    
    success "Go binaries built successfully"
}

install_composer_dependencies() {
    info "Installing Composer dependencies..."
    
    if [[ ! -f "$GRIM_ROOT/composer.json" ]]; then
        warning "composer.json not found - skipping Composer dependencies"
        return 0
    fi
    
    if command -v composer &> /dev/null; then
        cd "$GRIM_ROOT"
        composer install --no-dev --optimize-autoloader
        success "Composer dependencies installed"
    else
        warning "Composer not found - please install Composer manually"
    fi
}

create_php_wrapper() {
    info "Creating PHP wrapper..."
    
    GRIM_BIN="$GRIM_ROOT/bin/grim"
    
    if [[ ! -f "$GRIM_BIN" ]]; then
        cat > "$GRIM_BIN" << 'EOF'
#!/usr/bin/env php
<?php

/**
 * Grim Reaper PHP CLI Entry Point
 * 
 * This script serves as the main entry point for the Grim Reaper PHP package.
 * It handles command routing and delegates to the appropriate throne script.
 */

// Prevent direct web access
if (php_sapi_name() !== 'cli') {
    die('This script can only be run from the command line.');
}

// Autoloader setup
$autoloadFiles = [
    __DIR__ . '/../vendor/autoload.php',
    __DIR__ . '/../../autoload.php',
    __DIR__ . '/../../../autoload.php'
];

$autoloaderLoaded = false;
foreach ($autoloadFiles as $autoloadFile) {
    if (file_exists($autoloadFile)) {
        require_once $autoloadFile;
        $autoloaderLoaded = true;
        break;
    }
}

if (!$autoloaderLoaded) {
    die("❌ Composer autoloader not found. Please run 'composer install' first.\n");
}

use GrimReaper\GrimCLI;

// Run the CLI application
$cli = new GrimCLI();
$cli->run($argv);
EOF
        
        chmod +x "$GRIM_BIN"
        success "PHP wrapper created: $GRIM_BIN"
    fi
}

create_global_symlinks() {
    info "Creating global symlinks..."
    
    GRIM_BIN="$GRIM_ROOT/bin/grim"
    GLOBAL_BIN="/usr/local/bin/grim"
    
    if [[ -f "$GRIM_BIN" ]] && [[ ! -f "$GLOBAL_BIN" ]]; then
        if sudo ln -sf "$GRIM_BIN" "$GLOBAL_BIN"; then
            success "Global symlink created: $GLOBAL_BIN"
        else
            warning "Failed to create global symlink (may need manual sudo)"
        fi
    fi
}

verify_installation() {
    info "Verifying installation..."
    
    # Check if grim command is available
    if command -v grim &> /dev/null; then
        success "Grim command is available"
    else
        warning "Grim command not found in PATH"
    fi
    
    # Check if throne script exists
    if [[ -f "$GRIM_ROOT/throne/php_grim_throne.sh" ]]; then
        success "Throne script found"
    else
        error "Throne script not found"
    fi
    
    # Check if PHP wrapper exists
    if [[ -f "$GRIM_ROOT/bin/grim" ]]; then
        success "PHP wrapper found"
    else
        error "PHP wrapper not found"
    fi
    
    success "Installation verification complete"
}

main() {
    echo -e "${CYAN}🗡️  Grim Reaper PHP Package Dependency Installation${NC}"
    echo "=========================================================="
    
    check_root
    detect_os
    info "Detected OS: $OS $VER"
    
    check_php_requirements
    install_system_dependencies
    install_go
    setup_grim_directory
    build_go_binaries
    install_composer_dependencies
    create_php_wrapper
    create_global_symlinks
    verify_installation
    
    echo ""
    echo -e "${GREEN}🎉 Grim Reaper PHP package installation completed successfully!${NC}"
    echo ""
    echo "Usage:"
    echo "  grim help          - Show available commands"
    echo "  grim check-deps    - Verify dependencies"
    echo "  grim backup        - Start backup operations"
    echo "  grim monitor       - Monitor system health"
    echo ""
    echo "For more information: https://grim.so"
}

main "$@" 