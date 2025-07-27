#!/bin/bash

# Verification script for all Grim packages
echo "🔍 Verifying all Grim packages meet standards..."
echo "=============================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Track issues
issues=0

# Function to check file contains string
check_contains() {
    local file="$1"
    local search="$2"
    local desc="$3"
    
    if grep -q "$search" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $desc in $(basename $file)"
    else
        echo -e "${RED}✗${NC} Missing $desc in $(basename $file)"
        ((issues++))
    fi
}

# Function to check file does NOT contain string
check_not_contains() {
    local file="$1"
    local search="$2"
    local desc="$3"
    
    if grep -q "$search" "$file" 2>/dev/null; then
        echo -e "${RED}✗${NC} Found $desc in $(basename $file) (should not exist)"
        ((issues++))
    else
        echo -e "${GREEN}✓${NC} No $desc in $(basename $file)"
    fi
}

echo -e "\n${YELLOW}1. Checking JavaScript package...${NC}"
echo "-----------------------------------"
check_contains "/opt/reaper/pkg/js_grim/package.json" '"license": "BBL"' "BBL license"
check_not_contains "/opt/reaper/pkg/js_grim/package.json" "Be Like Brit" "incorrect license name"
check_contains "/opt/reaper/pkg/js_grim/package.json" '"grim": "./grim.js"' "grim command"
check_contains "/opt/reaper/pkg/js_grim/package.json" "https://grim.so" "correct website"
check_not_contains "/opt/reaper/pkg/js_grim/package.json" "grim-reaper.org" "old website"
check_contains "/opt/reaper/pkg/js_grim/README.md" "https://grim.so/license" "license disclaimer"
check_contains "/opt/reaper/pkg/js_grim/README.md" "Bernie Gengel and his beagle Buddy" "official bio"
check_contains "/opt/reaper/pkg/js_grim/lib/installer.js" "get.grim.so" "auto-installer"
check_contains "/opt/reaper/pkg/js_grim/lib/grim-reaper.js" "grim-ascii.sh" "error handling"

echo -e "\n${YELLOW}2. Checking Python package...${NC}"
echo "-------------------------------"
check_contains "/opt/reaper/pkg/py_grim/setup.py" 'license="BBL"' "BBL license"
check_not_contains "/opt/reaper/pkg/py_grim/setup.py" "Be Like Brit" "incorrect license name"
check_contains "/opt/reaper/pkg/py_grim/setup.py" '"grim=grim_reaper:main"' "grim command"
check_contains "/opt/reaper/pkg/py_grim/README.md" "https://grim.so/license" "license disclaimer"
check_contains "/opt/reaper/pkg/py_grim/README.md" "Bernie Gengel and his beagle Buddy" "official bio"

echo -e "\n${YELLOW}3. Checking PHP package...${NC}"
echo "----------------------------"
check_contains "/opt/reaper/pkg/php_grim/composer.json" '"license": "BBL"' "BBL license"
check_not_contains "/opt/reaper/pkg/php_grim/composer.json" "Be Like Brit" "incorrect license name"
check_contains "/opt/reaper/pkg/php_grim/composer.json" '"bin/grim"' "grim command"
check_contains "/opt/reaper/pkg/php_grim/README.md" "https://grim.so/license" "license disclaimer"
check_contains "/opt/reaper/pkg/php_grim/README.md" "Bernie Gengel and his beagle Buddy" "official bio"
check_contains "/opt/reaper/pkg/php_grim/README.md" "grim php-setup" "PHP-specific commands"

echo -e "\n${YELLOW}4. Checking Ruby package...${NC}"
echo "-----------------------------"
check_contains "/opt/reaper/pkg/rb_grim/grim-reaper.gemspec" "BBL" "BBL license"
check_not_contains "/opt/reaper/pkg/rb_grim/grim-reaper.gemspec" "Be Like Brit" "incorrect license name"
check_contains "/opt/reaper/pkg/rb_grim/README.md" "https://grim.so/license" "license disclaimer"
check_contains "/opt/reaper/pkg/rb_grim/README.md" "Bernie Gengel and his beagle Buddy" "official bio"
check_contains "/opt/reaper/pkg/rb_grim/bin/grim" "get.grim.so" "installation reference"

echo -e "\n${YELLOW}5. Checking build and deploy scripts...${NC}"
echo "-----------------------------------------"
check_contains "/opt/reaper/pkg/deploy.sh" "-m|--message" "message support"

echo -e "\n${YELLOW}6. Checking command coverage in READMEs...${NC}"
echo "-------------------------------------------"
# Check for key commands that should be in all READMEs
for readme in /opt/reaper/pkg/*/README.md; do
    if [[ -f "$readme" ]]; then
        pkg=$(basename $(dirname "$readme"))
        echo -e "\n  Checking $pkg README:"
        check_contains "$readme" "grim health" "core commands"
        check_contains "$readme" "grim backup-create" "backup commands"
        check_contains "$readme" "grim monitor-start" "monitor commands"
        check_contains "$readme" "grim security-audit" "security commands"
        check_contains "$readme" "grim ai-analyze" "AI commands"
        check_contains "$readme" "grim emergency-heal" "emergency commands"
    fi
done

echo -e "\n${YELLOW}7. Checking error handling...${NC}"
echo "--------------------------------"
check_contains "/opt/reaper/pkg/grim-ascii.sh" "terd.txt" "terd ASCII"
check_contains "/opt/reaper/pkg/grim-ascii.sh" "https://get.grim.so" "installation URL"

echo -e "\n=============================================="
if [[ $issues -eq 0 ]]; then
    echo -e "${GREEN}✅ All packages meet standards! 100% bulletproof!${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $issues issues that need fixing${NC}"
    exit 1
fi