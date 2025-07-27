#!/bin/bash

# GRIM Common Functions
# Shared utilities for all GRIM scripts

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp]${NC} $message"
    
    # Also log to file if GRIM_LOG is set
    if [[ -n "${GRIM_LOG:-}" ]]; then
        echo "[$timestamp] $message" >> "$GRIM_LOG"
    fi
}

# Error logging function
log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] ERROR:${NC} $message" >&2
    
    # Also log to file if GRIM_LOG is set
    if [[ -n "${GRIM_LOG:-}" ]]; then
        echo "[$timestamp] ERROR: $message" >> "$GRIM_LOG"
    fi
}

# Warning logging function
log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] WARNING:${NC} $message" >&2
    
    # Also log to file if GRIM_LOG is set
    if [[ -n "${GRIM_LOG:-}" ]]; then
        echo "[$timestamp] WARNING: $message" >> "$GRIM_LOG"
    fi
}

# Success logging function
log_success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] SUCCESS:${NC} $message"
    
    # Also log to file if GRIM_LOG is set
    if [[ -n "${GRIM_LOG:-}" ]]; then
        echo "[$timestamp] SUCCESS: $message" >> "$GRIM_LOG"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log "Created directory: $dir"
    fi
}

# Cleanup function
cleanup_temp_files() {
    if [[ -n "${TEMP_FILES:-}" ]]; then
        for file in $TEMP_FILES; do
            if [[ -f "$file" ]]; then
                rm -f "$file"
                log "Cleaned up temporary file: $file"
            fi
        done
    fi
}

# Set up cleanup trap
trap cleanup_temp_files EXIT 