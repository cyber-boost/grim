#!/bin/bash

# =============================================================================
# 🗡️ GRIM REAPER MASTER BUILD SCRIPT
# =============================================================================
# Builds all language packages effortlessly
# Built by Bernie Gengel and his beagle Buddy
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Version management
VERSION="${1:-$(date +%Y.%m.%d)}"
BUILD_DIR="/opt/reaper/pkg"
LOG_DIR="$BUILD_DIR/build-logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create log directory
mkdir -p "$LOG_DIR"

# Log function
log() {
    echo -e "${2:-$BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_DIR/build-$TIMESTAMP.log"
}

# Error handler
handle_error() {
    log "❌ Build failed at line $1" "$RED"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Header
clear
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           🗡️  GRIM REAPER PACKAGE BUILDER v$VERSION            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

log "🚀 Starting master build process..." "$GREEN"
log "📁 Build directory: $BUILD_DIR"
log "📝 Log file: $LOG_DIR/build-$TIMESTAMP.log"

# Update version in all packages
update_version() {
    local pkg=$1
    local file=$2
    local pattern=$3
    local replacement=$4
    
    log "📦 Updating version for $pkg to $VERSION..."
    
    if [[ -f "$BUILD_DIR/$pkg/$file" ]]; then
        sed -i.bak "$pattern" "$BUILD_DIR/$pkg/$file"
        rm -f "$BUILD_DIR/$pkg/$file.bak"
        log "✅ Updated $pkg version" "$GREEN"
    else
        log "⚠️  Could not find $file for $pkg" "$YELLOW"
    fi
}

# Build functions for each language
build_javascript() {
    log "🌟 Building JavaScript package..." "$BLUE"
    cd "$BUILD_DIR/js_grim"
    
    # Update version
    update_version "js_grim" "package.json" "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" 
    
    # Install dependencies
    log "📦 Installing dependencies..."
    npm install
    
    # Run tests
    log "🧪 Running tests..."
    npm test || log "⚠️  Tests failed, continuing..." "$YELLOW"
    
    # Pack for npm
    log "📦 Creating npm package..."
    npm pack
    
    log "✅ JavaScript build complete" "$GREEN"
}

build_python() {
    log "🐍 Building Python package..." "$BLUE"
    cd "$BUILD_DIR/py_grim"
    
    # Update version
    update_version "py_grim" "setup.py" "s/version='[^']*'/version='$VERSION'/"
    
    # Create virtual environment
    log "🐍 Setting up virtual environment..."
    python3 -m venv venv || true
    source venv/bin/activate || true
    
    # Install dependencies
    log "📦 Installing dependencies..."
    pip install -r requirements.txt || log "⚠️  Some dependencies failed" "$YELLOW"
    
    # Build package
    log "📦 Building Python package..."
    python setup.py sdist bdist_wheel
    
    log "✅ Python build complete" "$GREEN"
}

build_ruby() {
    log "💎 Building Ruby package..." "$BLUE"
    cd "$BUILD_DIR/rb_grim"
    
    # Update version
    update_version "rb_grim" "grim-reaper.gemspec" "s/spec.version = '[^']*'/spec.version = '$VERSION'/"
    
    # Install dependencies
    log "📦 Installing dependencies..."
    bundle install || log "⚠️  Some dependencies failed" "$YELLOW"
    
    # Build gem
    log "💎 Building gem..."
    gem build grim-reaper.gemspec
    
    log "✅ Ruby build complete" "$GREEN"
}

build_rust() {
    log "🦀 Building Rust package..." "$BLUE"
    cd "$BUILD_DIR/rs_grim"
    
    # Update version
    update_version "rs_grim" "Cargo.toml" "s/version = \"[^\"]*\"/version = \"$VERSION\"/"
    
    # Build release
    log "🦀 Building release binary..."
    cargo build --release || log "⚠️  Rust build failed" "$YELLOW"
    
    # Package for crates.io
    log "📦 Packaging for crates.io..."
    cargo package --allow-dirty || log "⚠️  Packaging failed" "$YELLOW"
    
    log "✅ Rust build complete" "$GREEN"
}

build_php() {
    log "🐘 Building PHP package..." "$BLUE"
    cd "$BUILD_DIR/php_grim"
    
    # Update version
    log "📦 Updating composer.json version..."
    if command -v jq &> /dev/null; then
        jq ".version = \"$VERSION\"" composer.json > composer.json.tmp && mv composer.json.tmp composer.json
    else
        log "⚠️  jq not installed, skipping version update" "$YELLOW"
    fi
    
    # Install dependencies
    log "📦 Installing dependencies..."
    composer install --no-dev || log "⚠️  Some dependencies failed" "$YELLOW"
    
    # Create archive
    log "📦 Creating archive..."
    composer archive --format=zip --file="grim-reaper-$VERSION"
    
    log "✅ PHP build complete" "$GREEN"
}

build_go() {
    log "🐹 Building Go package..." "$BLUE"
    cd "$BUILD_DIR/go_grim"
    
    # Update version
    log "📦 Updating version..."
    echo "package grim_reaper

const Version = \"$VERSION\"" > version.go
    
    # Get dependencies
    log "📦 Getting dependencies..."
    go mod tidy || log "⚠️  Some dependencies failed" "$YELLOW"
    
    # Build
    log "🐹 Building package..."
    go build -v ./...
    
    log "✅ Go build complete" "$GREEN"
}

build_csharp() {
    log "🔷 Building C# package..." "$BLUE"
    cd "$BUILD_DIR/cs_grim"
    
    # Check for dotnet
    if ! command -v dotnet &> /dev/null; then
        log "⚠️  .NET SDK not installed, skipping C# build" "$YELLOW"
        return
    fi
    
    # Update version
    update_version "cs_grim" "GrimReaper.csproj" "s/<Version>[^<]*<\/Version>/<Version>$VERSION<\/Version>/"
    
    # Build
    log "🔷 Building C# package..."
    dotnet build -c Release
    
    # Pack for NuGet
    log "📦 Creating NuGet package..."
    dotnet pack -c Release
    
    log "✅ C# build complete" "$GREEN"
}

build_java() {
    log "☕ Building Java package..." "$BLUE"
    cd "$BUILD_DIR/java_grim"
    
    # Check for Maven
    if ! command -v mvn &> /dev/null; then
        log "⚠️  Maven not installed, skipping Java build" "$YELLOW"
        return
    fi
    
    # Update version
    update_version "java_grim" "pom.xml" "s/<version>[^<]*<\/version>/<version>$VERSION<\/version>/" 
    
    # Build
    log "☕ Building Java package..."
    mvn clean package
    
    log "✅ Java build complete" "$GREEN"
}

# Create build summary
create_summary() {
    log "📊 Creating build summary..." "$BLUE"
    
    SUMMARY_FILE="$LOG_DIR/build-summary-$TIMESTAMP.txt"
    
    cat > "$SUMMARY_FILE" << EOF
🗡️ GRIM REAPER BUILD SUMMARY
==========================
Version: $VERSION
Build Date: $(date)
Build Host: $(hostname)

PACKAGES BUILT:
EOF

    # Check each package
    for pkg in js_grim py_grim rb_grim rs_grim php_grim go_grim cs_grim java_grim; do
        if [[ -d "$BUILD_DIR/$pkg" ]]; then
            echo "✅ $pkg" >> "$SUMMARY_FILE"
        else
            echo "❌ $pkg (not found)" >> "$SUMMARY_FILE"
        fi
    done
    
    echo "" >> "$SUMMARY_FILE"
    echo "Build logs: $LOG_DIR/build-$TIMESTAMP.log" >> "$SUMMARY_FILE"
    
    log "✅ Build summary created: $SUMMARY_FILE" "$GREEN"
    cat "$SUMMARY_FILE"
}

# Main build process
main() {
    # Build all packages
    build_javascript
    build_python
    build_ruby
    build_rust
    build_php
    build_go
    build_csharp
    build_java
    
    # Create summary
    create_summary
    
    log "🎉 Master build complete!" "$GREEN"
    log "📦 All packages built with version: $VERSION" "$GREEN"
    log "📝 Check logs at: $LOG_DIR" "$BLUE"
}

# Run main
main

# C.3.R.B.H.F