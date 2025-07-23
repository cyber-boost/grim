#!/bin/bash

# Grim Reaper Credential Manager
# Secure credential management and validation system

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
GRIM_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="${GRIM_ROOT}/config/credentials.tsk"
LOG_FILE="${GRIM_ROOT}/logs/credentials.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Parse TuskLang configuration
parse_config() {
    local config_file="$1"
    local section="$2"
    local key="$3"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    local in_section=false
    local result=""
    
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*): ]]; then
            local current_section="${BASH_REMATCH[1]}"
            if [[ "$current_section" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi
        
        if [[ "$in_section" == "true" ]]; then
            if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*(.+)$ ]]; then
                local current_key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                if [[ "$current_key" == "$key" ]]; then
                    value="${value%\"}"
                    value="${value#\"}"
                    value="${value%\'}"
                    value="${value#\'}"
                    echo "$value"
                    return 0
                fi
            fi
        fi
    done < "$config_file"
    
    return 1
}

# Generate secure random credential
generate_credential() {
    local length="${1:-32}"
    local use_special="${2:-true}"
    
    if [[ "$use_special" == "true" ]]; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    else
        openssl rand -hex "$length" | cut -c1-"$length"
    fi
}

# Validate credential strength
validate_credential() {
    local credential="$1"
    local min_length="$2"
    
    if [[ ${#credential} -lt $min_length ]]; then
        return 1
    fi
    
    # Check for special characters if required
    if [[ "$credential" =~ [^a-zA-Z0-9] ]]; then
        return 0
    fi
    
    return 1
}

# Check required environment variables
check_required_credentials() {
    local missing_vars=()
    
    # Get required variables from config
    local required_vars_section=$(parse_config "$CONFIG_FILE" "validation" "required_vars")
    
    if [[ -n "$required_vars_section" ]]; then
        while IFS= read -r var; do
            if [[ -z "${!var}" ]]; then
                missing_vars+=("$var")
            fi
        done <<< "$required_vars_section"
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Set optional credentials with defaults
set_optional_credentials() {
    local optional_vars_section=$(parse_config "$CONFIG_FILE" "validation" "optional_vars")
    
    if [[ -n "$optional_vars_section" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([A-Z_]+):[[:space:]]*(.+)$ ]]; then
                local var="${BASH_REMATCH[1]}"
                local default="${BASH_REMATCH[2]}"
                
                if [[ -z "${!var}" ]]; then
                    if [[ "$default" == "auto_generate" ]]; then
                        export "$var=$(generate_credential 32 true)"
                        log "Auto-generated credential for $var"
                    else
                        export "$var=$default"
                        log "Set default credential for $var"
                    fi
                fi
            fi
        done <<< "$optional_vars_section"
    fi
}

# Validate all credentials
validate_all_credentials() {
    local min_length=$(parse_config "$CONFIG_FILE" "validation" "min_key_length")
    [[ -z "$min_length" ]] && min_length=32
    
    local all_vars=()
    
    # Get all credential environment variables
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*_env): ]]; then
            local env_var="${BASH_REMATCH[1]}"
            local actual_var=$(parse_config "$CONFIG_FILE" "security" "$env_var")
            if [[ -n "$actual_var" ]]; then
                all_vars+=("$actual_var")
            fi
        fi
    done < "$CONFIG_FILE"
    
    local invalid_vars=()
    for var in "${all_vars[@]}"; do
        if [[ -n "${!var}" ]]; then
            if ! validate_credential "${!var}" "$min_length"; then
                invalid_vars+=("$var")
            fi
        fi
    done
    
    if [[ ${#invalid_vars[@]} -gt 0 ]]; then
        log_error "Invalid credentials (too weak): ${invalid_vars[*]}"
        return 1
    fi
    
    return 0
}

# Rotate credentials
rotate_credentials() {
    local var="$1"
    local new_credential=$(generate_credential 32 true)
    
    export "$var=$new_credential"
    log "Rotated credential for $var"
    
    # Update environment file if it exists
    local env_file="${GRIM_ROOT}/.env"
    if [[ -f "$env_file" ]]; then
        if grep -q "^$var=" "$env_file"; then
            sed -i "s/^$var=.*/$var=$new_credential/" "$env_file"
        else
            echo "$var=$new_credential" >> "$env_file"
        fi
    fi
}

# Main credential validation function
validate_credentials() {
    log "Starting credential validation..."
    
    if ! check_required_credentials; then
        log_error "Credential validation failed - missing required variables"
        return 1
    fi
    
    set_optional_credentials
    
    if ! validate_all_credentials; then
        log_error "Credential validation failed - weak credentials detected"
        return 1
    fi
    
    log "Credential validation completed successfully"
    return 0
}

# Show credential status
show_status() {
    echo -e "${CYAN}=== Credential Status ===${NC}"
    
    local all_vars=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*_env): ]]; then
            local env_var="${BASH_REMATCH[1]}"
            local actual_var=$(parse_config "$CONFIG_FILE" "security" "$env_var")
            if [[ -n "$actual_var" ]]; then
                all_vars+=("$actual_var")
            fi
        fi
    done < "$CONFIG_FILE"
    
    for var in "${all_vars[@]}"; do
        if [[ -n "${!var}" ]]; then
            local status="${GREEN}✓${NC}"
            local value="[SET]"
        else
            local status="${RED}✗${NC}"
            local value="[MISSING]"
        fi
        echo -e "$status $var: $value"
    done
}

# Main function
main() {
    case "${1:-validate}" in
        "validate")
            validate_credentials
            ;;
        "status")
            show_status
            ;;
        "rotate")
            if [[ -n "$2" ]]; then
                rotate_credentials "$2"
            else
                log_error "Usage: $0 rotate <VARIABLE_NAME>"
                exit 1
            fi
            ;;
        "generate")
            local length="${2:-32}"
            local use_special="${3:-true}"
            echo "$(generate_credential "$length" "$use_special")"
            ;;
        *)
            echo "Usage: $0 {validate|status|rotate|generate}"
            echo "  validate - Validate all credentials"
            echo "  status   - Show credential status"
            echo "  rotate   - Rotate specific credential"
            echo "  generate - Generate new credential"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 