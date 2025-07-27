#!/bin/bash

# Grim Packager - Version Management and Distribution Infrastructure
# Handles automated builds, versioning, packaging, and distribution

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/packager.log"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Packager Configuration
PACKAGE_VERSION="${PACKAGE_VERSION:-1.0.0}"
BUILD_DIR="${BUILD_DIR:-$GRIM_ROOT/build}"
DIST_DIR="${DIST_DIR:-$GRIM_ROOT/dist}"
REPO_URL="${REPO_URL:-https://github.com/grim-project/grim}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-grim.registry.io}"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Packager - Version Management and Distribution"
    echo "Usage: packager.sh <command> [options]"
    echo ""
    echo "Purpose: Automated builds, versioning, packaging, and distribution"
    echo "         infrastructure for the Grimm system."
    echo ""
    echo "Commands:"
    echo "  init                    - Initialize packaging system"
    echo "  build [target]          - Build package for target platform"
    echo "  package [type]          - Create distribution package"
    echo "  version [action]        - Version management operations"
    echo "  release [version]       - Create and publish release"
    echo "  deploy [environment]    - Deploy to target environment"
    echo "  docker [action]         - Docker container operations"
    echo "  test [suite]            - Run package tests"
    echo "  clean                   - Clean build artifacts"
    echo "  help, -h, --help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./packager.sh init"
    echo "  ./packager.sh build linux"
    echo "  ./packager.sh package tar.gz"
    echo "  ./packager.sh version bump minor"
    echo "  ./packager.sh release 1.2.0"
    echo "  ./packager.sh help"
}

# Initialize packaging system
init_packager() {
    echo -e "${CYAN}=== Initializing Packaging System ===${NC}"
    
    # Create necessary directories
    mkdir -p "$BUILD_DIR" "$DIST_DIR" "$GRIM_ROOT/logs" "$GRIM_ROOT/db"
    
    # Initialize packaging database
    init_packager_db
    
    # Create default configuration
    create_packager_config
    
    # Set up build environment
    setup_build_environment
    
    log "Packaging system initialized"
    "$NOTIFY_MODULE" send success "Packager Initialized" "Packaging system ready" "{\"version\": \"$PACKAGE_VERSION\", \"build_dir\": \"$BUILD_DIR\"}"
    
    echo -e "${GREEN}✅ Packaging system initialized${NC}"
    echo "Build Directory: $BUILD_DIR"
    echo "Distribution Directory: $DIST_DIR"
    echo "Version: $PACKAGE_VERSION"
}

# Initialize packaging database
init_packager_db() {
    sqlite3 "$DB_PATH" <<EOF
-- Package builds tracking
CREATE TABLE IF NOT EXISTS package_builds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL,
    platform TEXT NOT NULL,
    architecture TEXT NOT NULL,
    build_type TEXT DEFAULT 'release',
    status TEXT DEFAULT 'pending',
    build_start TIMESTAMP,
    build_end TIMESTAMP,
    build_duration INTEGER,
    artifacts TEXT,
    checksum TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Package releases
CREATE TABLE IF NOT EXISTS package_releases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL UNIQUE,
    release_type TEXT DEFAULT 'stable',
    release_notes TEXT,
    changelog TEXT,
    artifacts_count INTEGER DEFAULT 0,
    download_count INTEGER DEFAULT 0,
    published_at TIMESTAMP,
    published_by TEXT,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Distribution targets
CREATE TABLE IF NOT EXISTS distribution_targets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    url TEXT,
    credentials TEXT,
    status TEXT DEFAULT 'active',
    last_sync TIMESTAMP,
    sync_status TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Docker images
CREATE TABLE IF NOT EXISTS docker_images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    tag TEXT NOT NULL,
    registry TEXT,
    size INTEGER,
    layers INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pushed_at TIMESTAMP,
    status TEXT DEFAULT 'local'
);

-- Version history
CREATE TABLE IF NOT EXISTS version_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL,
    change_type TEXT NOT NULL,
    description TEXT,
    author TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Build dependencies
CREATE TABLE IF NOT EXISTS build_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    type TEXT NOT NULL,
    source TEXT,
    required BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_builds_version ON package_builds(version);
CREATE INDEX IF NOT EXISTS idx_builds_platform ON package_builds(platform);
CREATE INDEX IF NOT EXISTS idx_releases_version ON package_releases(version);
CREATE INDEX IF NOT EXISTS idx_docker_name_tag ON docker_images(name, tag);
CREATE INDEX IF NOT EXISTS idx_version_history_version ON version_history(version);
EOF
    
    log "Packaging database initialized"
}

# Create default packager configuration
create_packager_config() {
    local config_file="$GRIM_ROOT/config/packager.tsk"
    
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" <<EOF
# Grim Packager Configuration
package:
  name: "grim"
  version: "$PACKAGE_VERSION"
  description: "Grimm Reaper - The Intelligent Backup System"
  author: "Grim Project"
  license: "MIT"
  homepage: "$REPO_URL"

build:
  directory: "$BUILD_DIR"
  distribution: "$DIST_DIR"
  platforms:
    - linux
    - macos
    - windows
  architectures:
    - x86_64
    - arm64
    - armv7

versioning:
  scheme: "semver"
  auto_bump: true
  changelog: true
  git_tags: true

packaging:
  formats:
    - tar.gz
    - zip
    - deb
    - rpm
    - docker
  compression: true
  signing: false
  checksums: true

distribution:
  targets:
    - name: "github"
      type: "github_release"
      url: "$REPO_URL"
    - name: "docker_hub"
      type: "docker_registry"
      url: "$DOCKER_REGISTRY"
    - name: "package_registry"
      type: "package_registry"
      url: "https://packages.grim.so"

docker:
  registry: "$DOCKER_REGISTRY"
  base_image: "alpine:latest"
  multi_arch: true
  security_scan: true

testing:
  unit_tests: true
  integration_tests: true
  security_tests: true
  performance_tests: false

notifications:
  build_success: true
  build_failure: true
  release_published: true
  deployment_complete: true
EOF
        log "Created packager configuration: $config_file"
    fi
}

# Set up build environment
setup_build_environment() {
    # Install build dependencies
    local dependencies=(
        "build-essential"
        "cmake"
        "ninja-build"
        "pkg-config"
        "libssl-dev"
        "libsqlite3-dev"
        "curl"
        "wget"
        "git"
        "docker.io"
    )
    
    echo "Installing build dependencies..."
    for dep in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii  $dep "; then
            echo "Installing $dep..."
            apt-get update && apt-get install -y "$dep"
        fi
    done
    
    # Create build scripts
    create_build_scripts
    
    log "Build environment setup complete"
}

# Create build scripts
create_build_scripts() {
    # Main build script
    cat > "$BUILD_DIR/build.sh" <<'EOF'
#!/bin/bash
# Grim Build Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR"
DIST_DIR="$GRIM_ROOT/dist"

# Build configuration
PLATFORM="${1:-linux}"
ARCH="${2:-x86_64}"
BUILD_TYPE="${3:-release}"
VERSION="${4:-$(cat "$GRIM_ROOT/VERSION" 2>/dev/null || echo "1.0.0")}"

echo "Building Grim $VERSION for $PLATFORM-$ARCH ($BUILD_TYPE)"

# Create build directory
BUILD_PATH="$BUILD_DIR/$PLATFORM-$ARCH"
mkdir -p "$BUILD_PATH"

# Copy source files
echo "Copying source files..."
cp -r "$GRIM_ROOT/modules" "$BUILD_PATH/"
cp -r "$GRIM_ROOT/bin" "$BUILD_PATH/"
cp -r "$GRIM_ROOT/config" "$BUILD_PATH/"
cp "$GRIM_ROOT/reaper.sh" "$BUILD_PATH/"
cp "$GRIM_ROOT/README.md" "$BUILD_PATH/"

# Create directories
mkdir -p "$BUILD_PATH/db" "$BUILD_PATH/logs" "$BUILD_PATH/licenses"

# Set permissions
chmod +x "$BUILD_PATH/reaper.sh"
find "$BUILD_PATH/bin" -name "*.sh" -exec chmod +x {} \;
find "$BUILD_PATH/modules" -name "*.sh" -exec chmod +x {} \;

# Create version file
echo "$VERSION" > "$BUILD_PATH/VERSION"

# Create package manifest
cat > "$BUILD_PATH/MANIFEST" <<MANIFEST
Package: grim
Version: $VERSION
Platform: $PLATFORM
Architecture: $ARCH
BuildType: $BUILD_TYPE
BuildDate: $(date -u +%Y-%m-%dT%H:%M:%SZ)
GitCommit: $(git rev-parse HEAD 2>/dev/null || echo "unknown")
MANIFEST

echo "Build complete: $BUILD_PATH"
EOF
    
    chmod +x "$BUILD_DIR/build.sh"
    
    # Docker build script
    cat > "$BUILD_DIR/docker-build.sh" <<'EOF'
#!/bin/bash
# Grim Docker Build Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${1:-$(cat "$GRIM_ROOT/VERSION" 2>/dev/null || echo "1.0.0")}"
REGISTRY="${2:-grim.registry.io}"

echo "Building Docker image for Grim $VERSION"

# Create Dockerfile
cat > "$GRIM_ROOT/Dockerfile" <<DOCKERFILE
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \\
    bash \\
    sqlite \\
    curl \\
    wget \\
    git \\
    ca-certificates

# Create grim user
RUN addgroup -g 1000 grim && \\
    adduser -D -s /bin/bash -u 1000 -G grim grim

# Copy application
COPY --chown=grim:grim . /opt/grim/
WORKDIR /opt/grim

# Set permissions
RUN chmod +x /opt/grim/reaper.sh && \\
    find /opt/grim/bin -name "*.sh" -exec chmod +x {} \; && \\
    find /opt/grim/modules -name "*.sh" -exec chmod +x {} \;

# Create necessary directories
RUN mkdir -p /opt/grim/db /opt/grim/logs /opt/grim/licenses && \\
    chown -R grim:grim /opt/grim

# Switch to grim user
USER grim

# Expose ports
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:8080/health || exit 1

# Default command
ENTRYPOINT ["/opt/grim/reaper.sh"]
CMD ["help"]
DOCKERFILE

# Build image
docker build -t "$REGISTRY/grim:$VERSION" "$GRIM_ROOT"
docker tag "$REGISTRY/grim:$VERSION" "$REGISTRY/grim:latest"

echo "Docker image built: $REGISTRY/grim:$VERSION"
EOF
    
    chmod +x "$BUILD_DIR/docker-build.sh"
    
    log "Build scripts created"
}

# Build package for target platform
build_package() {
    local target="${1:-linux}"
    local arch="${2:-x86_64}"
    local build_type="${3:-release}"
    
    echo -e "${CYAN}=== Building Package ===${NC}"
    echo "Target: $target"
    echo "Architecture: $arch"
    echo "Build Type: $build_type"
    echo "Version: $PACKAGE_VERSION"
    
    # Record build start
    local build_id=$(sqlite3 "$DB_PATH" <<EOF
INSERT INTO package_builds (version, platform, architecture, build_type, status, build_start)
VALUES ('$PACKAGE_VERSION', '$target', '$arch', '$build_type', 'building', CURRENT_TIMESTAMP);
SELECT last_insert_rowid();
EOF
)
    
    local start_time=$(date +%s)
    
    # Execute build
    if "$BUILD_DIR/build.sh" "$target" "$arch" "$build_type" "$PACKAGE_VERSION"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Calculate checksum
        local build_path="$BUILD_DIR/$target-$arch"
        local checksum=$(find "$build_path" -type f -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1)
        
        # Update build record
        sqlite3 "$DB_PATH" <<EOF
UPDATE package_builds 
SET status = 'completed', 
    build_end = CURRENT_TIMESTAMP, 
    build_duration = $duration,
    artifacts = '$build_path',
    checksum = '$checksum'
WHERE id = $build_id;
EOF
        
        log "Package build completed successfully"
        "$NOTIFY_MODULE" send success "Build Complete" "Package built for $target-$arch" "{\"version\": \"$PACKAGE_VERSION\", \"platform\": \"$target\", \"architecture\": \"$arch\", \"duration\": \"$duration\"}"
        
        echo -e "${GREEN}✅ Package built successfully${NC}"
        echo "Build Path: $build_path"
        echo "Duration: ${duration}s"
        echo "Checksum: $checksum"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Update build record
        sqlite3 "$DB_PATH" <<EOF
UPDATE package_builds 
SET status = 'failed', 
    build_end = CURRENT_TIMESTAMP, 
    build_duration = $duration
WHERE id = $build_id;
EOF
        
        log_error "Package build failed"
        "$NOTIFY_MODULE" send error "Build Failed" "Package build failed for $target-$arch" "{\"version\": \"$PACKAGE_VERSION\", \"platform\": \"$target\", \"architecture\": \"$arch\"}"
        
        echo -e "${RED}❌ Package build failed${NC}"
        return 1
    fi
}

# Create distribution package
create_package() {
    local package_type="${1:-tar.gz}"
    local target="${2:-linux}"
    local arch="${3:-x86_64}"
    
    echo -e "${CYAN}=== Creating Distribution Package ===${NC}"
    echo "Type: $package_type"
    echo "Target: $target-$arch"
    echo "Version: $PACKAGE_VERSION"
    
    local build_path="$BUILD_DIR/$target-$arch"
    if [ ! -d "$build_path" ]; then
        echo -e "${RED}❌ Build not found: $build_path${NC}"
        return 1
    fi
    
    local package_name="grim-$PACKAGE_VERSION-$target-$arch.$package_type"
    local package_path="$DIST_DIR/$package_name"
    
    # Create distribution directory
    mkdir -p "$DIST_DIR"
    
    # Create package based on type
    case "$package_type" in
        tar.gz)
            tar -czf "$package_path" -C "$build_path" .
            ;;
        zip)
            cd "$build_path" && zip -r "$package_path" .
            ;;
        deb)
            create_deb_package "$build_path" "$package_path"
            ;;
        rpm)
            create_rpm_package "$build_path" "$package_path"
            ;;
        docker)
            create_docker_package "$build_path" "$package_path"
            ;;
        *)
            echo -e "${RED}❌ Unknown package type: $package_type${NC}"
            return 1
            ;;
    esac
    
    # Calculate checksum
    local checksum=$(sha256sum "$package_path" | cut -d' ' -f1)
    
    # Create checksum file
    echo "$checksum  $package_name" > "$package_path.sha256"
    
    log "Distribution package created: $package_name"
    "$NOTIFY_MODULE" send success "Package Created" "Distribution package created" "{\"package\": \"$package_name\", \"type\": \"$package_type\", \"checksum\": \"$checksum\"}"
    
    echo -e "${GREEN}✅ Distribution package created${NC}"
    echo "Package: $package_path"
    echo "Size: $(du -h "$package_path" | cut -f1)"
    echo "Checksum: $checksum"
}

# Create DEB package
create_deb_package() {
    local build_path="$1"
    local package_path="$2"
    
    # Create DEB structure
    local deb_dir="$BUILD_DIR/deb"
    mkdir -p "$deb_dir/DEBIAN" "$deb_dir/opt/grim"
    
    # Copy files
    cp -r "$build_path"/* "$deb_dir/opt/grim/"
    
    # Create control file
    cat > "$deb_dir/DEBIAN/control" <<EOF
Package: grim
Version: $PACKAGE_VERSION
Architecture: amd64
Maintainer: Grim Project <grim@project.com>
Depends: bash, sqlite3, curl, wget
Description: Grimm Reaper - The Intelligent Backup System
 A comprehensive backup and system management solution
 with advanced monitoring and automation capabilities.
EOF
    
    # Create postinst script
    cat > "$deb_dir/DEBIAN/postinst" <<EOF
#!/bin/bash
chmod +x /opt/grim/reaper.sh
update-alternatives --install /usr/bin/grim grim /opt/grim/reaper.sh 100
EOF
    chmod +x "$deb_dir/DEBIAN/postinst"
    
    # Build DEB
    dpkg-deb --build "$deb_dir" "$package_path"
}

# Create RPM package
create_rpm_package() {
    local build_path="$1"
    local package_path="$2"
    
    # Create RPM structure
    local rpm_dir="$BUILD_DIR/rpm"
    mkdir -p "$rpm_dir/BUILD" "$rpm_dir/RPMS" "$rpm_dir/SOURCES" "$rpm_dir/SPECS"
    
    # Copy files
    cp -r "$build_path" "$rpm_dir/BUILD/grim-$PACKAGE_VERSION"
    
    # Create spec file
    cat > "$rpm_dir/SPECS/grim.spec" <<EOF
Name: grim
Version: $PACKAGE_VERSION
Release: 1%{?dist}
Summary: Grimm Reaper - The Intelligent Backup System
License: MIT
URL: $REPO_URL
Source0: %{name}-%{version}.tar.gz
BuildArch: x86_64

%description
A comprehensive backup and system management solution
with advanced monitoring and automation capabilities.

%files
%defattr(-,root,root,-)
/opt/grim/

%post
chmod +x /opt/grim/reaper.sh

%changelog
* $(date '+%a %b %d %Y') Grim Project <grim@project.com> - $PACKAGE_VERSION
- Initial package release
EOF
    
    # Build RPM
    rpmbuild --define "_topdir $rpm_dir" -bb "$rpm_dir/SPECS/grim.spec"
    
    # Copy result
    cp "$rpm_dir/RPMS/x86_64/grim-$PACKAGE_VERSION-1.*.rpm" "$package_path"
}

# Create Docker package
create_docker_package() {
    local build_path="$1"
    local package_path="$2"
    
    # Build Docker image
    "$BUILD_DIR/docker-build.sh" "$PACKAGE_VERSION" "$DOCKER_REGISTRY"
    
    # Save image to file
    docker save "$DOCKER_REGISTRY/grim:$PACKAGE_VERSION" | gzip > "$package_path"
    
    # Record Docker image
    local image_size=$(docker images "$DOCKER_REGISTRY/grim:$PACKAGE_VERSION" --format "{{.Size}}" | sed 's/[^0-9]//g')
    local layers=$(docker history "$DOCKER_REGISTRY/grim:$PACKAGE_VERSION" | wc -l)
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO docker_images (name, tag, registry, size, layers, status)
VALUES ('grim', '$PACKAGE_VERSION', '$DOCKER_REGISTRY', $image_size, $layers, 'local');
EOF
}

# Version management operations
manage_version() {
    local action="$1"
    local component="${2:-patch}"
    
    case "$action" in
        bump)
            bump_version "$component"
            ;;
        set)
            set_version "$component"
            ;;
        show)
            show_version
            ;;
        history)
            show_version_history
            ;;
        *)
            echo "Usage: packager.sh version bump|set|show|history"
            exit 1
            ;;
    esac
}

# Bump version
bump_version() {
    local component="$1"
    local current_version=$(cat "$GRIM_ROOT/VERSION" 2>/dev/null || echo "1.0.0")
    
    echo -e "${CYAN}=== Bumping Version ===${NC}"
    echo "Current Version: $current_version"
    echo "Component: $component"
    
    # Parse current version
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Bump appropriate component
    case "$component" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}❌ Invalid component: $component${NC}"
            return 1
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    
    # Update version file
    echo "$new_version" > "$GRIM_ROOT/VERSION"
    
    # Update PACKAGE_VERSION
    PACKAGE_VERSION="$new_version"
    
    # Record version change
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO version_history (version, change_type, description, author)
VALUES ('$new_version', 'bump_$component', 'Version bumped from $current_version to $new_version', 'packager');
EOF
    
    log "Version bumped from $current_version to $new_version"
    "$NOTIFY_MODULE" send info "Version Bumped" "Version bumped to $new_version" "{\"old_version\": \"$current_version\", \"new_version\": \"$new_version\", \"component\": \"$component\"}"
    
    echo -e "${GREEN}✅ Version bumped to $new_version${NC}"
}

# Set specific version
set_version() {
    local new_version="$1"
    
    if [ -z "$new_version" ]; then
        echo -e "${RED}❌ Version is required${NC}"
        return 1
    fi
    
    local current_version=$(cat "$GRIM_ROOT/VERSION" 2>/dev/null || echo "1.0.0")
    
    echo -e "${CYAN}=== Setting Version ===${NC}"
    echo "Current Version: $current_version"
    echo "New Version: $new_version"
    
    # Update version file
    echo "$new_version" > "$GRIM_ROOT/VERSION"
    
    # Update PACKAGE_VERSION
    PACKAGE_VERSION="$new_version"
    
    # Record version change
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO version_history (version, change_type, description, author)
VALUES ('$new_version', 'set', 'Version set from $current_version to $new_version', 'packager');
EOF
    
    log "Version set from $current_version to $new_version"
    "$NOTIFY_MODULE" send info "Version Set" "Version set to $new_version" "{\"old_version\": \"$current_version\", \"new_version\": \"$new_version\"}"
    
    echo -e "${GREEN}✅ Version set to $new_version${NC}"
}

# Show current version
show_version() {
    local version=$(cat "$GRIM_ROOT/VERSION" 2>/dev/null || echo "1.0.0")
    echo -e "${CYAN}=== Current Version ===${NC}"
    echo "Version: $version"
    
    # Show recent builds
    echo ""
    echo "Recent Builds:"
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT version, platform, architecture, status, build_start
FROM package_builds 
ORDER BY build_start DESC 
LIMIT 5;
EOF
}

# Show version history
show_version_history() {
    echo -e "${CYAN}=== Version History ===${NC}"
    
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT version, change_type, description, timestamp
FROM version_history 
ORDER BY timestamp DESC;
EOF
}

# Create and publish release
create_release() {
    local version="${1:-$PACKAGE_VERSION}"
    local release_type="${2:-stable}"
    
    echo -e "${CYAN}=== Creating Release ===${NC}"
    echo "Version: $version"
    echo "Type: $release_type"
    
    # Check if version exists
    if [ ! -f "$GRIM_ROOT/VERSION" ] || [ "$(cat "$GRIM_ROOT/VERSION")" != "$version" ]; then
        echo -e "${RED}❌ Version $version not found${NC}"
        return 1
    fi
    
    # Build for all platforms
    local platforms=("linux" "macos" "windows")
    local architectures=("x86_64" "arm64")
    local packages=()
    
    for platform in "${platforms[@]}"; do
        for arch in "${architectures[@]}"; do
            echo "Building for $platform-$arch..."
            if build_package "$platform" "$arch" "release"; then
                # Create packages
                for pkg_type in "tar.gz" "zip"; do
                    if create_package "$pkg_type" "$platform" "$arch"; then
                        local pkg_name="grim-$version-$platform-$arch.$pkg_type"
                        packages+=("$pkg_name")
                    fi
                done
            fi
        done
    done
    
    # Create Docker image
    if create_package "docker" "linux" "x86_64"; then
        packages+=("grim-$version-docker.tar.gz")
    fi
    
    # Record release
    local artifacts_count=${#packages[@]}
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO package_releases (version, release_type, artifacts_count, published_at, published_by, status)
VALUES ('$version', '$release_type', $artifacts_count, CURRENT_TIMESTAMP, 'packager', 'published');
EOF
    
    # Create release notes
    create_release_notes "$version" "$release_type"
    
    log "Release $version created with $artifacts_count artifacts"
    "$NOTIFY_MODULE" send success "Release Published" "Release $version published" "{\"version\": \"$version\", \"type\": \"$release_type\", \"artifacts\": $artifacts_count}"
    
    echo -e "${GREEN}✅ Release $version created successfully${NC}"
    echo "Artifacts: ${packages[*]}"
}

# Create release notes
create_release_notes() {
    local version="$1"
    local release_type="$2"
    
    local notes_file="$DIST_DIR/RELEASE_NOTES-$version.md"
    
    cat > "$notes_file" <<EOF
# Grim $version Release Notes

**Release Date:** $(date '+%Y-%m-%d')
**Release Type:** $release_type

## What's New

- Enhanced packaging and distribution system
- Improved version management
- Multi-platform support
- Docker containerization
- Automated build pipeline

## Installation

### Linux
\`\`\`bash
# Download and extract
wget https://github.com/grim-project/grim/releases/download/v$version/grim-$version-linux-x86_64.tar.gz
tar -xzf grim-$version-linux-x86_64.tar.gz
cd grim-$version-linux-x86_64

# Run
./reaper.sh help
\`\`\`

### Docker
\`\`\`bash
docker pull $DOCKER_REGISTRY/grim:$version
docker run -it $DOCKER_REGISTRY/grim:$version help
\`\`\`

## Changelog

$(git log --oneline --since="1 month ago" | head -10)

## System Requirements

- Linux/macOS/Windows
- Bash 4.0+
- SQLite 3.0+
- 100MB disk space
- 512MB RAM

## Support

- Documentation: $REPO_URL/docs
- Issues: $REPO_URL/issues
- Discussions: $REPO_URL/discussions
EOF
    
    echo "Release notes created: $notes_file"
}

# Deploy to target environment
deploy_package() {
    local environment="${1:-staging}"
    local version="${2:-$PACKAGE_VERSION}"
    
    echo -e "${CYAN}=== Deploying Package ===${NC}"
    echo "Environment: $environment"
    echo "Version: $version"
    
    # Check if package exists
    local package_path="$DIST_DIR/grim-$version-linux-x86_64.tar.gz"
    if [ ! -f "$package_path" ]; then
        echo -e "${RED}❌ Package not found: $package_path${NC}"
        return 1
    fi
    
    # Deploy based on environment
    case "$environment" in
        staging)
            deploy_to_staging "$package_path" "$version"
            ;;
        production)
            deploy_to_production "$package_path" "$version"
            ;;
        docker)
            deploy_to_docker "$version"
            ;;
        *)
            echo -e "${RED}❌ Unknown environment: $environment${NC}"
            return 1
            ;;
    esac
    
    log "Package deployed to $environment"
    "$NOTIFY_MODULE" send success "Deployment Complete" "Package deployed to $environment" "{\"environment\": \"$environment\", \"version\": \"$version\"}"
    
    echo -e "${GREEN}✅ Package deployed to $environment${NC}"
}

# Deploy to staging
deploy_to_staging() {
    local package_path="$1"
    local version="$2"
    
    echo "Deploying to staging environment..."
    
    # Extract to staging directory
    local staging_dir="/opt/grim/staging"
    mkdir -p "$staging_dir"
    
    tar -xzf "$package_path" -C "$staging_dir"
    
    # Update symlinks
    ln -sf "$staging_dir/reaper.sh" /usr/local/bin/grim
    
    echo "Staging deployment complete"
}

# Deploy to production
deploy_to_production() {
    local package_path="$1"
    local version="$2"
    
    echo "Deploying to production environment..."
    
    # Backup current version
    if [ -d "/opt/grim/production" ]; then
        mv /opt/grim/production /opt/grim/production.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Extract to production directory
    local production_dir="/opt/grim/production"
    mkdir -p "$production_dir"
    
    tar -xzf "$package_path" -C "$production_dir"
    
    # Update symlinks
    ln -sf "$production_dir/reaper.sh" /usr/local/bin/grim
    
    echo "Production deployment complete"
}

# Deploy to Docker
deploy_to_docker() {
    local version="$1"
    
    echo "Deploying Docker image..."
    
    # Push to registry
    docker push "$DOCKER_REGISTRY/grim:$version"
    docker push "$DOCKER_REGISTRY/grim:latest"
    
    # Update Docker image record
    sqlite3 "$DB_PATH" <<EOF
UPDATE docker_images 
SET status = 'pushed', pushed_at = CURRENT_TIMESTAMP 
WHERE name = 'grim' AND tag = '$version';
EOF
    
    echo "Docker deployment complete"
}

# Docker operations
manage_docker() {
    local action="$1"
    local image_tag="${2:-$PACKAGE_VERSION}"
    
    case "$action" in
        build)
            build_docker_image "$image_tag"
            ;;
        push)
            push_docker_image "$image_tag"
            ;;
        pull)
            pull_docker_image "$image_tag"
            ;;
        list)
            list_docker_images
            ;;
        clean)
            clean_docker_images
            ;;
        *)
            echo "Usage: packager.sh docker build|push|pull|list|clean"
            exit 1
            ;;
    esac
}

# Build Docker image
build_docker_image() {
    local tag="$1"
    
    echo -e "${CYAN}=== Building Docker Image ===${NC}"
    echo "Tag: $tag"
    
    "$BUILD_DIR/docker-build.sh" "$tag" "$DOCKER_REGISTRY"
    
    echo -e "${GREEN}✅ Docker image built: $DOCKER_REGISTRY/grim:$tag${NC}"
}

# Push Docker image
push_docker_image() {
    local tag="$1"
    
    echo -e "${CYAN}=== Pushing Docker Image ===${NC}"
    echo "Tag: $tag"
    
    docker push "$DOCKER_REGISTRY/grim:$tag"
    docker push "$DOCKER_REGISTRY/grim:latest"
    
    # Update database
    sqlite3 "$DB_PATH" <<EOF
UPDATE docker_images 
SET status = 'pushed', pushed_at = CURRENT_TIMESTAMP 
WHERE name = 'grim' AND tag = '$tag';
EOF
    
    echo -e "${GREEN}✅ Docker image pushed${NC}"
}

# Pull Docker image
pull_docker_image() {
    local tag="$1"
    
    echo -e "${CYAN}=== Pulling Docker Image ===${NC}"
    echo "Tag: $tag"
    
    docker pull "$DOCKER_REGISTRY/grim:$tag"
    
    echo -e "${GREEN}✅ Docker image pulled${NC}"
}

# List Docker images
list_docker_images() {
    echo -e "${CYAN}=== Docker Images ===${NC}"
    
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT name, tag, registry, size, status, created_at
FROM docker_images 
ORDER BY created_at DESC;
EOF
}

# Clean Docker images
clean_docker_images() {
    echo -e "${CYAN}=== Cleaning Docker Images ===${NC}"
    
    # Remove old images
    docker images "$DOCKER_REGISTRY/grim" --format "{{.Repository}}:{{.Tag}}" | grep -v "latest" | head -10 | xargs -r docker rmi
    
    echo -e "${GREEN}✅ Docker images cleaned${NC}"
}

# Run package tests
run_tests() {
    local test_suite="${1:-all}"
    
    echo -e "${CYAN}=== Running Tests ===${NC}"
    echo "Test Suite: $test_suite"
    
    case "$test_suite" in
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        security)
            run_security_tests
            ;;
        all)
            run_unit_tests
            run_integration_tests
            run_security_tests
            ;;
        *)
            echo -e "${RED}❌ Unknown test suite: $test_suite${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Tests completed${NC}"
}

# Run unit tests
run_unit_tests() {
    echo "Running unit tests..."
    
    # Test reaper.sh
    if "$GRIM_ROOT/reaper.sh" help > /dev/null 2>&1; then
        echo "✅ reaper.sh help test passed"
    else
        echo "❌ reaper.sh help test failed"
        return 1
    fi
    
    # Test modules
    for module in "$GRIM_ROOT/modules"/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module" .sh)
            if bash "$module" help > /dev/null 2>&1; then
                echo "✅ $module_name help test passed"
            else
                echo "❌ $module_name help test failed"
            fi
        fi
    done
}

# Run integration tests
run_integration_tests() {
    echo "Running integration tests..."
    
    # Test build process
    if build_package "linux" "x86_64" "test"; then
        echo "✅ Build integration test passed"
    else
        echo "❌ Build integration test failed"
        return 1
    fi
    
    # Test packaging
    if create_package "tar.gz" "linux" "x86_64"; then
        echo "✅ Package integration test passed"
    else
        echo "❌ Package integration test failed"
        return 1
    fi
}

# Run security tests
run_security_tests() {
    echo "Running security tests..."
    
    # Check for sensitive files
    local sensitive_files=(
        "*.key"
        "*.pem"
        "*.p12"
        "*.pfx"
        "id_rsa"
        "id_dsa"
        "*.env"
    )
    
    for pattern in "${sensitive_files[@]}"; do
        if find "$GRIM_ROOT" -name "$pattern" -type f | grep -q .; then
            echo "⚠️  Sensitive files found: $pattern"
        fi
    done
    
    # Check file permissions
    find "$GRIM_ROOT" -name "*.sh" -type f | while read -r file; do
        if [ ! -x "$file" ]; then
            echo "⚠️  Non-executable script: $file"
        fi
    done
    
    echo "✅ Security tests completed"
}

# Clean build artifacts
clean_builds() {
    echo -e "${CYAN}=== Cleaning Build Artifacts ===${NC}"
    
    # Remove build directories
    rm -rf "$BUILD_DIR"/*
    
    # Remove distribution packages
    rm -rf "$DIST_DIR"/*
    
    # Clean Docker images
    clean_docker_images
    
    # Clean database records
    sqlite3 "$DB_PATH" <<EOF
DELETE FROM package_builds WHERE status = 'completed';
DELETE FROM docker_images WHERE status = 'local';
EOF
    
    log "Build artifacts cleaned"
    echo -e "${GREEN}✅ Build artifacts cleaned${NC}"
}

# Main command handler
main() {
    case "${1:-}" in
        init)
            init_packager
            ;;
        build)
            build_package "${2:-linux}" "${3:-x86_64}" "${4:-release}"
            ;;
        package)
            create_package "${2:-tar.gz}" "${3:-linux}" "${4:-x86_64}"
            ;;
        version)
            manage_version "${2:-}" "${3:-}"
            ;;
        release)
            create_release "${2:-}" "${3:-stable}"
            ;;
        deploy)
            deploy_package "${2:-staging}" "${3:-}"
            ;;
        docker)
            manage_docker "${2:-}" "${3:-}"
            ;;
        test)
            run_tests "${2:-all}"
            ;;
        clean)
            clean_builds
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Only call main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 