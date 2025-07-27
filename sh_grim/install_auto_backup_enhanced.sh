#!/bin/bash

# Grim Enhanced Auto-Backup Installer
# Installs and configures tier-aware auto-backup system

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVICE_FILE="$SCRIPT_DIR/grim-auto-backup-enhanced.service"
SYSTEMD_DIR="/etc/systemd/system"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for compression tools
    if ! command -v zstd >/dev/null 2>&1; then
        missing_deps+=("zstd")
    fi
    
    if ! command -v gzip >/dev/null 2>&1; then
        missing_deps+=("gzip")
    fi
    
    if ! command -v xz >/dev/null 2>&1; then
        missing_deps+=("xz")
    fi
    
    # Check for jq (for metadata parsing)
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        warning "Missing dependencies: ${missing_deps[*]}"
        log "Installing missing dependencies..."
        
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_deps[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_deps[@]}"
        else
            error "Cannot install dependencies automatically. Please install: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    success "All dependencies satisfied"
}

# Create directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p /root/.graveyard/auto_backups
    mkdir -p /var/log
    mkdir -p /var/run
    
    success "Directories created"
}

# Install systemd service
install_service() {
    log "Installing systemd service..."
    
    if [[ ! -f "$SERVICE_FILE" ]]; then
        error "Service file not found: $SERVICE_FILE"
        exit 1
    fi
    
    cp "$SERVICE_FILE" "$SYSTEMD_DIR/"
    systemctl daemon-reload
    
    success "Systemd service installed"
}

# Configure tier settings
configure_tier() {
    local tier="${1:-FREE}"
    
    log "Configuring for tier: $tier"
    
    # Update service file with tier-specific settings
    sed -i "s/Environment=USER_TIER=FREE/Environment=USER_TIER=$tier/" "$SYSTEMD_DIR/grim-auto-backup-enhanced.service"
    
    # Set tier-specific limits
    case "$tier" in
        "FREE")
            sed -i "s/Environment=MAX_BACKUPS=50/Environment=MAX_BACKUPS=10/" "$SYSTEMD_DIR/grim-auto-backup-enhanced.service"
            ;;
        "PRO")
            sed -i "s/Environment=MAX_BACKUPS=50/Environment=MAX_BACKUPS=50/" "$SYSTEMD_DIR/grim-auto-backup-enhanced.service"
            ;;
        "MASTER")
            sed -i "s/Environment=MAX_BACKUPS=50/Environment=MAX_BACKUPS=200/" "$SYSTEMD_DIR/grim-auto-backup-enhanced.service"
            ;;
        "REAPER")
            sed -i "s/Environment=MAX_BACKUPS=50/Environment=MAX_BACKUPS=1000/" "$SYSTEMD_DIR/grim-auto-backup-enhanced.service"
            ;;
    esac
    
    systemctl daemon-reload
    success "Tier configuration updated"
}

# Enable and start service
start_service() {
    log "Starting auto-backup service..."
    
    systemctl enable grim-auto-backup-enhanced.service
    systemctl start grim-auto-backup-enhanced.service
    
    # Wait a moment and check status
    sleep 2
    if systemctl is-active --quiet grim-auto-backup-enhanced; then
        success "Auto-backup service started successfully"
    else
        error "Failed to start auto-backup service"
        systemctl status grim-auto-backup-enhanced --no-pager
        exit 1
    fi
}

# Show tier information
show_tier_info() {
    local tier="${1:-FREE}"
    
    echo -e "${CYAN}=== Tier Information ===${NC}"
    echo "Tier: $tier"
    
    case "$tier" in
        "FREE")
            echo "Backup Limit: 10"
            echo "Retention: 7 days"
            echo "Max File Size: 100MB"
            echo "Features: Basic auto-backup with limitations"
            ;;
        "PRO")
            echo "Backup Limit: 50"
            echo "Retention: 30 days"
            echo "Max File Size: 1GB"
            echo "Features: Enhanced auto-backup with compression"
            ;;
        "MASTER")
            echo "Backup Limit: 200"
            echo "Retention: 90 days"
            echo "Max File Size: 10GB"
            echo "Features: Advanced auto-backup with AI optimization"
            ;;
        "REAPER")
            echo "Backup Limit: 1000"
            echo "Retention: 365 days"
            echo "Max File Size: 100GB"
            echo "Features: Unlimited auto-backup with enterprise features"
            ;;
    esac
}

# Show usage information
show_usage() {
    echo -e "${CYAN}=== Grim Enhanced Auto-Backup Usage ===${NC}"
    echo ""
    echo "Service Commands:"
    echo "  systemctl status grim-auto-backup-enhanced  - Check service status"
    echo "  systemctl stop grim-auto-backup-enhanced    - Stop auto-backup"
    echo "  systemctl restart grim-auto-backup-enhanced - Restart auto-backup"
    echo "  journalctl -u grim-auto-backup-enhanced -f  - Watch live logs"
    echo ""
    echo "Direct Commands:"
    echo "  grim auto-backup list                       - List auto-backups"
    echo "  grim auto-backup restore <file> [dir]       - Restore from backup"
    echo "  grim auto-backup status                     - Check daemon status"
    echo ""
    echo "Configuration:"
    echo "  Backup Location: /root/.graveyard/auto_backups"
    echo "  Log File: /var/log/grim-auto-backup.log"
    echo "  Config File: /opt/reaper/sh_grim/auto_backup.conf"
    echo ""
    echo "Tier Features:"
    echo "  FREE: Basic auto-backup (10 backups, 7 days retention)"
    echo "  PRO: Enhanced auto-backup (50 backups, 30 days retention)"
    echo "  MASTER: Advanced auto-backup (200 backups, 90 days retention)"
    echo "  REAPER: Unlimited auto-backup (1000 backups, 365 days retention)"
}

# Main installation function
install_auto_backup() {
    local tier="${1:-FREE}"
    
    echo -e "${CYAN}=== Grim Enhanced Auto-Backup Installer ===${NC}"
    echo ""
    
    # Check prerequisites
    check_root
    check_dependencies
    
    # Show tier information
    show_tier_info "$tier"
    echo ""
    
    # Install components
    create_directories
    install_service
    configure_tier "$tier"
    start_service
    
    echo ""
    success "Grim Enhanced Auto-Backup installed successfully!"
    echo ""
    show_usage
}

# Upgrade tier
upgrade_tier() {
    local new_tier="$1"
    
    if [[ -z "$new_tier" ]]; then
        error "Tier required. Usage: $0 upgrade <tier>"
        exit 1
    fi
    
    log "Upgrading to tier: $new_tier"
    
    # Stop service
    systemctl stop grim-auto-backup-enhanced.service 2>/dev/null || true
    
    # Update configuration
    configure_tier "$new_tier"
    
    # Start service
    start_service
    
    success "Successfully upgraded to $new_tier tier"
    show_tier_info "$new_tier"
}

# Uninstall
uninstall() {
    log "Uninstalling Grim Enhanced Auto-Backup..."
    
    # Stop and disable service
    systemctl stop grim-auto-backup-enhanced.service 2>/dev/null || true
    systemctl disable grim-auto-backup-enhanced.service 2>/dev/null || true
    
    # Remove service file
    rm -f "$SYSTEMD_DIR/grim-auto-backup-enhanced.service"
    systemctl daemon-reload
    
    success "Grim Enhanced Auto-Backup uninstalled"
}

# Main command handler
case "${1:-}" in
    install)
        install_auto_backup "${2:-FREE}"
        ;;
    upgrade)
        upgrade_tier "$2"
        ;;
    uninstall)
        uninstall
        ;;
    status)
        systemctl status grim-auto-backup-enhanced --no-pager
        ;;
    help)
        echo -e "${CYAN}Grim Enhanced Auto-Backup Installer${NC}"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  install [tier]     - Install auto-backup system (default: FREE)"
        echo "  upgrade <tier>     - Upgrade to different tier"
        echo "  uninstall          - Remove auto-backup system"
        echo "  status             - Check service status"
        echo "  help               - Show this help"
        echo ""
        echo "Tiers: FREE, PRO, MASTER, REAPER"
        echo ""
        echo "Examples:"
        echo "  $0 install FREE"
        echo "  $0 install PRO"
        echo "  $0 upgrade MASTER"
        ;;
    *)
        install_auto_backup "${1:-FREE}"
        ;;
esac 