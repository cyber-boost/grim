#!/bin/bash
# grim-ascii.sh - Grim Reaper ASCII Art Management
# Enhanced ASCII art display for Grim Reaper commands
# Author: Grim Reaper Team
# Date: 2025-01-15

# ============================================================================
# SETUP
# ============================================================================
set -euo pipefail

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ASCII_DIR="$SCRIPT_DIR/ascii"

# Source the main ASCII art system
if [[ -f "$SCRIPT_DIR/ascii.sh" ]]; then
    source "$SCRIPT_DIR/ascii.sh"
else
    echo "Error: ascii.sh not found in $SCRIPT_DIR"
    exit 1
fi

# ============================================================================
# GRIM-SPECIFIC ASCII ART MAPPING
# ============================================================================
declare -A GRIM_ASCII_FILES=(
    # Core Grim variants
    [grim-1]="grim-1.txt"
    [grim-2]="grim-2.txt"
    [grim-3]="grim-3.txt"
    [grim-4]="grim-4.txt"
    [grim-5]="grim-5.txt"
    
    # Specialized designs
    [scythe]="sycthe.txt"
    [scythe-alt]="scythe-alt.txt"
    [skull]="skull-1.txt"
    [terd]="terd.txt"
    [init]="init.txt"
)

declare -A GRIM_COMMAND_THEMES=(
    # Core operations (random Grim art)
    [health]="random:green:animate"
    [status]="random:blue:center"
    [backup]="random:bold-blue:animate"
    [restore]="random:yellow:center"
    [scan]="random:cyan:animate"
    [monitor]="random:purple:rainbow"
    [web]="random:bold-cyan:center"
    
    # Security (random Grim art)
    [security-audit]="random:red:animate"
    [security-encrypt]="random:bold-red:animate"
    [security-decrypt]="random:bold-red:animate"
    
    # AI/ML (random Grim art)
    [ai-analyze]="random:yellow:rainbow"
    [ai-recommend]="random:cyan:animate"
    [ai-train]="random:green:animate"
    [ai-predict]="random:purple:animate"
    [ai-setup]="random:blue:center"
    [ai-optimize]="random:bold-cyan:rainbow"
    [smart-suggestions]="random:bold-yellow:animate"
    
    # Emergency (random Grim art)
    [emergency-heal]="random:bold-red:animate"
    [emergency-isolate]="random:red:animate"
    [emergency-restore]="random:bold-yellow:animate"
    [emergency-encrypt]="random:bold-red:animate"
    
    # Special cases
    [help]="init:bold-cyan:center"
    [init]="init:bold-green:center"
    [error]="terd:red:animate"
)

# ============================================================================
# GRIM ASCII ART FUNCTIONS
# ============================================================================

# Display Grim ASCII art with theme
grim_show_ascii() {
    local command="${1:-help}"
    local theme="${GRIM_COMMAND_THEMES[$command]:-random:default:center}"
    
    IFS=':' read -r art_name color animation <<< "$theme"
    
    # Handle special art types
    case "$art_name" in
        "random")
            # Get random Grim art (excluding init and terd)
            local grim_arts=("grim-1.txt" "grim-2.txt" "grim-3.txt" "grim-4.txt" "grim-5.txt" "scythe-alt.txt" "sycthe.txt" "skull-1.txt")
            local random_index=$((RANDOM % ${#grim_arts[@]}))
            local filename="${grim_arts[$random_index]}"
            ;;
        "init")
            local filename="init.txt"
            ;;
        "terd")
            local filename="terd.txt"
            ;;
        *)
            local filename="${GRIM_ASCII_FILES[$art_name]:-$art_name}"
            ;;
    esac
    
    local art_file="$ASCII_DIR/$filename"
    
    if [[ ! -f "$art_file" ]]; then
        echo "Warning: ASCII art file not found: $art_file" >&2
        return 1
    fi
    
    case "$animation" in
        "rainbow")
            show_rainbow_ascii "$art_file"
            ;;
        "animate")
            show_animated_ascii "$art_file" "$color"
            ;;
        "center")
            show_centered_ascii "$art_file" "$color"
            ;;
        *)
            show_simple_ascii "$art_file" "$color"
            ;;
    esac
}

# Rainbow effect for ASCII art
show_rainbow_ascii() {
    local art_file="$1"
    local lines=()
    
    while IFS= read -r line; do
        lines+=("$line")
    done < "$art_file"
    
    for i in "${!lines[@]}"; do
        local rainbow_color=$(get_rainbow_color $i)
        echo -e "${rainbow_color}${lines[$i]}${NC}"
        sleep 0.03
    done
    echo ""
}

# Animated ASCII art display
show_animated_ascii() {
    local art_file="$1"
    local color="${2:-default}"
    local color_code="${COLOR_THEMES[$color]:-$NC}"
    local lines=()
    
    while IFS= read -r line; do
        lines+=("$line")
    done < "$art_file"
    
    for line in "${lines[@]}"; do
        echo -e "${color_code}${line}${NC}"
        sleep 0.05
    done
    echo ""
}

# Centered ASCII art display
show_centered_ascii() {
    local art_file="$1"
    local color="${2:-default}"
    local color_code="${COLOR_THEMES[$color]:-$NC}"
    
    while IFS= read -r line; do
        center_line "${color_code}${line}${NC}"
    done < "$art_file"
    echo ""
}

# Simple ASCII art display
show_simple_ascii() {
    local art_file="$1"
    local color="${2:-default}"
    local color_code="${COLOR_THEMES[$color]:-$NC}"
    
    while IFS= read -r line; do
        echo -e "${color_code}${line}${NC}"
    done < "$art_file"
    echo ""
}

# ============================================================================
# GRIM-SPECIFIC SCENES
# ============================================================================

# Grim Reaper startup sequence
grim_startup_sequence() {
    clear
    echo -e "${BOLD_RED}Initializing Grim Reaper...${NC}\n"
    
    # Show loading animation with grim-1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local art_file="$ASCII_DIR/grim-1.txt"
    
    for i in {1..15}; do
        clear
        echo -e "${BOLD_RED}Initializing Grim Reaper ${frames[$((i % ${#frames[@]}))]}${NC}\n"
        show_simple_ascii "$art_file" "red"
        sleep 0.1
    done
    
    # Final display
    clear
    show_animated_ascii "$ASCII_DIR/grim-3.txt" "bold-red"
    echo -e "${BOLD_GREEN}✓ Grim Reaper Ready!${NC}\n"
    sleep 1
}

# Grim Reaper shutdown sequence
grim_shutdown_sequence() {
    echo -e "${BOLD_YELLOW}Shutting down Grim Reaper...${NC}\n"
    
    # Fade out effect
    for i in {5..1}; do
        echo -e "${BOLD_YELLOW}Shutdown in $i...${NC}"
        show_simple_ascii "$ASCII_DIR/grim-1.txt" "yellow"
        sleep 1
        clear
    done
    
    show_animated_ascii "$ASCII_DIR/skull-1.txt" "red"
    echo -e "${BOLD_RED}Grim Reaper terminated.${NC}"
}

# Grim Reaper error display
grim_error_display() {
    local error_msg="${1:-Unknown error}"
    show_animated_ascii "$ASCII_DIR/terd.txt" "red"
    echo -e "${BOLD_RED}❌ ERROR: $error_msg${NC}"
    echo -e "${YELLOW}It seems like you are missing the needed dependencies${NC}"
    echo -e "${GREEN}Please run: curl -fsSL https://get.grim.so | sudo bash${NC}"
}

# Grim Reaper success display
grim_success_display() {
    local success_msg="${1:-Operation completed}"
    show_animated_ascii "$ASCII_DIR/grim-3.txt" "green"
    echo -e "${BOLD_GREEN}✅ SUCCESS: $success_msg${NC}"
}

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

grim_ascii_usage() {
    cat << EOF
${BOLD_CYAN}Grim Reaper ASCII Art Manager${NC}

${BOLD}USAGE:${NC}
    $(basename "$0") [OPTIONS] [COMMAND]

${BOLD}OPTIONS:${NC}
    -h, --help              Show this help message
    -l, --list              List available Grim commands
    -s, --startup           Show Grim startup sequence
    -e, --error MSG         Show error display
    -S, --success MSG       Show success display
    -t, --theme COMMAND     Show ASCII art for specific command

${BOLD}AVAILABLE COMMANDS:${NC}
EOF
    for cmd in "${!GRIM_COMMAND_THEMES[@]}"; do
        printf "    %-20s - %s\n" "$cmd" "${GRIM_COMMAND_THEMES[$cmd]}"
    done | sort

    cat << EOF

${BOLD}EXAMPLES:${NC}
    # Show startup sequence
    $(basename "$0") -s
    
    # Show ASCII art for backup command
    $(basename "$0") -t backup
    
    # Show error display
    $(basename "$0") -e "Backup failed"
    
    # Show success display
    $(basename "$0") -S "Backup completed"

EOF
}

# ============================================================================
# MAIN
# ============================================================================

case "${1:-}" in
    -h|--help)
        grim_ascii_usage
        ;;
    -l|--list)
        echo -e "${BOLD_CYAN}Available Grim Commands:${NC}\n"
        for cmd in "${!GRIM_COMMAND_THEMES[@]}"; do
            printf "%-20s - %s\n" "$cmd" "${GRIM_COMMAND_THEMES[$cmd]}"
        done | sort
        ;;
    -s|--startup)
        grim_startup_sequence
        ;;
    -e|--error)
        grim_error_display "${2:-Unknown error}"
        ;;
    -S|--success)
        grim_success_display "${2:-Operation completed}"
        ;;
    -t|--theme)
        if [[ -z "${2:-}" ]]; then
            echo "Error: Command name required for --theme" >&2
            exit 1
        fi
        grim_show_ascii "$2"
        ;;
    "")
        grim_ascii_usage
        ;;
    *)
        grim_show_ascii "$1"
        ;;
esac 