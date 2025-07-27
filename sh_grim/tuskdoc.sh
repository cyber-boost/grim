#!/bin/bash
# Grimm TuskDoc Module: Prints TuskLang config summary

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
TUSK_FILE="$GRIM_ROOT/config/grimm.tusk"
TUSK_PARSER="$GRIM_ROOT/bin/tusk_parser.sh"

# Load Tusk config
source "$TUSK_PARSER" "$TUSK_FILE"

show_help() {
    echo "Grimm TuskDoc Module"
    echo "Usage: tuskdoc.sh [command]"
    echo ""
    echo "Purpose: Displays and documents TuskLang configuration files,"
    echo "         providing a human-readable summary of system settings."
    echo ""
    echo "Commands:"
    echo "  show                  - Show TuskLang config summary (default)"
    echo "  help, -h, --help      - Show this help message"
    echo ""
    echo "Options:"
    echo "  None - displays current configuration"
    echo ""
    echo "Features:"
    echo "  - Parses TuskLang configuration files"
    echo "  - Displays active configuration settings"
    echo "  - Filters out comments and empty lines"
    echo "  - Provides documentation links"
    echo "  - Shows configuration file location"
    echo ""
    echo "Examples:"
    echo "  ./tuskdoc.sh                    # Show config summary"
    echo "  ./tuskdoc.sh show               # Explicitly show config"
    echo "  ./tuskdoc.sh help               # Show help"
    echo ""
    echo "Configuration File:"
    echo "  Location: $TUSK_FILE"
    echo "  Format: TuskLang (.tsk)"
    echo "  Documentation: https://tonton.io/master-tusker.txt"
}

main() {
    local command="${1:-show}"
    
    case "$command" in
        help|-h|--help)
            show_help
            ;;
        show|*)
            echo "==== Grimm TuskLang Config Summary ===="
            echo "Config file: $TUSK_FILE"
            echo ""
            grep -v '^#' "$TUSK_FILE" | grep -v '^$' | while read line; do
                echo "  $line"
            done
            echo ""
            echo "TuskLang docs: https://tonton.io/master-tusker.txt"
            ;;
    esac
}

main "$@" 