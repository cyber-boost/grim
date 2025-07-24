#!/bin/bash
# Grim Reaper Rust Build & Deploy System
# Comprehensive Rust crate management with build, test, and deploy capabilities

set -euo pipefail

# Auto-detect GRIM_ROOT based on script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

# Source the unified ASCII art system
if [[ -f "$GRIM_ROOT/throne/bash_central/grim-ascii-unified.sh" ]]; then
    source "$GRIM_ROOT/throne/bash_central/grim-ascii-unified.sh"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
RUST_PACKAGE_NAME="grim"
RUST_REGISTRY="crates.io"
CARGO_TOML_PATH=""
BUILD_TARGET="release"
TEST_TIMEOUT=300
DEPLOY_ENVIRONMENT="production"

# Logging
LOG_FILE="$GRIM_ROOT/logs/grimrust.log"
mkdir -p "$(dirname "$LOG_FILE")"

error() {
    grim_ascii_main "error" "" "$1"
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}✅ SUCCESS: $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE"
}

info() {
    echo -e "${BLUE}ℹ️  INFO: $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: $1" >> "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE"
}

debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}🔍 DEBUG: $1${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - DEBUG: $1" >> "$LOG_FILE"
    fi
}

# ============================================================================
# RUST ENVIRONMENT DETECTION
# ============================================================================

check_rust_installation() {
    info "Checking Rust installation..."
    
    if ! command -v rustc &> /dev/null; then
        error "Rust compiler (rustc) not found. Please install Rust first: https://rustup.rs/"
    fi
    
    if ! command -v cargo &> /dev/null; then
        error "Cargo package manager not found. Please install Rust first: https://rustup.rs/"
    fi
    
    local rust_version=$(rustc --version)
    local cargo_version=$(cargo --version)
    
    info "Rust version: $rust_version"
    info "Cargo version: $cargo_version"
    
    success "Rust environment verified"
}

find_cargo_toml() {
    # Look for Cargo.toml in current directory first, then common locations
    local search_paths=(
        "$SCRIPT_DIR"
        "$GRIM_ROOT/rs_grim"
        "$GRIM_ROOT/go_grim"
        "$GRIM_ROOT/crates"
        "$GRIM_ROOT"
        "$GRIM_ROOT/src"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -f "$path/Cargo.toml" ]]; then
            CARGO_TOML_PATH="$path"
            info "Found Cargo.toml at: $CARGO_TOML_PATH"
            return 0
        fi
    done
    
    error "Cargo.toml not found in any expected location"
}

# ============================================================================
# BUILD SYSTEM
# ============================================================================

build_crate() {
    local target="${1:-$BUILD_TARGET}"
    
    grim_ascii_main "command" "build"
    info "Building Rust crate in $target mode..."
    
    cd "$CARGO_TOML_PATH"
    
    # Clean previous builds
    info "Cleaning previous build artifacts..."
    cargo clean
    
    # Update dependencies
    info "Updating dependencies..."
    cargo update
    
    # Build the crate
    info "Building crate..."
    if [[ "$target" == "release" ]]; then
        cargo build --release
    else
        cargo build
    fi
    
    # Check build artifacts
    local binary_path=""
    if [[ "$target" == "release" ]]; then
        binary_path="target/release/$RUST_PACKAGE_NAME"
    else
        binary_path="target/debug/$RUST_PACKAGE_NAME"
    fi
    
    if [[ -f "$binary_path" ]]; then
        local size=$(du -h "$binary_path" | cut -f1)
        success "Build completed successfully! Binary size: $size"
    else
        warning "Binary not found at expected location: $binary_path"
    fi
}

# ============================================================================
# TESTING SYSTEM
# ============================================================================

run_tests() {
    local test_type="${1:-all}"
    
    grim_ascii_main "command" "test"
    info "Running Rust tests ($test_type)..."
    
    cd "$CARGO_TOML_PATH"
    
    case "$test_type" in
        "unit")
            info "Running unit tests..."
            timeout "$TEST_TIMEOUT" cargo test --lib
            ;;
        "integration")
            info "Running integration tests..."
            timeout "$TEST_TIMEOUT" cargo test --tests
            ;;
        "doc")
            info "Running documentation tests..."
            timeout "$TEST_TIMEOUT" cargo test --doc
            ;;
        "all")
            info "Running all tests..."
            timeout "$TEST_TIMEOUT" cargo test
            ;;
        *)
            error "Unknown test type: $test_type"
            ;;
    esac
    
    success "All tests passed!"
}

run_benchmarks() {
    grim_ascii_main "command" "bench"
    info "Running Rust benchmarks..."
    
    cd "$CARGO_TOML_PATH"
    
    if [[ -d "benches" ]]; then
        cargo bench
        success "Benchmarks completed"
    else
        warning "No benchmarks directory found"
    fi
}

# ============================================================================
# CODE QUALITY
# ============================================================================

run_clippy() {
    grim_ascii_main "command" "clippy"
    info "Running Clippy linting..."
    
    cd "$CARGO_TOML_PATH"
    
    if command -v cargo-clippy &> /dev/null || rustup component list | grep -q clippy; then
        cargo clippy -- -D warnings
        success "Clippy linting passed"
    else
        warning "Clippy not installed. Installing..."
        rustup component add clippy
        cargo clippy -- -D warnings
        success "Clippy linting passed"
    fi
}

format_code() {
    grim_ascii_main "command" "fmt"
    info "Formatting Rust code..."
    
    cd "$CARGO_TOML_PATH"
    
    if command -v rustfmt &> /dev/null || rustup component list | grep -q rustfmt; then
        cargo fmt -- --check
        success "Code formatting check passed"
    else
        warning "rustfmt not installed. Installing..."
        rustup component add rustfmt
        cargo fmt -- --check
        success "Code formatting check passed"
    fi
}

check_code() {
    grim_ascii_main "command" "check"
    info "Checking Rust code..."
    
    cd "$CARGO_TOML_PATH"
    
    cargo check
    success "Code check passed"
}

# ============================================================================
# DEPLOYMENT SYSTEM
# ============================================================================

deploy_crate() {
    local environment="${1:-$DEPLOY_ENVIRONMENT}"
    
    grim_ascii_main "command" "deploy"
    info "Deploying Rust crate to $environment..."
    
    cd "$CARGO_TOML_PATH"
    
    # Check if we're ready to publish
    if [[ "$environment" == "production" ]]; then
        # Run all checks before deployment
        info "Running pre-deployment checks..."
        check_rust_installation
        check_code
        run_clippy
        format_code
        run_tests "all"
        build_crate "release"
        
        # Check if crate is ready for publishing
        if ! cargo package --list; then
            error "Crate is not ready for publishing. Check Cargo.toml configuration."
        fi
        
        # Confirm deployment
        echo -e "${YELLOW}⚠️  WARNING: This will publish to $RUST_REGISTRY${NC}"
        read -p "Are you sure you want to deploy to production? (yes/no): " confirm
        
        if [[ "$confirm" != "yes" ]]; then
            warning "Deployment cancelled by user"
            return 1
        fi
        
        # Publish to crates.io
        info "Publishing to $RUST_REGISTRY..."
        cargo publish
        
        success "Crate published successfully to $RUST_REGISTRY!"
        
    elif [[ "$environment" == "staging" ]]; then
        # Build for staging
        info "Building for staging deployment..."
        build_crate "release"
        
        # Create staging package
        local staging_dir="$GRIM_ROOT/builds/staging"
        mkdir -p "$staging_dir"
        
        if [[ "$BUILD_TARGET" == "release" ]]; then
            cp "target/release/$RUST_PACKAGE_NAME" "$staging_dir/"
        else
            cp "target/debug/$RUST_PACKAGE_NAME" "$staging_dir/"
        fi
        
        success "Staging deployment ready at: $staging_dir"
        
    else
        error "Unknown deployment environment: $environment"
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

show_info() {
    grim_ascii_main "command" "info"
    
    echo -e "${CYAN}🗡️  Grim Reaper Rust Build System${NC}"
    echo ""
    echo "Package: $RUST_PACKAGE_NAME"
    echo "Location: $CARGO_TOML_PATH"
    echo "Build Target: $BUILD_TARGET"
    echo "Registry: $RUST_REGISTRY"
    echo ""
    
    if [[ -n "$CARGO_TOML_PATH" ]]; then
        cd "$CARGO_TOML_PATH"
        
        # Show package info
        if [[ -f "Cargo.toml" ]]; then
            echo "Package Information:"
            echo "  Name: $(grep '^name =' Cargo.toml | cut -d'"' -f2)"
            echo "  Version: $(grep '^version =' Cargo.toml | cut -d'"' -f2)"
            echo "  Authors: $(grep '^authors =' Cargo.toml | cut -d'"' -f2)"
            echo ""
        fi
        
        # Show build status
        if [[ -f "target/release/$RUST_PACKAGE_NAME" ]]; then
            local size=$(du -h "target/release/$RUST_PACKAGE_NAME" | cut -f1)
            echo "Build Status: ✅ Release binary available ($size)"
        elif [[ -f "target/debug/$RUST_PACKAGE_NAME" ]]; then
            local size=$(du -h "target/debug/$RUST_PACKAGE_NAME" | cut -f1)
            echo "Build Status: ⚠️  Debug binary available ($size)"
        else
            echo "Build Status: ❌ No binary found"
        fi
    fi
}

clean_builds() {
    grim_ascii_main "command" "clean"
    info "Cleaning build artifacts..."
    
    cd "$CARGO_TOML_PATH"
    cargo clean
    
    # Clean staging builds
    if [[ -d "$GRIM_ROOT/builds/staging" ]]; then
        rm -rf "$GRIM_ROOT/builds/staging"
    fi
    
    success "Build artifacts cleaned"
}

show_help() {
    grim_ascii_main "command" "help"
    
    echo -e "${CYAN}🗡️  Grim Reaper Rust Build & Deploy System${NC}"
    echo ""
    echo "Usage: ./grimrust.sh <command> [options]"
    echo ""
    echo "Build Commands:"
    echo "  build [target]              Build crate (debug/release)"
    echo "  clean                       Clean build artifacts"
    echo "  check                       Check code without building"
    echo ""
    echo "Testing Commands:"
    echo "  test [type]                 Run tests (unit/integration/doc/all)"
    echo "  bench                       Run benchmarks"
    echo ""
    echo "Quality Commands:"
    echo "  clippy                      Run Clippy linting"
    echo "  fmt                         Format code"
    echo ""
    echo "Deployment Commands:"
    echo "  deploy [env]                Deploy crate (staging/production)"
    echo ""
    echo "Utility Commands:"
    echo "  info                        Show package information"
    echo "  setup                       Setup Rust environment"
    echo "  help                        Show this help"
    echo ""
    echo "Examples:"
    echo "  ./grimrust.sh build         # Build in release mode"
    echo "  ./grimrust.sh test all      # Run all tests"
    echo "  ./grimrust.sh deploy staging # Deploy to staging"
    echo "  ./grimrust.sh deploy        # Deploy to production"
    echo ""
    echo "Environment Variables:"
    echo "  DEBUG=true                  Enable debug output"
    echo "  BUILD_TARGET=debug          Set build target"
    echo "  DEPLOY_ENVIRONMENT=staging  Set deployment environment"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Initialize
    check_rust_installation
    find_cargo_toml
    
    # Parse command
    local command="${1:-help}"
    
    case "$command" in
        "build")
            build_crate "${2:-}"
            ;;
        "test")
            run_tests "${2:-}"
            ;;
        "bench")
            run_benchmarks
            ;;
        "clippy")
            run_clippy
            ;;
        "fmt")
            format_code
            ;;
        "check")
            check_code
            ;;
        "deploy")
            deploy_crate "${2:-}"
            ;;
        "clean")
            clean_builds
            ;;
        "info")
            show_info
            ;;
        "setup")
            check_rust_installation
            success "Rust environment setup complete"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            error "Unknown command: $command. Use './grimrust.sh help' for usage."
            ;;
    esac
}

# Run main function with all arguments
main "$@" 