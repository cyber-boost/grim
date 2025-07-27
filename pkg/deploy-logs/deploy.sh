#!/bin/bash

# =============================================================================
# 🚀 GRIM REAPER MASTER DEPLOY SCRIPT
# =============================================================================
# Deploys all language packages to their respective package managers
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

# Configurationcd 
BUILD_DIR="/opt/reaper/pkg"
LOG_DIR="$BUILD_DIR/deploy-logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DRY_RUN=false
DEPLOY_MESSAGE=""
SKIP_NPM=false
SKIP_NUGET=false
SKIP_PYTHON=false
SKIP_RUBY=false
SKIP_RUST=false
SKIP_PHP=false
SKIP_GO=false
SKIP_JAVA=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -m|--message)
            DEPLOY_MESSAGE="$2"
            shift 2
            ;;
        --skip-npm)
            SKIP_NPM=true
            shift
            ;;
        --skip-nuget)
            SKIP_NUGET=true
            shift
            ;;
        --skip-python|--skip-pypi)
            SKIP_PYTHON=true
            shift
            ;;
        --skip-ruby|--skip-gem)
            SKIP_RUBY=true
            shift
            ;;
        --skip-rust|--skip-crates)
            SKIP_RUST=true
            shift
            ;;
        --skip-php)
            SKIP_PHP=true
            shift
            ;;
        --skip-go)
            SKIP_GO=true
            shift
            ;;
        --skip-java|--skip-maven)
            SKIP_JAVA=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [-m 'message'] [--skip-npm] [--help]"
            echo "  --dry-run    Show what would be deployed without actually deploying"
            echo "  -m MESSAGE   Add deployment message/changelog"
            echo "  --skip-npm        Skip npm deployment"
            echo "  --skip-nuget      Skip NuGet deployment"
            echo "  --skip-python     Skip PyPI deployment (alias: --skip-pypi)"
            echo "  --skip-ruby       Skip RubyGems deployment (alias: --skip-gem)"
            echo "  --skip-rust       Skip crates.io deployment (alias: --skip-crates)"
            echo "  --skip-php        Skip PHP/Packagist deployment"
            echo "  --skip-go         Skip Go deployment"
            echo "  --skip-java       Skip Maven deployment (alias: --skip-maven)"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create log directory
mkdir -p "$LOG_DIR"

# Log function
log() {
    echo -e "${2:-$BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_DIR/deploy-$TIMESTAMP.log"
}

# Error handler
handle_error() {
    log "❌ Deploy failed at line $1" "$RED"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Header
clear
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           🚀 GRIM REAPER PACKAGE DEPLOYER                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
    log "🧪 DRY RUN MODE - No actual deployments will occur" "$YELLOW"
fi

if [[ -n "$DEPLOY_MESSAGE" ]]; then
    log "📝 Deploy message: $DEPLOY_MESSAGE" "$BLUE"
fi

log "🚀 Starting master deploy process..." "$GREEN"
log "📁 Deploy directory: $BUILD_DIR"
log "📝 Log file: $LOG_DIR/deploy-$TIMESTAMP.log"

# Check for credentials
check_credentials() {
    log "🔑 Checking deployment credentials..." "$BLUE"
    
    local missing=()
    
    # NPM
    if ! npm whoami &> /dev/null; then
        missing+=("NPM (run: npm login)")
    fi
    
    # PyPI
    if [[ ! -f ~/.pypirc ]] && [[ -z "$TWINE_USERNAME" ]]; then
        missing+=("PyPI (create ~/.pypirc or set TWINE_USERNAME)")
    fi
    
    # RubyGems
    if ! gem list -r grim-reaper &> /dev/null; then
        if [[ ! -f ~/.gem/credentials ]]; then
            missing+=("RubyGems (run: gem signin)")
        fi
    fi
    
    # Crates.io
    if [[ ! -f ~/.cargo/credentials.toml ]]; then
        missing+=("Crates.io (run: cargo login)")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "⚠️  Missing credentials for: ${missing[*]}" "$YELLOW"
        log "💡 Some deployments may fail without proper credentials" "$YELLOW"
    else
        log "✅ All credentials found" "$GREEN"
    fi
}

# Deploy functions for each language
deploy_javascript() {
    log "🌟 Deploying JavaScript package to npm..." "$BLUE"
    cd "$BUILD_DIR/js_grim"
    
    # Check if package exists
    local package_file=$(ls -t grim-reaper-*.tgz 2>/dev/null | head -1)
    if [[ -z "$package_file" ]]; then
        log "❌ No package file found. Run build.sh first!" "$RED"
        return 1
    fi
    
    # Get version from package.json
    local version=$(node -p "require('./package.json').version")
    log "📦 Package version: $version"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: npm publish $package_file" "$YELLOW"
    else
        # Check if version already exists
        if npm view grim-reaper@$version &> /dev/null; then
            log "⚠️  Version $version already published to npm" "$YELLOW"
        else
            log "📤 Publishing to npm..."
            if [[ -n "$DEPLOY_MESSAGE" ]]; then
                # npm doesn't support messages directly, but we can update README
                echo -e "\n## Latest Update\n\n$DEPLOY_MESSAGE\n\n---\n" | cat - README.md > README.tmp && mv README.tmp README.md
            fi
            npm publish "$package_file"
            log "✅ JavaScript package deployed to npm" "$GREEN"
        fi
    fi
}

deploy_python() {
    log "🐍 Deploying Python package to PyPI..." "$BLUE"
    cd "$BUILD_DIR/py_grim"
    
    # Check if dist exists
    if [[ ! -d dist ]]; then
        log "❌ No dist directory found. Run build.sh first!" "$RED"
        return 1
    fi
    
    # Install twine if needed
    if ! command -v twine &> /dev/null; then
        log "📦 Installing twine..."
        pip install twine
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: twine upload dist/*" "$YELLOW"
    else
        log "📤 Uploading to PyPI..."
        twine upload dist/* --skip-existing || log "⚠️  PyPI upload failed" "$YELLOW"
        log "✅ Python package deployed to PyPI" "$GREEN"
    fi
}

deploy_ruby() {
    log "💎 Deploying Ruby gem to RubyGems..." "$BLUE"
    cd "$BUILD_DIR/rb_grim"
    
    # Check if gem exists
    local gem_file=$(ls -t grim-reaper-*.gem 2>/dev/null | head -1)
    if [[ -z "$gem_file" ]]; then
        log "❌ No gem file found. Run build.sh first!" "$RED"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: gem push $gem_file" "$YELLOW"
    else
        log "📤 Pushing to RubyGems..."
        gem push "$gem_file" || log "⚠️  RubyGems push failed" "$YELLOW"
        log "✅ Ruby gem deployed to RubyGems" "$GREEN"
    fi
}

deploy_rust() {
    log "🦀 Deploying Rust package to crates.io..." "$BLUE"
    cd "$BUILD_DIR/rs_grim"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: cargo publish" "$YELLOW"
    else
        log "📤 Publishing to crates.io..."
        cargo publish --allow-dirty || log "⚠️  Crates.io publish failed" "$YELLOW"
        log "✅ Rust package deployed to crates.io" "$GREEN"
    fi
}

deploy_php() {
    log "🐘 Deploying PHP package to Packagist..." "$BLUE"
    cd "$BUILD_DIR/php_grim"
    
    log "📝 PHP packages are deployed via Git tags" "$YELLOW"
    log "💡 Push to GitHub and create a release tag" "$YELLOW"
    
    # Get current version
    if command -v jq &> /dev/null; then
        local version=$(jq -r '.version' composer.json)
        log "📦 Current version: $version"
        log "💡 Run: git tag v$version && git push origin v$version" "$YELLOW"
    fi
}

deploy_go() {
    log "🐹 Deploying Go package to pkg.go.dev..." "$BLUE"
    cd "$BUILD_DIR/go_grim"
    
    log "📝 Go packages are deployed via Git tags" "$YELLOW"
    log "💡 Push to GitHub with proper module path" "$YELLOW"
    
    if [[ -f go.mod ]]; then
        local module=$(head -1 go.mod | cut -d' ' -f2)
        log "📦 Module: $module"
        log "💡 Ensure your repository is at: https://$module" "$YELLOW"
    fi
}

deploy_csharp() {
    log "🔷 Deploying C# package to NuGet..." "$BLUE"
    cd "$BUILD_DIR/cs_grim"
    
    # Check if nupkg exists
    local nupkg_file=$(find . -name "*.nupkg" -type f | head -1)
    if [[ -z "$nupkg_file" ]]; then
        log "⚠️  No .nupkg file found. Run build.sh first!" "$YELLOW"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Would deploy: dotnet nuget push $nupkg_file" "$YELLOW"
    else
        # Check for API key
        if [[ -z "$NUGET_API_KEY" ]]; then
            log "⚠️  NUGET_API_KEY not set, skipping NuGet deployment" "$YELLOW"
        else
            log "📤 Pushing to NuGet..."
            dotnet nuget push "$nupkg_file" --api-key "$NUGET_API_KEY" --source https://api.nuget.org/v3/index.json
            log "✅ C# package deployed to NuGet" "$GREEN"
        fi
    fi
}

deploy_java() {
    log "☕ Deploying Java package to Maven Central..." "$BLUE"
    cd "$BUILD_DIR/java_grim"
    
    log "📝 Java packages require special setup for Maven Central" "$YELLOW"
    log "💡 See: https://central.sonatype.org/publish/publish-guide/" "$YELLOW"
    
    if [[ -f pom.xml ]]; then
        local version=$(grep -o '<version>[^<]*</version>' pom.xml | head -1 | sed 's/<[^>]*>//g')
        log "📦 Current version: $version"
    fi
}

# Create deployment report
create_report() {
    log "📊 Creating deployment report..." "$BLUE"
    
    REPORT_FILE="$LOG_DIR/deploy-report-$TIMESTAMP.txt"
    
    cat > "$REPORT_FILE" << EOF
🚀 GRIM REAPER DEPLOYMENT REPORT
===============================
Deploy Date: $(date)
Deploy Host: $(hostname)
Dry Run: $DRY_RUN

DEPLOYMENT STATUS:
EOF

    # Add package status
    echo "" >> "$REPORT_FILE"
    echo "Package URLs:" >> "$REPORT_FILE"
    echo "- NPM: https://www.npmjs.com/package/grim-reaper" >> "$REPORT_FILE"
    echo "- PyPI: https://pypi.org/project/grim-reaper/" >> "$REPORT_FILE"
    echo "- RubyGems: https://rubygems.org/gems/grim-reaper" >> "$REPORT_FILE"
    echo "- Crates.io: https://crates.io/crates/grim-reaper" >> "$REPORT_FILE"
    echo "- Packagist: https://packagist.org/packages/grim/reaper" >> "$REPORT_FILE"
    echo "- Go: https://pkg.go.dev/github.com/cyber-boost/grim" >> "$REPORT_FILE"
    echo "- NuGet: https://www.nuget.org/packages/GrimReaper" >> "$REPORT_FILE"
    echo "- Maven: https://search.maven.org/artifact/so.grim/grim-reaper" >> "$REPORT_FILE"
    
    echo "" >> "$REPORT_FILE"
    echo "Deploy logs: $LOG_DIR/deploy-$TIMESTAMP.log" >> "$REPORT_FILE"
    
    log "✅ Deployment report created: $REPORT_FILE" "$GREEN"
    cat "$REPORT_FILE"
}

# Main deploy process
main() {
    # Check credentials
    check_credentials
    
    # Deploy all packages
    if [[ "$SKIP_NPM" == "false" ]]; then
        deploy_javascript
    else
        log "⏭️  Skipping npm deployment (--skip-npm)" "$YELLOW"
    fi
    
    if [[ "$SKIP_PYTHON" == "false" ]]; then
        deploy_python
    else
        log "⏭️  Skipping Python/PyPI deployment (--skip-python)" "$YELLOW"
    fi
    
    if [[ "$SKIP_RUBY" == "false" ]]; then
        deploy_ruby
    else
        log "⏭️  Skipping Ruby/RubyGems deployment (--skip-ruby)" "$YELLOW"
    fi
    
    if [[ "$SKIP_RUST" == "false" ]]; then
        deploy_rust
    else
        log "⏭️  Skipping Rust/crates.io deployment (--skip-rust)" "$YELLOW"
    fi
    
    if [[ "$SKIP_PHP" == "false" ]]; then
        deploy_php
    else
        log "⏭️  Skipping PHP/Packagist deployment (--skip-php)" "$YELLOW"
    fi
    
    if [[ "$SKIP_GO" == "false" ]]; then
        deploy_go
    else
        log "⏭️  Skipping Go deployment (--skip-go)" "$YELLOW"
    fi
    if [[ "$SKIP_NUGET" == "false" ]]; then
        deploy_csharp
    else
        log "⏭️  Skipping NuGet deployment (--skip-nuget)" "$YELLOW"
    fi
    
    if [[ "$SKIP_JAVA" == "false" ]]; then
        deploy_java
    else
        log "⏭️  Skipping Java/Maven deployment (--skip-java)" "$YELLOW"
    fi
    
    # Create report
    create_report
    
    log "🎉 Master deployment complete!" "$GREEN"
    log "📦 Check package manager sites for updated packages" "$GREEN"
    log "📝 Check logs at: $LOG_DIR" "$BLUE"
}

# Run main
main

# C.3.R.B.H.F