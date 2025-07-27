#!/bin/bash
# Grim ASCII Art Display System
# Shows contextual ASCII art based on system state and timing
# Integrated into the throne system for enhanced user experience

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(dirname "$SCRIPT_DIR")"

# ASCII art files directory
ASCII_DIR="$GRIM_ROOT/admin/bash_central/ascii"

# Timing control file
LAST_ASCII_FILE="$GRIM_ROOT/.last_ascii_display"
ASCII_INTERVAL=300  # 5 minutes in seconds

# Colors for enhanced display
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Function to check if we should show ASCII art
should_show_ascii() {
    local current_time=$(date +%s)
    
    # If no last display file, always show
    if [[ ! -f "$LAST_ASCII_FILE" ]]; then
        echo "$current_time" > "$LAST_ASCII_FILE"
        return 0
    fi
    
    local last_time=$(cat "$LAST_ASCII_FILE" 2>/dev/null || echo "0")
    local time_diff=$((current_time - last_time))
    
    # Show if more than 5 minutes have passed
    if [[ $time_diff -gt $ASCII_INTERVAL ]]; then
        echo "$current_time" > "$LAST_ASCII_FILE"
        return 0
    fi
    
    return 1
}

# Function to display ASCII art with color
display_ascii() {
    local file="$1"
    local color="${2:-$CYAN}"
    
    if [[ -f "$file" ]]; then
        echo -e "${color}"
        cat "$file"
        echo -e "${NC}"
        echo ""
    fi
}

# Function to show contextual ASCII art
show_contextual_ascii() {
    local context="${1:-random}"
    
    case "$context" in
        "init"|"install")
            display_ascii "$ASCII_DIR/init.txt" "$GREEN"
            ;;
        "first")
            display_ascii "$ASCII_DIR/first.txt" "$PURPLE"
            ;;
        "error"|"terd")
            display_ascii "$ASCII_DIR/terd.txt" "$RED"
            ;;
        "random"|*)
            show_random_ascii
            ;;
    esac
}

# Function to show random ASCII art (excluding special ones)
show_random_ascii() {
    # Only show if timing interval has passed
    if ! should_show_ascii; then
        return 0
    fi
    
    # Find all ASCII files except special ones
    local ascii_files=()
    for file in "$ASCII_DIR"/*.txt; do
        [[ -f "$file" ]] || continue
        local basename=$(basename "$file")
        
        # Skip special files
        case "$basename" in
            "init.txt"|"first.txt"|"terd.txt")
                continue
                ;;
            *)
                ascii_files+=("$file")
                ;;
        esac
    done
    
    # If we have ASCII files, pick one randomly
    if [[ ${#ascii_files[@]} -gt 0 ]]; then
        local random_index=$((RANDOM % ${#ascii_files[@]}))
        local selected_file="${ascii_files[$random_index]}"
        
        # Choose random color
        local colors=("$CYAN" "$PURPLE" "$BLUE" "$YELLOW")
        local color_index=$((RANDOM % ${#colors[@]}))
        local selected_color="${colors[$color_index]}"
        
        display_ascii "$selected_file" "$selected_color"
        
        # Add a themed message
        echo -e "${WHITE}💀 The Reaper watches over your data 💀${NC}"
        echo ""
    fi
}

# Function to check if it's the first run ever
is_first_run() {
    local first_run_marker="$GRIM_ROOT/.first_run_complete"
    
    if [[ ! -f "$first_run_marker" ]]; then
        touch "$first_run_marker"
        return 0
    fi
    
    return 1
}

# Main function
main() {
    local context="${1:-auto}"
    
    # Handle automatic context detection
    if [[ "$context" == "auto" ]]; then
        if is_first_run; then
            context="first"
        else
            context="random"
        fi
    fi
    
    show_contextual_ascii "$context"
}

# Handle command line arguments
case "${1:-auto}" in
    "init"|"install")
        main "init"
        ;;
    "first")
        main "first"
        ;;
    "error"|"terd")
        main "error"
        ;;
    "random")
        main "random"
        ;;
    "--force-random")
        # Force show random ASCII regardless of timing
        rm -f "$LAST_ASCII_FILE"
        main "random"
        ;;
    "--reset-first")
        # Reset first run marker
        rm -f "$GRIM_ROOT/.first_run_complete"
        echo "First run marker reset"
        ;;
    "--help"|"-h")
        echo "Grim ASCII Art Display System"
        echo ""
        echo "Usage: $0 [context]"
        echo ""
        echo "Contexts:"
        echo "  auto        - Automatic context detection (default)"
        echo "  init        - Installation/initialization ASCII"
        echo "  first       - First run ASCII"
        echo "  error/terd  - Error ASCII"
        echo "  random      - Random ASCII (respects 5-minute interval)"
        echo ""
        echo "Options:"
        echo "  --force-random  - Force random ASCII regardless of timing"
        echo "  --reset-first   - Reset first run marker"
        echo "  --help/-h       - Show this help"
        ;;
    *)
        main "auto"
        ;;
esac