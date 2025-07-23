#!/bin/bash
# 🗡️ GRIM REAPER REMOVAL SCRIPT
# SAFE REMOVAL - Use with caution!
# This script completely removes Grim Reaper from a system

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
GRIM_INSTALL_DIR="${GRIM_INSTALL_DIR:-/root/reaper}"
GRIM_GRAVEYARD="${GRIM_GRAVEYARD:-$HOME/.graveyard}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

print_banner() {
    echo -e "${RED}"
    echo "  ██████  ██████  ██ ███    ███     ██████  ███████  █████  ██████  ███████ ██████  "
    echo " ██       ██   ██ ██ ████  ████     ██   ██ ██      ██   ██ ██   ██ ██      ██   ██ "
    echo " ██   ███ ██████  ██ ██ ████ ██     ██████  █████   ███████ ██████  █████   ██████  "
    echo " ██    ██ ██   ██ ██ ██  ██  ██     ██   ██ ██      ██   ██ ██      ██      ██   ██ "
    echo "  ██████  ██   ██ ██ ██      ██     ██   ██ ███████ ██   ██ ██      ███████ ██   ██ "
    echo ""
    echo "                          🗡️  REMOVAL SCRIPT  🗡️"
    echo -e "${NC}"
}

# ============================================================================
# SAFETY CHECKS
# ============================================================================
confirm_removal() {
    echo -e "${RED}${BOLD}⚠️  WARNING: This will completely remove Grim Reaper from the system! ⚠️${NC}"
    echo ""
    echo -e "${YELLOW}The following will be removed:${NC}"
    echo -e "  • Grim installation directory: ${CYAN}$GRIM_INSTALL_DIR${NC}"
    echo -e "  • Grim graveyard: ${CYAN}$GRIM_GRAVEYARD${NC}"
    echo -e "  • Grim systemd services"
    echo -e "  • Grim nginx configurations"
    echo -e "  • Grim commands from PATH"
    echo -e "  • Grim virtual environments"
    echo ""
    echo -e "${RED}This action cannot be undone!${NC}"
    echo ""
    
    read -p "Are you absolutely sure you want to continue? Type 'YES' to confirm: " -r
    echo
    if [[ ! $REPLY =~ ^YES$ ]]; then
        echo -e "${GREEN}Removal cancelled.${NC}"
        exit 0
    fi
    
    echo -e "${RED}Final confirmation: This will permanently delete all Grim data.${NC}"
    read -p "Type 'DELETE' to proceed: " -r
    echo
    if [[ ! $REPLY =~ ^DELETE$ ]]; then
        echo -e "${GREEN}Removal cancelled.${NC}"
        exit 0
    fi
}

# ============================================================================
# REMOVAL FUNCTIONS
# ============================================================================
stop_grim_services() {
    log "Stopping Grim services..."
    
    # Stop systemd services
    systemctl stop grim-scythe 2>/dev/null || true
    systemctl stop grim-admin 2>/dev/null || true
    systemctl disable grim-scythe 2>/dev/null || true
    systemctl disable grim-admin 2>/dev/null || true
    
    # Kill any remaining Grim processes
    pkill -f "scythe" 2>/dev/null || true
    pkill -f "grim" 2>/dev/null || true
    
    success "Grim services stopped"
}

remove_systemd_services() {
    log "Removing systemd services..."
    
    # Remove systemd service files
    rm -f /etc/systemd/system/grim-scythe.service
    rm -f /etc/systemd/system/grim-admin.service
    
    # Reload systemd
    systemctl daemon-reload 2>/dev/null || true
    
    success "Systemd services removed"
}

remove_nginx_config() {
    log "Removing nginx configuration..."
    
    # Remove nginx site configuration
    rm -f /etc/nginx/sites-available/grim
    rm -f /etc/nginx/sites-enabled/grim
    
    # Test and reload nginx
    if command -v nginx >/dev/null 2>&1; then
        nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    fi
    
    success "Nginx configuration removed"
}

remove_grim_commands() {
    log "Removing Grim commands..."
    
    # Remove grim command from /usr/local/bin
    rm -f /usr/local/bin/grim
    rm -f /usr/local/bin/grim-admin
    
    # Remove from PATH in bashrc
    if [[ -f /root/.bashrc ]]; then
        sed -i '/export PATH.*reaper/d' /root/.bashrc 2>/dev/null || true
    fi
    
    if [[ -f "$HOME/.bashrc" ]]; then
        sed -i '/export PATH.*reaper/d' "$HOME/.bashrc" 2>/dev/null || true
    fi
    
    success "Grim commands removed"
}

remove_installation_directories() {
    log "Removing Grim installation directories..."
    
    # Remove main installation directory
    if [[ -d "$GRIM_INSTALL_DIR" ]]; then
        log "Removing $GRIM_INSTALL_DIR..."
        rm -rf "$GRIM_INSTALL_DIR"
        success "Main installation directory removed"
    else
        warning "Main installation directory not found: $GRIM_INSTALL_DIR"
    fi
    
    # Remove graveyard directory
    if [[ -d "$GRIM_GRAVEYARD" ]]; then
        log "Removing $GRIM_GRAVEYARD..."
        rm -rf "$GRIM_GRAVEYARD"
        success "Graveyard directory removed"
    else
        warning "Graveyard directory not found: $GRIM_GRAVEYARD"
    fi
    
    # Remove any other Grim-related directories
    for dir in /opt/grim /opt/grim-reaper /usr/local/grim; do
        if [[ -d "$dir" ]]; then
            log "Removing $dir..."
            rm -rf "$dir"
            success "Additional directory removed: $dir"
        fi
    done
}

remove_virtual_environments() {
    log "Removing Grim virtual environments..."
    
    # Remove virtual environments in common locations
    for venv_dir in /opt/grim_venv /root/grim_venv "$HOME/grim_venv" /usr/local/grim_venv; do
        if [[ -d "$venv_dir" ]]; then
            log "Removing virtual environment: $venv_dir..."
            rm -rf "$venv_dir"
            success "Virtual environment removed: $venv_dir"
        fi
    done
}

cleanup_package_manager() {
    log "Cleaning up package manager..."
    
    # Remove any Grim-related packages (if they exist)
    if command -v apt >/dev/null 2>&1; then
        apt autoremove -y 2>/dev/null || true
        apt autoclean 2>/dev/null || true
    elif command -v yum >/dev/null 2>&1; then
        yum autoremove -y 2>/dev/null || true
        yum clean all 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf autoremove -y 2>/dev/null || true
        dnf clean all 2>/dev/null || true
    fi
    
    success "Package manager cleaned"
}

# ============================================================================
# MAIN REMOVAL PROCESS
# ============================================================================
main() {
    print_banner
    
    log "Starting Grim Reaper removal process..."
    
    # Safety confirmation
    confirm_removal
    
    # Stop services first
    stop_grim_services
    
    # Remove system components
    remove_systemd_services
    remove_nginx_config
    remove_grim_commands
    
    # Remove directories
    remove_installation_directories
    remove_virtual_environments
    
    # Cleanup
    cleanup_package_manager
    
    echo ""
    echo -e "${GREEN}${BOLD}🎉 GRIM REAPER REMOVAL COMPLETE! 🎉${NC}"
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                 REMOVAL SUMMARY                  │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│  ${WHITE}✅ Services stopped and disabled${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}✅ Systemd services removed${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}✅ Nginx configuration cleaned${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}✅ Grim commands removed${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}✅ Installation directories deleted${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}✅ Virtual environments removed${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}│  ${WHITE}✅ Package manager cleaned${NC}                ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${GREEN}💀 Grim Reaper has been completely removed from the system! 💀${NC}"
    echo ""
    echo -e "${YELLOW}Note: You may need to restart your shell or run 'source ~/.bashrc'${NC}"
    echo -e "${YELLOW}to clear any remaining PATH references.${NC}"
}

# Run main removal process
if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
    main "$@"
fi 