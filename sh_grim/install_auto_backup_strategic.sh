#!/bin/bash

# Grim Strategic Auto-Backup Installer
# Installs paywall-protected auto-backup system
# Creates encrypted backups but restricts access until payment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Dynamic user detection - don't hard-code /root
CURRENT_USER="${SUDO_USER:-$USER}"
if [[ "$CURRENT_USER" == "root" ]]; then
    # If running as root, try to detect the actual user
    if [[ -n "${SUDO_USER:-}" ]]; then
        CURRENT_USER="$SUDO_USER"
    elif [[ -f /etc/passwd ]]; then
        # Find the first non-root user
        CURRENT_USER=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1; exit}' /etc/passwd)
    fi
fi

# Use user's home directory instead of hard-coded /root
USER_HOME=$(eval echo "~$CURRENT_USER")
GRAVEYARD_DIR="${GRAVEYARD_DIR:-$USER_HOME/.graveyard}"
RIP_DIR="$GRAVEYARD_DIR/.rip"
AUTO_BACKUP_DIR="$RIP_DIR/auto-backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "$*"; }
log_error() { log "ERROR" "$*"; }
log_debug() { log "DEBUG" "$*"; }

# Success and error functions
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}" >&2; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${CYAN}ℹ️  $1${NC}"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for required commands
    for cmd in zstd gzip openssl jq tar find stat; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install the missing packages:"
        echo "  Ubuntu/Debian: sudo apt-get install zstd gzip openssl jq"
        echo "  CentOS/RHEL: sudo yum install zstd gzip openssl jq"
        exit 1
    fi
    
    success "All dependencies satisfied"
}

# Create directories with secure permissions
create_directories() {
    log "Creating necessary directories..."
    
    # Create tier-based backup directories
    mkdir -p "$AUTO_BACKUP_DIR/free"
    mkdir -p "$AUTO_BACKUP_DIR/pro"
    mkdir -p "$AUTO_BACKUP_DIR/master"
    mkdir -p "$AUTO_BACKUP_DIR/reaper"
    
    # Create log and run directories
    mkdir -p /var/log
    mkdir -p /var/run
    
    # Set secure permissions
    chmod 700 "$RIP_DIR"
    chmod 700 "$AUTO_BACKUP_DIR"
    chmod 700 "$AUTO_BACKUP_DIR/free"
    chmod 700 "$AUTO_BACKUP_DIR/pro"
    chmod 700 "$AUTO_BACKUP_DIR/master"
    chmod 700 "$AUTO_BACKUP_DIR/reaper"
    
    success "Directories created with secure permissions"
    log "Backup directories created for user: $CURRENT_USER"
}

# Install systemd service
install_service() {
    log "Installing systemd service..."
    
    # Create service file with dynamic paths
    cat > /etc/systemd/system/grim-auto-backup-strategic.service << EOF
[Unit]
Description=Grim Strategic Auto-Backup System
Documentation=https://grim.so/docs/auto-backup-strategic
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$GRIM_ROOT
Environment=GRIM_ROOT=$GRIM_ROOT
Environment=CURRENT_USER=$CURRENT_USER
Environment=USER_HOME=$USER_HOME
Environment=GRAVEYARD_DIR=$GRAVEYARD_DIR
Environment=RIP_DIR=$RIP_DIR
Environment=AUTO_BACKUP_DIR=$AUTO_BACKUP_DIR
Environment=MONITOR_DIR=$GRIM_ROOT
Environment=BACKUP_INTERVAL=300
Environment=MAX_BACKUPS=100
Environment=COMPRESSION_ALGORITHM=zstd
Environment=ENCRYPTION_ENABLED=true
ExecStart=$GRIM_ROOT/sh_grim/auto_backup_strategic.sh start
ExecStop=$GRIM_ROOT/sh_grim/auto_backup_strategic.sh stop
ExecReload=$GRIM_ROOT/sh_grim/auto_backup_strategic.sh restart
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=grim-auto-backup-strategic

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$GRAVEYARD_DIR $GRIM_ROOT /var/log /var/run

# Resource limits
LimitNOFILE=65536
MemoryMax=512M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    success "Systemd service installed"
}

# Enable and start service
start_service() {
    log "Enabling and starting service..."
    
    # Enable service
    systemctl enable grim-auto-backup-strategic.service
    
    # Start service
    systemctl start grim-auto-backup-strategic.service
    
    # Check service status
    if systemctl is-active --quiet grim-auto-backup-strategic.service; then
        success "Strategic auto-backup service started successfully"
        log "Service PID: $(systemctl show -p MainPID grim-auto-backup-strategic.service | cut -d= -f2)"
    else
        error "Failed to start strategic auto-backup service"
        systemctl status grim-auto-backup-strategic.service --no-pager -l
        return 1
    fi
}

# Show strategic information
show_strategic_info() {
    echo -e "${CYAN}=== Grim Strategic Auto-Backup System ===${NC}"
    echo ""
    echo -e "${YELLOW}Strategy:${NC}"
    echo "  • Auto-backup runs continuously for ALL users"
    echo "  • Backups are encrypted and password-protected"
    echo "  • Access to backups requires paid tier upgrade"
    echo "  • Creates strong incentive for tier upgrades"
    echo ""
    echo -e "${YELLOW}Benefits:${NC}"
    echo "  • Users get immediate data protection"
    echo "  • No data loss regardless of payment status"
    echo "  • Natural upgrade path through backup access"
    echo "  • Secure, encrypted storage in hidden directories"
    echo ""
    echo -e "${YELLOW}Access Control:${NC}"
    echo "  • FREE tier: Can create backups, cannot access them"
    echo "  • PRO/MASTER/REAPER: Full access to backups"
    echo "  • Tier-based backup storage locations"
    echo ""
    echo -e "${YELLOW}Smart Features:${NC}"
    echo "  • Only backs up important file types"
    echo "  • Skips temporary and dependency files"
    echo "  • Prevents duplicate backups within 10 minutes"
    echo "  • Automatic cleanup of old backups"
    echo ""
}

# Show usage information
show_usage() {
    echo -e "${CYAN}=== Strategic Auto-Backup Usage ===${NC}"
    echo ""
    echo -e "${YELLOW}Service Commands:${NC}"
    echo "  sudo systemctl start grim-auto-backup-strategic"
    echo "  sudo systemctl stop grim-auto-backup-strategic"
    echo "  sudo systemctl restart grim-auto-backup-strategic"
    echo "  sudo systemctl status grim-auto-backup-strategic"
    echo ""
    echo -e "${YELLOW}Direct Commands:${NC}"
    echo "  grim auto-backup start"
    echo "  grim auto-backup stop"
    echo "  grim auto-backup status"
    echo "  grim auto-backup list"
    echo "  grim auto-backup restore <file>"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Backup Directory: $AUTO_BACKUP_DIR"
    echo "  Log File: /var/log/grim-auto-backup.log"
    echo "  Monitor Directory: $GRIM_ROOT"
    echo "  Backup Interval: 5 minutes"
    echo ""
    echo -e "${YELLOW}Payment Status:${NC}"
    echo "  • Backups are created automatically"
    echo "  • Access requires tier upgrade"
    echo "  • Use 'grim scythe-tier upgrade PRO' to access"
    echo ""
}

# Grant paid access (calls auto_backup_strategic.sh)
grant_paid_access() {
    local access_key="$1"
    
    if [[ -z "$access_key" ]]; then
        error "Access key required"
        echo "Usage: $0 grant-access <access_key>"
        return 1
    fi
    
    info "Granting paid access..."
    "$GRIM_ROOT/sh_grim/auto_backup_strategic.sh" grant-access "$access_key"
}

# Check payment status (calls auto_backup_strategic.sh)
check_payment_status() {
    info "Checking payment status..."
    "$GRIM_ROOT/sh_grim/auto_backup_strategic.sh" payment-status
}

# Main installation function
install_strategic_auto_backup() {
    echo -e "${CYAN}Installing Grim Strategic Auto-Backup System...${NC}"
    echo ""
    
    check_root
    check_dependencies
    show_strategic_info
    create_directories
    install_service
    start_service
    
    echo ""
    success "Strategic auto-backup system installed successfully!"
    echo ""
    show_usage
    echo ""
    echo -e "${GREEN}💀 Strategic auto-backup is now protecting your data! 💀${NC}"
}

# Uninstall function
uninstall() {
    echo -e "${YELLOW}Uninstalling Grim Strategic Auto-Backup System...${NC}"
    
    # Stop and disable service
    systemctl stop grim-auto-backup-strategic.service 2>/dev/null || true
    systemctl disable grim-auto-backup-strategic.service 2>/dev/null || true
    
    # Remove service file
    rm -f /etc/systemd/system/grim-auto-backup-strategic.service
    
    # Reload systemd
    systemctl daemon-reload
    
    success "Strategic auto-backup system uninstalled"
    warning "Backup files remain in $AUTO_BACKUP_DIR"
    echo "To remove backups: rm -rf $AUTO_BACKUP_DIR"
}

# Main command handler
case "${1:-install}" in
    "install")
        install_strategic_auto_backup
        ;;
    "uninstall")
        uninstall
        ;;
    "status")
        systemctl status grim-auto-backup-strategic.service --no-pager -l
        ;;
    "grant-access")
        grant_paid_access "${2:-}"
        ;;
    "payment-status")
        check_payment_status
        ;;
    "help"|"--help"|"-h")
        echo -e "${CYAN}Grim Strategic Auto-Backup Installer${NC}"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install        - Install strategic auto-backup system"
        echo "  uninstall      - Uninstall strategic auto-backup system"
        echo "  status         - Check service status"
        echo "  grant-access   - Grant paid access with key"
        echo "  payment-status - Check payment status"
        echo "  help           - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 install"
        echo "  $0 grant-access <access_key>"
        echo "  $0 uninstall"
        ;;
    *)
        error "Unknown command: $1"
        echo "Use '$0 help' for available commands"
        exit 1
        ;;
esac 