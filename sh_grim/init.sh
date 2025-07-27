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

# Central API configuration
SH_GRIM_CONFIG[api_endpoint]="${GRIM_API_ENDPOINT:-http://localhost:4746}"
SH_GRIM_CONFIG[api_key]="${GRIM_API_KEY:-default-api-key}"

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
    
    # Create .graveyard/.rip directory structure
    print_info "Setting up .graveyard/.rip structure..."
    setup_graveyard_structure
    
    print_success "sh_grim environment configured"
    print_info "GRIM_ROOT: $GRIM_ROOT"
    print_info "SH_GRIM_ROOT: $SH_GRIM_ROOT"
    print_info "MODULES_DIR: $MODULES_DIR"
    print_info "DB_PATH: $DB_PATH"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
generate_install_id() {
    # Generate a unique install ID based on hostname, user, and timestamp
    local hostname=$(hostname)
    local user=$(whoami)
    local timestamp=$(date +%s)
    local random_suffix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 2>/dev/null || echo "fallback")
    
    echo "grim-${hostname}-${user}-${timestamp}-${random_suffix}"
}

get_or_create_install_id() {
    local init_info="$1"
    local install_id=""
    
    # Try to get existing install_id from init-info.json
    if [[ -f "$init_info" ]]; then
        if command_exists jq; then
            install_id=$(jq -r '.install_id // empty' "$init_info" 2>/dev/null)
        elif command_exists python3; then
            install_id=$(python3 -c "
import json, sys
try:
    with open('$init_info') as f:
        data = json.load(f)
    print(data.get('install_id', ''))
except: pass
" 2>/dev/null)
        fi
    fi
    
    # Generate new install_id if not found
    if [[ -z "$install_id" ]]; then
        install_id=$(generate_install_id)
    fi
    
    echo "$install_id"
}

call_api() {
    local endpoint="$1"
    local method="$2"
    local data="$3"
    local api_url="${SH_GRIM_CONFIG[api_endpoint]}"
    
    if ! command_exists curl; then
        print_error "curl not available - cannot connect to central API"
        return 1
    fi
    
    local response
    local http_code
    
    # Make the API call with timeout and error handling
    if [[ "$method" == "POST" ]]; then
        response=$(curl -s -w "\n%{http_code}" \
            --connect-timeout 10 \
            --max-time 30 \
            -H "Content-Type: application/json" \
            -X POST \
            -d "$data" \
            "$api_url$endpoint" 2>/dev/null)
    else
        response=$(curl -s -w "\n%{http_code}" \
            --connect-timeout 10 \
            --max-time 30 \
            "$api_url$endpoint" 2>/dev/null)
    fi
    
    if [[ $? -ne 0 ]]; then
        print_warning "Failed to connect to central API at $api_url"
        return 1
    fi
    
    # Extract HTTP code (last line) and response body
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        echo "$response_body"
        return 0
    else
        print_warning "API call failed with HTTP $http_code: $response_body"
        return 1
    fi
}

register_installation() {
    local install_id="$1"
    local hostname=$(hostname)
    local user=$(whoami)
    local platform=$(uname -s)
    local arch=$(uname -m)
    local api_key="${SH_GRIM_CONFIG[api_key]}"
    local version="${SH_GRIM_CONFIG[app_version]}"
    
    local registration_data=$(cat <<EOF
{
  "install_id": "$install_id",
  "api_key": "$api_key",
  "version": "$version",
  "os": "$platform",
  "arch": "$arch",
  "hostname": "$hostname",
  "user": "$user",
  "install_type": "init"
}
EOF
)
    
    print_info "Registering installation with central system..."
    
    local result
    if result=$(call_api "/create_child" "POST" "$registration_data"); then
        print_success "Installation registered successfully"
        if command_exists jq; then
            local action=$(echo "$result" | jq -r '.action // "unknown"')
            print_info "Action: $action"
        fi
        return 0
    else
        print_warning "Failed to register installation - continuing anyway"
        return 1
    fi
}

relay_error_to_central() {
    local install_id="$1"
    local error_type="$2"
    local error_message="$3"
    local error_details="$4"
    local severity="${5:-medium}"
    
    local hostname=$(hostname)
    local user=$(whoami)
    local platform=$(uname -s)
    local arch=$(uname -m)
    local api_key="${SH_GRIM_CONFIG[api_key]}"
    local version="${SH_GRIM_CONFIG[app_version]}"
    
    local error_data=$(cat <<EOF
{
  "install_id": "$install_id",
  "api_key": "$api_key",
  "error_type": "$error_type",
  "error_message": "$error_message",
  "error_details": "$error_details",
  "severity": "$severity",
  "version": "$version",
  "os": "$platform",
  "arch": "$arch",
  "hostname": "$hostname",
  "user": "$user"
}
EOF
)
    
    local result
    if result=$(call_api "/cry_to_mom" "POST" "$error_data"); then
        return 0
    else
        return 1
    fi
}

update_registration_status() {
    local init_info="$1"
    local registered="$2"
    
    if [[ ! -f "$init_info" ]]; then
        return 1
    fi
    
    # Update the registration status in the JSON file
    if command_exists jq; then
        local temp_file=$(mktemp)
        jq ".api.registered = $registered" "$init_info" > "$temp_file" && mv "$temp_file" "$init_info"
    elif command_exists python3; then
        python3 -c "
import json
try:
    with open('$init_info', 'r') as f:
        data = json.load(f)
    if 'api' not in data:
        data['api'] = {}
    data['api']['registered'] = $registered
    with open('$init_info', 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    print(f'Error updating registration status: {e}')
" 2>/dev/null
    fi
}

relay_all_errors() {
    local graveyard_dir="$GRIM_ROOT/.graveyard"
    local rip_dir="$graveyard_dir/.rip"  
    local mother_db="$rip_dir/mother.db"
    local init_info="$rip_dir/init-info.json"
    
    if [[ ! -f "$mother_db" ]]; then
        print_error "Mother database not found: $mother_db"
        return 1
    fi
    
    if [[ ! -f "$init_info" ]]; then
        print_error "Init info not found: $init_info"
        return 1
    fi
    
    # Get install_id
    local install_id=$(get_or_create_install_id "$init_info")
    if [[ -z "$install_id" ]]; then
        print_error "Could not determine install_id"
        return 1
    fi
    
    if ! command_exists sqlite3; then
        print_error "sqlite3 not available - cannot read errors from mother database"
        return 1
    fi
    
    print_info "Relaying errors from local mother database to central system..."
    
    # Get all errors from mother database
    local error_count=0
    local relayed_count=0
    local failed_count=0
    
    # Read errors and relay them
    while IFS='|' read -r error_id timestamp error_type error_message context; do
        if [[ -n "$error_id" ]]; then
            ((error_count++))
            
            # Determine severity based on error_type
            local severity="medium"
            case "$error_type" in
                *critical*|*fatal*|*fail*) severity="high" ;;
                *warning*|*warn*) severity="low" ;;
                *) severity="medium" ;;
            esac
            
            # Relay error to central system
            if relay_error_to_central "$install_id" "$error_type" "$error_message" "$context" "$severity"; then
                ((relayed_count++))
                print_success "Relayed error: $error_type"
            else
                ((failed_count++))
                print_warning "Failed to relay error: $error_type"
            fi
        fi
    done < <(sqlite3 "$mother_db" "SELECT id, timestamp, error_type, error_message, context FROM errors ORDER BY timestamp;" 2>/dev/null || echo "")
    
    # Summary
    print_section "Error Relay Summary"
    print_info "Total errors found: $error_count"
    print_info "Successfully relayed: $relayed_count"
    if [[ $failed_count -gt 0 ]]; then
        print_warning "Failed to relay: $failed_count"
    fi
    
    if [[ $error_count -eq 0 ]]; then
        print_success "No errors found in mother database"
        return 0
    elif [[ $relayed_count -eq $error_count ]]; then
        print_success "All errors relayed successfully"
        return 0
    else
        print_warning "Some errors could not be relayed to central system"
        return 1
    fi
}

# ============================================================================
# GRAVEYARD STRUCTURE SETUP
# ============================================================================
setup_graveyard_structure() {
    local graveyard_dir="$GRIM_ROOT/.graveyard"
    local rip_dir="$graveyard_dir/.rip"
    local mother_db="$rip_dir/mother.db"
    local init_info="$rip_dir/init-info.json"
    
    # Create .graveyard/.rip directories
    ensure_dir "$graveyard_dir"
    ensure_dir "$rip_dir"
    
    # Export graveyard paths
    export GRAVEYARD_DIR="$graveyard_dir"
    export RIP_DIR="$rip_dir"
    export MOTHER_DB="$mother_db"
    
    # Create SQLite mother database with required tables
    if [[ ! -f "$mother_db" ]] && command_exists sqlite3; then
        print_info "Creating mother database at $mother_db"
        sqlite3 "$mother_db" <<EOF
-- Installations table
CREATE TABLE IF NOT EXISTS installations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    grim_root TEXT NOT NULL,
    version TEXT,
    platform TEXT,
    status TEXT DEFAULT 'active'
);

-- Errors table  
CREATE TABLE IF NOT EXISTS errors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    error_type TEXT,
    error_message TEXT,
    context TEXT
);

-- Initial installation record
INSERT INTO installations (grim_root, version, platform, status) 
VALUES ('$GRIM_ROOT', '${SH_GRIM_CONFIG[app_version]}', '$(uname -s)', 'active');
EOF
        if [[ $? -eq 0 ]]; then
            print_success "Mother database created successfully"
        else
            print_error "Failed to create mother database"
        fi
    elif [[ -f "$mother_db" ]]; then
        print_info "Mother database already exists at $mother_db"
    else
        print_warning "sqlite3 not available - skipping mother database creation"
    fi
    
    # Create init-info.json with install_id
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local platform=$(uname -s)
    local arch=$(uname -m)
    local hostname=$(hostname)
    local user=$(whoami)
    local install_id=$(get_or_create_install_id "$init_info")
    
    cat > "$init_info" <<EOF
{
  "timestamp": "$timestamp",
  "install_id": "$install_id",
  "grim_root": "$GRIM_ROOT",
  "sh_grim_root": "$SH_GRIM_ROOT",
  "version": "${SH_GRIM_CONFIG[app_version]}",
  "platform": "$platform",
  "architecture": "$arch",
  "hostname": "$hostname",
  "user": "$user",
  "environment": {
    "db_dir": "$DB_DIR",
    "log_dir": "$LOG_DIR",
    "backup_dir": "$BACKUP_DIR",
    "tmp_dir": "$TMP_DIR",
    "modules_dir": "$MODULES_DIR"
  },
  "graveyard": {
    "graveyard_dir": "$graveyard_dir",
    "rip_dir": "$rip_dir",
    "mother_db": "$mother_db"
  },
  "api": {
    "endpoint": "${SH_GRIM_CONFIG[api_endpoint]}",
    "registered": false
  },
  "init_type": "sh_grim"
}
EOF
    
    if [[ $? -eq 0 ]]; then
        print_success "Init info saved to $init_info"
        
        # Try to register installation with central system
        print_info "Attempting to register installation with central system..."
        if register_installation "$install_id"; then
            # Update registration status in init-info.json
            update_registration_status "$init_info" true
            print_success "Installation registered with central system"
        else
            print_warning "Central system registration failed - continuing with local setup"
            update_registration_status "$init_info" false
        fi
    else
        print_error "Failed to create init info file"
    fi
    
    # Set proper permissions
    chmod 750 "$graveyard_dir" "$rip_dir" 2>/dev/null || true
    chmod 640 "$mother_db" "$init_info" 2>/dev/null || true
    
    # Start automatic error relay daemon
    start_error_relay_daemon
}

# ============================================================================
# ERROR RELAY DAEMON MANAGEMENT
# ============================================================================
start_error_relay_daemon() {
    local daemon_script="$SH_GRIM_ROOT/error_relay_daemon_simple.sh"
    
    if [[ ! -f "$daemon_script" ]]; then
        print_warning "Error relay daemon script not found: $daemon_script"
        return 1
    fi
    
    if [[ ! -x "$daemon_script" ]]; then
        print_warning "Error relay daemon script is not executable: $daemon_script"
        chmod +x "$daemon_script" 2>/dev/null || true
    fi
    
    print_info "Starting automatic error relay daemon..."
    
    # Check if daemon is already running
    if "$daemon_script" status >/dev/null 2>&1; then
        print_info "Error relay daemon is already running"
        return 0
    fi
    
    # Start the daemon
    if "$daemon_script" start >/dev/null 2>&1; then
        print_success "Automatic error relay daemon started"
        print_info "Errors will be automatically relayed to central system every 5 minutes"
        return 0
    else
        print_warning "Failed to start error relay daemon - errors will need to be relayed manually"
        return 1
    fi
}

stop_error_relay_daemon() {
    local daemon_script="$SH_GRIM_ROOT/error_relay_daemon_simple.sh"
    
    if [[ ! -f "$daemon_script" ]]; then
        print_warning "Error relay daemon script not found: $daemon_script"
        return 1
    fi
    
    print_info "Stopping automatic error relay daemon..."
    
    if "$daemon_script" stop >/dev/null 2>&1; then
        print_success "Error relay daemon stopped"
        return 0
    else
        print_warning "Failed to stop error relay daemon or it wasn't running"
        return 1
    fi
}

show_error_relay_status() {
    local daemon_script="$SH_GRIM_ROOT/error_relay_daemon_simple.sh"
    
    if [[ ! -f "$daemon_script" ]]; then
        print_error "Error relay daemon script not found: $daemon_script"
        return 1
    fi
    
    print_section "Error Relay Daemon Status"
    "$daemon_script" status
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
    
    # Check graveyard structure
    print_section "Graveyard Structure Check"
    local graveyard_dir="$GRIM_ROOT/.graveyard"
    local rip_dir="$graveyard_dir/.rip"
    local mother_db="$rip_dir/mother.db"
    local init_info="$rip_dir/init-info.json"
    
    if [[ -d "$graveyard_dir" ]]; then
        print_success "Graveyard directory exists"
    else
        print_error "Graveyard directory missing: $graveyard_dir"
        ((issues++))
    fi
    
    if [[ -d "$rip_dir" ]]; then
        print_success "RIP directory exists"
    else
        print_error "RIP directory missing: $rip_dir"
        ((issues++))
    fi
    
    if [[ -f "$mother_db" ]]; then
        if command_exists sqlite3 && sqlite3 "$mother_db" "SELECT COUNT(*) FROM installations;" >/dev/null 2>&1; then
            print_success "Mother database accessible"
        else
            print_error "Mother database corrupted or inaccessible"
            ((issues++))
        fi
    else
        print_warning "Mother database not found: $mother_db"
    fi
    
    if [[ -f "$init_info" ]]; then
        if command_exists jq && jq empty "$init_info" >/dev/null 2>&1; then
            print_success "Init info file valid JSON"
            
            # Check API registration status
            local registered=$(jq -r '.api.registered // false' "$init_info" 2>/dev/null)
            if [[ "$registered" == "true" ]]; then
                print_success "Installation registered with central system"
            else
                print_warning "Installation not registered with central system"
            fi
        elif python3 -c "import json; json.load(open('$init_info'))" >/dev/null 2>&1; then
            print_success "Init info file valid JSON (verified with Python)"
            
            # Check API registration status
            local registered=$(python3 -c "
import json
try:
    with open('$init_info') as f:
        data = json.load(f)
    print(data.get('api', {}).get('registered', False))
except: print('false')
" 2>/dev/null)
            if [[ "$registered" == "True" ]]; then
                print_success "Installation registered with central system"
            else
                print_warning "Installation not registered with central system"
            fi
        else
            print_error "Init info file invalid JSON: $init_info"
            ((issues++))
        fi
    else
        print_warning "Init info file not found: $init_info"
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
    echo "  setup            - Set up sh_grim environment (starts auto error relay)"
    echo "  health           - Check sh_grim health"
    echo "  modules          - List available modules"
    echo "  deps             - Check dependencies"
    echo "  info             - Show configuration info"
    echo "  graveyard        - Show graveyard structure status"
    echo "  register         - Re-register installation with central system"
    echo "  help             - Show this help"
    echo ""
    echo "Error Relay Commands:"
    echo "  error-relay-start   - Start automatic error relay daemon"
    echo "  error-relay-stop    - Stop automatic error relay daemon"
    echo "  error-relay-status  - Show error relay daemon status"
    echo "  relay-errors        - Manual one-time error relay (DEPRECATED - use automatic relay)"
    echo ""
    echo "Environment Variables:"
    echo "  GRIM_API_ENDPOINT - Central API endpoint (default: http://localhost:4746)"
    echo "  GRIM_API_KEY      - API key for central system (default: default-api-key)"
    echo ""
}

show_config_info() {
    print_header "SH_GRIM CONFIGURATION"
    
    print_section "Basic Configuration"
    for key in "${!SH_GRIM_CONFIG[@]}"; do
        printf "%-15s: %s\n" "$key" "${SH_GRIM_CONFIG[$key]}"
    done
    
    print_section "Graveyard Structure"
    if [[ -n "${GRAVEYARD_DIR:-}" ]]; then
        printf "%-15s: %s\n" "graveyard_dir" "$GRAVEYARD_DIR"
        printf "%-15s: %s\n" "rip_dir" "$RIP_DIR"
        printf "%-15s: %s\n" "mother_db" "$MOTHER_DB"
    else
        print_warning "Graveyard structure not initialized"
    fi
}

show_graveyard_status() {
    print_header "GRAVEYARD STRUCTURE STATUS"
    
    local graveyard_dir="$GRIM_ROOT/.graveyard"
    local rip_dir="$graveyard_dir/.rip"
    local mother_db="$rip_dir/mother.db"
    local init_info="$rip_dir/init-info.json"
    
    print_section "Directory Structure"
    if [[ -d "$graveyard_dir" ]]; then
        print_success "Graveyard: $graveyard_dir"
    else
        print_error "Graveyard missing: $graveyard_dir"
    fi
    
    if [[ -d "$rip_dir" ]]; then
        print_success "RIP: $rip_dir"
    else
        print_error "RIP missing: $rip_dir"
    fi
    
    print_section "Database Status"
    if [[ -f "$mother_db" ]]; then
        print_success "Mother DB: $mother_db"
        if command_exists sqlite3; then
            local install_count=$(sqlite3 "$mother_db" "SELECT COUNT(*) FROM installations;" 2>/dev/null || echo "0")
            local error_count=$(sqlite3 "$mother_db" "SELECT COUNT(*) FROM errors;" 2>/dev/null || echo "0")
            print_info "Installations: $install_count"
            print_info "Errors logged: $error_count"
        fi
    else
        print_error "Mother DB missing: $mother_db"
    fi
    
    print_section "Init Info & Registration"
    if [[ -f "$init_info" ]]; then
        print_success "Init info: $init_info"
        if command_exists jq; then
            local timestamp=$(jq -r '.timestamp // "unknown"' "$init_info" 2>/dev/null)
            local version=$(jq -r '.version // "unknown"' "$init_info" 2>/dev/null)
            local platform=$(jq -r '.platform // "unknown"' "$init_info" 2>/dev/null)
            local install_id=$(jq -r '.install_id // "unknown"' "$init_info" 2>/dev/null)
            local registered=$(jq -r '.api.registered // false' "$init_info" 2>/dev/null)
            local api_endpoint=$(jq -r '.api.endpoint // "unknown"' "$init_info" 2>/dev/null)
            print_info "Install ID: $install_id"
            print_info "Initialized: $timestamp"
            print_info "Version: $version"
            print_info "Platform: $platform"
            print_info "API Endpoint: $api_endpoint"
            if [[ "$registered" == "true" ]]; then
                print_success "Registration: Registered with central system"
            else
                print_warning "Registration: Not registered with central system"
            fi
        elif command_exists python3; then
            local info=$(python3 -c "
import json, sys
try:
    with open('$init_info') as f:
        data = json.load(f)
    print(f\"Install ID: {data.get('install_id', 'unknown')}\")
    print(f\"Initialized: {data.get('timestamp', 'unknown')}\")
    print(f\"Version: {data.get('version', 'unknown')}\")
    print(f\"Platform: {data.get('platform', 'unknown')}\")
    api_info = data.get('api', {})
    print(f\"API Endpoint: {api_info.get('endpoint', 'unknown')}\")
    registered = api_info.get('registered', False)
    print(f\"Registration: {'Registered' if registered else 'Not registered'}\")
except Exception:
    print('Unable to parse init info')
" 2>/dev/null)
            echo "$info" | while read line; do print_info "$line"; done
        fi
    else
        print_error "Init info missing: $init_info"
    fi
}

re_register_installation() {
    print_header "RE-REGISTERING INSTALLATION"
    
    local graveyard_dir="$GRIM_ROOT/.graveyard"
    local rip_dir="$graveyard_dir/.rip"
    local init_info="$rip_dir/init-info.json"
    
    if [[ ! -f "$init_info" ]]; then
        print_error "Init info not found: $init_info"
        print_info "Please run './init.sh setup' first"
        return 1
    fi
    
    # Get install_id
    local install_id=$(get_or_create_install_id "$init_info")
    if [[ -z "$install_id" ]]; then
        print_error "Could not determine install_id"
        return 1
    fi
    
    print_info "Install ID: $install_id"
    
    # Attempt registration
    if register_installation "$install_id"; then
        update_registration_status "$init_info" true
        print_success "Installation re-registered successfully"
        return 0
    else
        update_registration_status "$init_info" false
        print_error "Failed to re-register installation"
        return 1
    fi
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
            setup_sh_grim_environment >/dev/null 2>&1
            show_config_info
            ;;
        graveyard)
            setup_sh_grim_environment >/dev/null 2>&1
            show_graveyard_status
            ;;
        relay-errors)
            setup_sh_grim_environment >/dev/null 2>&1
            print_warning "DEPRECATED: Manual error relay is deprecated. Use automatic error relay daemon instead."
            print_info "Start automatic relay with: $0 error-relay-start"
            print_info "Check status with: $0 error-relay-status"
            print_info ""
            print_info "Proceeding with one-time manual relay..."
            relay_all_errors
            ;;
        error-relay-start)
            setup_sh_grim_environment >/dev/null 2>&1
            start_error_relay_daemon
            ;;
        error-relay-stop)
            setup_sh_grim_environment >/dev/null 2>&1
            stop_error_relay_daemon
            ;;
        error-relay-status)
            setup_sh_grim_environment >/dev/null 2>&1
            show_error_relay_status
            ;;
        register)
            setup_sh_grim_environment >/dev/null 2>&1
            re_register_installation
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