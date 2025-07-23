#!/bin/bash
# Grim Admin Server Installation Script
# Installs the high-performance admin server with TuskLang integration

set -euo pipefail

# Colors
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
    echo "                    🚀 ADMIN SERVER WITH TUSKLANG PERFORMANCE  🚀"
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
# SYSTEM CHECK
# ============================================================================
check_system() {
    log "Checking system requirements..."
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed"
    fi
    
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log "Python version: $PYTHON_VERSION"
    
    # Check if we're in the right directory
    if [[ ! -f "grim_admin_server.py" ]]; then
        error "Please run this script from the tsk_flask directory"
    fi
    
    success "System requirements met"
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================
install_dependencies() {
    log "Installing Python dependencies..."
    
    # Install core dependencies
    if pip3 install -r requirements.txt; then
        success "Core dependencies installed"
    else
        error "Failed to install core dependencies"
    fi
    
    # Install performance libraries
    log "Installing performance libraries..."
    if pip3 install orjson ujson msgpack; then
        success "Performance libraries installed"
    else
        warning "Some performance libraries failed to install - will use fallbacks"
    fi
    
    # Install Flask-CORS if not already installed
    if ! python3 -c "import flask_cors" 2>/dev/null; then
        log "Installing Flask-CORS..."
        pip3 install Flask-CORS>=4.0.0
        success "Flask-CORS installed"
    fi
}

# ============================================================================
# CONFIGURATION SETUP
# ============================================================================
setup_configuration() {
    log "Setting up configuration..."
    
    # Create sample configuration
    if python3 grim_admin_server.py --create-config; then
        success "Sample configuration created"
    else
        warning "Failed to create sample configuration"
    fi
    
    # Check if convert directory exists
    if [[ ! -d "convert" ]]; then
        warning "Convert directory not found - static content may not be available"
    else
        success "Static content directory found"
    fi
}

# ============================================================================
# PERFORMANCE TESTING
# ============================================================================
test_performance() {
    log "Testing performance engine..."
    
    # Test basic imports
    if python3 -c "
from performance_engine import TurboTemplateEngine, render_turbo_template
from flask_tsk import FlaskTSK
print('✅ Performance engine imports successful')
"; then
        success "Performance engine imports successful"
    else
        error "Performance engine imports failed"
    fi
    
    # Run performance demo
    if python3 performance_demo.py; then
        success "Performance demo completed"
    else
        warning "Performance demo failed - check logs"
    fi
}

# ============================================================================
# SERVICE SETUP
# ============================================================================
setup_service() {
    log "Setting up system service..."
    
    # Create systemd service file
    SERVICE_FILE="/etc/systemd/system/grim-admin.service"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Grim Admin Server with TuskLang Performance
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/python3 grim_admin_server.py --host 0.0.0.0 --port 5000
Restart=always
RestartSec=10
Environment=PYTHONPATH=$(pwd)

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable grim-admin.service
    
    success "System service configured"
    log "To start the service: sudo systemctl start grim-admin"
    log "To check status: sudo systemctl status grim-admin"
}

# ============================================================================
# NGINX SETUP
# ============================================================================
setup_nginx() {
    log "Setting up Nginx configuration..."
    
    # Create Nginx config
    NGINX_CONFIG="/etc/nginx/sites-available/grim-admin"
    
    cat > "$NGINX_CONFIG" << EOF
server {
    listen 80;
    server_name grim-admin.local;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /static/ {
        alias $(pwd)/convert/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }
}
EOF
    
    # Enable site
    ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    success "Nginx configuration created"
}

# ============================================================================
# SECURITY SETUP
# ============================================================================
setup_security() {
    log "Setting up security..."
    
    # Create firewall rules
    if command -v ufw &> /dev/null; then
        ufw allow 5000/tcp
        success "Firewall rules configured"
    fi
    
    # Set proper permissions
    chmod 755 grim_admin_server.py
    chmod 644 peanut.tsk 2>/dev/null || true
    
    success "Security configuration completed"
}

# ============================================================================
# VERIFICATION
# ============================================================================
verify_installation() {
    log "Verifying installation..."
    
    # Test server startup
    timeout 10s python3 grim_admin_server.py --host 127.0.0.1 --port 5001 &
    SERVER_PID=$!
    
    sleep 3
    
    # Test health endpoint
    if curl -s http://127.0.0.1:5001/health | grep -q "healthy"; then
        success "Server health check passed"
    else
        warning "Server health check failed"
    fi
    
    # Kill test server
    kill $SERVER_PID 2>/dev/null || true
    
    # Test performance
    if python3 performance_benchmark.py; then
        success "Performance benchmark completed"
    else
        warning "Performance benchmark failed"
    fi
}

# ============================================================================
# MAIN INSTALLATION
# ============================================================================
main() {
    print_banner
    
    log "Starting Grim Admin Server installation..."
    
    check_system
    install_dependencies
    setup_configuration
    test_performance
    setup_service
    setup_nginx
    setup_security
    verify_installation
    
    echo ""
    echo -e "${GREEN}🎉 Grim Admin Server installation completed!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "1. Start the service: ${BOLD}sudo systemctl start grim-admin${NC}"
    echo "2. Check status: ${BOLD}sudo systemctl status grim-admin${NC}"
    echo "3. View logs: ${BOLD}sudo journalctl -u grim-admin -f${NC}"
    echo "4. Access admin: ${BOLD}http://localhost:5000${NC}"
    echo "5. Performance demo: ${BOLD}python3 performance_demo.py${NC}"
    echo ""
    echo -e "${YELLOW}Configuration file: ${BOLD}peanut.tsk${NC}"
    echo -e "${YELLOW}Static content: ${BOLD}convert/ directory${NC}"
    echo -e "${YELLOW}Service file: ${BOLD}/etc/systemd/system/grim-admin.service${NC}"
    echo ""
    echo -e "${GREEN}🚀 Enjoy the revolutionary TuskLang performance!${NC}"
}

# Run main function
main "$@" 