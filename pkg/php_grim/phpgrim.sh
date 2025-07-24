#!/bin/bash
# Grim Reaper PHP Package Build and Deployment Script
# Handles building, testing, and deploying to Packagist

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Auto-detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHP_GRIM_ROOT="$SCRIPT_DIR"

error() {
    echo -e "${RED}❌ $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Show help if no arguments
if [[ $# -eq 0 ]]; then
    echo -e "${CYAN}🗡️  Grim Reaper PHP Package Build & Deployment${NC}"
    echo "=================================================="
    echo ""
    echo "Usage: ./phpgrim.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  build                    Build the package"
    echo "  test                     Run tests"
    echo "  clean                    Clean build artifacts"
    echo "  validate                 Validate package structure"
    echo "  package                  Create distribution package"
    echo "  deploy                   Deploy to Packagist"
    echo "  release <version>        Create new release"
    echo "  install-deps             Install development dependencies"
    echo "  check-deps               Check all dependencies"
    echo "  doctor                   Diagnose build issues"
    echo "  help                     Show this help"
    echo ""
    echo "Examples:"
    echo "  ./phpgrim.sh build       # Build the package"
    echo "  ./phpgrim.sh test        # Run tests"
    echo "  ./phpgrim.sh release 1.0.0 # Create v1.0.0 release"
    echo "  ./phpgrim.sh deploy      # Deploy to Packagist"
    echo ""
    exit 0
fi

COMMAND="$1"
shift || true

# Check if we're in the right directory
check_environment() {
    if [[ ! -f "$PHP_GRIM_ROOT/composer.json" ]]; then
        error "composer.json not found. Please run this script from the php_grim directory."
    fi
    
    if [[ ! -d "$PHP_GRIM_ROOT/src" ]]; then
        error "src directory not found. Please run this script from the php_grim directory."
    fi
    
    success "Environment check passed"
}

# Install development dependencies
install_deps() {
    info "Installing development dependencies..."
    
    if ! command -v composer &> /dev/null; then
        error "Composer not found. Please install Composer first."
    fi
    
    cd "$PHP_GRIM_ROOT"
    composer install --dev
    
    success "Development dependencies installed"
}

# Check dependencies
check_deps() {
    info "Checking dependencies..."
    
    # Check PHP version
    PHP_VERSION=$(php -r "echo PHP_VERSION;")
    if [[ ! "$PHP_VERSION" =~ ^8\.[1-9] ]] && [[ ! "$PHP_VERSION" =~ ^[9-9] ]]; then
        error "PHP 8.1 or higher is required. Current version: $PHP_VERSION"
    fi
    success "PHP version: $PHP_VERSION"
    
    # Check required extensions
    REQUIRED_EXTENSIONS=("json" "curl" "openssl" "zip")
    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        if php -m | grep -q "^$ext$"; then
            success "PHP extension: $ext"
        else
            error "Required PHP extension not loaded: $ext"
        fi
    done
    
    # Check Composer
    if command -v composer &> /dev/null; then
        COMPOSER_VERSION=$(composer --version | awk '{print $3}')
        success "Composer version: $COMPOSER_VERSION"
    else
        error "Composer not found"
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | awk '{print $3}')
        success "Git version: $GIT_VERSION"
    else
        error "Git not found"
    fi
    
    success "All dependencies satisfied"
}

# Validate package structure
validate() {
    info "Validating package structure..."
    
    cd "$PHP_GRIM_ROOT"
    
    # Check required files
    REQUIRED_FILES=(
        "composer.json"
        "src/GrimCLI.php"
        "src/Installer.php"
        "bin/grim"
        "README_PHP.md"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            success "Found: $file"
        else
            error "Missing required file: $file"
        fi
    done
    
    # Validate composer.json
    if composer validate --no-check-all --no-check-publish; then
        success "composer.json is valid"
    else
        error "composer.json validation failed"
    fi
    
    # Check PSR-4 autoloading
    if composer dump-autoload --no-dev --optimize; then
        success "PSR-4 autoloading configured correctly"
    else
        error "PSR-4 autoloading configuration failed"
    fi
    
    # Check binary script
    if [[ -x "bin/grim" ]]; then
        success "Binary script is executable"
    else
        error "Binary script is not executable"
    fi
    
    success "Package structure validation passed"
}

# Run tests
test() {
    info "Running tests..."
    
    cd "$PHP_GRIM_ROOT"
    
    # Check if PHPUnit is available
    if [[ -f "vendor/bin/phpunit" ]]; then
        vendor/bin/phpunit
        success "Tests completed"
    else
        warning "PHPUnit not found. Run 'composer install --dev' first."
    fi
    
    # Run static analysis if available
    if [[ -f "vendor/bin/phpstan" ]]; then
        info "Running static analysis..."
        vendor/bin/phpstan analyse src tests --level=8
        success "Static analysis completed"
    else
        warning "PHPStan not found. Run 'composer install --dev' first."
    fi
}

# Build the package
build() {
    info "Building PHP Grim Reaper package..."
    
    check_environment
    check_deps
    validate
    
    cd "$PHP_GRIM_ROOT"
    
    # Clean previous builds
    if [[ -d "vendor" ]]; then
        composer dump-autoload --no-dev --optimize
    fi
    
    # Create build directory
    BUILD_DIR="$PHP_GRIM_ROOT/build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Copy files to build directory
    cp -r src bin composer.json README_PHP.md install_php_dependencies.sh "$BUILD_DIR/"
    
    # Create version file
    VERSION=$(php -r "echo json_decode(file_get_contents('composer.json'), true)['version'];")
    echo "$VERSION" > "$BUILD_DIR/VERSION"
    
    success "Package built successfully in $BUILD_DIR"
}

# Clean build artifacts
clean() {
    info "Cleaning build artifacts..."
    
    cd "$PHP_GRIM_ROOT"
    
    # Remove build directory
    if [[ -d "build" ]]; then
        rm -rf build
        success "Build directory removed"
    fi
    
    # Remove vendor directory
    if [[ -d "vendor" ]]; then
        rm -rf vendor
        success "Vendor directory removed"
    fi
    
    # Remove composer.lock
    if [[ -f "composer.lock" ]]; then
        rm composer.lock
        success "composer.lock removed"
    fi
    
    success "Clean completed"
}

# Create distribution package
package() {
    info "Creating distribution package..."
    
    # Build first
    build
    
    cd "$PHP_GRIM_ROOT"
    
    # Get version
    VERSION=$(php -r "echo json_decode(file_get_contents('composer.json'), true)['version'];")
    
    # Create archive
    PACKAGE_NAME="grim-reaper-php-$VERSION.tar.gz"
    tar -czf "$PACKAGE_NAME" -C build .
    
    success "Distribution package created: $PACKAGE_NAME"
}

# Create new release
release() {
    if [[ $# -eq 0 ]]; then
        error "Usage: ./phpgrim.sh release <version>"
    fi
    
    VERSION="$1"
    
    info "Creating release v$VERSION..."
    
    # Validate version format
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "Invalid version format. Use semantic versioning (e.g., 1.0.0)"
    fi
    
    cd "$PHP_GRIM_ROOT"
    
    # Check if we're in a git repository
    if [[ ! -d ".git" ]]; then
        error "Not in a git repository. Please initialize git first."
    fi
    
    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain)" ]]; then
        error "You have uncommitted changes. Please commit or stash them first."
    fi
    
    # Update version in composer.json
    sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" composer.json
    
    # Commit version change
    git add composer.json
    git commit -m "Bump version to $VERSION"
    
    # Create tag
    git tag -a "v$VERSION" -m "Release v$VERSION"
    
    # Push changes
    git push origin main
    git push origin "v$VERSION"
    
    success "Release v$VERSION created and pushed"
}

# Deploy to Packagist
deploy() {
    info "Deploying to Packagist..."
    
    # Check if we're in a git repository
    if [[ ! -d ".git" ]]; then
        error "Not in a git repository. Packagist requires a git repository."
    fi
    
    # Check if remote is configured
    if ! git remote get-url origin &> /dev/null; then
        error "Git remote 'origin' not configured. Please add your GitHub repository."
    fi
    
    # Get current version
    VERSION=$(php -r "echo json_decode(file_get_contents('composer.json'), true)['version'];")
    
    # Check if tag exists
    if ! git tag -l "v$VERSION" | grep -q "v$VERSION"; then
        error "Tag v$VERSION not found. Run './phpgrim.sh release $VERSION' first."
    fi
    
    info "Package is ready for Packagist deployment"
    info "Version: $VERSION"
    info "Repository: $(git remote get-url origin)"
    info ""
    info "To deploy to Packagist:"
    info "1. Go to https://packagist.org/"
    info "2. Submit your repository URL: $(git remote get-url origin)"
    info "3. Packagist will automatically detect releases"
    info ""
    info "Or use the Packagist API:"
    info "curl -X POST https://packagist.org/api/update-package?username=YOUR_USERNAME&apiToken=YOUR_TOKEN -d '{\"repository\":{\"url\":\"$(git remote get-url origin)\"}}'"
}

# Diagnose build issues
doctor() {
    echo -e "${CYAN}🏥 Grim Reaper PHP Package Doctor${NC}"
    echo "====================================="
    echo ""
    
    cd "$PHP_GRIM_ROOT"
    
    # Check environment
    echo "🔍 Environment Check:"
    if [[ -f "composer.json" ]]; then
        success "composer.json found"
    else
        error "composer.json missing"
    fi
    
    if [[ -d "src" ]]; then
        success "src directory found"
    else
        error "src directory missing"
    fi
    
    if [[ -d "bin" ]]; then
        success "bin directory found"
    else
        error "bin directory missing"
    fi
    
    echo ""
    
    # Check dependencies
    echo "📦 Dependency Check:"
    check_deps
    
    echo ""
    
    # Check Git status
    echo "🔧 Git Status:"
    if [[ -d ".git" ]]; then
        success "Git repository initialized"
        
        if git remote get-url origin &> /dev/null; then
            success "Remote origin configured: $(git remote get-url origin)"
        else
            warning "Remote origin not configured"
        fi
        
        if [[ -n "$(git status --porcelain)" ]]; then
            warning "Uncommitted changes detected"
        else
            success "Working directory clean"
        fi
    else
        warning "Not in a Git repository"
    fi
    
    echo ""
    
    # Check Packagist readiness
    echo "📤 Packagist Readiness:"
    if [[ -f "composer.json" ]]; then
        if composer validate --no-check-all --no-check-publish &> /dev/null; then
            success "composer.json is valid"
        else
            error "composer.json has issues"
        fi
        
        VERSION=$(php -r "echo json_decode(file_get_contents('composer.json'), true)['version'];")
        success "Current version: $VERSION"
    fi
    
    echo ""
    echo "💡 Run './phpgrim.sh help' for available commands"
}

# Main command router
case "$COMMAND" in
    build)
        build
        ;;
    test)
        test
        ;;
    clean)
        clean
        ;;
    validate)
        validate
        ;;
    package)
        package
        ;;
    deploy)
        deploy
        ;;
    release)
        release "$@"
        ;;
    install-deps)
        install_deps
        ;;
    check-deps)
        check_deps
        ;;
    doctor)
        doctor
        ;;
    help)
        # Help is shown at the beginning
        ;;
    *)
        error "Unknown command: $COMMAND\nRun './phpgrim.sh help' for available commands"
        ;;
esac 