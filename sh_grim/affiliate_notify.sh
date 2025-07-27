#!/bin/bash
# Grim Affiliate Notification System
# Shows users their affiliate link after first command and periodically until they get a signup

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
AFFILIATE_API="https://grim.so/api/affiliate"
AFFILIATE_URL_BASE="https://grim.so/underworld"
AFFILIATE_FILE="$HOME/.graveyard/.affiliate_id"
AFFILIATE_STATS_FILE="$HOME/.graveyard/.affiliate_stats"
NOTIFICATION_FREQUENCY=5  # Show notification every 5 commands until first signup

# Generate or get existing affiliate ID
get_or_create_affiliate_id() {
    local affiliate_id=""
    
    # Check if affiliate ID already exists
    if [ -f "$AFFILIATE_FILE" ]; then
        affiliate_id=$(cat "$AFFILIATE_FILE" 2>/dev/null)
    fi
    
    # If no affiliate ID, create one
    if [ -z "$affiliate_id" ]; then
        # Generate based on system info
        local username=$(whoami)
        local hostname=$(hostname 2>/dev/null || echo "dev")
        local timestamp=$(date +%s)
        local random=$(openssl rand -hex 4 2>/dev/null || echo $(($RANDOM * $RANDOM)))
        
        affiliate_id="${username}_${hostname}_${random}"
        affiliate_id=$(echo "$affiliate_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-20)
        
        # Save affiliate ID
        mkdir -p "$(dirname "$AFFILIATE_FILE")"
        echo "$affiliate_id" > "$AFFILIATE_FILE"
        
        # Register with affiliate system (background)
        register_affiliate "$affiliate_id" &
        
        echo "$affiliate_id"
    else
        echo "$affiliate_id"
    fi
}

# Register affiliate with the system
register_affiliate() {
    local affiliate_id="$1"
    
    # Gather user info
    local email="${GRIM_USER_EMAIL:-$(git config user.email 2>/dev/null)}"
    local name="${GRIM_USER_NAME:-$(git config user.name 2>/dev/null)}"
    local company="${GRIM_COMPANY:-}"
    
    # Register via API (silent background)
    curl -s -X POST "$AFFILIATE_API/create" \
        -H "Content-Type: application/json" \
        -d "{
            \"affiliate_id\": \"$affiliate_id\",
            \"email\": \"$email\",
            \"name\": \"$name\", 
            \"company\": \"$company\",
            \"cli_install_id\": \"$(cat $HOME/.graveyard/.install_id 2>/dev/null || echo 'unknown')\",
            \"created_from\": \"cli\"
        }" >/dev/null 2>&1
}

# Get affiliate stats
get_affiliate_stats() {
    local affiliate_id="$1"
    
    # Try to get stats from API
    local stats=$(curl -s "$AFFILIATE_API/$affiliate_id/stats" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$stats" ]; then
        echo "$stats" > "$AFFILIATE_STATS_FILE"
        echo "$stats"
    elif [ -f "$AFFILIATE_STATS_FILE" ]; then
        # Fallback to cached stats
        cat "$AFFILIATE_STATS_FILE"
    else
        # Default stats
        echo '{"clicks": 0, "conversions": 0, "earnings_usd": 0, "conversion_rate": 0}'
    fi
}

# Check if we should show notification
should_show_notification() {
    local command_count_file="$HOME/.graveyard/.command_count"
    local last_notification_file="$HOME/.graveyard/.last_notification"
    
    # Increment command counter
    local count=1
    if [ -f "$command_count_file" ]; then
        count=$(cat "$command_count_file")
        count=$((count + 1))
    fi
    echo "$count" > "$command_count_file"
    
    # First run - always show
    if [ "$count" -eq 1 ]; then
        echo "$count" > "$last_notification_file"
        return 0
    fi
    
    # Check if user has conversions (if so, show less frequently)
    local affiliate_id=$(get_or_create_affiliate_id)
    local stats=$(get_affiliate_stats "$affiliate_id")
    local conversions=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin).get('conversions', 0))" 2>/dev/null || echo "0")
    
    # If they have conversions, show every 20 commands
    if [ "$conversions" -gt 0 ]; then
        local last_shown=$(cat "$last_notification_file" 2>/dev/null || echo "0")
        if [ $((count - last_shown)) -ge 20 ]; then
            echo "$count" > "$last_notification_file"
            return 0
        fi
        return 1
    fi
    
    # No conversions yet - show every 5 commands
    local last_shown=$(cat "$last_notification_file" 2>/dev/null || echo "0")
    if [ $((count - last_shown)) -ge $NOTIFICATION_FREQUENCY ]; then
        echo "$count" > "$last_notification_file"
        return 0
    fi
    
    return 1
}

# Show affiliate notification
show_affiliate_notification() {
    local affiliate_id=$(get_or_create_affiliate_id)
    local affiliate_url="$AFFILIATE_URL_BASE/$affiliate_id"
    local stats=$(get_affiliate_stats "$affiliate_id")
    
    # Parse stats
    local clicks=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin).get('clicks', 0))" 2>/dev/null || echo "0")
    local conversions=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin).get('conversions', 0))" 2>/dev/null || echo "0")
    local earnings=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin).get('earnings_usd', 0))" 2>/dev/null || echo "0")
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}                         💰 GRIM AFFILIATE PROGRAM                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════╣${NC}"
    
    if [ "$conversions" -eq 0 ]; then
        # First time or no conversions yet
        echo -e "${CYAN}║${NC} ${YELLOW}🎯 Earn 33% revenue sharing with the BBL (Balanced Beneficial License)${NC}     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}Your Affiliate Link:${NC}                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${BOLD}${BLUE}${affiliate_url}${NC}                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}💡 Share with friends, colleagues, and companies:${NC}                      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   • Get ${BOLD}50% of first month${NC} for company signups                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   • Get ${BOLD}10% monthly${NC} for the first year                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   • Get ${BOLD}5% perpetual${NC} commission as long as they stay                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}Current Stats:${NC} ${clicks} clicks, ${conversions} conversions, $${earnings} earned             ${CYAN}║${NC}"
    else
        # User has conversions - celebration mode
        echo -e "${CYAN}║${NC} ${GREEN}🎉 CONGRATULATIONS! You're earning with Grim Reaper!${NC}                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${BOLD}Your Performance:${NC}                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   • ${GREEN}${clicks} clicks${NC} on your affiliate link                                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   • ${GREEN}${conversions} successful conversions${NC} (${GREEN}$(echo "scale=1; $conversions * 100 / ($clicks + 1)" | bc 2>/dev/null || echo "0")%${NC} conversion rate)           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   • ${GREEN}$${earnings} earned${NC} so far (quarterly payouts)                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}Keep sharing:${NC} ${BOLD}${BLUE}${affiliate_url}${NC}     ${CYAN}║${NC}"
    fi
    
    echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}Learn more about BBL revenue sharing:${NC} https://grim.so/bbl              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Main function
main() {
    # Only show if we should
    if should_show_notification; then
        show_affiliate_notification
    fi
}

# Command line usage
case "${1:-main}" in
    "main")
        main
        ;;
    "show")
        show_affiliate_notification
        ;;
    "stats")
        local affiliate_id=$(get_or_create_affiliate_id)
        get_affiliate_stats "$affiliate_id" | python3 -m json.tool 2>/dev/null || echo "Stats unavailable"
        ;;
    "id")
        get_or_create_affiliate_id
        ;;
    "url")
        local affiliate_id=$(get_or_create_affiliate_id)
        echo "$AFFILIATE_URL_BASE/$affiliate_id"
        ;;
    *)
        echo "Usage: $0 [main|show|stats|id|url]"
        echo "  main  - Check if notification should be shown (default)"
        echo "  show  - Force show notification"
        echo "  stats - Show affiliate stats"
        echo "  id    - Show affiliate ID"
        echo "  url   - Show affiliate URL"
        ;;
esac