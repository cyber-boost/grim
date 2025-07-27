#!/bin/bash

# Tier Check Script for grim_throne.sh integration
# Usage: ./tier_check.sh <command> <user_id> [usage_type] [current_usage]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/cli_wrapper.py"
CONFIG_DIR="$HOME/.scythe"
LOG_FILE="$CONFIG_DIR/tier_check.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Error handling
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

# Check if Python script exists
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    error_exit "Python script not found: $PYTHON_SCRIPT"
fi

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Function to check command access
check_command_access() {
    local user_id="$1"
    local command="$2"
    
    log "Checking command access for user $user_id, command: $command"
    
    # Run Python script
    result=$(python3 "$PYTHON_SCRIPT" "check_access" "$user_id" "$command" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        error_exit "Failed to check command access"
    fi
    
    # Parse JSON result
    allowed=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('allowed', False))")
    message=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('message', ''))")
    user_tier=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('user_tier', 'FREE'))")
    
    if [[ "$allowed" == "True" ]]; then
        echo -e "${GREEN}✓ Access granted${NC}"
        log "Access granted for user $user_id, command: $command"
        return 0
    else
        echo -e "${RED}✗ Access denied${NC}"
        echo -e "${YELLOW}$message${NC}"
        log "Access denied for user $user_id, command: $command - $message"
        return 1
    fi
}

# Function to check usage limits
check_usage_limits() {
    local user_id="$1"
    local usage_type="$2"
    local current_usage="$3"
    
    log "Checking usage limits for user $user_id, type: $usage_type, usage: $current_usage"
    
    # Run Python script
    result=$(python3 "$PYTHON_SCRIPT" "check_limits" "$user_id" "$usage_type" "$current_usage" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        error_exit "Failed to check usage limits"
    fi
    
    # Parse JSON result
    allowed=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('allowed', False))")
    current_usage=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('current_usage', 0))")
    limit=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('limit', 0))")
    remaining=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('remaining', 0))")
    overage=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('overage', 0))")
    overage_cost=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('overage_cost', 0))")
    
    if [[ "$allowed" == "True" ]]; then
        echo -e "${GREEN}✓ Usage within limits${NC}"
        echo -e "${BLUE}Current: $current_usage / $limit (Remaining: $remaining)${NC}"
        log "Usage within limits for user $user_id, type: $usage_type"
        return 0
    else
        echo -e "${RED}✗ Usage limit exceeded${NC}"
        echo -e "${YELLOW}Current: $current_usage / $limit (Overage: $overage)${NC}"
        if [[ "$overage_cost" != "0" ]]; then
            echo -e "${YELLOW}Overage cost: \$$overage_cost${NC}"
        fi
        log "Usage limit exceeded for user $user_id, type: $usage_type"
        return 1
    fi
}

# Function to get available commands
get_available_commands() {
    local user_id="$1"
    
    log "Getting available commands for user $user_id"
    
    # Run Python script
    result=$(python3 "$PYTHON_SCRIPT" "get_commands" "$user_id" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        error_exit "Failed to get available commands"
    fi
    
    # Parse JSON result
    commands=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(' '.join(data.get('commands', [])))")
    
    echo -e "${BLUE}Available commands for user $user_id:${NC}"
    echo "$commands" | tr ' ' '\n' | sort
    log "Retrieved available commands for user $user_id"
}

# Function to get user usage
get_user_usage() {
    local user_id="$1"
    local usage_type="$2"
    
    log "Getting usage for user $user_id, type: $usage_type"
    
    # Run Python script
    if [[ -n "$usage_type" ]]; then
        result=$(python3 "$PYTHON_SCRIPT" "get_usage" "$user_id" "$usage_type" 2>/dev/null)
    else
        result=$(python3 "$PYTHON_SCRIPT" "get_usage" "$user_id" 2>/dev/null)
    fi
    
    if [[ $? -ne 0 ]]; then
        error_exit "Failed to get user usage"
    fi
    
    # Parse JSON result
    echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(json.dumps(data, indent=2))"
    log "Retrieved usage for user $user_id"
}

# Function to get upgrade message
get_upgrade_message() {
    local current_tier="$1"
    local required_tier="$2"
    
    log "Getting upgrade message from $current_tier to $required_tier"
    
    # Run Python script
    result=$(python3 "$PYTHON_SCRIPT" "upgrade_message" "$current_tier" "$required_tier" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        error_exit "Failed to get upgrade message"
    fi
    
    # Parse JSON result
    message=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('message', ''))")
    
    echo -e "${YELLOW}$message${NC}"
    log "Generated upgrade message: $message"
}

# Main script logic
main() {
    local command="$1"
    local user_id="$2"
    
    # Validate arguments
    if [[ -z "$command" || -z "$user_id" ]]; then
        echo "Usage: $0 <command> <user_id> [usage_type] [current_usage]"
        echo ""
        echo "Commands:"
        echo "  check_access <user_id> <command>     - Check if user can access command"
        echo "  check_limits <user_id> <type> <usage> - Check usage limits"
        echo "  get_commands <user_id>               - Get available commands"
        echo "  get_usage <user_id> [type]           - Get user usage"
        echo "  upgrade_message <current> <required> - Get upgrade message"
        exit 1
    fi
    
    case "$command" in
        "check_access")
            if [[ -z "$3" ]]; then
                error_exit "Command name required for check_access"
            fi
            check_command_access "$user_id" "$3"
            ;;
        "check_limits")
            if [[ -z "$3" || -z "$4" ]]; then
                error_exit "Usage type and current usage required for check_limits"
            fi
            check_usage_limits "$user_id" "$3" "$4"
            ;;
        "get_commands")
            get_available_commands "$user_id"
            ;;
        "get_usage")
            get_user_usage "$user_id" "$3"
            ;;
        "upgrade_message")
            if [[ -z "$3" ]]; then
                error_exit "Required tier needed for upgrade_message"
            fi
            get_upgrade_message "$user_id" "$3"
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function with all arguments
main "$@" 