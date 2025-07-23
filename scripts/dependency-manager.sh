#!/bin/bash
# Grim Reaper Dependency Manager
# Automatically detects and installs required dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

error() {
    echo -e "${RED}❌ $1${NC}" >&2
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

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/debian_version ]]; then
            echo "debian"
        elif [[ -f /etc/redhat-release ]]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Python installation
check_python() {
    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        echo "python3:$PYTHON_VERSION"
    elif command_exists python; then
        PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
        echo "python:$PYTHON_VERSION"
    else
        echo "missing"
    fi
}

# Check Go installation
check_go() {
    if command_exists go; then
        GO_VERSION=$(go version | cut -d' ' -f3 | sed 's/go//')
        echo "go:$GO_VERSION"
    else
        echo "missing"
    fi
}

# Check Node.js installation
check_node() {
    if command_exists node; then
        NODE_VERSION=$(node --version | sed 's/v//')
        echo "node:$NODE_VERSION"
    else
        echo "missing"
    fi
}

# Install Python on Debian/Ubuntu
install_python_debian() {
    info "Installing Python 3 on Debian/Ubuntu..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv
    success "Python 3 installed successfully"
}

# Install Python on RedHat/CentOS
install_python_redhat() {
    info "Installing Python 3 on RedHat/CentOS..."
    sudo yum update -y
    sudo yum install -y python3 python3-pip
    success "Python 3 installed successfully"
}

# Install Python on macOS
install_python_macos() {
    info "Installing Python 3 on macOS..."
    if command_exists brew; then
        brew install python3
    else
        warning "Homebrew not found. Please install Python 3 manually from https://www.python.org/"
        return 1
    fi
    success "Python 3 installed successfully"
}

# Install Go on Debian/Ubuntu
install_go_debian() {
    info "Installing Go on Debian/Ubuntu..."
    sudo apt-get update
    sudo apt-get install -y golang-go
    success "Go installed successfully"
}

# Install Go on RedHat/CentOS
install_go_redhat() {
    info "Installing Go on RedHat/CentOS..."
    sudo yum update -y
    sudo yum install -y golang
    success "Go installed successfully"
}

# Install Go on macOS
install_go_macos() {
    info "Installing Go on macOS..."
    if command_exists brew; then
        brew install go
    else
        warning "Homebrew not found. Installing Go manually..."
        # Download and install Go manually
        GO_VERSION="1.21.0"
        curl -O "https://golang.org/dl/go${GO_VERSION}.darwin-amd64.pkg"
        sudo installer -pkg "go${GO_VERSION}.darwin-amd64.pkg" -target /
        rm "go${GO_VERSION}.darwin-amd64.pkg"
    fi
    success "Go installed successfully"
}

# Install Python dependencies
install_python_deps() {
    info "Installing Python dependencies..."
    
    # Track dependency installation start (graceful - don't fail if error tracker fails)
    if [[ -f "scripts/error-tracker.sh" ]]; then
        ./scripts/error-tracker.sh dependency python_deps true || true
    fi
    
    # Check if we're in an externally managed environment (PEP 668)
    if python3 -c "import sys; print('externally-managed' in sys.modules)" 2>/dev/null || python3 -m pip --version 2>&1 | grep -q "externally-managed-environment"; then
        warning "Detected externally managed Python environment (PEP 668)"
        info "Creating virtual environment for Grim Reaper..."
        
        # Create virtual environment in Grim Reaper directory
        GRIM_DIR="/opt/grim-reaper"
        VENV_DIR="$GRIM_DIR/venv"
        
        if [[ ! -d "$VENV_DIR" ]]; then
            python3 -m venv "$VENV_DIR"
            success "Created virtual environment at $VENV_DIR"
        fi
        
        # Activate virtual environment and install dependencies
        source "$VENV_DIR/bin/activate"
        
        if [[ -f "py_grim/requirements.txt" ]]; then
            pip install -r py_grim/requirements.txt
            success "Python dependencies installed in virtual environment"
        else
            warning "requirements.txt not found, installing basic dependencies..."
            pip install flask requests psutil
            success "Basic Python dependencies installed in virtual environment"
        fi
        
        # Deactivate virtual environment
        deactivate
        
        # Create activation script for Grim Reaper
        cat > "$GRIM_DIR/activate_venv.sh" << 'EOF'
#!/bin/bash
# Activate Grim Reaper virtual environment
source /opt/grim-reaper/venv/bin/activate
EOF
        chmod +x "$GRIM_DIR/activate_venv.sh"
        
    else
        # Standard installation
        if [[ -f "py_grim/requirements.txt" ]]; then
            python3 -m pip install --user -r py_grim/requirements.txt
            success "Python dependencies installed successfully"
        else
            warning "requirements.txt not found, installing basic dependencies..."
            python3 -m pip install --user flask requests psutil
            success "Basic Python dependencies installed"
        fi
    fi
    
    # Track successful dependency installation (graceful - don't fail if error tracker fails)
    if [[ -f "scripts/error-tracker.sh" ]]; then
        ./scripts/error-tracker.sh dependency python_deps true || true
    fi
}

# Install Go dependencies
install_go_deps() {
    info "Installing Go dependencies..."
    
    # Track dependency installation start (graceful - don't fail if error tracker fails)
    if [[ -f "scripts/error-tracker.sh" ]]; then
        ./scripts/error-tracker.sh dependency go_deps true || true
    fi
    
    # Find the go_grim directory relative to the current script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    GO_GRIM_DIR="$PROJECT_ROOT/go_grim"
    
    if [[ -d "$GO_GRIM_DIR" ]]; then
        cd "$GO_GRIM_DIR"
        
        # Check if go.mod exists
        if [[ -f "go.mod" ]]; then
            info "Found go.mod, downloading dependencies..."
            # Try to download dependencies (graceful if it fails)
            go mod download 2>/dev/null || warning "No Go dependencies to download or download failed"
        else
            warning "go.mod not found, creating basic module..."
            go mod init grim-reaper/go_grim
        fi
        
        # Build binaries if source exists
        if [[ -d "cmd/compression" ]]; then
            info "Building grim-compression..."
            go build -o build/grim-compression ./cmd/compression 2>/dev/null || warning "Failed to build grim-compression"
        fi
        
        if [[ -d "cmd/scanner" ]]; then
            info "Building grim-scanner..."
            go build -o build/grim-scanner ./cmd/scanner 2>/dev/null || warning "Failed to build grim-scanner"
        fi
        
        if [[ -d "cmd/transfer" ]]; then
            info "Building grim-transfer..."
            go build -o build/grim-transfer ./cmd/transfer 2>/dev/null || warning "Failed to build grim-transfer"
        fi
        
        cd "$PROJECT_ROOT"
        success "Go dependencies processed successfully"
    else
        warning "go_grim directory not found at $GO_GRIM_DIR"
    fi
    
    # Track successful dependency installation (graceful - don't fail if error tracker fails)
    if [[ -f "scripts/error-tracker.sh" ]]; then
        ./scripts/error-tracker.sh dependency go_deps true || true
    fi
}

# Main dependency check and install function
check_and_install_dependencies() {
    echo -e "${CYAN}🗡️  Grim Reaper Dependency Check${NC}"
    echo "=================================================="
    
    OS=$(detect_os)
    info "Detected OS: $OS"
    
    # Check current installations
    PYTHON_STATUS=$(check_python)
    GO_STATUS=$(check_go)
    NODE_STATUS=$(check_node)
    
    echo ""
    echo "Current Dependencies:"
    echo "  Python: $PYTHON_STATUS"
    echo "  Go: $GO_STATUS"
    echo "  Node.js: $NODE_STATUS"
    echo ""
    
    MISSING_DEPS=()
    
    # Check Python
    if [[ "$PYTHON_STATUS" == "missing" ]]; then
        warning "Python 3 is required but not installed"
        MISSING_DEPS+=("python")
    else
        success "Python is available: $PYTHON_STATUS"
    fi
    
    # Check Go
    if [[ "$GO_STATUS" == "missing" ]]; then
        warning "Go is required but not installed"
        MISSING_DEPS+=("go")
    else
        success "Go is available: $GO_STATUS"
    fi
    
    # Check Node.js
    if [[ "$NODE_STATUS" == "missing" ]]; then
        warning "Node.js is required but not installed"
        MISSING_DEPS+=("node")
    else
        success "Node.js is available: $NODE_STATUS"
    fi
    
    # Install missing dependencies
    if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
        echo ""
        warning "Missing dependencies detected: ${MISSING_DEPS[*]}"
        echo ""
        
        read -p "Would you like to install missing dependencies automatically? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            info "Installing missing dependencies..."
            
            for dep in "${MISSING_DEPS[@]}"; do
                case $dep in
                    "python")
                        case $OS in
                            "debian") install_python_debian ;;
                            "redhat") install_python_redhat ;;
                            "macos") install_python_macos ;;
                            *) error "Unsupported OS for Python installation" ;;
                        esac
                        ;;
                    "go")
                        case $OS in
                            "debian") install_go_debian ;;
                            "redhat") install_go_redhat ;;
                            "macos") install_go_macos ;;
                            *) error "Unsupported OS for Go installation" ;;
                        esac
                        ;;
                    "node")
                        error "Node.js installation not automated. Please install from https://nodejs.org/"
                        ;;
                esac
            done
            
            echo ""
            info "Installing language-specific dependencies..."
            install_python_deps
            install_go_deps
            
            echo ""
            success "Dependency installation complete!"
            echo ""
            info "Running final dependency check..."
            check_and_install_dependencies
        else
            echo ""
            error "Dependencies not installed. Grim Reaper may not work correctly."
            echo "Please install the following manually:"
            for dep in "${MISSING_DEPS[@]}"; do
                echo "  - $dep"
            done
            exit 1
        fi
    else
        echo ""
        success "All required dependencies are available!"
        echo ""
        info "Installing/updating language-specific dependencies..."
        install_python_deps
        install_go_deps
        echo ""
        success "Grim Reaper is ready to use! 🗡️"
    fi
}

# Run dependency check
check_and_install_dependencies 