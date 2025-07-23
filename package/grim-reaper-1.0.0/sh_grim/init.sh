#!/bin/bash
# sh_grim initialization script - Using bash_central utilities
# Sets up proper environment and paths for sh_grim modules

# ============================================================================
# LOAD BASH_CENTRAL UTILITIES
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASH_CENTRAL_DIR="$REAPER_ROOT/bash_central"

# Source bash_central utilities
if [[ -f "$BASH_CENTRAL_DIR/defaults.sh" ]]; then
    source "$BASH_CENTRAL_DIR/defaults.sh"
fi

if [[ -f "$BASH_CENTRAL_DIR/functions.sh" ]]; then
    source "$BASH_CENTRAL_DIR/functions.sh"
fi

if [[ -f "$BASH_CENTRAL_DIR/config.sh" ]]; then
    source "$BASH_CENTRAL_DIR/config.sh"
fi

# ============================================================================
# SH_GRIM CONFIGURATION
# ============================================================================
declare -A SH_GRIM_CONFIG

# Set proper paths for sh_grim
SH_GRIM_CONFIG[reaper_root]="$REAPER_ROOT"
SH_GRIM_CONFIG[sh_grim_root]="$SCRIPT_DIR"
SH_GRIM_CONFIG[modules_dir]="$SCRIPT_DIR"  # Modules ARE in sh_grim directory
SH_GRIM_CONFIG[db_dir]="$REAPER_ROOT/db"
SH_GRIM_CONFIG[log_dir]="$REAPER_ROOT/logs"
SH_GRIM_CONFIG[backup_dir]="$REAPER_ROOT/backups"
SH_GRIM_CONFIG[tmp_dir]="$REAPER_ROOT/tmp"

# Application info
SH_GRIM_CONFIG[app_name]="sh_grim"
SH_GRIM_CONFIG[app_version]="1.0.0"
SH_GRIM_CONFIG[debug]="false"

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================
setup_sh_grim_environment() {
    print_section "Setting up sh_grim environment"
    
    # Export environment variables
    export SH_GRIM_ROOT="${SH_GRIM_CONFIG[sh_grim_root]}"
    export GRIM_ROOT="${SH_GRIM_CONFIG[reaper_root]}"
    export MODULES_DIR="${SH_GRIM_CONFIG[modules_dir]}"
    export DB_DIR="${SH_GRIM_CONFIG[db_dir]}"
    export LOG_DIR="${SH_GRIM_CONFIG[log_dir]}"
    export BACKUP_DIR="${SH_GRIM_CONFIG[backup_dir]}"
    export TMP_DIR="${SH_GRIM_CONFIG[tmp_dir]}"
    
    # Create required directories
    print_info "Creating required directories..."
    ensure_dir "$DB_DIR"
    ensure_dir "$LOG_DIR"  
    ensure_dir "$BACKUP_DIR"
    ensure_dir "$TMP_DIR"
    
    # Set up database path
    export DB_PATH="$DB_DIR/grimm.db"
    export LOG_FILE="$LOG_DIR/sh_grim.log"
    
    print_success "sh_grim environment configured"
    print_info "GRIM_ROOT: $GRIM_ROOT"
    print_info "SH_GRIM_ROOT: $SH_GRIM_ROOT"
    print_info "MODULES_DIR: $MODULES_DIR"
    print_info "DB_PATH: $DB_PATH"
}

# ============================================================================
# MODULE UTILITIES
# ============================================================================
list_available_modules() {
    print_section "Available sh_grim modules"
    
    local modules_found=0
    for script in "$MODULES_DIR"/*.sh; do
        if [[ -f "$script" && -x "$script" ]]; then
            local module_name=$(basename "$script")
            print_success "$module_name"
            ((modules_found++))
        fi
    done
    
    if [[ $modules_found -eq 0 ]]; then
        print_warning "No executable modules found in $MODULES_DIR"
        return 1
    fi
    
    print_info "Found $modules_found executable modules"
    return 0
}

check_module_dependencies() {
    print_section "Checking module dependencies"
    
    # Check core utilities
    local missing_deps=()
    
    # Essential commands
    for cmd in sqlite3 curl jq bc; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "Missing dependencies: ${missing_deps[*]}"
        print_info "Install with: sudo apt-get install ${missing_deps[*]}"
        return 1
    fi
    
    print_success "All dependencies satisfied"
    return 0
}

# ============================================================================
# HEALTH CHECK FUNCTIONS
# ============================================================================
check_sh_grim_health() {
    print_header "SH_GRIM HEALTH CHECK"
    
    local issues=0
    
    # Check environment
    print_section "Environment Check"
    if [[ -z "$SH_GRIM_ROOT" ]]; then
        print_error "SH_GRIM_ROOT not set"
        ((issues++))
    else
        print_success "SH_GRIM_ROOT: $SH_GRIM_ROOT"
    fi
    
    # Check directories
    print_section "Directory Check"
    for dir_key in db_dir log_dir backup_dir tmp_dir; do
        local dir_path="${SH_GRIM_CONFIG[$dir_key]}"
        if [[ -d "$dir_path" ]]; then
            print_success "$dir_key: $dir_path"
        else
            print_error "$dir_key not found: $dir_path"
            ((issues++))
        fi
    done
    
    # Check modules
    print_section "Module Check"
    local core_modules=(backup.sh restore.sh scan.sh health.sh monitor.sh)
    for module in "${core_modules[@]}"; do
        local module_path="$MODULES_DIR/$module"
        if [[ -f "$module_path" && -x "$module_path" ]]; then
            print_success "$module"
        else
            print_error "$module missing or not executable"
            ((issues++))
        fi
    done
    
    # Check database
    print_section "Database Check"
    if command_exists sqlite3; then
        if [[ -f "$DB_PATH" ]]; then
            if sqlite3 "$DB_PATH" "SELECT 1;" >/dev/null 2>&1; then
                print_success "Database accessible: $DB_PATH"
            else
                print_error "Database corrupted: $DB_PATH"
                ((issues++))
            fi
        else
            print_warning "Database not initialized: $DB_PATH"
        fi
    else
        print_error "sqlite3 not available"
        ((issues++))
    fi
    
    # Summary
    print_section "Health Summary"
    if [[ $issues -eq 0 ]]; then
        print_success "sh_grim is HEALTHY"
        return 0
    else
        print_error "Found $issues issue(s) - sh_grim is DEGRADED"
        return 1
    fi
}

# ============================================================================
# MAIN FUNCTIONS
# ============================================================================
show_help() {
    print_header "SH_GRIM INITIALIZATION SCRIPT"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup     - Set up sh_grim environment"
    echo "  health    - Check sh_grim health"
    echo "  modules   - List available modules"
    echo "  deps      - Check dependencies"
    echo "  info      - Show configuration info"
    echo "  help      - Show this help"
    echo ""
}

show_config_info() {
    print_header "SH_GRIM CONFIGURATION"
    
    for key in "${!SH_GRIM_CONFIG[@]}"; do
        printf "%-15s: %s\n" "$key" "${SH_GRIM_CONFIG[$key]}"
    done
}

main() {
    case "${1:-}" in
        setup)
            setup_sh_grim_environment
            ;;
        health)
            setup_sh_grim_environment >/dev/null 2>&1
            check_sh_grim_health
            ;;
        modules)
            list_available_modules
            ;;
        deps)
            check_module_dependencies
            ;;
        info)
            show_config_info
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            # Default: setup environment quietly
            setup_sh_grim_environment >/dev/null 2>&1
            ;;
    esac
}

# ============================================================================
# AUTO-SETUP
# ============================================================================
# If sourced, set up environment
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    setup_sh_grim_environment >/dev/null 2>&1
else
    # If executed directly, run main function
    main "$@"
fi