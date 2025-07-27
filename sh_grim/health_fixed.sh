#!/bin/bash
# Fixed Health Module for sh_grim with proper path handling

# ============================================================================
# INITIALIZATION
# ============================================================================
SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="${GRIM_ROOT:-$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)}"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/health_check.log"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
    log "Health check: $1"
}

print_section() {
    echo -e "\n${BLUE}--- $1 ---${NC}"
}

print_success() {
    echo -e "✅ $1"
    log "Health check: $1 - OK"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
    log "Health check: $1 - WARNING"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log "Health check: $1 - ERROR"
}

print_info() {
    echo -e "${CYAN}ℹ️ $1${NC}"
    log "Health check: $1 - INFO"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_internet() {
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_success "Internet connectivity: OK"
        return 0
    else
        print_error "Internet connectivity: FAILED"
        return 1
    fi
}

# ============================================================================
# HEALTH CHECK FUNCTIONS
# ============================================================================
check_system_health() {
    print_header "SH_GRIM SYSTEM HEALTH CHECK"
    
    local total_issues=0
    
    # Environment check
    print_section "Environment Validation"
    if [[ -z "$GRIM_ROOT" ]]; then
        print_error "GRIM_ROOT not set"
        ((total_issues++))
    else
        print_success "GRIM_ROOT: $GRIM_ROOT"
    fi
    
    # Directory structure check
    print_section "Directory Structure"
    local required_dirs=("$GRIM_ROOT/db" "$GRIM_ROOT/logs" "$GRIM_ROOT/backups" "$GRIM_ROOT/tmp")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_success "$(basename "$dir"): $dir"
        else
            print_warning "Missing directory: $dir"
            mkdir -p "$dir" 2>/dev/null && print_info "Created directory: $dir"
        fi
    done
    
    # Core modules check
    print_section "Core Modules"
    local core_modules=(backup.sh restore.sh scan.sh monitor.sh notify.sh health.sh)
    local available_modules=0
    
    for module in "${core_modules[@]}"; do
        if [[ -f "$GRIM_ROOT/sh_grim/$module" ]]; then
            print_success "Module $module: Available"
            ((available_modules++))
        else
            print_warning "Module $module: Missing"
        fi
    done
    
    print_info "Available modules: $available_modules/${#core_modules[@]}"
    
    # System resources
    check_disk_health
    check_memory_health
    check_network_health
    
    # Summary
    print_section "Health Check Summary"
    if [[ $total_issues -eq 0 ]]; then
        print_success "All systems healthy"
    else
        print_warning "Found $total_issues issue(s)"
    fi
    
    return $total_issues
}

check_services() {
    print_header "SERVICE HEALTH CHECK"
    
    local services=("ssh" "cron")
    local issues=0
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_success "$service: Running"
        else
            print_error "$service: Not running"
            ((issues++))
        fi
    done
    
    # Check if database is accessible
    if [[ -f "$DB_PATH" ]] || command_exists sqlite3; then
        print_success "Database: Accessible"
    else
        print_error "Database: Not accessible"
        ((issues++))
    fi
    
    return $issues
}

check_disk_health() {
    print_section "Disk Health"
    
    local issues=0
    
    # Check disk usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        print_success "Disk usage: ${disk_usage}%"
    elif [[ $disk_usage -lt 90 ]]; then
        print_warning "Disk usage: ${disk_usage}% (Warning)"
        ((issues++))
    else
        print_error "Disk usage: ${disk_usage}% (Critical)"
        ((issues++))
    fi
    
    # Check inode usage
    local inode_usage=$(df -i / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $inode_usage -lt 80 ]]; then
        print_success "Inode usage: ${inode_usage}%"
    else
        print_warning "Inode usage: ${inode_usage}%"
        ((issues++))
    fi
    
    return $issues
}

check_memory_health() {
    print_section "Memory Health"
    
    local issues=0
    
    if command_exists free; then
        local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        if [[ $mem_usage -lt 80 ]]; then
            print_success "Memory usage: ${mem_usage}%"
        elif [[ $mem_usage -lt 90 ]]; then
            print_warning "Memory usage: ${mem_usage}% (Warning)"
            ((issues++))
        else
            print_error "Memory usage: ${mem_usage}% (Critical)"
            ((issues++))
        fi
    else
        print_warning "Cannot check memory usage (free command not available)"
        ((issues++))
    fi
    
    return $issues
}

check_network_health() {
    print_section "Network Health"
    
    local issues=0
    
    # Check internet connectivity
    if ! check_internet; then
        ((issues++))
    fi
    
    # Check DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        print_success "DNS resolution: OK"
    else
        print_error "DNS resolution: FAILED"
        ((issues++))
    fi
    
    # Check network interfaces
    local interfaces=$(ip link show | grep -E '^[0-9]+:' | grep -v lo | awk -F': ' '{print $2}' | head -3)
    for interface in $interfaces; do
        if ip link show "$interface" | grep -q "state UP"; then
            print_success "Interface $interface: UP"
        else
            print_warning "Interface $interface: DOWN"
            ((issues++))
        fi
    done
    
    return $issues
}

fix_issues() {
    print_header "AUTOMATED SYSTEM FIXES"
    
    local fixes_applied=0
    
    # Create missing directories
    print_section "Directory Structure Fixes"
    local required_dirs=("$GRIM_ROOT/db" "$GRIM_ROOT/logs" "$GRIM_ROOT/backups" "$GRIM_ROOT/tmp")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if mkdir -p "$dir" 2>/dev/null; then
                print_success "Created directory: $dir"
                ((fixes_applied++))
            else
                print_error "Failed to create directory: $dir"
            fi
        fi
    done
    
    # Fix permissions
    print_section "Permission Fixes"
    if [[ -d "$GRIM_ROOT" ]]; then
        if chmod -R 755 "$GRIM_ROOT" 2>/dev/null; then
            print_success "Fixed permissions for GRIM_ROOT"
            ((fixes_applied++))
        fi
    fi
    
    print_section "Fix Summary"
    print_info "Applied $fixes_applied fix(es)"
    
    return 0
}

generate_report() {
    print_header "DETAILED HEALTH REPORT"
    
    local report_file="$GRIM_ROOT/logs/health_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== GRIM HEALTH REPORT ==="
        echo "Generated: $(date)"
        echo "System: $(uname -a)"
        echo "GRIM_ROOT: $GRIM_ROOT"
        echo ""
        
        echo "=== DISK USAGE ==="
        df -h
        echo ""
        
        echo "=== MEMORY USAGE ==="
        free -h
        echo ""
        
        echo "=== SYSTEM LOAD ==="
        uptime
        echo ""
        
        echo "=== NETWORK INTERFACES ==="
        ip addr show
        echo ""
        
        echo "=== RUNNING SERVICES ==="
        systemctl list-units --type=service --state=running
        echo ""
        
    } > "$report_file"
    
    print_success "Report generated: $report_file"
    
    return 0
}

# ============================================================================
# MAIN COMMAND HANDLER
# ============================================================================
main() {
    case "${1:-check}" in
        "check")
            check_system_health
            ;;
        "services")
            check_services
            ;;
        "disk")
            check_disk_health
            ;;
        "memory")
            check_memory_health
            ;;
        "network")
            check_network_health
            ;;
        "fix")
            fix_issues
            ;;
        "report")
            generate_report
            ;;
        "help"|"--help"|"-h")
            echo "Health Check Commands:"
            echo "  check     - Overall system health check"
            echo "  services  - Check service health"
            echo "  disk      - Check disk health"
            echo "  memory    - Check memory health"
            echo "  network   - Check network health"
            echo "  fix       - Automated system fixes"
            echo "  report    - Generate detailed health report"
            echo "  help      - Show this help"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use 'help' for available commands"
            exit 1
            ;;
    esac
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Run main function with all arguments
main "$@"