#!/bin/bash
# Grim Settings Module - Configuration and Alert Management
# Manages user preferences, system settings, and email alerts

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Don't source reaper.sh to avoid circular dependency

# Set GRIM_ROOT if not already set
GRIM_ROOT="${GRIM_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Define colors if not already defined
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration files
SETTINGS_FILE="$GRIM_ROOT/config/settings.conf"
EMAIL_CONFIG="$GRIM_ROOT/config/email.conf"
PROFILES_DIR="$GRIM_ROOT/config/profiles"

# Create directories if needed
mkdir -p "$PROFILES_DIR" 2>/dev/null || true

# Show help
show_help() {
    cat << EOF
Grim Settings - Configuration and Alert Management

Usage: grim settings <command> [options]

Commands:
    show [key]          Show all settings or specific key
    set <key> <value>   Set a configuration value
    reset [key]         Reset to defaults (all or specific key)
    
    email setup         Configure email alerts
    email test          Test email configuration
    email enable        Enable email alerts
    email disable       Disable email alerts
    
    profile list        List configuration profiles
    profile save <name> Save current settings as profile
    profile load <name> Load settings from profile
    profile delete <name> Delete a profile
    
    export [file]       Export settings to file
    import <file>       Import settings from file

Examples:
    grim settings show
    grim settings set backup.frequency daily
    grim settings email setup
    grim settings profile save production
EOF
}

# Initialize settings file if not exists
init_settings() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        cat > "$SETTINGS_FILE" << 'EOF'
# Grim Settings Configuration
# Generated on $(date)

# Backup Settings
backup.frequency=daily
backup.retention_days=30
backup.compression=gzip
backup.encryption=false
backup.deduplication=false
backup.verify_after_create=true

# Scan Settings
scan.exclude_patterns=*.tmp,*.log,*.cache
scan.follow_symlinks=false
scan.max_file_size=5G
scan.batch_size=1000

# Notification Settings
notify.enabled=true
notify.channels=email
notify.on_success=false
notify.on_failure=true
notify.on_warning=true
notify.disk_threshold=90

# Performance Settings
performance.parallel_jobs=4
performance.nice_level=10
performance.io_nice_class=3
performance.memory_limit=2G

# Security Settings
security.audit_enabled=false
security.checksum_algorithm=sha256
security.paranoid_mode=false

# System Settings
system.log_level=info
system.log_retention_days=7
system.temp_directory=/tmp/grim
system.database_path=$GRIM_ROOT/db/grimm.db
EOF
        echo "Created default settings file: $SETTINGS_FILE"
    fi
}

# Load settings
load_settings() {
    init_settings
    # Convert settings file to environment variables
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # Clean key and value
        key=$(echo "$key" | tr -d ' ')
        value=$(echo "$value" | tr -d ' ')
        
        # Export as environment variable
        export "GRIM_${key^^}"="$value"
    done < "$SETTINGS_FILE"
}

# Show settings
show_settings() {
    local key="$1"
    init_settings
    
    if [[ -n "$key" ]]; then
        # Show specific key
        grep "^$key=" "$SETTINGS_FILE" | cut -d'=' -f2 || echo "Key not found: $key"
    else
        # Show all settings
        echo -e "${CYAN}Current Grim Settings:${NC}"
        echo "======================"
        cat "$SETTINGS_FILE" | grep -v '^#' | grep -v '^$' | column -t -s '='
    fi
}

# Set a configuration value
set_setting() {
    local key="$1"
    local value="$2"
    
    init_settings
    
    # Validate key format
    if [[ ! "$key" =~ ^[a-z_]+\.[a-z_]+$ ]]; then
        echo -e "${RED}Invalid key format. Use category.setting (e.g., backup.frequency)${NC}"
        return 1
    fi
    
    # Check if key exists
    if grep -q "^$key=" "$SETTINGS_FILE"; then
        # Update existing key
        sed -i "s|^$key=.*|$key=$value|" "$SETTINGS_FILE"
        echo -e "${GREEN}Updated: $key = $value${NC}"
    else
        # Add new key
        echo "$key=$value" >> "$SETTINGS_FILE"
        echo -e "${GREEN}Added: $key = $value${NC}"
    fi
    
    # Log the change
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Settings updated: $key = $value" >> "$GRIM_ROOT/logs/settings.log" 2>/dev/null || true
}

# Reset settings
reset_settings() {
    local key="$1"
    
    if [[ -n "$key" ]]; then
        echo -e "${YELLOW}Resetting $key to default...${NC}"
        # Reset specific key (would need default values map)
        case "$key" in
            backup.frequency) set_setting "$key" "daily" ;;
            backup.retention_days) set_setting "$key" "30" ;;
            backup.encryption) set_setting "$key" "false" ;;
            notify.enabled) set_setting "$key" "true" ;;
            *) echo "Unknown key: $key" ;;
        esac
    else
        # Reset all settings
        echo -e "${YELLOW}Resetting all settings to defaults...${NC}"
        rm -f "$SETTINGS_FILE"
        init_settings
        echo -e "${GREEN}All settings reset to defaults${NC}"
    fi
}

# Email configuration
setup_email() {
    echo -e "${CYAN}Email Alert Configuration${NC}"
    echo "========================="
    
    # Create email config if not exists
    if [[ ! -f "$EMAIL_CONFIG" ]]; then
        touch "$EMAIL_CONFIG"
        chmod 600 "$EMAIL_CONFIG"
    fi
    
    # Gather email settings
    read -p "SMTP Server: " smtp_server
    read -p "SMTP Port [587]: " smtp_port
    smtp_port=${smtp_port:-587}
    
    read -p "SMTP Username: " smtp_user
    read -s -p "SMTP Password: " smtp_pass
    echo
    
    read -p "From Email: " from_email
    read -p "To Email (alerts recipient): " to_email
    
    read -p "Use TLS? [Y/n]: " use_tls
    use_tls=${use_tls:-Y}
    
    # Save configuration (encrypted)
    cat > "$EMAIL_CONFIG" << EOF
SMTP_SERVER="$smtp_server"
SMTP_PORT="$smtp_port"
SMTP_USER="$smtp_user"
SMTP_PASS="$smtp_pass"
FROM_EMAIL="$from_email"
TO_EMAIL="$to_email"
USE_TLS="$use_tls"
EOF
    
    # Encrypt the email config if encryption is available
    if command -v openssl >/dev/null 2>&1 && [[ -f "$GRIM_ROOT/config/.master.key" ]]; then
        openssl enc -aes-256-cbc -salt -pbkdf2 -in "$EMAIL_CONFIG" \
            -out "${EMAIL_CONFIG}.enc" -pass file:"$GRIM_ROOT/config/.master.key"
        shred -u "$EMAIL_CONFIG" 2>/dev/null || rm -f "$EMAIL_CONFIG"
        echo -e "${GREEN}Email configuration encrypted${NC}"
    fi
    
    # Update settings to enable email
    set_setting "notify.channels" "email"
    set_setting "notify.email_configured" "true"
    
    echo -e "${GREEN}Email alerts configured successfully${NC}"
}

# Test email configuration
test_email() {
    echo -e "${CYAN}Testing email configuration...${NC}"
    
    # Check if email is configured
    if [[ ! -f "${EMAIL_CONFIG}.enc" ]] && [[ ! -f "$EMAIL_CONFIG" ]]; then
        echo -e "${RED}Email not configured. Run: grim settings email setup${NC}"
        return 1
    fi
    
    # Load email config
    if [[ -f "${EMAIL_CONFIG}.enc" ]] && [[ -f "$GRIM_ROOT/config/.master.key" ]]; then
        eval "$(openssl enc -aes-256-cbc -d -pbkdf2 -in "${EMAIL_CONFIG}.enc" \
            -pass file:"$GRIM_ROOT/config/.master.key" 2>/dev/null)"
    elif [[ -f "$EMAIL_CONFIG" ]]; then
        source "$EMAIL_CONFIG"
    fi
    
    # Send test email
    local subject="Grim Test Alert"
    local body="This is a test email from Grim backup system.\n\nIf you received this, email alerts are working correctly.\n\nHost: $(hostname)\nDate: $(date)"
    
    if command -v sendemail >/dev/null 2>&1; then
        sendemail -f "$FROM_EMAIL" -t "$TO_EMAIL" -u "$subject" \
            -m "$body" -s "$SMTP_SERVER:$SMTP_PORT" \
            -xu "$SMTP_USER" -xp "$SMTP_PASS" -o tls=yes
    elif command -v mail >/dev/null 2>&1; then
        echo -e "$body" | mail -s "$subject" "$TO_EMAIL"
    else
        echo -e "${RED}No email client found. Install sendemail or mail${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Test email sent to $TO_EMAIL${NC}"
}

# Profile management
save_profile() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/${profile_name}.profile"
    
    cp "$SETTINGS_FILE" "$profile_file"
    echo -e "${GREEN}Profile saved: $profile_name${NC}"
}

load_profile() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/${profile_name}.profile"
    
    if [[ ! -f "$profile_file" ]]; then
        echo -e "${RED}Profile not found: $profile_name${NC}"
        return 1
    fi
    
    cp "$profile_file" "$SETTINGS_FILE"
    echo -e "${GREEN}Profile loaded: $profile_name${NC}"
}

# Main command dispatcher
case "${1:-help}" in
    show)
        show_settings "${2:-}"
        ;;
    set)
        if [[ $# -lt 3 ]]; then
            echo "Usage: grim settings set <key> <value>"
            exit 1
        fi
        set_setting "$2" "$3"
        ;;
    reset)
        reset_settings "${2:-}"
        ;;
    email)
        case "${2:-help}" in
            setup)
                setup_email
                ;;
            test)
                test_email
                ;;
            enable)
                set_setting "notify.enabled" "true"
                echo "Email alerts enabled"
                ;;
            disable)
                set_setting "notify.enabled" "false"
                echo "Email alerts disabled"
                ;;
            *)
                echo "Usage: grim settings email <setup|test|enable|disable>"
                ;;
        esac
        ;;
    profile)
        case "${2:-help}" in
            list)
                ls -1 "$PROFILES_DIR"/*.profile 2>/dev/null | xargs -n1 basename | sed 's/\.profile$//'
                ;;
            save)
                save_profile "$3"
                ;;
            load)
                load_profile "$3"
                ;;
            delete)
                rm -f "$PROFILES_DIR/${3}.profile"
                echo "Profile deleted: $3"
                ;;
            *)
                echo "Usage: grim settings profile <list|save|load|delete> [name]"
                ;;
        esac
        ;;
    export)
        cp "$SETTINGS_FILE" "${2:-grim-settings-export.conf}"
        echo "Settings exported to: ${2:-grim-settings-export.conf}"
        ;;
    import)
        if [[ ! -f "$2" ]]; then
            echo "File not found: $2"
            exit 1
        fi
        cp "$2" "$SETTINGS_FILE"
        echo "Settings imported from: $2"
        ;;
    help|*)
        show_help
        ;;
esac