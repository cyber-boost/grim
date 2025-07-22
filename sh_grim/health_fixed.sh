#!/bin/bash
# Fixed Health Module for sh_grim with proper path handling

# ============================================================================
# INITIALIZATION
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source sh_grim initialization
if [[ -f "$SCRIPT_DIR/init.sh" ]]; then
    source "$SCRIPT_DIR/init.sh"
else
    echo "ERROR: init.sh not found - cannot initialize sh_grim environment"
    exit 1
fi

# ============================================================================
# HEALTH CHECK FUNCTIONS
# ============================================================================
check_system_health() {
    print_header "SH_GRIM SYSTEM HEALTH CHECK"
    
    local total_issues=0
    
    # Environment check
    print_section "Environment Validation"
    if [[ -z "$SH_GRIM_ROOT" ]] || [[ -z "$GRIM_ROOT" ]]; then
        print_error "Environment not properly initialized"
        ((total_issues++))
    else
        print_success "Environment initialized"
    fi
    
    # Directory structure check
    print_section "Directory Structure"
    local required_dirs=("$DB_DIR" "$LOG_DIR" "$BACKUP_DIR" "$TMP_DIR")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_success "$(basename "$dir"): $dir"
        else
            print_error "Missing directory: $dir"
            ((total_issues++))
        fi
    done
    
    # Core modules check
    print_section "Core Modules"
    local core_modules=(backup.sh restore.sh scan.sh monitor.sh notify.sh)
    local available_modules=0
    
    for module in "${core_modules[@]}"; do
        local module_path="$MODULES_DIR/$module"
        if [[ -f "$module_path" && -x "$module_path" ]]; then
            print_success "$module - Available"
            ((available_modules++))
        else
            print_warning "$module - Missing or not executable"
        fi
    done
    
    print_info "Available modules: $available_modules/${#core_modules[@]}"
    
    # Database health
    print_section "Database Health"
    if command_exists sqlite3; then
        if [[ -f "$DB_PATH" ]]; then
            if sqlite3 "$DB_PATH" "SELECT 1;" >/dev/null 2>&1; then
                print_success "Database operational: $DB_PATH"
            else
                print_error "Database corrupted: $DB_PATH"
                ((total_issues++))
            fi
        else
            print_info "Database will be created on first use: $DB_PATH"
        fi
    else
        print_error "sqlite3 not available"
        ((total_issues++))
    fi
    
    # System resources
    print_section "System Resources"
    
    # Memory check
    if command_exists free; then
        local mem_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
        if (( $(echo "$mem_usage > 90" | bc -l) )); then
            print_error "High memory usage: ${mem_usage}%"
            ((total_issues++))
        elif (( $(echo "$mem_usage > 75" | bc -l) )); then
            print_warning "Moderate memory usage: ${mem_usage}%"
        else
            print_success "Memory usage: ${mem_usage}%"
        fi
    fi
    
    # Disk space check
    if command_exists df; then
        local disk_usage=$(df "$GRIM_ROOT" | tail -1 | awk '{print int($5)}')
        if [[ $disk_usage -gt 90 ]]; then
            print_error "High disk usage: ${disk_usage}%"
            ((total_issues++))
        elif [[ $disk_usage -gt 75 ]]; then
            print_warning "Moderate disk usage: ${disk_usage}%"
        else
            print_success "Disk usage: ${disk_usage}%"
        fi
    fi
    
    # Network connectivity
    print_section "Network Connectivity"
    if check_internet; then
        print_success "Internet connectivity available"
    else
        print_warning "No internet connectivity (non-critical)"
    fi
    
    # Final assessment
    print_section "Health Summary"
    if [[ $total_issues -eq 0 ]]; then
        print_success "sh_grim is HEALTHY - All systems operational"
        echo "Status: HEALTHY" > "$LOG_DIR/sh_grim_status.txt"
        return 0
    elif [[ $total_issues -le 2 ]]; then
        print_warning "sh_grim is DEGRADED - $total_issues minor issue(s) found"
        echo "Status: DEGRADED" > "$LOG_DIR/sh_grim_status.txt"
        return 1
    else
        print_error "sh_grim is FAILED - $total_issues critical issue(s) found"
        echo "Status: FAILED" > "$LOG_DIR/sh_grim_status.txt"
        return 2
    fi
}

run_quick_health_check() {
    # Quick health check for scythe orchestrator
    local issues=0
    
    # Check if we can access modules directory
    if [[ ! -d "$MODULES_DIR" ]]; then
        echo "FAILED: Modules directory not found"
        return 2
    fi
    
    # Check for core modules
    local core_count=0
    for module in backup.sh restore.sh scan.sh monitor.sh; do
        if [[ -f "$MODULES_DIR/$module" && -x "$MODULES_DIR/$module" ]]; then
            ((core_count++))
        fi
    done
    
    if [[ $core_count -ge 3 ]]; then
        echo "HEALTHY: $core_count core modules available"
        return 0
    else
        echo "DEGRADED: Only $core_count core modules available"
        return 1
    fi
}

show_help() {
    print_header "SH_GRIM HEALTH CHECK"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  check     - Run full health check"
    echo "  quick     - Run quick health check"
    echo "  status    - Show current status"
    echo "  modules   - List available modules"
    echo "  info      - Show system information"
    echo "  help      - Show this help"
    echo ""
}

show_status() {
    print_section "Current Status"
    
    if [[ -f "$LOG_DIR/sh_grim_status.txt" ]]; then
        local status=$(cat "$LOG_DIR/sh_grim_status.txt")
        case "$status" in
            "Status: HEALTHY")
                print_success "sh_grim is HEALTHY"
                ;;
            "Status: DEGRADED")
                print_warning "sh_grim is DEGRADED"
                ;;
            "Status: FAILED")
                print_error "sh_grim is FAILED"
                ;;
            *)
                print_info "Status unknown - run health check"
                ;;
        esac
    else
        print_info "No status available - run health check first"
    fi
}

main() {
    case "${1:-check}" in
        check)
            check_system_health
            ;;
        quick)
            run_quick_health_check
            ;;
        status)
            show_status
            ;;
        modules)
            list_available_modules
            ;;
        info)
            show_config_info
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"