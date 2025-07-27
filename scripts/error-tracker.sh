#!/bin/bash
# Grim Reaper Error Tracker
# Sends error logs and installation analytics to Grim database

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

error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# Configuration
# Support both old and new server URLs for backward compatibility
# Legacy server is primary since existing 2000+ installations use it
GRIM_DB_URL="${GRIM_DB_URL:-https://db.grim.so}"
GRIM_LEGACY_URL="${GRIM_LEGACY_URL:-http://localhost:4746}"
GRIM_INSTALL_ID="${GRIM_INSTALL_ID:-}"
GRIM_VERSION="${GRIM_VERSION:-1.0.17}"
GRIM_OS="${GRIM_OS:-}"
GRIM_ARCH="${GRIM_ARCH:-}"
GRIM_API_KEY="${GRIM_API_KEY:-}"

# Generate unique install ID if not set
if [[ -z "$GRIM_INSTALL_ID" ]]; then
    GRIM_INSTALL_ID=$(uuidgen 2>/dev/null || echo "$(date +%s)-$(hostname)-$$")
fi

# Auto-generate API key if not set
if [[ -z "$GRIM_API_KEY" ]]; then
    GRIM_API_KEY=$(openssl rand -hex 32 2>/dev/null || echo "$(date +%s)-$(hostname)-$$-key")
fi

# Backward compatibility: Check for existing installation data
if [[ -f "/tmp/grim-api-key.txt" ]]; then
    GRIM_API_KEY=$(cat /tmp/grim-api-key.txt)
fi

if [[ -f "/tmp/grim-install-id.txt" ]]; then
    GRIM_INSTALL_ID=$(cat /tmp/grim-install-id.txt)
fi

# Helper function to send data with fallback URLs
send_with_fallback() {
    local endpoint="$1"
    local payload="$2"
    local operation_name="$3"
    
    # Use saved server URL if available, otherwise try both
    local saved_url=""
    if [[ -f "/tmp/grim-server-url.txt" ]]; then
        saved_url=$(cat /tmp/grim-server-url.txt)
    fi
    
    local urls=()
    if [[ -n "$saved_url" ]]; then
        urls=("$saved_url" "$GRIM_DB_URL" "$GRIM_LEGACY_URL")
    else
        urls=("$GRIM_DB_URL" "$GRIM_LEGACY_URL")
    fi
    
    local last_error=""
    
    for url in "${urls[@]}"; do
        info "Sending $operation_name via $url"
        
        local response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$url/$endpoint" 2>/dev/null)
        
        local http_code="${response: -3}"
        local response_body="${response%???}"
        
        if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
            success "$operation_name sent successfully via $url"
            echo "$url" > /tmp/grim-server-url.txt
            return 0
        else
            last_error="HTTP $http_code: $response_body"
            warning "Failed to send $operation_name via $url ($last_error)"
        fi
    done
    
    error "Failed to send $operation_name with any server. Last error: $last_error"
    return 1
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

# Register this installation with Grim database
register_installation() {
    local payload=$(cat <<EOF
{
    "install_id": "$GRIM_INSTALL_ID",
    "api_key": "$GRIM_API_KEY",
    "version": "$GRIM_VERSION",
    "os": "$GRIM_OS",
    "arch": "$GRIM_ARCH",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    info "Registering installation with Grim database..."
    
    # Try legacy server first (where existing 2000+ installations are), then fallback to local
    local urls=("$GRIM_DB_URL" "$GRIM_LEGACY_URL")
    local last_error=""
    
    for url in "${urls[@]}"; do
        info "Trying server: $url"
        
        local response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$url/create_child" 2>/dev/null)
        
        local http_code="${response: -3}"
        local response_body="${response%???}"
        
        if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
            success "Installation registered successfully via $url"
            echo "$GRIM_API_KEY" > /tmp/grim-api-key.txt
            echo "$GRIM_INSTALL_ID" > /tmp/grim-install-id.txt
            echo "$url" > /tmp/grim-server-url.txt
            return 0
        else
            last_error="HTTP $http_code: $response_body"
            warning "Failed to register via $url ($last_error)"
        fi
    done
    
    error "Failed to register installation with any server. Last error: $last_error"
    return 1
}

# Send error report to Grim database
send_error_report() {
    local error_type="$1"
    local error_message="$2"
    local error_details="$3"
    local severity="${4:-medium}"
    
    # Always log locally
    local log_entry="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: $error_type - $error_message - $error_details - $severity"
    echo "$log_entry" >> /tmp/grim-error.log
    
    # Register installation if not already done
    if [[ ! -f "/tmp/grim-api-key.txt" ]]; then
        register_installation
    fi
    
    local payload=$(cat <<EOF
{
    "install_id": "$GRIM_INSTALL_ID",
    "api_key": "$GRIM_API_KEY",
    "version": "$GRIM_VERSION",
    "os": "$GRIM_OS",
    "arch": "$GRIM_ARCH",
    "error_type": "$error_type",
    "error_message": "$error_message",
    "error_details": "$error_details",
    "severity": "$severity",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
}
EOF
)
    
    info "Sending error report to Grim database..."
    
    send_with_fallback "cry_to_mom" "$payload" "error report"
}

# Send installation analytics
send_install_analytics() {
    local install_type="$1"
    local success="$2"
    local details="$3"
    
    # Register installation if not already done
    if [[ ! -f "/tmp/grim-api-key.txt" ]]; then
        register_installation
    fi
    
    local payload=$(cat <<EOF
{
    "install_id": "$GRIM_INSTALL_ID",
    "api_key": "$GRIM_API_KEY",
    "version": "$GRIM_VERSION",
    "os": "$GRIM_OS",
    "arch": "$GRIM_ARCH",
    "install_type": "$install_type",
    "success": $success,
    "details": "$details",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
}
EOF
)
    
    info "Sending installation analytics to Grim database..."
    
    send_with_fallback "cry_to_mom" "$payload" "analytics"
}

# Track package manager downloads with detailed metrics
track_download() {
    local package_manager="$1"
    local package_name="$2"
    local version="$3"
    local download_source="$4"
    local user_agent="${5:-unknown}"
    
    # Generate unique download ID
    local download_id=$(uuidgen 2>/dev/null || echo "$(date +%s)-$(hostname)-$$-dl")
    
    # Register installation if not already done
    if [[ ! -f "/tmp/grim-api-key.txt" ]]; then
        register_installation
    fi
    
    local payload=$(cat <<EOF
{
    "download_id": "$download_id",
    "install_id": "$GRIM_INSTALL_ID",
    "api_key": "$GRIM_API_KEY",
    "package_manager": "$package_manager",
    "package_name": "$package_name",
    "version": "$version",
    "download_source": "$download_source",
    "user_agent": "$user_agent",
    "os": "$GRIM_OS",
    "arch": "$GRIM_ARCH",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "ip_hash": "$(hostname | sha256sum | cut -d' ' -f1)"
}
EOF
)
    
    info "Tracking download: $package_manager/$package_name@$version"
    
    send_with_fallback "track_download" "$payload" "download tracking"
    
    # Save download data locally for backup
    echo "$payload" >> /tmp/grim-downloads.log
}

# Track conversion events (download to registration, trial to paid, etc.)
track_conversion() {
    local conversion_type="$1"
    local from_stage="$2"
    local to_stage="$3"
    local value="${4:-0}"
    local details="$5"
    
    # Register installation if not already done
    if [[ ! -f "/tmp/grim-api-key.txt" ]]; then
        register_installation
    fi
    
    local payload=$(cat <<EOF
{
    "install_id": "$GRIM_INSTALL_ID",
    "api_key": "$GRIM_API_KEY",
    "conversion_type": "$conversion_type",
    "from_stage": "$from_stage",
    "to_stage": "$to_stage",
    "value": $value,
    "details": "$details",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
}
EOF
)
    
    info "Tracking conversion: $from_stage -> $to_stage ($conversion_type)"
    
    send_with_fallback "track_conversion" "$payload" "conversion tracking"
}

# Track user engagement and feature usage
track_usage() {
    local feature_name="$1"
    local usage_type="$2"
    local duration="${3:-0}"
    local details="$4"
    
    # Register installation if not already done
    if [[ ! -f "/tmp/grim-api-key.txt" ]]; then
        register_installation
    fi
    
    local payload=$(cat <<EOF
{
    "install_id": "$GRIM_INSTALL_ID",
    "api_key": "$GRIM_API_KEY",
    "feature_name": "$feature_name",
    "usage_type": "$usage_type",
    "duration": $duration,
    "details": "$details",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
}
EOF
)
    
    info "Tracking usage: $feature_name ($usage_type)"
    
    send_with_fallback "track_usage" "$payload" "usage tracking"
}

# Send health check report
send_health_report() {
    local health_status="$1"
    local details="$2"
    
    # Register installation if not already done
    if [[ ! -f "/tmp/grim-api-key.txt" ]]; then
        register_installation
    fi
    
    local payload=$(cat <<EOF
{
    "install_id": "$GRIM_INSTALL_ID",
    "api_key": "$GRIM_API_KEY",
    "version": "$GRIM_VERSION",
    "os": "$GRIM_OS",
    "arch": "$GRIM_ARCH",
    "health_status": "$health_status",
    "details": "$details",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
}
EOF
)
    
    info "Sending health report to Grim database..."
    
    send_with_fallback "cry_to_mom" "$payload" "health report"
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

# Migration function for existing installations
migrate_existing_installation() {
    info "Checking for existing installation data..."
    
    # If we have an API key but no install_id, try to recover
    if [[ -f "/tmp/grim-api-key.txt" && -z "$GRIM_INSTALL_ID" ]]; then
        local old_api_key=$(cat /tmp/grim-api-key.txt)
        if [[ -n "$old_api_key" ]]; then
            GRIM_API_KEY="$old_api_key"
            info "Recovered existing API key"
        fi
    fi
    
    # If we have an install_id file, use it
    if [[ -f "/tmp/grim-install-id.txt" ]]; then
        local saved_install_id=$(cat /tmp/grim-install-id.txt)
        if [[ -n "$saved_install_id" ]]; then
            GRIM_INSTALL_ID="$saved_install_id"
            info "Recovered existing install ID: $GRIM_INSTALL_ID"
        fi
    fi
}

# Main function
main() {
    detect_system
    migrate_existing_installation
    
    case "${1:-}" in
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
        "download")
            if [[ $# -lt 5 ]]; then
                error "Usage: $0 download <package_manager> <package_name> <version> <download_source> [user_agent]"
                exit 1
            fi
            track_download "$2" "$3" "$4" "$5" "${6:-}"
            ;;
        "conversion")
            if [[ $# -lt 4 ]]; then
                error "Usage: $0 conversion <type> <from_stage> <to_stage> [value] [details]"
                exit 1
            fi
            track_conversion "$2" "$3" "$4" "${5:-0}" "${6:-}"
            ;;
        "usage")
            if [[ $# -lt 3 ]]; then
                error "Usage: $0 usage <feature_name> <usage_type> [duration] [details]"
                exit 1
            fi
            track_usage "$2" "$3" "${4:-0}" "${5:-}"
            ;;
        "register")
            register_installation
            ;;
        "test")
            info "Testing API connectivity..."
            register_installation
            if [[ $? -eq 0 ]]; then
                send_health_report "test" "API connectivity test successful"
                success "API test completed successfully"
            else
                error "API test failed"
                exit 1
            fi
            ;;
        *)
            echo -e "${CYAN}🗡️  Grim Reaper Error Tracker${NC}"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  error <type> <message> [details] [severity]  Send error report"
            echo "  install <type> <success> [details]          Send installation analytics"
            echo "  health <status> [details]                   Send health report"
            echo "  dependency <name> <success> [error]         Track dependency installation"
            echo "  command <cmd> <success> <time> [error]      Track command execution"
            echo "  download <pkg_mgr> <name> <ver> <src> [ua]  Track package downloads"
            echo "  conversion <type> <from> <to> [val] [det]   Track conversion events"
            echo "  usage <feature> <type> [duration] [details] Track feature usage"
            echo "  register                                     Register installation with database"
            echo "  test                                         Test API connectivity"
            echo ""
            echo "Examples:"
            echo "  $0 error dependency_failed 'Python not found' 'python3: command not found' high"
            echo "  $0 install npm true 'Successfully installed via NPM'"
            echo "  $0 health healthy 'All systems operational'"
            echo "  $0 dependency python3 true"
            echo "  $0 command 'grim health' true 2.5"
            echo "  $0 download npm grim-reaper 1.0.30 npmjs.com 'npm/8.1.0'"
            echo "  $0 conversion download_to_register download register 0 'User registered after NPM install'"
            echo "  $0 usage backup_command start 45 'User created backup of /home/data'"
            echo "  $0 register"
            echo "  $0 test"
            echo ""
            echo "Environment Variables:"
            echo "  GRIM_DB_URL       - Primary database URL (default: https://db.grim.so)"
            echo "  GRIM_LEGACY_URL   - Fallback database URL (default: http://localhost:4746)"
            echo "  GRIM_INSTALL_ID   - Unique install identifier (auto-generated if not set)"
            echo "  GRIM_VERSION      - Grim Reaper version (default: 1.0.17)"
            echo "  GRIM_API_KEY      - API key (auto-generated if not set)"
            echo ""
            echo "Local Logs:"
            echo "  Error logs: /tmp/grim-error.log"
            echo "  API key: /tmp/grim-api-key.txt"
            echo "  Install ID: /tmp/grim-install-id.txt"
            echo "  Server URL: /tmp/grim-server-url.txt"
            exit 0
            ;;
    esac
}

# Run main function
main "$@" 