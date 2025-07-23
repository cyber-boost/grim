#!/bin/bash

# Grim Reaper System - Installation Script
# Version: 1.0.0
# Date: $(date +%Y-%m-%d)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GRIM_VERSION="1.0.0"
GRIM_INSTALL_DIR="/opt/grim-reaper"
GRIM_CONFIG_DIR="/etc/grim-reaper"
GRIM_LOG_DIR="/var/log/grim"
GRIM_BACKUP_DIR="/backups"
GRIM_USER="grim"
GRIM_GROUP="grim"

# Logging
LOG_FILE="/tmp/grim-install.log"
exec > >(tee -a $LOG_FILE) 2>&1

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Unsupported operating system"
        exit 1
    fi
    
    # Check memory
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    if [[ $MEMORY_GB -lt 4 ]]; then
        log_warning "Recommended minimum 4GB RAM, found ${MEMORY_GB}GB"
    fi
    
    # Check disk space
    DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
    DISK_SPACE_GB=$((DISK_SPACE / 1024 / 1024))
    if [[ $DISK_SPACE_GB -lt 10 ]]; then
        log_error "Insufficient disk space. Need at least 10GB, found ${DISK_SPACE_GB}GB"
        exit 1
    fi
    
    log_success "System requirements check passed"
}

install_dependencies() {
    log_info "Installing system dependencies..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE="apt-get update"
        PKG_INSTALL="apt-get install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf update -y"
        PKG_INSTALL="dnf install -y"
    else
        log_error "Unsupported package manager"
        exit 1
    fi
    
    # Update package lists
    eval $PKG_UPDATE
    
    # Install dependencies
    eval $PKG_INSTALL python3 python3-pip python3-venv \
        golang-go nodejs npm postgresql redis-server \
        docker.io docker-compose rsync tar gzip openssl \
        nginx certbot python3-certbot-nginx curl wget
    
    log_success "Dependencies installed successfully"
}

create_system_user() {
    log_info "Creating system user and group..."
    
    # Create group if it doesn't exist
    if ! getent group $GRIM_GROUP > /dev/null 2>&1; then
        groupadd -r $GRIM_GROUP
    fi
    
    # Create user if it doesn't exist
    if ! getent passwd $GRIM_USER > /dev/null 2>&1; then
        useradd -r -s /bin/false -g $GRIM_GROUP $GRIM_USER
    fi
    
    # Add user to docker group
    usermod -aG docker $GRIM_USER
    
    log_success "System user created: $GRIM_USER"
}

create_directories() {
    log_info "Creating system directories..."
    
    # Create installation directory
    mkdir -p $GRIM_INSTALL_DIR
    chown $GRIM_USER:$GRIM_GROUP $GRIM_INSTALL_DIR
    chmod 755 $GRIM_INSTALL_DIR
    
    # Create configuration directory
    mkdir -p $GRIM_CONFIG_DIR
    chown $GRIM_USER:$GRIM_GROUP $GRIM_CONFIG_DIR
    chmod 700 $GRIM_CONFIG_DIR
    
    # Create log directory
    mkdir -p $GRIM_LOG_DIR
    chown $GRIM_USER:$GRIM_GROUP $GRIM_LOG_DIR
    chmod 755 $GRIM_LOG_DIR
    
    # Create backup directory
    mkdir -p $GRIM_BACKUP_DIR
    chown $GRIM_USER:$GRIM_GROUP $GRIM_BACKUP_DIR
    chmod 755 $GRIM_BACKUP_DIR
    
    log_success "System directories created"
}

install_components() {
    log_info "Installing Grim Reaper components..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Install sh_grim
    log_info "Installing sh_grim..."
    cp -r $PACKAGE_DIR/sh_grim/* $GRIM_INSTALL_DIR/
    chmod +x $GRIM_INSTALL_DIR/*.sh
    chown -R $GRIM_USER:$GRIM_GROUP $GRIM_INSTALL_DIR
    
    # Install go_grim
    log_info "Installing go_grim..."
    cd $PACKAGE_DIR/go_grim
    if [[ -f "build.sh" ]]; then
        ./build.sh
    fi
    cp -r * $GRIM_INSTALL_DIR/go_grim/
    
    # Install py_grim
    log_info "Installing py_grim..."
    cd $PACKAGE_DIR/py_grim
    pip3 install -r requirements.txt
    python3 setup.py install
    
    # Install scythe
    log_info "Installing scythe..."
    cd $PACKAGE_DIR/scythe
    python3 setup.py install
    
    log_success "All components installed successfully"
}

setup_database() {
    log_info "Setting up database..."
    
    # Start PostgreSQL if not running
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create database and user
    sudo -u postgres psql -c "CREATE DATABASE grim_reaper;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE USER grim WITH PASSWORD 'grim_secure_password';" 2>/dev/null || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE grim_reaper TO grim;" 2>/dev/null || true
    
    # Initialize database schema
    cd $GRIM_INSTALL_DIR/py_grim
    python3 manage.py migrate --run-syncdb
    
    log_success "Database setup completed"
}

setup_services() {
    log_info "Setting up system services..."
    
    # Create systemd service files
    cat > /etc/systemd/system/grim-backup.service << EOF
[Unit]
Description=Grim Reaper Backup Service
After=network.target

[Service]
Type=simple
User=$GRIM_USER
Group=$GRIM_GROUP
WorkingDirectory=$GRIM_INSTALL_DIR
ExecStart=$GRIM_INSTALL_DIR/backup.sh daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/grim-monitor.service << EOF
[Unit]
Description=Grim Reaper Monitoring Service
After=network.target

[Service]
Type=simple
User=$GRIM_USER
Group=$GRIM_GROUP
WorkingDirectory=$GRIM_INSTALL_DIR
ExecStart=$GRIM_INSTALL_DIR/monitor.sh daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/grim-web.service << EOF
[Unit]
Description=Grim Reaper Web Service
After=network.target

[Service]
Type=simple
User=$GRIM_USER
Group=$GRIM_GROUP
WorkingDirectory=$GRIM_INSTALL_DIR/py_grim
ExecStart=python3 manage.py runserver 0.0.0.0:8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable grim-backup grim-monitor grim-web
    
    log_success "System services configured"
}

setup_configuration() {
    log_info "Setting up configuration..."
    
    # Create default configuration
    cat > $GRIM_CONFIG_DIR/config.yaml << EOF
# Grim Reaper System Configuration
system:
  name: "grim-reaper"
  environment: "production"
  debug: false
  log_level: "INFO"

database:
  host: "localhost"
  port: 5432
  name: "grim_reaper"
  user: "grim"
  password: "grim_secure_password"
  ssl_mode: "disable"

redis:
  host: "localhost"
  port: 6379
  password: ""
  db: 0

backup:
  storage_path: "$GRIM_BACKUP_DIR"
  retention_days: 30
  compression_level: 6
  encryption_enabled: false
  max_concurrent_backups: 3

monitoring:
  check_interval: 60
  alert_threshold: 100M
  exclude_patterns:
    - "*.tmp"
    - "*.log"
    - ".git/*"

security:
  license_check_interval: 3600
  violation_threshold: 3
  auto_quarantine: false

web:
  host: "0.0.0.0"
  port: 8080
  ssl_enabled: false
  session_secret: "$(openssl rand -hex 32)"
EOF

    # Set proper permissions
    chown $GRIM_USER:$GRIM_GROUP $GRIM_CONFIG_DIR/config.yaml
    chmod 600 $GRIM_CONFIG_DIR/config.yaml
    
    log_success "Configuration setup completed"
}

setup_nginx() {
    log_info "Setting up Nginx configuration..."
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/grim-reaper << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /static/ {
        alias $GRIM_INSTALL_DIR/py_grim/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/grim-reaper /etc/nginx/sites-enabled/
    nginx -t
    systemctl reload nginx
    
    log_success "Nginx configuration completed"
}

start_services() {
    log_info "Starting Grim Reaper services..."
    
    # Start Redis
    systemctl start redis-server
    systemctl enable redis-server
    
    # Start services
    systemctl start grim-backup grim-monitor grim-web
    
    log_success "Services started successfully"
}

verify_installation() {
    log_info "Verifying installation..."
    
    # Check if services are running
    if systemctl is-active --quiet grim-backup; then
        log_success "Backup service is running"
    else
        log_error "Backup service failed to start"
        return 1
    fi
    
    if systemctl is-active --quiet grim-monitor; then
        log_success "Monitoring service is running"
    else
        log_error "Monitoring service failed to start"
        return 1
    fi
    
    if systemctl is-active --quiet grim-web; then
        log_success "Web service is running"
    else
        log_error "Web service failed to start"
        return 1
    fi
    
    # Test web interface
    if curl -s http://localhost:8080/api/v1/system/health > /dev/null; then
        log_success "Web interface is accessible"
    else
        log_warning "Web interface may not be fully initialized yet"
    fi
    
    log_success "Installation verification completed"
}

display_completion() {
    echo
    echo "=========================================="
    echo "  🎉 Grim Reaper Installation Complete!  "
    echo "=========================================="
    echo
    echo "Installation Details:"
    echo "  Version: $GRIM_VERSION"
    echo "  Install Directory: $GRIM_INSTALL_DIR"
    echo "  Config Directory: $GRIM_CONFIG_DIR"
    echo "  Log Directory: $GRIM_LOG_DIR"
    echo "  Backup Directory: $GRIM_BACKUP_DIR"
    echo
    echo "Services:"
    echo "  Backup Service: $(systemctl is-active grim-backup)"
    echo "  Monitor Service: $(systemctl is-active grim-monitor)"
    echo "  Web Service: $(systemctl is-active grim-web)"
    echo
    echo "Access Points:"
    echo "  Web Interface: http://localhost:8080"
    echo "  API Endpoint: http://localhost:8080/api/v1"
    echo "  Documentation: $GRIM_INSTALL_DIR/docs/"
    echo
    echo "Next Steps:"
    echo "  1. Configure your backup paths"
    echo "  2. Set up monitoring directories"
    echo "  3. Configure security settings"
    echo "  4. Review documentation in $GRIM_INSTALL_DIR/docs/"
    echo
    echo "Log file: $LOG_FILE"
    echo
}

# Main installation process
main() {
    echo "=========================================="
    echo "  Grim Reaper System Installation"
    echo "  Version: $GRIM_VERSION"
    echo "=========================================="
    echo
    
    check_root
    check_system_requirements
    install_dependencies
    create_system_user
    create_directories
    install_components
    setup_database
    setup_services
    setup_configuration
    setup_nginx
    start_services
    verify_installation
    display_completion
    
    log_success "Installation completed successfully!"
}

# Run main function
main "$@" 