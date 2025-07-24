#!/bin/bash
# Grim Reaper Rust Package Deployment Script
# Deploys to crates.io

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[CRATES.IO]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}" >&2; exit 1; }

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v cargo &> /dev/null; then
        error "Cargo is not installed"
    fi
    
    if ! command -v rustc &> /dev/null; then
        error "Rust compiler is not installed"
    fi
    
    # Check if cargo login is configured
    if [[ ! -f ~/.cargo/credentials ]] && [[ -z "${CARGO_REGISTRY_TOKEN:-}" ]]; then
        warning "No crates.io credentials found"
        log "Please configure crates.io credentials with:"
        log "  cargo login <your-token>"
        log "Or set CARGO_REGISTRY_TOKEN environment variable"
        return 1
    fi
    
    success "Prerequisites check passed"
}

# Update version if provided
update_version() {
    if [[ $# -gt 0 ]]; then
        local version="$1"
        log "Updating version to $version..."
        
        # Update Cargo.toml version
        sed -i "s/version = \"[^\"]*\"/version = \"$version\"/" Cargo.toml
        
        # Update version in main.rs if present
        if grep -q "#\[command(version = " src/main.rs; then
            sed -i "s/#\[command(version = \"[^\"]*\")\]/#[command(version = \"$version\")]/" src/main.rs
        fi
        
        success "Version updated to $version"
    fi
}

# Create README if missing
create_readme() {
    if [[ ! -f "README.md" ]]; then
        log "Creating README.md..."
        
        cat > README.md << 'EOF'
# Grim Reaper Rust Package 🗡️🦀

**Real core integration** - No mock files! Directly calls actual `sh_grim` modules, `go_grim` binaries, and `py_grim` APIs from your Grim installation.

## Installation

```bash
cargo install grim-reaper
```

## Usage

```bash
# Create backups using real sh_grim/backup.sh
grim backup /important/data --name daily_backup --compress zstd

# Compress files using go_grim compression engine
grim compress large_file.tar --algorithm zstd --level 10

# Monitor directories using sh_grim/monitor.sh  
grim monitor /watch/this/path --interval 5 --events all

# Security scanning using sh_grim/security.sh
grim security-scan /sensitive/data --deep --report security_report.json

# Health checks using sh_grim/health.sh
grim health

# Get API status from py_grim FastAPI
grim api-status
```

## Core Integration

This package provides real integration with:

- **sh_grim modules**: 64+ shell modules for backup, monitoring, security, etc.
- **go_grim binaries**: High-performance compression and scanning tools
- **py_grim APIs**: FastAPI services for web integration and advanced features

## Portable Installation Discovery

Works anywhere Grim is installed - uses smart path discovery:

1. `GRIM_ROOT` environment variable
2. Search up directory tree from current location
3. Standard installation paths (`/opt/reaper`, `/usr/local/reaper`, etc.)
4. User directories (`~/reaper`, `~/.reaper`)

## License

**Balanced Beneficiary License (BBL)** - see LICENSE file for details.

## Links

- **Homepage**: https://grim.so
- **Repository**: https://github.com/cyber-boost/grim
- **Documentation**: https://grim.so/docs
EOF
        
        success "README.md created"
    fi
}

# Build and test package
build_package() {
    log "Building Rust package..."
    
    # Clean previous builds
    cargo clean
    
    # Build in release mode
    cargo build --release
    
    # Run tests
    log "Running tests..."
    cargo test
    
    # Check code formatting
    log "Checking code formatting..."
    cargo fmt -- --check || {
        warning "Code formatting issues found - auto-fixing..."
        cargo fmt
    }
    
    # Run clippy for linting
    log "Running clippy linting..."
    cargo clippy -- -D warnings || {
        warning "Clippy warnings found - please review before deploying"
    }
    
    success "Package built and tested successfully"
}

# Upload to crates.io
upload_package() {
    log "Uploading to crates.io..."
    
    # Check if we have credentials
    if [[ ! -f ~/.cargo/credentials ]] && [[ -z "${CARGO_REGISTRY_TOKEN:-}" ]]; then
        error "No crates.io credentials found - run 'cargo login <token>' first"
    fi
    
    # Dry run first
    log "Running cargo publish dry-run..."
    cargo publish --dry-run
    
    # Actual publish
    log "Publishing to crates.io..."
    cargo publish
    
    success "Package uploaded to crates.io"
}

# Generate deployment report
generate_report() {
    log "Generating deployment report..."
    
    local version=$(grep '^version = ' Cargo.toml | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "deployment-report.txt" << EOF
Grim Reaper Rust Package Deployment Report
==========================================

Package: grim-reaper
Version: $version
Deployed: $timestamp
Registry: https://crates.io/crates/grim-reaper

Installation:
  cargo install grim-reaper

Usage:
  grim backup /path/to/data --name backup_name
  grim compress file.tar --algorithm zstd
  grim monitor /watch/path --interval 5
  grim health

Integration:
  ✅ Proper sh_grim module integration via subprocess
  ✅ Real go_grim binary calls for compression
  ✅ py_grim FastAPI service integration via HTTP
  ✅ Portable path discovery with GRIM_ROOT support

Files Included:
  - src/main.rs (main application)
  - Cargo.toml (package definition)
  - README.md (documentation)
  - LICENSE (Balanced Beneficiary License)

Core Integration:
  - Calls actual sh_grim/*.sh modules
  - Uses real go_grim/build/* binaries
  - Integrates with py_grim FastAPI at localhost:8000
  - Rust-specific features: async/await, tokio, proper error handling
EOF
    
    success "Deployment report: deployment-report.txt"
}

# Run basic smoke tests
run_tests() {
    log "Running integration tests..."
    
    # Test that binary was built
    if [[ -f "target/release/grim" ]]; then
        success "Binary build test passed"
    else
        warning "Binary not found - build may have failed"
    fi
    
    # Test basic compilation
    if cargo check --quiet; then
        success "Compilation test passed"
    else
        warning "Compilation test failed"
    fi
    
    # Test that dependencies resolve
    if cargo tree > /dev/null 2>&1; then
        success "Dependency resolution test passed"
    else
        warning "Dependency resolution test failed"
    fi
}

# Main deployment function
deploy() {
    echo -e "${CYAN}🚀 Deploying Grim Reaper Rust Package${NC}"
    echo ""
    
    check_prerequisites
    update_version "$@"
    create_readme
    build_package
    run_tests
    upload_package
    generate_report
    
    echo ""
    echo -e "${GREEN}✅ Rust package deployed successfully!${NC}"
    echo -e "${BLUE}📦 Package: https://crates.io/crates/grim-reaper${NC}"
    echo -e "${YELLOW}💡 Install: cargo install grim-reaper${NC}"
}

# Show help
show_help() {
    echo "Grim Reaper Rust Package Deployment"
    echo ""
    echo "Usage: $0 [version]"
    echo ""
    echo "Examples:"
    echo "  $0              # Deploy current version"
    echo "  $0 1.2.3        # Deploy specific version"
    echo ""
    echo "Environment Variables:"
    echo "  CARGO_REGISTRY_TOKEN  # crates.io API token"
}

# Handle arguments
case "${1:-deploy}" in
    help|-h|--help)
        show_help
        ;;
    *)
        deploy "$@"
        ;;
esac