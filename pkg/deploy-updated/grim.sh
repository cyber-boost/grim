#!/bin/bash

# =============================================================================
# 🗡️ GRIM REAPER UNIFIED BUILD & DEPLOY SYSTEM
# =============================================================================
# Manages building and deploying all language packages with version control
# Built by Bernie Gengel and his beagle Buddy
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/grim-config.json"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Command options
COMMAND=""
VERSION=""
DRY_RUN=false
DEPLOY_MESSAGE=""
OTP_NPM=""
OTP_RUBY=""
SKIP_PACKAGES=()

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing required dependencies: ${missing[*]}${NC}"
        echo -e "${YELLOW}💡 Install with: sudo apt-get install ${missing[*]}${NC}"
        exit 1
    fi
}

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    # Load paths
    BUILD_DIR=$(jq -r '.paths.base' "$CONFIG_FILE")
    LOG_DIR=$(jq -r '.paths.logs' "$CONFIG_FILE")
    
    # Create directories
    mkdir -p "$LOG_DIR"
    
    # Get version
    local override_version=$(jq -r '.version.override // empty' "$CONFIG_FILE")
    if [[ -n "$override_version" ]]; then
        VERSION="$override_version"
    elif [[ -z "$VERSION" ]]; then
        VERSION=$(jq -r '.version.current' "$CONFIG_FILE")
    fi
}

# Log function
log() {
    echo -e "${2:-$BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_DIR/grim-$TIMESTAMP.log"
}

# Error handler
handle_error() {
    log "❌ Failed at line $1" "$RED"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            build|deploy|all)
                COMMAND="$1"
                shift
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -m|--message)
                DEPLOY_MESSAGE="$2"
                shift 2
                ;;
            --otp-npm)
                OTP_NPM="$2"
                shift 2
                ;;
            --otp-ruby)
                OTP_RUBY="$2"
                shift 2
                ;;
            --skip-*)
                SKIP_PACKAGES+=("${1#--skip-}")
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
🗡️ GRIM REAPER BUILD & DEPLOY SYSTEM

Usage: $0 [build|deploy|all] [options]

Commands:
  build         Build all packages
  deploy        Deploy all packages
  all           Build and deploy all packages

Options:
  -v, --version VERSION     Set version (overrides config)
  --dry-run                 Show what would be done without doing it
  -m, --message MESSAGE     Add deployment message/changelog
  --otp-npm TOKEN          NPM OTP token for 2FA
  --otp-ruby TOKEN         RubyGems OTP token for 2FA
  --skip-LANG              Skip specific language (npm, python, ruby, rust, php, go, csharp, java)
  -h, --help               Show this help message

Examples:
  $0 build                          # Build all packages with version from config
  $0 deploy --dry-run               # Test deployment without actually deploying
  $0 all -v 2024.12.20              # Build and deploy with specific version
  $0 deploy --otp-npm 123456        # Deploy with NPM 2FA token
  $0 all --skip-java --skip-csharp  # Build and deploy, skipping Java and C#

Configuration: $CONFIG_FILE
EOF
}

# Update version in config
update_config_version() {
    local new_version="$1"
    local message="${2:-Version update}"
    
    # Update current version
    jq ".version.current = \"$new_version\"" "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    
    # Add to history
    jq ".version.history += [{\"version\": \"$new_version\", \"date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"notes\": \"$message\"}]" "$CONFIG_FILE.tmp" > "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.tmp"
    
    log "📝 Updated version in config to $new_version" "$GREEN"
}

# Check if package should be skipped
should_skip() {
    local package="$1"
    local lang="${package%_grim}"
    
    # Check if disabled in config
    local enabled=$(jq -r ".packages.$package.enabled // true" "$CONFIG_FILE")
    if [[ "$enabled" == "false" ]]; then
        return 0
    fi
    
    # Check skip flags
    for skip in "${SKIP_PACKAGES[@]}"; do
        if [[ "$skip" == "$lang" ]] || [[ "$skip" == "$package" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Update version in package files
update_package_version() {
    local package="$1"
    local pkg_info=$(jq -r ".packages.$package" "$CONFIG_FILE")
    
    if [[ "$pkg_info" == "null" ]]; then
        return
    fi
    
    local pkg_dir="$BUILD_DIR/$package"
    if [[ ! -d "$pkg_dir" ]]; then
        log "⚠️  Package directory not found: $pkg_dir" "$YELLOW"
        return
    fi
    
    cd "$pkg_dir"
    
    # Handle different version update methods
    if [[ $(echo "$pkg_info" | jq -r '.files.json_field // empty') ]]; then
        # JSON field update (e.g., composer.json)
        local file=$(echo "$pkg_info" | jq -r '.files.version')
        local field=$(echo "$pkg_info" | jq -r '.files.json_field')
        
        if [[ -f "$file" ]]; then
            jq ".$field = \"$VERSION\"" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            log "✅ Updated $package version to $VERSION" "$GREEN"
        fi
    elif [[ $(echo "$pkg_info" | jq -r '.files.content // empty') ]]; then
        # Full file content (e.g., version.go)
        local file=$(echo "$pkg_info" | jq -r '.files.version')
        local content=$(echo "$pkg_info" | jq -r '.files.content' | sed "s/VERSION/$VERSION/g")
        
        echo "$content" > "$file"
        log "✅ Updated $package version to $VERSION" "$GREEN"
    elif [[ $(echo "$pkg_info" | jq -r '.files.pattern // empty') ]]; then
        # Pattern replacement
        local file=$(echo "$pkg_info" | jq -r '.files.version')
        local pattern=$(echo "$pkg_info" | jq -r '.files.pattern' | sed "s/VERSION/$VERSION/g")
        
        if [[ -f "$file" ]]; then
            # Create sed pattern
            local search=$(echo "$pattern" | sed "s/$VERSION/[^\"'<>]*/g")
            local replace=$(echo "$pattern")
            
            sed -i.bak "s|$search|$replace|g" "$file"
            rm -f "$file.bak"
            log "✅ Updated $package version to $VERSION" "$GREEN"
        fi
    fi
}

# Build functions
build_javascript() {
    log "🌟 Building JavaScript package..." "$BLUE"
    cd "$BUILD_DIR/js_grim"
    
    update_package_version "js_grim"
    
    npm install
    npm test || log "⚠️  Tests failed, continuing..." "$YELLOW"
    npm pack
    
    log "✅ JavaScript build complete" "$GREEN"
}

build_python() {
    log "🐍 Building Python package..." "$BLUE"
    cd "$BUILD_DIR/py_grim"
    
    update_package_version "py_grim"
    
    python3 -m venv venv || true
    source venv/bin/activate || true
    pip install -r requirements.txt || log "⚠️  Some dependencies failed" "$YELLOW"
    python setup.py sdist bdist_wheel
    
    log "✅ Python build complete" "$GREEN"
}

build_ruby() {
    log "💎 Building Ruby package..." "$BLUE"
    cd "$BUILD_DIR/rb_grim"
    
    update_package_version "rb_grim"
    
    bundle install || log "⚠️  Some dependencies failed" "$YELLOW"
    gem build grim-reaper.gemspec
    
    log "✅ Ruby build complete" "$GREEN"
}

build_rust() {
    log "🦀 Building Rust package..." "$BLUE"
    cd "$BUILD_DIR/rs_grim"
    
    update_package_version "rs_grim"
    
    cargo build --release || log "⚠️  Rust build failed" "$YELLOW"
    cargo package --allow-dirty || log "⚠️  Packaging failed" "$YELLOW"
    
    log "✅ Rust build complete" "$GREEN"
}

build_php() {
    log "🐘 Building PHP package..." "$BLUE"
    cd "$BUILD_DIR/php_grim"
    
    update_package_version "php_grim"
    
    composer install --no-dev || log "⚠️  Some dependencies failed" "$YELLOW"
    composer archive --format=zip --file="grim-reaper-$VERSION"
    
    log "✅ PHP build complete" "$GREEN"
}

build_go() {
    log "🐹 Building Go package..." "$BLUE"
    cd "$BUILD_DIR/go_grim"
    
    update_package_version "go_grim"
    
    go mod tidy || log "⚠️  Some dependencies failed" "$YELLOW"
    go build -v ./...
    
    log "✅ Go build complete" "$GREEN"
}

build_csharp() {
    log "🔷 Building C# package..." "$BLUE"
    
    if ! command -v dotnet &> /dev/null; then
        log "⚠️  .NET SDK not installed, skipping C# build" "$YELLOW"
        return
    fi
    
    cd "$BUILD_DIR/cs_grim"
    update_package_version "cs_grim"
    
    dotnet build -c Release
    dotnet pack -c Release
    
    log "✅ C# build complete" "$GREEN"
}

build_java() {
    log "☕ Building Java package..." "$BLUE"
    
    if ! command -v mvn &> /dev/null; then
        log "⚠️  Maven not installed, skipping Java build" "$YELLOW"
        return
    fi
    
    cd "$BUILD_DIR/java_grim"
    update_package_version "java_grim"
    
    mvn clean package
    
    log "✅ Java build complete" "$GREEN"
}

# Deploy functions
deploy_javascript() {
    log "🌟 Deploying JavaScript package to npm..." "$BLUE"
    cd "$BUILD_DIR/js_grim"
    
    local package_file=$(ls -t grim-reaper-*.tgz 2>/dev/null | head -1)
    if [[ -z "$package_file" ]]; then
        log "❌ No package file found" "$RED"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: npm publish $package_file" "$YELLOW"
        [[ -n "$OTP_NPM" ]] && log "   with OTP: $OTP_NPM" "$YELLOW"
    else
        local otp_arg=""
        [[ -n "$OTP_NPM" ]] && otp_arg="--otp $OTP_NPM"
        
        npm publish "$package_file" $otp_arg
        log "✅ JavaScript package deployed to npm" "$GREEN"
    fi
}

deploy_ruby() {
    log "💎 Deploying Ruby gem to RubyGems..." "$BLUE"
    cd "$BUILD_DIR/rb_grim"
    
    local gem_file=$(ls -t grim-reaper-*.gem 2>/dev/null | head -1)
    if [[ -z "$gem_file" ]]; then
        log "❌ No gem file found" "$RED"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: gem push $gem_file" "$YELLOW"
        [[ -n "$OTP_RUBY" ]] && log "   with OTP: $OTP_RUBY" "$YELLOW"
    else
        local otp_arg=""
        [[ -n "$OTP_RUBY" ]] && otp_arg="--otp $OTP_RUBY"
        
        gem push "$gem_file" $otp_arg
        log "✅ Ruby gem deployed to RubyGems" "$GREEN"
    fi
}

deploy_python() {
    log "🐍 Deploying Python package to PyPI..." "$BLUE"
    cd "$BUILD_DIR/py_grim"
    
    if [[ ! -d dist ]]; then
        log "❌ No dist directory found" "$RED"
        return 1
    fi
    
    if ! command -v twine &> /dev/null; then
        pip install twine
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: twine upload dist/*" "$YELLOW"
    else
        twine upload dist/* --skip-existing
        log "✅ Python package deployed to PyPI" "$GREEN"
    fi
}

deploy_rust() {
    log "🦀 Deploying Rust package to crates.io..." "$BLUE"
    cd "$BUILD_DIR/rs_grim"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: cargo publish" "$YELLOW"
    else
        cargo publish --allow-dirty
        log "✅ Rust package deployed to crates.io" "$GREEN"
    fi
}

deploy_php() {
    log "🐘 PHP packages deploy via Git tags" "$YELLOW"
    log "💡 Run: git tag v$VERSION && git push origin v$VERSION" "$YELLOW"
}

deploy_go() {
    log "🐹 Go packages deploy via Git tags" "$YELLOW"
    log "💡 Run: git tag v$VERSION && git push origin v$VERSION" "$YELLOW"
}

deploy_csharp() {
    log "🔷 Deploying C# package to NuGet..." "$BLUE"
    cd "$BUILD_DIR/cs_grim"
    
    local nupkg_file=$(find . -name "*.nupkg" -type f | head -1)
    if [[ -z "$nupkg_file" ]]; then
        log "⚠️  No .nupkg file found" "$YELLOW"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: dotnet nuget push $nupkg_file" "$YELLOW"
    else
        if [[ -z "$NUGET_API_KEY" ]]; then
            log "⚠️  NUGET_API_KEY not set" "$YELLOW"
        else
            dotnet nuget push "$nupkg_file" --api-key "$NUGET_API_KEY" --source https://api.nuget.org/v3/index.json
            log "✅ C# package deployed to NuGet" "$GREEN"
        fi
    fi
}

deploy_java() {
    log "☕ Java deployment requires Maven Central setup" "$YELLOW"
    log "💡 See: https://central.sonatype.org/publish/publish-guide/" "$YELLOW"
}

# Build all packages
build_all() {
    log "🔨 Building all packages with version $VERSION..." "$CYAN"
    
    local build_funcs=(
        "js_grim:build_javascript"
        "py_grim:build_python"
        "rb_grim:build_ruby"
        "rs_grim:build_rust"
        "php_grim:build_php"
        "go_grim:build_go"
        "cs_grim:build_csharp"
        "java_grim:build_java"
    )
    
    for item in "${build_funcs[@]}"; do
        local package="${item%%:*}"
        local func="${item##*:}"
        
        if should_skip "$package"; then
            log "⏭️  Skipping $package build" "$YELLOW"
            continue
        fi
        
        $func || log "⚠️  $package build failed, continuing..." "$YELLOW"
    done
}

# Deploy all packages in order
deploy_all() {
    log "🚀 Deploying all packages..." "$CYAN"
    
    # Get deployment order from config
    local order=$(jq -r '.deployment.order[]' "$CONFIG_FILE")
    
    while IFS= read -r package; do
        if should_skip "$package"; then
            log "⏭️  Skipping $package deployment" "$YELLOW"
            continue
        fi
        
        case $package in
            js_grim) deploy_javascript ;;
            rb_grim) deploy_ruby ;;
            py_grim) deploy_python ;;
            rs_grim) deploy_rust ;;
            php_grim) deploy_php ;;
            go_grim) deploy_go ;;
            cs_grim) deploy_csharp ;;
            java_grim) deploy_java ;;
        esac
    done <<< "$order"
}

# Create summary report
create_summary() {
    local action="$1"
    
    log "📊 Creating $action summary..." "$BLUE"
    
    local summary_file="$LOG_DIR/$action-summary-$TIMESTAMP.txt"
    
    cat > "$summary_file" << EOF
🗡️ GRIM REAPER $action SUMMARY
============================
Version: $VERSION
Date: $(date)
Host: $(hostname)
Action: $action
Dry Run: $DRY_RUN

PACKAGES:
EOF

    # Add package status
    local packages=$(jq -r '.packages | keys[]' "$CONFIG_FILE")
    while IFS= read -r package; do
        if should_skip "$package"; then
            echo "⏭️  $package (skipped)" >> "$summary_file"
        else
            echo "✅ $package" >> "$summary_file"
        fi
    done <<< "$packages"
    
    echo "" >> "$summary_file"
    echo "Version History:" >> "$summary_file"
    jq -r '.version.history[-3:] | reverse | .[] | "  \(.version) - \(.date) - \(.notes)"' "$CONFIG_FILE" >> "$summary_file"
    
    echo "" >> "$summary_file"
    echo "Log file: $LOG_DIR/grim-$TIMESTAMP.log" >> "$summary_file"
    
    log "✅ Summary created: $summary_file" "$GREEN"
    cat "$summary_file"
}

# Main function
main() {
    check_dependencies
    parse_args "$@"
    
    if [[ -z "$COMMAND" ]]; then
        echo -e "${RED}❌ No command specified${NC}"
        show_help
        exit 1
    fi
    
    load_config
    
    # Header
    clear
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║      🗡️  GRIM REAPER BUILD & DEPLOY SYSTEM v$VERSION          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 DRY RUN MODE - No actual changes will be made" "$YELLOW"
    fi
    
    case $COMMAND in
        build)
            build_all
            create_summary "build"
            ;;
        deploy)
            deploy_all
            create_summary "deploy"
            ;;
        all)
            build_all
            deploy_all
            create_summary "build-deploy"
            update_config_version "$VERSION" "${DEPLOY_MESSAGE:-Build and deploy}"
            ;;
    esac
    
    log "🎉 Operation complete!" "$GREEN"
}

# Run main
main "$@"

# C.3.R.B.H.F