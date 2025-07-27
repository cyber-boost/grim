#!/bin/bash

# 💀 Grim Reaper - Backward Compatibility Layer
# =============================================
# This file provides backward compatibility for scripts that expect reaper.sh
# The modern Grim Reaper system uses grim_throne.sh as the main entry point
# This file provides environment variables and colors for legacy scripts

set -euo pipefail

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color
RESET='\033[0m'

# --- Environment Variables ---
# Determine GRIM_ROOT dynamically
if [ -z "${GRIM_ROOT:-}" ]; then
    SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
    GRIM_ROOT="$(dirname "$SCRIPT_PATH")"
    export GRIM_ROOT
fi

# Ensure GRIM_ROOT points to the correct directory
if [[ "$GRIM_ROOT" == "/root/.grim-reaper" ]]; then
    GRIM_ROOT="/opt/reaper"
    export GRIM_ROOT
fi

# Verify GRIM_ROOT exists
if [ ! -d "$GRIM_ROOT" ]; then
    echo "Error: GRIM_ROOT directory not found: $GRIM_ROOT"
    echo "Please set GRIM_ROOT environment variable to the Grim Reaper installation directory"
    exit 1
fi

# --- Directory Structure ---
export GRIM_CONFIG_DIR="${GRIM_CONFIG_DIR:-$GRIM_ROOT/config}"
export GRIM_DB_DIR="${GRIM_DB_DIR:-$GRIM_ROOT/db}"
export GRIM_LOG_DIR="${GRIM_LOG_DIR:-$GRIM_ROOT/logs}"
export GRIM_RUN_DIR="${GRIM_RUN_DIR:-$GRIM_ROOT/run}"
export GRIM_CACHE_DIR="${GRIM_CACHE_DIR:-$GRIM_ROOT/cache}"
export GRIM_BACKUP_DIR="${GRIM_BACKUP_DIR:-$GRIM_ROOT/backups}"
export GRIM_TEMP_DIR="${GRIM_TEMP_DIR:-$GRIM_ROOT/temp}"
export GRIM_DATA_DIR="${GRIM_DATA_DIR:-$GRIM_ROOT/data}"

# --- Create directories if they don't exist ---
mkdir -p "$GRIM_CONFIG_DIR" "$GRIM_DB_DIR" "$GRIM_LOG_DIR" "$GRIM_RUN_DIR" \
         "$GRIM_CACHE_DIR" "$GRIM_BACKUP_DIR" "$GRIM_TEMP_DIR" "$GRIM_DATA_DIR"

# --- Utility Functions ---
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# --- Main Entry Point Logic ---
# If this script is executed directly (not sourced), delegate to grim_throne.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if grim_throne.sh exists
    if [[ -f "$GRIM_ROOT/throne/grim_throne.sh" ]]; then
        # Delegate to the modern grim_throne.sh system
        exec "$GRIM_ROOT/throne/grim_throne.sh" "$@"
    elif [[ -f "$GRIM_ROOT/grim_throne.sh" ]]; then
        # Fallback to grim_throne.sh in root
        exec "$GRIM_ROOT/grim_throne.sh" "$@"
    else
        echo -e "${RED}Error: grim_throne.sh not found${NC}"
        echo "Expected locations:"
        echo "  $GRIM_ROOT/throne/grim_throne.sh"
        echo "  $GRIM_ROOT/grim_throne.sh"
        exit 1
    fi
fi

# --- Legacy Support Functions ---
# These functions are provided for backward compatibility with old scripts

# Legacy module dispatcher (for scripts that expect this)
dispatch_module() {
    local cmd="$1"; shift
    local module_script="$GRIM_ROOT/sh_grim/$cmd.sh"
    if [[ -f "$module_script" ]]; then
        bash "$module_script" "$@"
    else
        echo -e "${YELLOW}⚠️  Unknown command: $cmd${NC}"
        echo -e "${CYAN}Use 'grim help' to see available commands.${NC}"
        exit 1
    fi
}

# Legacy help function
show_help() {
    echo -e "${CYAN}Grim Reaper - Unified Command System${NC}"
    echo "Usage: grim <category> <command> [options...]"
    echo ""
    echo "This is a backward compatibility layer for the Grim Reaper system."
    echo "The modern system uses 'grim' commands through grim_throne.sh"
    echo ""
    echo "For full help, run: grim help"
}

# --- Export all variables for sourcing ---
export RED GREEN YELLOW BLUE CYAN MAGENTA PURPLE NC RESET
export GRIM_ROOT GRIM_CONFIG_DIR GRIM_DB_DIR GRIM_LOG_DIR
export GRIM_RUN_DIR GRIM_CACHE_DIR GRIM_BACKUP_DIR GRIM_TEMP_DIR GRIM_DATA_DIR

# --- Success message when sourced ---
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # This script was sourced, not executed
    # Don't show any output to avoid cluttering the environment
    :
fi 