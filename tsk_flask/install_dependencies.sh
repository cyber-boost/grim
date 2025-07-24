#!/bin/bash
# Grim Reaper Dependency Installation Script
# Handles system dependencies, Go installation, and binary building

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

GRIM_ROOT="/opt/reaper"

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
    else
        error "Cannot detect operating system"
    fi
}

install_system_dependencies() {
    info "Installing system dependencies..."
    
    case $OS in
        "Ubuntu"|"Debian GNU/Linux")
            sudo apt update
            sudo apt install -y \
                rsync tar gzip bzip2 xz-utils openssl \
                curl wget ssh-client scp findutils \
                build-essential git
            ;;
        "CentOS Linux"|"Red Hat Enterprise Linux")
            sudo yum update -y
            sudo yum install -y \
                rsync tar gzip bzip2 xz openssl \
                curl wget openssh-clients findutils \
                gcc gcc-c++ make git
            ;;
        *)
            warning "Unknown OS: $OS - please install dependencies manually"
            echo "Required packages: rsync tar gzip bzip2 xz openssl curl wget ssh scp find du df"
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
    
    sudo mkdir -p "$GRIM_ROOT"
    sudo chown $USER:$USER "$GRIM_ROOT"
    
    success "Grim directory created: $GRIM_ROOT"
}

build_go_binaries() {
    info "Building Go binaries..."
    
    if [[ ! -d "$GRIM_ROOT/go_grim" ]]; then
        error "Go source directory not found: $GRIM_ROOT/go_grim"
    fi
    
    cd "$GRIM_ROOT/go_grim"
    
    # Ensure Go modules are downloaded
    go mod download
    
    # Build binaries
    if [[ -f Makefile ]]; then
        make build
    else
        go build -o build/grim-compression ./cmd/compression
    fi
    
    success "Go binaries built successfully"
}

install_python_package() {
    info "Installing Python package..."
    
    # Install the grim-reaper package
    pip install grim-reaper
    
    success "Python package installed"
}

verify_installation() {
    info "Verifying installation..."
    
    # Check if grim command is available
    if command -v grim &> /dev/null; then
        success "Grim command is available"
    else
        error "Grim command not found in PATH"
    fi
    
    # Check dependencies
    grim check-deps
    
    success "Installation verification complete"
}

main() {
    echo -e "${CYAN}🗡️  Grim Reaper Dependency Installation${NC}"
    echo "================================================"
    
    check_root
    detect_os
    info "Detected OS: $OS $VER"
    
    install_system_dependencies
    install_go
    setup_grim_directory
    build_go_binaries
    install_python_package
    verify_installation
    
    echo ""
    echo -e "${GREEN}🎉 Grim Reaper installation completed successfully!${NC}"
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