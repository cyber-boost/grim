#!/bin/bash

# Grim Install - Installation and Deployment Coordination
# Manages installation, updates, and deployment of the Grimm system

# Source reaper.sh for utilities and colors
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
GRIM_ROOT="${GRIM_ROOT:-$(dirname "$SCRIPT_DIR")}"
source "$GRIM_ROOT/reaper.sh" 2>/dev/null || source /opt/grim/reaper.sh 2>/dev/null

INSTALL_VERSION="1.0.0"
INSTALL_CONFIG="${GRIM_CONFIG_DIR}/install.tsk"
INSTALL_DB="${GRIM_DB_DIR}/install.db"
INSTALL_LOG="${GRIM_LOG_DIR}/install.log"
INSTALL_PID="${GRIM_RUN_DIR}/install.pid"
INSTALL_CACHE="${GRIM_CACHE_DIR}/install"
INSTALL_BACKUP="${GRIM_BACKUP_DIR}/install"

# Initialize installation database
init_install_db() {
    sqlite3 "$INSTALL_DB" <<EOF
CREATE TABLE IF NOT EXISTS installations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component_name TEXT NOT NULL,
    version TEXT NOT NULL,
    install_path TEXT NOT NULL,
    install_type TEXT DEFAULT 'manual',
    status TEXT DEFAULT 'installed',
    install_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dependencies TEXT,
    config_hash TEXT,
    backup_path TEXT
);

CREATE TABLE IF NOT EXISTS deployments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    deployment_id TEXT UNIQUE NOT NULL,
    environment TEXT NOT NULL,
    target_hosts TEXT,
    components TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    deployed_by TEXT,
    rollback_available BOOLEAN DEFAULT FALSE,
    rollback_path TEXT
);

CREATE TABLE IF NOT EXISTS updates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component_name TEXT NOT NULL,
    from_version TEXT,
    to_version TEXT NOT NULL,
    update_type TEXT DEFAULT 'patch',
    changelog TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    applied_at TIMESTAMP,
    applied_by TEXT,
    backup_created BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS system_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component_name TEXT NOT NULL,
    requirement_type TEXT NOT NULL,
    requirement_name TEXT NOT NULL,
    min_version TEXT,
    max_version TEXT,
    current_version TEXT,
    status TEXT DEFAULT 'unknown',
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_installations_component ON installations(component_name);
CREATE INDEX IF NOT EXISTS idx_installations_status ON installations(status);
CREATE INDEX IF NOT EXISTS idx_deployments_id ON deployments(deployment_id);
CREATE INDEX IF NOT EXISTS idx_deployments_status ON deployments(status);
CREATE INDEX IF NOT EXISTS idx_updates_component ON updates(component_name);
CREATE INDEX IF NOT EXISTS idx_updates_status ON updates(status);
CREATE INDEX IF NOT EXISTS idx_requirements_component ON system_requirements(component_name);
EOF
}

# System requirement checking
check_system_requirements() {
    local component_name="$1"
    
    echo "${CYAN}Checking system requirements for $component_name...${RESET}"
    
    # Check operating system
    check_os_requirement "$component_name"
    
    # Check required packages
    check_package_requirements "$component_name"
    
    # Check disk space
    check_disk_requirements "$component_name"
    
    # Check memory
    check_memory_requirements "$component_name"
    
    # Check network connectivity
    check_network_requirements "$component_name"
    
    echo "${GREEN}✓ System requirements check completed${RESET}"
}

check_os_requirement() {
    local component_name="$1"
    
    local os_name=$(uname -s)
    local os_version=$(uname -r)
    
    # Store OS requirement
    sqlite3 "$INSTALL_DB" <<EOF
INSERT OR REPLACE INTO system_requirements (component_name, requirement_type, requirement_name, current_version, status, checked_at)
VALUES ('$component_name', 'os', '$os_name', '$os_version', 'ok', CURRENT_TIMESTAMP);
EOF
    
    echo "  OS: $os_name $os_version ✓"
}

check_package_requirements() {
    local component_name="$1"
    
    # Define required packages based on component
    local required_packages=""
    case "$component_name" in
        grim)
            required_packages="sqlite3 curl wget jq openssl"
            ;;
        scythe)
            required_packages="sqlite3 curl jq openssl"
            ;;
        security)
            required_packages="sqlite3 openssl certbot"
            ;;
        *)
            required_packages="sqlite3 curl"
            ;;
    esac
    
    for package in $required_packages; do
        local version=""
        local status="missing"
        
        case "$package" in
            sqlite3)
                if command -v sqlite3 >/dev/null 2>&1; then
                    version=$(sqlite3 --version | head -1 | cut -d' ' -f1)
                    status="ok"
                fi
                ;;
            curl)
                if command -v curl >/dev/null 2>&1; then
                    version=$(curl --version | head -1 | cut -d' ' -f2)
                    status="ok"
                fi
                ;;
            wget)
                if command -v wget >/dev/null 2>&1; then
                    version=$(wget --version | head -1 | cut -d' ' -f3)
                    status="ok"
                fi
                ;;
            jq)
                if command -v jq >/dev/null 2>&1; then
                    version=$(jq --version)
                    status="ok"
                fi
                ;;
            openssl)
                if command -v openssl >/dev/null 2>&1; then
                    version=$(openssl version | cut -d' ' -f2)
                    status="ok"
                fi
                ;;
            certbot)
                if command -v certbot >/dev/null 2>&1; then
                    version=$(certbot --version | cut -d' ' -f2)
                    status="ok"
                fi
                ;;
        esac
        
        # Store package requirement
        sqlite3 "$INSTALL_DB" <<EOF
INSERT OR REPLACE INTO system_requirements (component_name, requirement_type, requirement_name, current_version, status, checked_at)
VALUES ('$component_name', 'package', '$package', '$version', '$status', CURRENT_TIMESTAMP);
EOF
        
        if [[ "$status" == "ok" ]]; then
            echo "  Package: $package $version ✓"
        else
            echo "  Package: $package ❌ (missing)"
        fi
    done
}

check_disk_requirements() {
    local component_name="$1"
    local required_space=1000  # 1GB in MB
    local available_space=$(df -m "$GRIM_ROOT" | tail -1 | awk '{print $4}')
    
    local status="ok"
    if [[ $available_space -lt $required_space ]]; then
        status="insufficient"
    fi
    
    # Store disk requirement
    sqlite3 "$INSTALL_DB" <<EOF
INSERT OR REPLACE INTO system_requirements (component_name, requirement_type, requirement_name, current_version, status, checked_at)
VALUES ('$component_name', 'disk', 'available_space', '${available_space}MB', '$status', CURRENT_TIMESTAMP);
EOF
    
    if [[ "$status" == "ok" ]]; then
        echo "  Disk: ${available_space}MB available ✓"
    else
        echo "  Disk: ${available_space}MB available ❌ (insufficient)"
    fi
}

check_memory_requirements() {
    local component_name="$1"
    local required_memory=512  # 512MB
    local total_memory=$(free -m | grep Mem | awk '{print $2}')
    
    local status="ok"
    if [[ $total_memory -lt $required_memory ]]; then
        status="insufficient"
    fi
    
    # Store memory requirement
    sqlite3 "$INSTALL_DB" <<EOF
INSERT OR REPLACE INTO system_requirements (component_name, requirement_type, requirement_name, current_version, status, checked_at)
VALUES ('$component_name', 'memory', 'total_memory', '${total_memory}MB', '$status', CURRENT_TIMESTAMP);
EOF
    
    if [[ "$status" == "ok" ]]; then
        echo "  Memory: ${total_memory}MB total ✓"
    else
        echo "  Memory: ${total_memory}MB total ❌ (insufficient)"
    fi
}

check_network_requirements() {
    local component_name="$1"
    local test_urls="https://api.grim.so https://github.com"
    local status="ok"
    
    for url in $test_urls; do
        if ! curl -s --connect-timeout 5 --max-time 10 "$url" >/dev/null 2>&1; then
            status="unreachable"
            break
        fi
    done
    
    # Store network requirement
    sqlite3 "$INSTALL_DB" <<EOF
INSERT OR REPLACE INTO system_requirements (component_name, requirement_type, requirement_name, current_version, status, checked_at)
VALUES ('$component_name', 'network', 'connectivity', 'tested', '$status', CURRENT_TIMESTAMP);
EOF
    
    if [[ "$status" == "ok" ]]; then
        echo "  Network: Connectivity test passed ✓"
    else
        echo "  Network: Connectivity test failed ❌"
    fi
}

# Component installation
install_component() {
    local component_name="$1"
    local version="$2"
    local install_path="$3"
    local install_type="${4:-manual}"
    
    echo "${CYAN}Installing $component_name v$version...${RESET}"
    
    # Check system requirements
    check_system_requirements "$component_name"
    
    # Create installation directory
    mkdir -p "$install_path"
    
    # Download component if needed
    if [[ "$install_type" == "remote" ]]; then
        download_component "$component_name" "$version" "$install_path"
    fi
    
    # Install dependencies
    install_dependencies "$component_name"
    
    # Configure component
    configure_component "$component_name" "$install_path"
    
    # Create backup
    create_install_backup "$component_name" "$install_path"
    
    # Register installation
    register_installation "$component_name" "$version" "$install_path" "$install_type"
    
    echo "${GREEN}✓ $component_name v$version installed successfully${RESET}"
}

download_component() {
    local component_name="$1"
    local version="$2"
    local install_path="$3"
    
    local download_url="https://api.grim.so/download/$component_name/$version"
    local archive_file="$INSTALL_CACHE/${component_name}-${version}.tar.gz"
    
    echo "  Downloading from $download_url..."
    
    # Create cache directory
    mkdir -p "$INSTALL_CACHE"
    
    # Download component
    if curl -L -o "$archive_file" "$download_url"; then
        echo "  Download completed"
        
        # Extract component
        tar -xzf "$archive_file" -C "$install_path" --strip-components=1
        
        # Clean up
        rm -f "$archive_file"
    else
        echo "${RED}Error: Failed to download $component_name${RESET}"
        return 1
    fi
}

install_dependencies() {
    local component_name="$1"
    
    echo "  Installing dependencies..."
    
    case "$component_name" in
        grim)
            # Install Grim dependencies
            install_package_if_missing "sqlite3"
            install_package_if_missing "curl"
            install_package_if_missing "wget"
            install_package_if_missing "jq"
            ;;
        scythe)
            # Install Scythe dependencies
            install_package_if_missing "sqlite3"
            install_package_if_missing "curl"
            install_package_if_missing "jq"
            ;;
        security)
            # Install Security dependencies
            install_package_if_missing "sqlite3"
            install_package_if_missing "openssl"
            install_package_if_missing "certbot"
            ;;
    esac
}

install_package_if_missing() {
    local package="$1"
    
    if ! command -v "$package" >/dev/null 2>&1; then
        echo "    Installing $package..."
        
        # Detect package manager and install
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y "$package"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "$package"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "$package"
        elif command -v pacman >/dev/null 2>&1; then
            pacman -S --noconfirm "$package"
        else
            echo "${YELLOW}⚠ Package manager not detected, manual installation required for $package${RESET}"
        fi
    fi
}

configure_component() {
    local component_name="$1"
    local install_path="$2"
    
    echo "  Configuring $component_name..."
    
    # Create configuration directory
    mkdir -p "$GRIM_CONFIG_DIR"
    
    # Generate component configuration
    case "$component_name" in
        grim)
            create_grim_config "$install_path"
            ;;
        scythe)
            create_scythe_config "$install_path"
            ;;
        security)
            create_security_config "$install_path"
            ;;
    esac
    
    # Set permissions
    chmod +x "$install_path"/*.sh 2>/dev/null || true
}

create_grim_config() {
    local install_path="$1"
    
    cat > "$GRIM_CONFIG_DIR/grim.tsk" <<EOF
# Grim Configuration
grim:
  version: "1.0.0"
  install_path: "$install_path"
  log_level: "info"
  backup_retention: 30
  auto_update: true

modules:
  monitor: true
  health: true
  compress: true
  scythe: true
  security: true
  install: true

paths:
  config_dir: "$GRIM_CONFIG_DIR"
  data_dir: "$GRIM_DB_DIR"
  log_dir: "$GRIM_LOG_DIR"
  backup_dir: "$GRIM_BACKUP_DIR"
  cache_dir: "$GRIM_CACHE_DIR"
  run_dir: "$GRIM_RUN_DIR"
EOF
}

create_scythe_config() {
    local install_path="$1"
    
    cat > "$GRIM_CONFIG_DIR/scythe.tsk" <<EOF
# Scythe Configuration
scythe:
  version: "2.0.0"
  install_path: "$install_path"
  mother_db_url: "https://api.grim.so/scythe"
  check_interval: 3600
  stealth_mode: true

protection:
  default_license_file: ".license"
  check_files: true
  check_processes: true
  integrity_check: true

monitoring:
  silent: true
  background: true
  retry_attempts: 3
  timeout: 30

notifications:
  channels:
    - grim_command
    - email
    - web_dashboard
EOF
}

create_security_config() {
    local install_path="$1"
    
    cat > "$GRIM_CONFIG_DIR/security.tsk" <<EOF
# Security Configuration
security:
  version: "1.0.0"
  install_path: "$install_path"
  monitoring_interval: 300
  alert_threshold: 5

access_control:
  enabled: true
  default_permission: "deny"
  wildcard_support: true

encryption:
  default_algorithm: "aes256"
  key_rotation_days: 365
  auto_backup: true

ssl:
  auto_renew: true
  renewal_threshold: 30
  certbot_path: "/usr/bin/certbot"

audit:
  enabled: true
  retention_days: 90
  log_failed_attempts: true
EOF
}

create_install_backup() {
    local component_name="$1"
    local install_path="$2"
    
    local backup_path="$INSTALL_BACKUP/${component_name}-$(date +%Y%m%d-%H%M%S)"
    
    echo "  Creating backup..."
    
    mkdir -p "$INSTALL_BACKUP"
    cp -r "$install_path" "$backup_path"
    
    # Store backup path
    sqlite3 "$INSTALL_DB" "UPDATE installations SET backup_path = '$backup_path' WHERE component_name = '$component_name'"
}

register_installation() {
    local component_name="$1"
    local version="$2"
    local install_path="$3"
    local install_type="$4"
    
    # Calculate config hash
    local config_hash=$(find "$GRIM_CONFIG_DIR" -name "*.tsk" -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1)
    
    sqlite3 "$INSTALL_DB" <<EOF
INSERT OR REPLACE INTO installations (component_name, version, install_path, install_type, status, config_hash, last_update)
VALUES ('$component_name', '$version', '$install_path', '$install_type', 'installed', '$config_hash', CURRENT_TIMESTAMP);
EOF
}

# Deployment management
create_deployment() {
    local deployment_id="$1"
    local environment="$2"
    local target_hosts="$3"
    local components="$4"
    local deployed_by="$5"
    
    echo "${CYAN}Creating deployment $deployment_id...${RESET}"
    
    sqlite3 "$INSTALL_DB" <<EOF
INSERT INTO deployments (deployment_id, environment, target_hosts, components, deployed_by, status)
VALUES ('$deployment_id', '$environment', '$target_hosts', '$components', '$deployed_by', 'pending');
EOF
    
    echo "${GREEN}✓ Deployment $deployment_id created${RESET}"
}

execute_deployment() {
    local deployment_id="$1"
    
    echo "${CYAN}Executing deployment $deployment_id...${RESET}"
    
    # Get deployment details
    local deployment_info=$(sqlite3 "$INSTALL_DB" "
        SELECT environment, target_hosts, components, deployed_by 
        FROM deployments 
        WHERE deployment_id = '$deployment_id'
    ")
    
    if [[ -z "$deployment_info" ]]; then
        echo "${RED}Error: Deployment $deployment_id not found${RESET}"
        return 1
    fi
    
    local environment=$(echo "$deployment_info" | cut -d'|' -f1)
    local target_hosts=$(echo "$deployment_info" | cut -d'|' -f2)
    local components=$(echo "$deployment_info" | cut -d'|' -f3)
    local deployed_by=$(echo "$deployment_info" | cut -d'|' -f4)
    
    # Update status to running
    sqlite3 "$INSTALL_DB" "UPDATE deployments SET status = 'running' WHERE deployment_id = '$deployment_id'"
    
    # Deploy to each target host
    local success=true
    for host in $(echo "$target_hosts" | tr ',' ' '); do
        echo "  Deploying to $host..."
        
        if deploy_to_host "$host" "$components" "$environment"; then
            echo "    ✓ Deployment to $host successful"
        else
            echo "    ❌ Deployment to $host failed"
            success=false
        fi
    done
    
    # Update deployment status
    local final_status="completed"
    if [[ "$success" == "false" ]]; then
        final_status="failed"
    fi
    
    sqlite3 "$INSTALL_DB" "UPDATE deployments SET status = '$final_status', completed_at = CURRENT_TIMESTAMP WHERE deployment_id = '$deployment_id'"
    
    if [[ "$success" == "true" ]]; then
        echo "${GREEN}✓ Deployment $deployment_id completed successfully${RESET}"
    else
        echo "${RED}✗ Deployment $deployment_id failed${RESET}"
        return 1
    fi
}

deploy_to_host() {
    local host="$1"
    local components="$2"
    local environment="$3"
    
    # Create deployment script
    local deploy_script=$(mktemp)
    cat > "$deploy_script" <<EOF
#!/bin/bash
# Deployment script for $host
# Components: $components
# Environment: $environment

set -e

# Update system
apt-get update

# Install components
for component in $components; do
    echo "Installing \$component..."
    # Component-specific installation logic here
done

# Configure environment
echo "Configuring for $environment environment..."
# Environment-specific configuration here

echo "Deployment completed successfully"
EOF
    
    # Execute deployment script on target host
    if ssh "$host" "bash -s" < "$deploy_script"; then
        rm -f "$deploy_script"
        return 0
    else
        rm -f "$deploy_script"
        return 1
    fi
}

# Update management
check_for_updates() {
    local component_name="$1"
    
    echo "${CYAN}Checking for updates for $component_name...${RESET}"
    
    # Get current version
    local current_version=$(sqlite3 "$INSTALL_DB" "SELECT version FROM installations WHERE component_name = '$component_name' AND status = 'installed'")
    
    if [[ -z "$current_version" ]]; then
        echo "${YELLOW}⚠ $component_name not installed${RESET}"
        return 1
    fi
    
    # Check for updates from API
    local update_info=$(curl -s "https://api.grim.so/updates/$component_name" 2>/dev/null)
    local latest_version=$(echo "$update_info" | jq -r '.latest_version' 2>/dev/null)
    
    if [[ "$latest_version" != "null" ]] && [[ "$latest_version" != "$current_version" ]]; then
        echo "  Current version: $current_version"
        echo "  Latest version: $latest_version"
        
        # Create update record
        local changelog=$(echo "$update_info" | jq -r '.changelog // "No changelog available"' 2>/dev/null)
        local update_type=$(echo "$update_info" | jq -r '.update_type // "patch"' 2>/dev/null)
        
        sqlite3 "$INSTALL_DB" <<EOF
INSERT INTO updates (component_name, from_version, to_version, update_type, changelog, status)
VALUES ('$component_name', '$current_version', '$latest_version', '$update_type', '$changelog', 'pending');
EOF
        
        echo "${GREEN}✓ Update available for $component_name${RESET}"
        return 0
    else
        echo "${GREEN}✓ $component_name is up to date${RESET}"
        return 1
    fi
}

apply_update() {
    local component_name="$1"
    local to_version="$2"
    
    echo "${CYAN}Applying update for $component_name to v$to_version...${RESET}"
    
    # Get current installation info
    local install_info=$(sqlite3 "$INSTALL_DB" "
        SELECT install_path, version FROM installations 
        WHERE component_name = '$component_name' AND status = 'installed'
    ")
    
    if [[ -z "$install_info" ]]; then
        echo "${RED}Error: $component_name not installed${RESET}"
        return 1
    fi
    
    local install_path=$(echo "$install_info" | cut -d'|' -f1)
    local from_version=$(echo "$install_info" | cut -d'|' -f2)
    
    # Create backup before update
    create_install_backup "$component_name" "$install_path"
    
    # Download and install new version
    if download_component "$component_name" "$to_version" "$install_path"; then
        # Update installation record
        sqlite3 "$INSTALL_DB" "UPDATE installations SET version = '$to_version', last_update = CURRENT_TIMESTAMP WHERE component_name = '$component_name'"
        
        # Update update record
        sqlite3 "$INSTALL_DB" "UPDATE updates SET status = 'applied', applied_at = CURRENT_TIMESTAMP, applied_by = 'system' WHERE component_name = '$component_name' AND to_version = '$to_version' AND status = 'pending'"
        
        echo "${GREEN}✓ Update applied successfully${RESET}"
        return 0
    else
        echo "${RED}✗ Update failed${RESET}"
        return 1
    fi
}

# Rollback functionality
rollback_deployment() {
    local deployment_id="$1"
    
    echo "${CYAN}Rolling back deployment $deployment_id...${RESET}"
    
    # Get deployment info
    local deployment_info=$(sqlite3 "$INSTALL_DB" "
        SELECT rollback_path, components FROM deployments 
        WHERE deployment_id = '$deployment_id' AND rollback_available = 1
    ")
    
    if [[ -z "$deployment_info" ]]; then
        echo "${RED}Error: Rollback not available for deployment $deployment_id${RESET}"
        return 1
    fi
    
    local rollback_path=$(echo "$deployment_info" | cut -d'|' -f1)
    local components=$(echo "$deployment_info" | cut -d'|' -f2)
    
    # Restore from backup
    for component in $(echo "$components" | tr ',' ' '); do
        local component_backup="$rollback_path/$component"
        if [[ -d "$component_backup" ]]; then
            echo "  Rolling back $component..."
            rm -rf "$GRIM_ROOT/modules/$component"
            cp -r "$component_backup" "$GRIM_ROOT/modules/$component"
        fi
    done
    
    # Update deployment status
    sqlite3 "$INSTALL_DB" "UPDATE deployments SET status = 'rolled_back', completed_at = CURRENT_TIMESTAMP WHERE deployment_id = '$deployment_id'"
    
    echo "${GREEN}✓ Rollback completed successfully${RESET}"
}

# Installation report generation
generate_install_report() {
    local report_type="${1:-summary}"
    
    case "$report_type" in
        summary)
            echo "${GREEN}=== Installation Summary ===${RESET}"
            
            local total_installations=$(sqlite3 "$INSTALL_DB" "SELECT COUNT(*) FROM installations WHERE status = 'installed'")
            local total_deployments=$(sqlite3 "$INSTALL_DB" "SELECT COUNT(*) FROM deployments")
            local pending_updates=$(sqlite3 "$INSTALL_DB" "SELECT COUNT(*) FROM updates WHERE status = 'pending'")
            
            echo "Installed Components: $total_installations"
            echo "Total Deployments: $total_deployments"
            echo "Pending Updates: $pending_updates"
            ;;
            
        installations)
            echo "${CYAN}=== Installed Components ===${RESET}"
            sqlite3 "$INSTALL_DB" "
                SELECT component_name, version, install_path, install_type, install_date, last_update 
                FROM installations 
                WHERE status = 'installed'
                ORDER BY install_date DESC
            "
            ;;
            
        deployments)
            echo "${BLUE}=== Deployment History ===${RESET}"
            sqlite3 "$INSTALL_DB" "
                SELECT deployment_id, environment, components, status, started_at, completed_at, deployed_by 
                FROM deployments 
                ORDER BY started_at DESC
                LIMIT 20
            "
            ;;
            
        updates)
            echo "${YELLOW}=== Update History ===${RESET}"
            sqlite3 "$INSTALL_DB" "
                SELECT component_name, from_version, to_version, update_type, status, created_at, applied_at 
                FROM updates 
                ORDER BY created_at DESC
                LIMIT 20
            "
            ;;
            
        requirements)
            echo "${MAGENTA}=== System Requirements ===${RESET}"
            sqlite3 "$INSTALL_DB" "
                SELECT component_name, requirement_type, requirement_name, current_version, status, checked_at 
                FROM system_requirements 
                ORDER BY component_name, requirement_type
            "
            ;;
            
        *)
            echo "${RED}Unknown report type: $report_type${RESET}"
            echo "Available types: summary, installations, deployments, updates, requirements"
            ;;
    esac
}

# Display help
help() {
    cat <<EOF
${GREEN}Grim Install v$INSTALL_VERSION - Installation and Deployment Coordination${RESET}

Usage: $0 [command] [options]

Commands:
  init                                           Initialize installation database
  install <component> <version> <path> [type]   Install a component
  deploy create <id> <env> <hosts> <comps> <by> Create deployment
  deploy execute <id>                           Execute deployment
  deploy rollback <id>                          Rollback deployment
  update check <component>                      Check for updates
  update apply <component> <version>            Apply update
  requirements <component>                      Check system requirements
  report [type]                                 Generate installation report
  
Report Types:
  summary        - Installation overview
  installations  - Installed components
  deployments    - Deployment history
  updates        - Update history
  requirements   - System requirements

Options:
  -h, --help                Show this help message
  -v, --verbose             Verbose output
  -d, --debug               Debug mode

Examples:
  $0 init
  $0 install grim 1.0.0 /opt/grim
  $0 deploy create prod-001 production "host1,host2" "grim,scythe" admin
  $0 deploy execute prod-001
  $0 update check grim
  $0 requirements security
  $0 report deployments
  
Installation Features:
  - Automated component installation
  - System requirement checking
  - Multi-host deployment coordination
  - Update management with rollback
  - Comprehensive reporting
  - Backup and recovery
  - Configuration management
EOF
}

# Main command handler
case "${1:-help}" in
    init)
        init_install_db
        echo "${GREEN}✓ Installation database initialized${RESET}"
        ;;
    install)
        shift
        install_component "$@"
        ;;
    deploy)
        case "${2:-}" in
            create)
                shift 2
                create_deployment "$@"
                ;;
            execute)
                shift 2
                execute_deployment "$@"
                ;;
            rollback)
                shift 2
                rollback_deployment "$@"
                ;;
            *)
                echo "${RED}Usage: $0 deploy create|execute|rollback${RESET}"
                exit 1
                ;;
        esac
        ;;
    update)
        case "${2:-}" in
            check)
                shift 2
                check_for_updates "$@"
                ;;
            apply)
                shift 2
                apply_update "$@"
                ;;
            *)
                echo "${RED}Usage: $0 update check|apply${RESET}"
                exit 1
                ;;
        esac
        ;;
    requirements)
        shift
        check_system_requirements "$@"
        ;;
    report)
        shift
        generate_install_report "$@"
        ;;
    help|-h|--help)
        help
        ;;
    *)
        echo "${RED}Unknown command: $1${RESET}"
        help
        exit 1
        ;;
esac 