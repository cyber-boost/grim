#!/bin/bash

# Grim Scythe License Management Module
# Manages license creation, validation, and revocation

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
SCYTHE_MODULE="$GRIM_ROOT/modules/scythe.sh"
SCYTHE_MOTHER="$GRIM_ROOT/modules/scythe_mother.sh"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

show_help() {
    echo "Grimm Scythe License Management"
    echo "Usage: scythe-license.sh <command> [options]"
    echo ""
    echo "Purpose: Manage software licenses with full control and monitoring"
    echo "         capabilities."
    echo ""
    echo "Commands:"
    echo "  create <software_id> [type] [issued_to] [expires_days]"
    echo "                    - Generate new license key"
    echo "  validate <license_key>"
    echo "                    - Validate license key"
    echo "  revoke <license_key> [reason]"
    echo "                    - Revoke license"
    echo "  list               - List all licenses"
    echo "  info <license_key> - Show detailed license information"
    echo "  renew <license_key> [days]"
    echo "                    - Renew license expiration"
    echo "  transfer <license_key> <new_owner>"
    echo "                    - Transfer license ownership"
    echo "  violations <license_key>"
    echo "                    - Show license violations"
    echo "  help, -h, --help   - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scythe-license.sh create my_app full user@example.com 365"
    echo "  ./scythe-license.sh validate GRIM-ABCD-1234-EFGH"
    echo "  ./scythe-license.sh revoke GRIM-ABCD-1234-EFGH 'Violation detected'"
    echo "  ./scythe-license.sh list"
    echo "  ./scythe-license.sh help"
}

# Generate new license
create_license() {
    local software_id="$1"
    local type="${2:-full}"
    local issued_to="${3:-}"
    local expires_days="${4:-365}"
    
    if [ -z "$software_id" ]; then
        echo -e "${RED}❌ Software ID is required${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== Creating License ===${NC}"
    echo "Software ID: $software_id"
    echo "Type: $type"
    echo "Issued To: $issued_to"
    echo "Expires: $expires_days days"
    
    # Call Mother DB to generate license
    local license_key=$("$SCYTHE_MOTHER" license create "$software_id" "$type" "$issued_to" "$expires_days")
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ License created successfully${NC}"
        echo "License Key: $license_key"
        
        # Save to local file
        local license_file="$GRIM_ROOT/licenses/$software_id.license"
        mkdir -p "$(dirname "$license_file")"
        echo "$license_key" > "$license_file"
        chmod 600 "$license_file"
        
        echo "Saved to: $license_file"
        "$NOTIFY_MODULE" send success "License Created" "New license created for $software_id" "{\"software_id\": \"$software_id\", \"license_key\": \"$license_key\", \"type\": \"$type\"}"
    else
        echo -e "${RED}❌ Failed to create license${NC}"
        return 1
    fi
}

# Validate license
validate_license() {
    local license_key="$1"
    
    if [ -z "$license_key" ]; then
        echo -e "${RED}❌ License key is required${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== Validating License ===${NC}"
    echo "License Key: $license_key"
    
    # Call Scythe module to validate
    "$SCYTHE_MODULE" license validate "$license_key"
    
    local result=$?
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✅ License is valid${NC}"
    else
        echo -e "${RED}❌ License is invalid${NC}"
    fi
    
    return $result
}

# Revoke license
revoke_license() {
    local license_key="$1"
    local reason="${2:-Manual revocation}"
    
    if [ -z "$license_key" ]; then
        echo -e "${RED}❌ License key is required${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== Revoking License ===${NC}"
    echo "License Key: $license_key"
    echo "Reason: $reason"
    
    # Confirm revocation
    echo -ne "${RED}Type 'REVOKE' to confirm: ${NC}"
    read confirmation
    if [ "$confirmation" != "REVOKE" ]; then
        echo "Action cancelled"
        return 1
    fi
    
    # Call Mother DB to revoke
    "$SCYTHE_MOTHER" license revoke "$license_key"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ License revoked successfully${NC}"
        "$NOTIFY_MODULE" send warning "License Revoked" "License $license_key has been revoked" "{\"license_key\": \"$license_key\", \"reason\": \"$reason\"}"
    else
        echo -e "${RED}❌ Failed to revoke license${NC}"
        return 1
    fi
}

# List all licenses
list_licenses() {
    echo -e "${CYAN}=== License Registry ===${NC}"
    
    # Call Mother DB to list licenses
    "$SCYTHE_MOTHER" license list
}

# Show detailed license information
show_license_info() {
    local license_key="$1"
    
    if [ -z "$license_key" ]; then
        echo -e "${RED}❌ License key is required${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== License Information ===${NC}"
    echo "License Key: $license_key"
    
    # Query Mother DB for license details
    local info=$(sqlite3 "$GRIM_ROOT/db/mother_scythe.db" <<EOF
SELECT 
    l.license_key,
    l.software_id,
    l.type,
    l.issued_to,
    l.issued_at,
    l.expires_at,
    l.hardware_id,
    l.status,
    l.max_activations,
    l.current_activations,
    s.name as software_name,
    s.status as software_status
FROM licenses l
JOIN software s ON l.software_id = s.id
WHERE l.license_key = '$license_key';
EOF
)
    
    if [ -n "$info" ]; then
        IFS='|' read -r key software_id type issued_to issued_at expires_at hardware_id status max_activations current_activations software_name software_status <<< "$info"
        
        echo "Software: $software_name ($software_id)"
        echo "Type: $type"
        echo "Issued To: $issued_to"
        echo "Issued At: $issued_at"
        echo "Expires At: $expires_at"
        echo "Hardware ID: $hardware_id"
        echo "Status: $status"
        echo "Activations: $current_activations/$max_activations"
        echo "Software Status: $software_status"
        
        # Show recent violations
        echo ""
        echo -e "${YELLOW}Recent Violations:${NC}"
        local violations=$(sqlite3 "$GRIM_ROOT/db/mother_scythe.db" "SELECT violation_type, reported_at FROM violations WHERE license_key = '$license_key' ORDER BY reported_at DESC LIMIT 5")
        if [ -n "$violations" ]; then
            echo "$violations" | while IFS='|' read -r violation_type reported_at; do
                echo "  [$reported_at] $violation_type"
            done
        else
            echo "  No violations recorded"
        fi
    else
        echo -e "${RED}❌ License not found${NC}"
        return 1
    fi
}

# Renew license expiration
renew_license() {
    local license_key="$1"
    local days="${2:-365}"
    
    if [ -z "$license_key" ]; then
        echo -e "${RED}❌ License key is required${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== Renewing License ===${NC}"
    echo "License Key: $license_key"
    echo "Extension: $days days"
    
    # Update expiration in Mother DB
    sqlite3 "$GRIM_ROOT/db/mother_scythe.db" <<EOF
UPDATE licenses 
SET expires_at = datetime('now', '+$days days')
WHERE license_key = '$license_key';
EOF
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ License renewed successfully${NC}"
        "$NOTIFY_MODULE" send info "License Renewed" "License $license_key renewed for $days days" "{\"license_key\": \"$license_key\", \"days\": \"$days\"}"
    else
        echo -e "${RED}❌ Failed to renew license${NC}"
        return 1
    fi
}

# Transfer license ownership
transfer_license() {
    local license_key="$1"
    local new_owner="$2"
    
    if [ -z "$license_key" ] || [ -z "$new_owner" ]; then
        echo -e "${RED}❌ License key and new owner are required${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== Transferring License ===${NC}"
    echo "License Key: $license_key"
    echo "New Owner: $new_owner"
    
    # Update owner in Mother DB
    sqlite3 "$GRIM_ROOT/db/mother_scythe.db" <<EOF
UPDATE licenses 
SET issued_to = '$new_owner'
WHERE license_key = '$license_key';
EOF
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ License transferred successfully${NC}"
        "$NOTIFY_MODULE" send info "License Transferred" "License $license_key transferred to $new_owner" "{\"license_key\": \"$license_key\", \"new_owner\": \"$new_owner\"}"
    else
        echo -e "${RED}❌ Failed to transfer license${NC}"
        return 1
    fi
}

# Show license violations
show_violations() {
    local license_key="$1"
    
    if [ -z "$license_key" ]; then
        echo -e "${RED}❌ License key is required${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== License Violations ===${NC}"
    echo "License Key: $license_key"
    
    # Query violations from Mother DB
    local violations=$(sqlite3 "$GRIM_ROOT/db/mother_scythe.db" <<EOF
SELECT 
    v.violation_type,
    v.hardware_id,
    v.ip_address,
    v.details,
    v.severity,
    v.reported_at,
    v.action_taken
FROM violations v
WHERE v.license_key = '$license_key'
ORDER BY v.reported_at DESC;
EOF
)
    
    if [ -n "$violations" ]; then
        echo "$violations" | while IFS='|' read -r violation_type hardware_id ip_address details severity reported_at action_taken; do
            echo ""
            echo "Type: $violation_type"
            echo "Severity: $severity"
            echo "Hardware ID: $hardware_id"
            echo "IP Address: $ip_address"
            echo "Details: $details"
            echo "Reported: $reported_at"
            if [ -n "$action_taken" ]; then
                echo "Action: $action_taken"
            fi
            echo "---"
        done
    else
        echo "No violations recorded for this license"
    fi
}

# Main command handler
main() {
    case "${1:-}" in
        create)
            create_license "${2:-}" "${3:-}" "${4:-}" "${5:-}"
            ;;
        validate)
            validate_license "${2:-}"
            ;;
        revoke)
            revoke_license "${2:-}" "${3:-}"
            ;;
        list)
            list_licenses
            ;;
        info)
            show_license_info "${2:-}"
            ;;
        renew)
            renew_license "${2:-}" "${3:-}"
            ;;
        transfer)
            transfer_license "${2:-}" "${3:-}"
            ;;
        violations)
            show_violations "${2:-}"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Only call main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 