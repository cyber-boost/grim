#!/bin/bash
# 🗡️ GRIM Build Script
# Builds and prepares all Grim components for npm distribution

set -e

echo "🗡️  Building Grim System v1.0.1..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create necessary directories
print_status "Creating build directories..."
mkdir -p scripts
mkdir -p dist
mkdir -p docs

# Copy and prepare JavaScript component
print_status "Preparing JavaScript CLI..."
if [ -f "js_grim/grim.js" ]; then
    cp js_grim/grim.js dist/
    chmod +x dist/grim.js
    print_success "JavaScript CLI prepared"
else
    print_error "js_grim/grim.js not found!"
    exit 1
fi

# Copy and prepare Bash scripts
print_status "Preparing Bash components..."
if [ -d "sh_grim" ]; then
    cp -r sh_grim dist/
    find dist/sh_grim -name "*.sh" -exec chmod +x {} \;
    print_success "Bash components prepared"
else
    print_warning "sh_grim directory not found"
fi

# Copy and prepare Python components
print_status "Preparing Python components..."
if [ -d "py_grim" ]; then
    cp -r py_grim dist/
    print_success "Python components prepared"
else
    print_warning "py_grim directory not found"
fi

# Copy and prepare Go components
print_status "Preparing Go components..."
if [ -d "go_grim" ]; then
    cp -r go_grim dist/
    print_success "Go components prepared"
else
    print_warning "go_grim directory not found"
fi

# Copy and prepare Scythe component
print_status "Preparing Scythe component..."
if [ -d "scythe" ]; then
    cp -r scythe dist/
    print_success "Scythe component prepared"
else
    print_warning "scythe directory not found"
fi

# Copy ASCII art
print_status "Preparing ASCII art..."
if [ -d "ascii" ]; then
    cp -r ascii dist/
    print_success "ASCII art prepared"
else
    print_warning "ascii directory not found"
fi

# Copy configuration files
print_status "Preparing configuration files..."
if [ -d "config" ]; then
    cp -r config dist/
    print_success "Configuration files prepared"
else
    print_warning "config directory not found"
fi

# Create postinstall script
print_status "Creating postinstall script..."
cat > scripts/postinstall.sh << 'EOF'
#!/bin/bash
# 🗡️ GRIM Post-Install Script
# Runs after npm install to set up the Grim system

set -e

echo "🗡️  Setting up Grim system..."

# Create necessary directories
sudo mkdir -p /opt/grim-reaper
sudo mkdir -p /etc/grim-reaper
sudo mkdir -p /var/log/grim
sudo mkdir -p /backups

# Set permissions
sudo chown -R root:root /opt/grim-reaper
sudo chown -R root:root /etc/grim-reaper
sudo chmod -R 755 /opt/grim-reaper
sudo chmod -R 644 /etc/grim-reaper

# Create log directory with proper permissions
sudo chown -R root:root /var/log/grim
sudo chmod -R 755 /var/log/grim

# Create backup directory
sudo chown -R root:root /backups
sudo chmod -R 755 /backups

# Copy configuration files if they exist
if [ -d "config" ]; then
    sudo cp -r config/* /etc/grim-reaper/ 2>/dev/null || true
fi

# Copy components to installation directory
if [ -d "sh_grim" ]; then
    sudo cp -r sh_grim /opt/grim-reaper/
fi

if [ -d "py_grim" ]; then
    sudo cp -r py_grim /opt/grim-reaper/
fi

if [ -d "go_grim" ]; then
    sudo cp -r go_grim /opt/grim-reaper/
fi

if [ -d "scythe" ]; then
    sudo cp -r scythe /opt/grim-reaper/
fi

if [ -d "ascii" ]; then
    sudo cp -r ascii /opt/grim-reaper/
fi

# Set executable permissions
sudo find /opt/grim-reaper -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
sudo find /opt/grim-reaper -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

echo "✅ Grim system setup complete!"
echo "📁 Installation directory: /opt/grim-reaper"
echo "📁 Configuration directory: /etc/grim-reaper"
echo "📁 Log directory: /var/log/grim"
echo "📁 Backup directory: /backups"
echo ""
echo "🚀 You can now use: grim --help"
EOF

chmod +x scripts/postinstall.sh
print_success "Postinstall script created"

# Create installation script
print_status "Creating installation script..."
cat > install.sh << 'EOF'
#!/bin/bash
# 🗡️ GRIM Installation Script
# Installs Grim system globally

set -e

echo "🗡️  Installing Grim System..."

# Function to install Node.js automatically
install_nodejs() {
    echo "Node.js not found. Installing Node.js 18 LTS automatically..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        echo "Installing Node.js via apt (Debian/Ubuntu)..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora
        echo "Installing Node.js via yum (RHEL/CentOS/Fedora)..."
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        sudo yum install -y nodejs
    elif command -v dnf &> /dev/null; then
        # Fedora (newer)
        echo "Installing Node.js via dnf (Fedora)..."
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        sudo dnf install -y nodejs
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        echo "Installing Node.js via pacman (Arch Linux)..."
        sudo pacman -S nodejs npm --noconfirm
    else
        # Fallback to NVM
        echo "Using NVM fallback installation..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install 18
        nvm use 18
        nvm alias default 18
    fi
    
    # Verify installation
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        echo "Node.js installed successfully: $NODE_VERSION"
    else
        echo "Failed to install Node.js. Please install manually and try again."
        exit 1
    fi
}

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    install_nodejs
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
    echo "Node.js version $(node -v) is older than 16. Updating to Node.js 18..."
    install_nodejs
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Install globally
echo "🌍 Installing Grim globally..."
npm install -g .

echo "✅ Grim installation complete!"
echo ""
echo "🚀 Usage:"
echo "  grim --help          # Show help"
echo "  grim health          # Check system health"
echo "  grim backup /path    # Backup a directory"
echo "  grim monitor         # Start monitoring"
echo "  grim web             # Start web interface"
echo ""
echo "📚 Documentation: https://grim-reaper.org"
EOF

chmod +x install.sh
print_success "Installation script created"

# Create LICENSE file if it doesn't exist
if [ ! -f "LICENSE" ]; then
    print_status "Creating LICENSE file..."
    cat > LICENSE << 'EOF'
Be Like Brit License (BBL)

Copyright (c) 2025 Bernie Gengel and his beagle Buddy

This software is licensed under the Be Like Brit License (BBL). 
See the BBL file for complete license terms and conditions.
EOF
    print_success "LICENSE file created"
fi

# Create .npmignore to exclude unnecessary files
print_status "Creating .npmignore..."
cat > .npmignore << 'EOF'
# Build artifacts
dist/
build/
*.log

# Development files
.git/
.gitignore
.claude/
node_modules/
*.md
!README.md

# Temporary files
*.tmp
*.temp
.DS_Store
Thumbs.db

# Test files
test/
tests/
*.test.js
*.spec.js

# Documentation (except README)
docs/
*.md
!README.md

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db
EOF
print_success ".npmignore created"

# Create package documentation
print_status "Creating package documentation..."
cat > docs/PACKAGE.md << 'EOF'
# 🗡️ GRIM NPM Package

## Overview
Grim is the ultimate backup, monitoring, and security system that unifies multiple components:
- **sh_grim**: Bash-based backup and system operations
- **scyth**: File scanning and analysis
- **py_grim**: Python-based monitoring and AI
- **go_grim**: Go-based web interface and performance

## Installation
```bash
npm install -g grim
```

## Usage
```bash
grim --help          # Show help
grim health          # Check system health
grim backup /path    # Backup a directory
grim monitor         # Start monitoring
grim web             # Start web interface
```

## Components
Each component is installed to `/opt/grim-reaper/` and can be used independently or through the unified CLI.

## Configuration
Configuration files are stored in `/etc/grim-reaper/` and can be customized for your environment.

## Support
- Documentation: https://grim-reaper.org
- Issues: https://github.com/grim-reaper/grim/issues
EOF
print_success "Package documentation created"

# Final build summary
echo ""
print_success "🎉 Grim build complete!"
echo ""
echo "📦 Package contents:"
echo "  ✅ JavaScript CLI (js_grim/grim.js)"
echo "  ✅ Bash components (sh_grim/)"
echo "  ✅ Python components (py_grim/)"
echo "  ✅ Go components (go_grim/)"
echo "  ✅ Scythe component (scythe/)"
echo "  ✅ ASCII art (ascii/)"
echo "  ✅ Configuration files (config/)"
echo "  ✅ Installation scripts (scripts/)"
echo "  ✅ Documentation (docs/)"
echo ""
echo "🚀 Ready to publish to npm!"
echo "   Run: npm publish"
echo ""
echo "📚 Installation:"
echo "   npm install -g grim" 