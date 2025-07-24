#!/bin/bash

# =============================================================================
# 🔄 GRIM VERSION UPDATE SCRIPT
# =============================================================================
# Automatically increments version numbers in version-manifest.json
# Built by Bernie Gengel and his beagle Buddy
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Files
MANIFEST="/opt/reaper/pkg/version-manifest.json"
BACKUP_MANIFEST="/opt/reaper/pkg/version-manifest.json.bak"

# Function to increment version
increment_version() {
    local version=$1
    local type=${2:-patch}  # major, minor, patch
    
    # Remove 'v' prefix if present
    version=${version#v}
    
    # Split version
    IFS='.' read -r major minor patch <<< "$version"
    
    case $type in
        major)
            ((major++))
            minor=0
            patch=0
            ;;
        minor)
            ((minor++))
            patch=0
            ;;
        patch)
            ((patch++))
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq is required but not installed. Installing...${NC}"
    sudo apt-get update && sudo apt-get install -y jq
fi

# Parse arguments
PACKAGE=""
VERSION_TYPE="patch"

while [[ $# -gt 0 ]]; do
    case $1 in
        --package|-p)
            PACKAGE="$2"
            shift 2
            ;;
        --major)
            VERSION_TYPE="major"
            shift
            ;;
        --minor)
            VERSION_TYPE="minor"
            shift
            ;;
        --patch)
            VERSION_TYPE="patch"
            shift
            ;;
        --all)
            PACKAGE="all"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --package <name>  Update specific package (javascript, python, etc.)"
            echo "  --all            Update all packages"
            echo "  --major          Increment major version (X.0.0)"
            echo "  --minor          Increment minor version (x.X.0)"
            echo "  --patch          Increment patch version (x.x.X) [default]"
            echo "  --help           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Backup manifest
cp "$MANIFEST" "$BACKUP_MANIFEST"

# Read current manifest
CURRENT_MANIFEST=$(cat "$MANIFEST")

# Update timestamp
UPDATED_DATE=$(date +"%Y-%m-%d")

if [[ "$PACKAGE" == "all" ]]; then
    echo -e "${BLUE}📦 Updating all package versions...${NC}"
    
    # Get main version and increment it
    MAIN_VERSION=$(echo "$CURRENT_MANIFEST" | jq -r '.version')
    NEW_VERSION=$(increment_version "$MAIN_VERSION" "$VERSION_TYPE")
    
    # Update main version
    CURRENT_MANIFEST=$(echo "$CURRENT_MANIFEST" | jq ".version = \"$NEW_VERSION\"")
    CURRENT_MANIFEST=$(echo "$CURRENT_MANIFEST" | jq ".updated = \"$UPDATED_DATE\"")
    
    # Update all package versions
    for pkg in javascript python ruby php rust go csharp java; do
        PKG_VERSION=$(echo "$CURRENT_MANIFEST" | jq -r ".packages.$pkg.version")
        # Handle 'v' prefix for Go
        if [[ "$pkg" == "go" ]] && [[ "$PKG_VERSION" == v* ]]; then
            NEW_PKG_VERSION="v$(increment_version "$PKG_VERSION" "$VERSION_TYPE")"
        else
            NEW_PKG_VERSION=$(increment_version "$PKG_VERSION" "$VERSION_TYPE")
        fi
        CURRENT_MANIFEST=$(echo "$CURRENT_MANIFEST" | jq ".packages.$pkg.version = \"$NEW_PKG_VERSION\"")
        echo -e "${GREEN}✅ $pkg: $PKG_VERSION → $NEW_PKG_VERSION${NC}"
    done
    
elif [[ -n "$PACKAGE" ]]; then
    echo -e "${BLUE}📦 Updating $PACKAGE version...${NC}"
    
    # Check if package exists
    if ! echo "$CURRENT_MANIFEST" | jq -e ".packages.$PACKAGE" > /dev/null; then
        echo -e "${YELLOW}⚠️  Package '$PACKAGE' not found in manifest${NC}"
        exit 1
    fi
    
    # Get current version
    PKG_VERSION=$(echo "$CURRENT_MANIFEST" | jq -r ".packages.$PACKAGE.version")
    
    # Handle 'v' prefix for Go
    if [[ "$PACKAGE" == "go" ]] && [[ "$PKG_VERSION" == v* ]]; then
        NEW_PKG_VERSION="v$(increment_version "$PKG_VERSION" "$VERSION_TYPE")"
    else
        NEW_PKG_VERSION=$(increment_version "$PKG_VERSION" "$VERSION_TYPE")
    fi
    
    # Update version
    CURRENT_MANIFEST=$(echo "$CURRENT_MANIFEST" | jq ".packages.$PACKAGE.version = \"$NEW_PKG_VERSION\"")
    CURRENT_MANIFEST=$(echo "$CURRENT_MANIFEST" | jq ".updated = \"$UPDATED_DATE\"")
    
    echo -e "${GREEN}✅ $PACKAGE: $PKG_VERSION → $NEW_PKG_VERSION${NC}"
    
else
    echo -e "${YELLOW}⚠️  No package specified. Use --package <name> or --all${NC}"
    exit 1
fi

# Write updated manifest
echo "$CURRENT_MANIFEST" | jq '.' > "$MANIFEST"

echo -e "${GREEN}✅ Version manifest updated successfully!${NC}"
echo -e "${BLUE}📄 Manifest saved to: $MANIFEST${NC}"
echo -e "${BLUE}📄 Backup saved to: $BACKUP_MANIFEST${NC}"

# Show summary
echo -e "\n${BLUE}📊 Version Summary:${NC}"
echo "$CURRENT_MANIFEST" | jq -r '.packages | to_entries[] | "\(.key): \(.value.version)"'

# C.3.R.B.H.F