#!/bin/bash
# Grim Reaper Complete Installation Script
# "Set it and forget it" - Dead simple automated installation

set -euo pipefail

# ============================================================================
# COLORS AND UTILITIES
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "  ██████  ██████  ██ ███    ███     ██████  ███████  █████  ██████  ███████ ██████  "
    echo " ██       ██   ██ ██ ████  ████     ██   ██ ██      ██   ██ ██   ██ ██      ██   ██ "
    echo " ██   ███ ██████  ██ ██ ████ ██     ██████  █████   ███████ ██████  █████   ██████  "
    echo " ██    ██ ██   ██ ██ ██  ██  ██     ██   ██ ██      ██   ██ ██      ██      ██   ██ "
    echo "  ██████  ██   ██ ██ ██      ██     ██   ██ ███████ ██   ██ ██      ███████ ██   ██ "
    echo ""
    echo "                          🗡️  COMPLETE INSTALLATION  🗡️"
    echo -e "${NC}"
}

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
        GRIM_ROOT="$HOME/.graveyard"
    else
        SUDO=""
        GRIM_ROOT="/root/.graveyard"
    fi
    
    # Check if we're running from a build directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/manifest.tsk" ]]; then
        log "Running from build directory: $SCRIPT_DIR"
        BUILD_DIR="$SCRIPT_DIR"
    else
        # Look for grim-reaper-* directory in current location
        BUILD_DIR=$(find . -maxdepth 1 -name "grim-reaper-*" -type d | head -1)
        if [[ -n "$BUILD_DIR" ]]; then
            log "Found build directory: $BUILD_DIR"
        else
            error "No build directory found. Please run this script from a Grim Reaper build directory."
        fi
    fi
    
    # Ensure graveyard directory exists
    if [[ ! -d "$GRIM_ROOT" ]]; then
        log "Creating Grim graveyard directory: $GRIM_ROOT"
        $SUDO mkdir -p "$GRIM_ROOT"
        $SUDO chown -R $(whoami):$(whoami) "$GRIM_ROOT" 2>/dev/null || true
    fi
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================
install_system_packages() {
    log "Installing system packages..."
    
    # Common packages needed across all systems
    local packages=(
        curl wget git jq bc sqlite3 unzip tar gzip
        python3 python3-pip python3-venv python3-dev
        build-essential cmake pkg-config
        nginx
        cron
        htop iotop
        nodejs npm
        pm2
    )
    
    case $DISTRO in
        ubuntu|debian)
            $SUDO apt-get update
            $SUDO apt-get install -y "${packages[@]}"
            $SUDO apt-get install -y python3-fastapi python3-uvicorn || true
            ;;
        centos|rhel|rocky|almalinux)
            $SUDO yum update -y
            $SUDO yum install -y "${packages[@]}" epel-release
            $SUDO yum install -y python3-pip
            ;;
        fedora)
            $SUDO dnf update -y
            $SUDO dnf install -y "${packages[@]}"
            ;;
        arch|manjaro)
            $SUDO pacman -Syu --noconfirm "${packages[@]}"
            ;;
        *)
            warning "Unknown distribution: $DISTRO - you may need to install packages manually"
            ;;
    esac
    
    success "System packages installed"
}

install_go() {
    log "Installing Go programming language..."
    
    if command -v go >/dev/null 2>&1; then
        local go_version=$(go version | awk '{print $3}' | sed 's/go//')
        log "Go already installed: $go_version"
        return 0
    fi
    
    local GO_VERSION="1.21.5"
    local GO_TARBALL="go${GO_VERSION}.${OS}-${ARCH/x86_64/amd64}.tar.gz"
    local GO_URL="https://golang.org/dl/$GO_TARBALL"
    
    cd /tmp
    wget -q "$GO_URL" || error "Failed to download Go"
    
    $SUDO rm -rf /usr/local/go
    $SUDO tar -C /usr/local -xzf "$GO_TARBALL"
    
    # Add to PATH
    if ! grep -q "/usr/local/go/bin" /etc/environment 2>/dev/null; then
        echo 'PATH="/usr/local/go/bin:$PATH"' | $SUDO tee -a /etc/environment
    fi
    
    export PATH="/usr/local/go/bin:$PATH"
    
    success "Go $GO_VERSION installed"
}

install_python_packages() {
    log "Installing Python packages..."
    
    # Create virtual environment for Grim
    if [[ ! -d "$GRIM_ROOT/grim_venv" ]]; then
        $SUDO python3 -m venv "$GRIM_ROOT/grim_venv"
        $SUDO chown -R $(whoami):$(whoami) "$GRIM_ROOT/grim_venv" 2>/dev/null || true
    fi
    
    source "$GRIM_ROOT/grim_venv/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Core Python packages
    pip install \
        fastapi uvicorn pyyaml \
        requests aiofiles asyncio \
        click colorama tqdm \
        psutil \
        tensorflow==2.15.0 \
        torch==2.1.0 \
        numpy pandas scikit-learn \
        cryptography \
        --break-system-packages || pip install \
        fastapi uvicorn pyyaml \
        requests aiofiles \
        click colorama tqdm \
        psutil
    
    # Admin server packages (if tsk_flask exists)
    if [[ -d "$BUILD_DIR/tsk_flask" ]]; then
        log "Installing admin server dependencies..."
        pip install \
            flask flask-cors \
            --break-system-packages || pip install \
            flask flask-cors
        
        # Try to install flask-tsk (optional)
        pip install flask-tsk --break-system-packages 2>/dev/null || {
            warning "flask-tsk not available - admin server will work without TuskLang integration"
        }
        
        success "Admin server packages installed"
    fi
    
    success "Python packages installed"
}

install_nodejs() {
    log "Installing Node.js and npm..."
    
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        log "Node.js already installed: $node_version"
        return 0
    fi
    
    # Install Node.js 18 LTS
    curl -fsSL https://deb.nodesource.com/setup_18.x | $SUDO -E bash -
    $SUDO apt-get install -y nodejs || {
        # Fallback for non-Debian systems
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install 18
        nvm use 18
    }
    
    success "Node.js installed"
}

# ============================================================================
# GRIM SYSTEM SETUP
# ============================================================================
setup_grim_environment() {
    log "Setting up Grim environment..."
    
    # Copy build files to graveyard
    log "Copying build files to graveyard..."
    cp -r "$BUILD_DIR"/* "$GRIM_ROOT/"
    
    # Ensure proper ownership
    $SUDO chown -R $(whoami):$(whoami) "$GRIM_ROOT" 2>/dev/null || true
    
    # Create required directories
    mkdir -p "$GRIM_ROOT"/{logs,db,backups,tmp,builds}
    
    # Set up PATH
    if ! grep -q "$GRIM_ROOT" ~/.bashrc 2>/dev/null; then
        echo "export PATH=\"$GRIM_ROOT/sh_grim:\$PATH\"" >> ~/.bashrc
    fi
    
    # Create systemd service for scythe
    cat > /tmp/grim-scythe.service << EOF
[Unit]
Description=Grim Reaper Scythe Orchestrator
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$GRIM_ROOT
Environment=PATH=$GRIM_ROOT/grim_venv/bin:/usr/local/go/bin:/usr/bin:/bin
ExecStart=$GRIM_ROOT/grim_venv/bin/python3 $GRIM_ROOT/scythe/scythe.py health
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    $SUDO mv /tmp/grim-scythe.service /etc/systemd/system/
    $SUDO systemctl daemon-reload
    
    success "Grim environment configured"
}

build_go_components() {
    log "Building Go components..."
    
    cd "$GRIM_ROOT/go_grim"
    
    if [[ -f "Makefile" ]]; then
        make clean || true
        make build
        success "go_grim built successfully"
    else
        go mod tidy
        go build -o build/grim-compression ./cmd/compression/
        success "go_grim compiled manually"
    fi
}

setup_nginx() {
    log "Setting up Nginx configuration..."
    
    # Create Nginx config for Grim
    cat > /tmp/grim.conf << EOF
server {
    listen 80;
    server_name localhost grim.local;
    
    # API Gateway
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    # Web Dashboard  
    location /dashboard/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Builds and releases
    location /builds/ {
        alias $GRIM_ROOT/builds/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
    
    # Static files
    location / {
        root $GRIM_ROOT/web;
        index index.html;
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    $SUDO mv /tmp/grim.conf /etc/nginx/sites-available/grim
    $SUDO ln -sf /etc/nginx/sites-available/grim /etc/nginx/sites-enabled/grim
    $SUDO rm -f /etc/nginx/sites-enabled/default
    
    $SUDO nginx -t && $SUDO systemctl enable nginx && $SUDO systemctl restart nginx
    
    success "Nginx configured and started"
}

setup_admin_server() {
    log "Setting up admin server configuration..."
    
    if [[ ! -d "$GRIM_ROOT/tsk_flask" ]]; then
        warning "tsk_flask not found - skipping admin server setup"
        return 0
    fi
    
    # Create admin server configuration
    cat > /tmp/admin-server.conf << 'EOF'
# Grim Admin Server Configuration
# Copy this to your nginx sites-available and customize for your domain

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name rp.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name rp.yourdomain.com;
    
    # SSL Configuration (replace with your certificates)
    ssl_certificate /etc/ssl/yourdomain/fullchain.pem;
    ssl_certificate_key /etc/ssl/yourdomain/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Proxy to Grim admin server on port 4746
    location / {
        proxy_pass http://127.0.0.1:4746;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        
        # WebSocket support for real-time updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Serve static files directly from convert directory
    location /static/ {
        alias /opt/reaper/tsk_flask/convert/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options nosniff;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:4746/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:4746/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header X-Powered-By "Grim Admin Server 🗡️";
    add_header X-Environment "admin";
    
    # Logging
    access_log /var/log/nginx/grim-admin.access.log;
    error_log /var/log/nginx/grim-admin.error.log;
}
EOF
    
    # Copy configuration to Grim directory
    cp /tmp/admin-server.conf "$GRIM_ROOT/admin-server.conf.example"
    
    # Create admin server startup script
    cat > /tmp/grim-admin.sh << EOF
#!/bin/bash
# Grim Admin Server Startup Script

GRIM_ROOT="$GRIM_ROOT"
ADMIN_PORT="\${GRIM_ADMIN_PORT:-4746}"
ADMIN_HOST="\${GRIM_ADMIN_HOST:-127.0.0.1}"

cd "\$GRIM_ROOT"

# Check if tsk_flask exists
if [[ ! -d "tsk_flask" ]]; then
    echo "Error: tsk_flask directory not found"
    echo "Admin server is not installed"
    exit 1
fi

# Activate virtual environment
source "\$GRIM_ROOT/grim_venv/bin/activate"

# Start admin server
cd tsk_flask
python3 grim_admin_server.py --host "\$ADMIN_HOST" --port "\$ADMIN_PORT" --debug
EOF
    
    $SUDO mv /tmp/grim-admin.sh /usr/local/bin/grim-admin
    $SUDO chmod +x /usr/local/bin/grim-admin
    
    # Create systemd service for admin server
    cat > /tmp/grim-admin.service << EOF
[Unit]
Description=Grim Admin Server
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$GRIM_ROOT/tsk_flask
Environment=PATH=$GRIM_ROOT/grim_venv/bin:/usr/bin:/bin
Environment=GRIM_ADMIN_PORT=4746
Environment=GRIM_ADMIN_HOST=127.0.0.1
ExecStart=$GRIM_ROOT/grim_venv/bin/python3 grim_admin_server.py --host 127.0.0.1 --port 4746
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    $SUDO mv /tmp/grim-admin.service /etc/systemd/system/
    $SUDO systemctl daemon-reload
    
    success "Admin server configuration created"
    warning "To enable admin server:"
    warning "1. Customize $GRIM_ROOT/admin-server.conf.example for your domain"
    warning "2. Copy to /etc/nginx/sites-available/ and enable"
    warning "3. Run: sudo systemctl enable grim-admin && sudo systemctl start grim-admin"
}

setup_pm2() {
    log "Setting up PM2 process manager..."
    
    # Install PM2 globally if not already installed
    if ! command -v pm2 >/dev/null 2>&1; then
        $SUDO npm install -g pm2
    fi
    
    # Create PM2 ecosystem file
    cat > /tmp/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'grim-web',
      script: 'py_grim/grim_web/app.py',
      cwd: '/opt/reaper',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: 8000
      }
    },
    {
      name: 'grim-scythe',
      script: 'scythe/scythe.py',
      cwd: '/opt/reaper',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};
EOF
    
    $SUDO cp /tmp/ecosystem.config.js /opt/reaper/
    $SUDO chown -R $(whoami):$(whoami) /opt/reaper/ecosystem.config.js
    
    # Setup PM2 startup script
    $SUDO pm2 startup systemd -u $(whoami) --hp /home/$(whoami)
    
    success "PM2 configured"
}

start_grim_services() {
    log "Starting Grim services with PM2..."
    
    cd "/opt/reaper"
    
    # Start services with PM2
    if command -v pm2 >/dev/null 2>&1; then
        pm2 start ecosystem.config.js
        pm2 save
        pm2 startup
        success "Grim services started with PM2"
    else
        # Fallback to direct startup
        log "PM2 not available, starting services directly..."
        
        # Start web server in background
        nohup python3 py_grim/grim_web/app.py > logs/web.log 2>&1 &
        success "Web server started"
        
        # Start scythe orchestrator in background
        nohup python3 scythe/scythe.py > logs/scythe.log 2>&1 &
        success "Scythe orchestrator started"
    fi
    
    # Wait a moment for services to start
    sleep 3
    
    # Test if services are running
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        success "Web service is responding"
    else
        warning "Web service may not be fully started"
    fi
}

setup_database() {
    log "Initializing databases..."
    
    cd "/opt/reaper"
    
    # Initialize sh_grim database
    sqlite3 db/grimm.db << EOF
CREATE TABLE IF NOT EXISTS system_info (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT OR REPLACE INTO system_info (key, value) VALUES 
    ('installation_date', datetime('now')),
    ('version', '1.0.0'),
    ('status', 'installed');
EOF
    
    # Initialize scythe database if scythe exists
    if [[ -f "sh_grim/scythe.sh" ]]; then
        ./sh_grim/scythe.sh init || warning "Could not initialize scythe database"
    fi
    
    success "Databases initialized"
}

create_startup_scripts() {
    log "Creating startup scripts..."
    
    # Create main grim command
    cat > /tmp/grim << 'EOF'
#!/bin/bash
# Grim Reaper Main Command

GRIM_ROOT="/opt/reaper"
cd "$GRIM_ROOT"

case "${1:-help}" in
    health)
        python3 scythe/scythe.py health
        ;;
    backup)
        shift
        python3 scythe/scythe.py backup "$@"
        ;;
    restore)
        shift
        ./sh_grim/restore.sh "$@"
        ;;
    scan)
        shift
        ./sh_grim/scan.sh "$@"
        ;;
    monitor)
        shift
        ./sh_grim/monitor.sh "$@"
        ;;
    status)
        python3 scythe/scythe.py status
        ;;
    web)
        source /opt/grim_venv/bin/activate
        python3 py_grim/grim_web/app.py
        ;;
    admin)
        if [[ -d "tsk_flask" ]]; then
            source /opt/grim_venv/bin/activate
            cd tsk_flask
            python3 grim_admin_server.py --host 127.0.0.1 --port 4746 --debug
        else
            echo "Admin server not installed (tsk_flask not found)"
        fi
        ;;
    setup-admin)
        if [[ -d "tsk_flask" ]]; then
            echo "Setting up admin server..."
            echo "1. Customize /opt/reaper/admin-server.conf.example for your domain"
            echo "2. Copy to /etc/nginx/sites-available/ and enable"
            echo "3. Run: sudo systemctl enable grim-admin && sudo systemctl start grim-admin"
            echo ""
            echo "Default admin credentials:"
            echo "  Username: admin"
            echo "  Password: grim2025"
        else
            echo "Admin server not installed (tsk_flask not found)"
        fi
        ;;
    help|*)
        echo "Grim Reaper Commands:"
        echo "  grim health              - Check system health"
        echo "  grim backup <path>       - Create backup"
        echo "  grim restore <backup>    - Restore from backup"
        echo "  grim scan <path>         - Scan filesystem"
        echo "  grim monitor <path>      - Start monitoring"
        echo "  grim status              - System status"
        echo "  grim web                 - Start web interface"
        echo "  grim admin               - Start admin server (if installed)"
        echo "  grim setup-admin         - Show admin setup instructions"
        ;;
esac
EOF
    
    $SUDO mv /tmp/grim /usr/local/bin/grim
    $SUDO chmod +x /usr/local/bin/grim
    
    success "Startup scripts created"
}

# ============================================================================
# VALIDATION AND TESTING
# ============================================================================
run_validation_tests() {
    log "Running validation tests..."
    
    cd "/opt/reaper"
    
    # Test Go components
    if [[ -f "go_grim/build/grim-compression" ]]; then
        success "go_grim: Compression engine built"
    else
        warning "go_grim: Compression engine not found"
    fi
    
    # Test Python components
    source /opt/grim_venv/bin/activate
    if python3 -c "import fastapi, uvicorn" 2>/dev/null; then
        success "py_grim: Python dependencies available"
    else
        warning "py_grim: Missing Python dependencies"
    fi
    
    # Test sh_grim
    if [[ -x "sh_grim/health_fixed.sh" ]]; then
        if ./sh_grim/health_fixed.sh quick >/dev/null 2>&1; then
            success "sh_grim: Health check passed"
        else
            warning "sh_grim: Health check failed"
        fi
    else
        warning "sh_grim: Health script not found"
    fi
    
    # Test scythe orchestrator
    if python3 scythe/scythe.py health >/dev/null 2>&1; then
        success "scythe: Orchestrator operational"
    else
        warning "scythe: Orchestrator issues detected"
    fi
    
    # Test main command
    if command -v grim >/dev/null 2>&1; then
        success "grim: Main command available"
    else
        warning "grim: Main command not in PATH"
    fi
}

display_summary() {
    # Show init ASCII art
    if [[ -f "/opt/reaper/admin/bash_central/ascii/init.txt" ]]; then
        cat "/opt/reaper/admin/bash_central/ascii/init.txt"
        echo ""
    fi
    
    echo -e "${BOLD}${GREEN}🎉 GRIM REAPER INSTALLATION COMPLETE! 🎉${NC}"
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                 QUICK START                     │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│  ${WHITE}grim health${NC}              Check system health   ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}grim backup /path${NC}        Create backup          ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}grim monitor /path${NC}       Start monitoring       ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}grim web${NC}                 Start web interface    ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${YELLOW}System URLs:${NC}"
    echo -e "  Web Interface: ${BLUE}http://localhost/${NC}"
    echo -e "  API Docs:      ${BLUE}http://localhost/api/docs${NC}"
    echo -e "  Builds:        ${BLUE}http://localhost/builds/${NC}"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo -e "  Grim Root:     ${BLUE}/opt/reaper/${NC}"
    echo -e "  Config File:   ${BLUE}/opt/reaper/config.yaml${NC}"
    echo -e "  Logs:          ${BLUE}/opt/reaper/logs/${NC}"
    echo -e "  Backups:       ${BLUE}/opt/reaper/backups/${NC}"
    echo ""
    echo -e "${GREEN}💀 The Reaper is ready! 💀${NC}"
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================
main() {
    print_banner
    
    log "Starting Grim Reaper installation..."
    
    detect_system
    install_system_packages
    install_go
    install_python_packages
    install_nodejs
    setup_grim_environment
    build_go_components
    setup_nginx
    setup_admin_server
    setup_pm2
    setup_database
    create_startup_scripts
    
    log "Running validation tests..."
    run_validation_tests
    
    display_summary
    
    # Start services
    log "Starting Grim services..."
    start_grim_services
    
    log "Installation completed successfully!"
}

# Run main installation
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi