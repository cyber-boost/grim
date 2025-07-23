#!/bin/bash
# Grim Reaper Error Tracker
# Sends error logs and installation analytics to mother Grim database

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Configuration
MOTHER_API_URL="${MOTHER_API_URL:-https://rp.grim.so}"
GRIM_INSTALL_ID="${GRIM_INSTALL_ID:-}"
GRIM_VERSION="${GRIM_VERSION:-1.0.17}"
GRIM_OS="${GRIM_OS:-}"
GRIM_ARCH="${GRIM_ARCH:-}"
GRIM_CONFIG_DIR="/opt/grim-reaper"

# Generate unique install ID if not set
if [[ -z "$GRIM_INSTALL_ID" ]]; then
    GRIM_INSTALL_ID="$(hostname)-$(date +%s)"
fi

# Auto-generate and manage API key
get_or_create_api_key() {
    local api_key_file="$GRIM_CONFIG_DIR/.api_key"
    
    # Create config directory if it doesn't exist
    mkdir -p "$GRIM_CONFIG_DIR"
    
    # Generate API key if it doesn't exist
    if [[ ! -f "$api_key_file" ]]; then
        local api_key="grim-$(openssl rand -hex 16)"
        echo "$api_key" > "$api_key_file"
        chmod 600 "$api_key_file"
        info "Generated new API key: $api_key"
    fi
    
    cat "$api_key_file"
}

# Detect OS and architecture
detect_system() {
    if [[ -z "$GRIM_OS" ]]; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if [[ -f /etc/debian_version ]]; then
                GRIM_OS="debian"
            elif [[ -f /etc/redhat-release ]]; then
                GRIM_OS="redhat"
            else
                GRIM_OS="linux"
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            GRIM_OS="macos"
        else
            GRIM_OS="unknown"
        fi
    fi
    
    if [[ -z "$GRIM_ARCH" ]]; then
        GRIM_ARCH=$(uname -m)
    fi
}

# Register installation with mother database
register_installation() {
    local api_key=$(get_or_create_api_key)
    
    # Get IP address
    local ip_address=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "unknown")
    
    local payload=$(cat <<EOF
{
    "installation_id": "$GRIM_INSTALL_ID",
    "hostname": "$(hostname)",
    "ip_address": "$ip_address",
    "os_info": "$GRIM_OS $GRIM_ARCH",
    "grim_version": "$GRIM_VERSION",
    "installation_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "contact_email": "grim@grim.so"
}
EOF
)
    
    info "Registering installation with mother database..."
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload" \
        "$MOTHER_API_URL/create_child" 2>/dev/null)
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        success "Installation registered successfully"
        return 0
    else
        warning "Failed to register installation (HTTP $http_code): $response_body"
        return 1
    fi
}

# Send error report to mother Grim
send_error_report() {
    local error_type="$1"
    local error_message="$2"
    local error_details="$3"
    local severity="${4:-medium}"
    
    # Always log locally
    local log_entry="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: $error_type - $error_message - $error_details - $severity"
    echo "$log_entry" >> /tmp/grim-error.log
    
    local api_key=$(get_or_create_api_key)
    
    local payload=$(cat <<EOF
{
    "installation_id": "$GRIM_INSTALL_ID",
    "error_type": "$error_type",
    "error_message": "$error_message",
    "severity": "$severity",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "context": {
        "error_details": "$error_details",
        "version": "$GRIM_VERSION",
        "os": "$GRIM_OS",
        "arch": "$GRIM_ARCH",
        "hostname": "$(hostname)",
        "user": "$(whoami)"
    }
}
EOF
)
    
    info "Sending error report to Grim database..."
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload" \
        "$MOTHER_API_URL/cry_to_mom" 2>/dev/null)
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        success "Error report sent successfully"
        return 0
    else
        warning "Failed to send error report (HTTP $http_code): $response_body"
        return 1
    fi
}

# Send installation analytics
send_install_analytics() {
    local install_type="$1"
    local success="$2"
    local details="$3"
    
    local api_key=$(get_or_create_api_key)
    
    local payload=$(cat <<EOF
{
    "installation_id": "$GRIM_INSTALL_ID",
    "install_type": "$install_type",
    "success": $success,
    "details": "$details",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "context": {
        "version": "$GRIM_VERSION",
        "os": "$GRIM_OS",
        "arch": "$GRIM_ARCH",
        "hostname": "$(hostname)",
        "user": "$(whoami)"
    }
}
EOF
)
    
    info "Sending installation analytics to Grim database..."
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload" \
        "$MOTHER_API_URL/cry_to_mom" 2>/dev/null)
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        success "Analytics sent successfully"
        return 0
    else
        warning "Failed to send analytics (HTTP $http_code): $response_body"
        return 1
    fi
}

# Send health check report
send_health_report() {
    local health_status="$1"
    local details="$2"
    
    local api_key=$(get_or_create_api_key)
    
    local payload=$(cat <<EOF
{
    "installation_id": "$GRIM_INSTALL_ID",
    "error_type": "health_check",
    "error_message": "$health_status",
    "severity": "low",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "context": {
        "details": "$details",
        "version": "$GRIM_VERSION",
        "os": "$GRIM_OS",
        "arch": "$GRIM_ARCH",
        "hostname": "$(hostname)",
        "user": "$(whoami)"
    }
}
EOF
)
    
    info "Sending health report to Grim database..."
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload" \
        "$MOTHER_API_URL/cry_to_mom" 2>/dev/null)
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        success "Health report sent successfully"
        return 0
    else
        warning "Failed to send health report (HTTP $http_code): $response_body"
        return 1
    fi
}

# Track dependency installation
track_dependency_install() {
    local dependency="$1"
    local success="$2"
    local error_message="$3"
    
    if [[ "$success" == "true" ]]; then
        send_install_analytics "dependency_install" true "Dependency $dependency installed successfully"
    else
        send_error_report "dependency_install_failed" "Failed to install $dependency" "$error_message" "high"
    fi
}

# Track command execution
track_command() {
    local command="$1"
    local success="$2"
    local execution_time="$3"
    local error_message="$4"
    
    if [[ "$success" == "true" ]]; then
        send_install_analytics "command_execution" true "Command $command executed successfully in ${execution_time}s"
    else
        send_error_report "command_failed" "Command $command failed" "$error_message" "medium"
    fi
}

# Main function
main() {
    detect_system
    
    case "${1:-}" in
        "register")
            register_installation
            ;;
        "error")
            if [[ $# -lt 3 ]]; then
                error "Usage: $0 error <type> <message> [details] [severity]"
                exit 1
            fi
            send_error_report "$2" "$3" "${4:-}" "${5:-medium}"
            ;;
        "install")
            if [[ $# -lt 3 ]]; then
                error "Usage: $0 install <type> <success> [details]"
                exit 1
            fi
            send_install_analytics "$2" "$3" "${4:-}"
            ;;
        "health")
            if [[ $# -lt 2 ]]; then
                error "Usage: $0 health <status> [details]"
                exit 1
            fi
            send_health_report "$2" "${3:-}"
            ;;
        "dependency")
            if [[ $# -lt 3 ]]; then
                error "Usage: $0 dependency <name> <success> [error_message]"
                exit 1
            fi
            track_dependency_install "$2" "$3" "${4:-}"
            ;;
        "command")
            if [[ $# -lt 4 ]]; then
                error "Usage: $0 command <command> <success> <execution_time> [error_message]"
                exit 1
            fi
            track_command "$2" "$3" "$4" "${5:-}"
            ;;
        *)
            echo -e "${CYAN}🗡️  Grim Reaper Error Tracker${NC}"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  register                           Register installation with mother database"
            echo "  error <type> <message> [details] [severity]  Send error report"
            echo "  install <type> <success> [details]          Send installation analytics"
            echo "  health <status> [details]                   Send health report"
            echo "  dependency <name> <success> [error]         Track dependency installation"
            echo "  command <cmd> <success> <time> [error]      Track command execution"
            echo ""
            echo "Examples:"
            echo "  $0 register"
            echo "  $0 error dependency_failed 'Python not found' 'python3: command not found' high"
            echo "  $0 install npm true 'Successfully installed via NPM'"
            echo "  $0 health healthy 'All systems operational'"
            echo "  $0 dependency python3 true"
            echo "  $0 command 'grim health' true 2.5"
            echo ""
            echo "Environment Variables:"
            echo "  MOTHER_API_URL    - Mother Grim API URL (default: https://rp.grim.so)"
            echo "  GRIM_INSTALL_ID   - Unique install identifier (auto-generated if not set)"
            echo "  GRIM_VERSION      - Grim Reaper version (default: 1.0.17)"
            echo ""
            echo "API Key: Auto-generated and stored in $GRIM_CONFIG_DIR/.api_key"
            echo "Local Log: Errors are also logged to /tmp/grim-error.log"
            echo ""
            echo "Admin Dashboard: https://rp.grim.so/admin/mother-db"
            exit 0
            ;;
    esac
}

# Run main function
main "$@" 