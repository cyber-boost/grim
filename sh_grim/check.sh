#!/bin/bash

# Grim System Integrity Check and Auto-Recovery
# Handles comprehensive system verification and automatic issue resolution

set -e

# Source common functions
source "$GRIM_ROOT/sh_grim/common.sh" 2>/dev/null || true

# Configuration
MAX_ATTEMPTS=5
SUCCESS_FLAG_FILE="$GRIM_ROOT/.graveyard/.rip/check_success.flag"
RECOVERY_LOG="$GRIM_ROOT/logs/check_recovery.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$RECOVERY_LOG"
}

# Check if path exists
check_path() {
    local path="$1"
    local type="$2"
    
    if [[ "$type" == "dir" ]]; then
        [[ -d "$path" ]]
    else
        [[ -f "$path" ]]
    fi
}

# Check critical components
check_critical_components() {
    local missing=()
    
    # Critical directories and files
    local critical_paths=(
        "dir:$GRIM_ROOT"
        "dir:$GRIM_ROOT/.graveyard"
        "dir:$GRIM_ROOT/.graveyard/.rip"
        "file:$GRIM_ROOT/.graveyard/.rip/mother.db"
        "file:$GRIM_ROOT/.graveyard/.rip/init-info.json"
        "dir:$GRIM_ROOT/.graveyard/.rip/.scythe"
        "dir:$GRIM_ROOT/sh_grim"
        "file:$GRIM_ROOT/sh_grim/grim.sh"
        "dir:$GRIM_ROOT/backups"
        "dir:$GRIM_ROOT/logs"
        "dir:$GRIM_ROOT/db"
    )
    
    for path_info in "${critical_paths[@]}"; do
        local type="${path_info%%:*}"
        local path="${path_info#*:}"
        local name=$(basename "$path")
        
        if ! check_path "$path" "$type"; then
            missing+=("$name")
            echo -e "${RED}❌${NC} $name: MISSING"
        else
            echo -e "${GREEN}✅${NC} $name: OK"
        fi
    done
    
    echo "${missing[@]}"
}

# Check throne components
check_throne_components() {
    local missing=()
    
    local throne_paths=(
        "file:$GRIM_ROOT/throne/grim_throne.sh"
        "file:$GRIM_ROOT/throne/js_grim_throne.sh"
        "file:$GRIM_ROOT/throne/py_grim_throne.sh"
        "file:$GRIM_ROOT/throne/php_grim_throne.sh"
        "file:$GRIM_ROOT/throne/go_grim_throne.sh"
        "file:$GRIM_ROOT/throne/rs_grim_throne.sh"
        "file:$GRIM_ROOT/throne/rb_grim_throne.sh"
    )
    
    for path_info in "${throne_paths[@]}"; do
        local type="${path_info%%:*}"
        local path="${path_info#*:}"
        local name=$(basename "$path")
        
        if ! check_path "$path" "$type"; then
            missing+=("$name")
            echo -e "${YELLOW}⚠️${NC} $name: MISSING"
        else
            echo -e "${GREEN}✅${NC} $name: OK"
        fi
    done
    
    echo "${missing[@]}"
}

# Auto-fix missing components
auto_fix_components() {
    local missing_critical="$1"
    local missing_thrones="$2"
    local fixed=false
    
    # Fix critical components
    if [[ -n "$missing_critical" ]]; then
        log_message "INFO" "Attempting to fix critical components: $missing_critical"
        
        # Create missing directories
        for component in $missing_critical; do
            case "$component" in
                ".graveyard")
                    mkdir -p "$GRIM_ROOT/.graveyard/.rip/.scythe"
                    log_message "FIX" "Created .graveyard directory structure"
                    fixed=true
                    ;;
                "backups")
                    mkdir -p "$GRIM_ROOT/backups"
                    log_message "FIX" "Created backups directory"
                    fixed=true
                    ;;
                "logs")
                    mkdir -p "$GRIM_ROOT/logs"
                    log_message "FIX" "Created logs directory"
                    fixed=true
                    ;;
                "db")
                    mkdir -p "$GRIM_ROOT/db"
                    log_message "FIX" "Created db directory"
                    fixed=true
                    ;;
                "mother.db"|"init-info.json")
                    # These require grim init
                    log_message "INFO" "Critical database files missing - will run grim init"
                    ;;
            esac
        done
        
        # Run grim init if critical database files are missing
        if [[ "$missing_critical" == *"mother.db"* ]] || [[ "$missing_critical" == *"init-info.json"* ]]; then
            log_message "FIX" "Running grim init to create critical database files"
            bash "$GRIM_ROOT/sh_grim/init.sh" system
            fixed=true
        fi
    fi
    
    # Fix throne components if main throne is missing
    if [[ -n "$missing_thrones" ]] && [[ "$missing_thrones" == *"grim_throne.sh"* ]]; then
        log_message "INFO" "Main throne missing - attempting to rebuild"
        if [[ -f "$GRIM_ROOT/throne/build_grim_throne.sh" ]]; then
            bash "$GRIM_ROOT/throne/build_grim_throne.sh"
            log_message "FIX" "Rebuilt throne components"
            fixed=true
        fi
    fi
    
    echo "$fixed"
}

# Set success flag
set_success_flag() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    cat > "$SUCCESS_FLAG_FILE" << EOF
{
    "success": true,
    "timestamp": "$timestamp",
    "attempts": $1,
    "components_verified": true
}
EOF
    log_message "SUCCESS" "System integrity check passed - success flag set"
}

# Main check function
system_check() {
    echo -e "${BLUE}🔍 Grim System Integrity Check${NC}"
    echo "=================================================="
    
    echo -e "\n${BLUE}🔴 CRITICAL COMPONENTS:${NC}"
    echo "----------------------------------------"
    local missing_critical=$(check_critical_components)
    
    echo -e "\n${BLUE}🟡 THRONE COMPONENTS:${NC}"
    echo "----------------------------------------"
    local missing_thrones=$(check_throne_components)
    
    # Summary
    echo -e "\n${BLUE}📋 SUMMARY:${NC}"
    echo "=================================================="
    
    local critical_count=$(echo "$missing_critical" | wc -w)
    local throne_count=$(echo "$missing_thrones" | wc -w)
    
    if [[ "$critical_count" -eq 0 ]]; then
        echo -e "${GREEN}✅ All critical components are present${NC}"
    else
        echo -e "${RED}❌ $critical_count critical component(s) missing${NC}"
    fi
    
    if [[ "$throne_count" -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  $throne_count throne component(s) missing${NC}"
    fi
    
    # Return status
    if [[ "$critical_count" -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Auto-recovery function
auto_recovery() {
    echo -e "${BLUE}🔄 Grim Auto-Recovery Mode${NC}"
    echo "=================================================="
    
    # Create logs directory if it doesn't exist
    mkdir -p "$(dirname "$RECOVERY_LOG")"
    
    log_message "START" "Auto-recovery mode initiated"
    
    local attempt=1
    local success=false
    
    while [[ $attempt -le $MAX_ATTEMPTS ]] && [[ "$success" == "false" ]]; do
        echo -e "\n${BLUE}🔄 Attempt $attempt/$MAX_ATTEMPTS${NC}"
        echo "----------------------------------------"
        
        # Run system check
        if system_check; then
            success=true
            echo -e "\n${GREEN}🎉 System integrity check PASSED!${NC}"
            set_success_flag $attempt
            break
        else
            echo -e "\n${YELLOW}⚠️  System check failed - attempting auto-fix...${NC}"
            
            # Get missing components
            local missing_critical=$(check_critical_components 2>/dev/null | tail -n 1)
            local missing_thrones=$(check_throne_components 2>/dev/null | tail -n 1)
            
            # Attempt auto-fix
            local fixed=$(auto_fix_components "$missing_critical" "$missing_thrones")
            
            if [[ "$fixed" == "true" ]]; then
                echo -e "${GREEN}✅ Auto-fix applied - retrying check...${NC}"
                sleep 2
            else
                echo -e "${YELLOW}⚠️  No auto-fixes available${NC}"
            fi
            
            attempt=$((attempt + 1))
            
            if [[ $attempt -le $MAX_ATTEMPTS ]]; then
                echo -e "${BLUE}⏳ Waiting 3 seconds before next attempt...${NC}"
                sleep 3
            fi
        fi
    done
    
    if [[ "$success" == "false" ]]; then
        echo -e "\n${RED}❌ Auto-recovery failed after $MAX_ATTEMPTS attempts${NC}"
        log_message "ERROR" "Auto-recovery failed after $MAX_ATTEMPTS attempts"
        echo -e "\n${YELLOW}💡 Manual intervention required:${NC}"
        echo "   - Run 'grim init' to initialize system"
        echo "   - Check file permissions and disk space"
        echo "   - Verify Grim installation integrity"
        return 1
    fi
    
    return 0
}

# Verify function
verify() {
    echo -e "${BLUE}🔍 Verifying System Components${NC}"
    echo "=================================================="
    
    if [[ -f "$SUCCESS_FLAG_FILE" ]]; then
        echo -e "${GREEN}✅ Success flag found - system previously verified${NC}"
        cat "$SUCCESS_FLAG_FILE"
    else
        echo -e "${YELLOW}⚠️  No success flag found - running verification...${NC}"
        system_check
    fi
}

# Status function
status() {
    echo -e "${BLUE}📊 System Status${NC}"
    echo "=================================================="
    
    # Check success flag
    if [[ -f "$SUCCESS_FLAG_FILE" ]]; then
        echo -e "${GREEN}✅ System Status: VERIFIED${NC}"
        echo "Last verification: $(jq -r '.timestamp' "$SUCCESS_FLAG_FILE" 2>/dev/null || echo 'Unknown')"
        echo "Attempts required: $(jq -r '.attempts' "$SUCCESS_FLAG_FILE" 2>/dev/null || echo 'Unknown')"
    else
        echo -e "${YELLOW}⚠️  System Status: UNVERIFIED${NC}"
    fi
    
    # Quick component check
    echo -e "\n${BLUE}🔍 Quick Component Check:${NC}"
    system_check >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ All critical components present${NC}"
    else
        echo -e "${RED}❌ Critical components missing${NC}"
    fi
}

# Main command router
case "${1:-help}" in
    "system")
        system_check
        ;;
    "auto-recovery"|"auto")
        auto_recovery
        ;;
    "verify")
        verify
        ;;
    "status")
        status
        ;;
    "help"|"--help"|"-h"|"")
        echo "Grim System Integrity Check"
        echo "=========================="
        echo ""
        echo "Usage: grim check <command>"
        echo ""
        echo "Commands:"
        echo "  system        - One-time system integrity check"
        echo "  auto-recovery - Auto-run until system is configured (max $MAX_ATTEMPTS attempts)"
        echo "  verify        - Verify all components are present"
        echo "  status        - Show current system status"
        echo "  help          - Show this help"
        echo ""
        echo "Examples:"
        echo "  grim check system        # Quick check"
        echo "  grim check auto-recovery # Auto-fix until success"
        echo "  grim check status        # Show verification status"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use 'grim check help' for available commands"
        exit 1
        ;;
esac 