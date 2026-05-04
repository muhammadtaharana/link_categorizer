#!/bin/bash

# Link Categorizer Setup Script
# Initializes environment, checks dependencies, and prepares for use

set -euo pipefail

echo "=================================="
echo "Link Categorizer v2.0.1 - Setup"
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Counters
INSTALLED=0
MISSING=0
OPTIONAL=0

# Check functions
check_command() {
    local cmd=$1
    local pkg=$2
    local type=$3  # required, optional, alternative

    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd installed"
        ((INSTALLED++))
        return 0
    else
        if [ "$type" = "required" ]; then
            echo -e "${RED}✗${NC} $cmd NOT FOUND (required) - install with: apt-get install $pkg"
            ((MISSING++))
        elif [ "$type" = "optional" ]; then
            echo -e "${YELLOW}!${NC} $cmd NOT FOUND (optional) - install with: apt-get install $pkg"
            ((OPTIONAL++))
        fi
        return 1
    fi
}

echo "[*] Checking dependencies..."
echo ""

# Required
check_command "bash" "bash" "required"
check_command "grep" "grep" "required"
check_command "sed" "sed" "required"
check_command "awk" "gawk" "required"

echo ""
echo "[*] Checking optional tools..."
echo ""

# Optional but important
check_command "parallel" "parallel" "optional"
check_command "sqlite3" "sqlite3" "optional"
check_command "jq" "jq" "optional"
check_command "curl" "curl" "optional"

echo ""
echo "[*] Setting up directories and files..."
echo ""

# Create directories
mkdir -p .cache
mkdir -p logs
mkdir -p extreme_categorized_urls

# Create config if not exists
if [ ! -f "config.json" ]; then
    echo "Creating config.json template..."
    cat > config.json << 'EOF'
{
  "performance": {
    "parallel_jobs": 4,
    "batch_size": 1000,
    "cache_enabled": true
  },
  "output": {
    "formats": ["txt"]
  },
  "database": {
    "enabled": false
  }
}
EOF
fi

# Make script executable
chmod +x link_categorizer.sh

echo -e "${GREEN}✓${NC} Created .cache directory"
echo -e "${GREEN}✓${NC} Created logs directory"
echo -e "${GREEN}✓${NC} Created extreme_categorized_urls directory"
echo -e "${GREEN}✓${NC} Script is executable"

echo ""
echo "[*] Summary:"
echo "  Tools installed: $INSTALLED"
if [ $MISSING -gt 0 ]; then
    echo -e "  ${RED}Missing required: $MISSING${NC}"
fi
if [ $OPTIONAL -gt 0 ]; then
    echo -e "  ${YELLOW}Optional tools missing: $OPTIONAL${NC}"
    echo "    Install optional tools for better performance and features"
fi

echo ""
echo "[*] Quick start:"
echo ""
echo "  1. Basic usage:"
echo "     ./link_categorizer.sh urls.txt"
echo ""
echo "  2. Advanced usage:"
echo "     ./link_categorizer.sh -j 8 -p --validate-http urls.txt"
echo ""
echo "  3. View help:"
echo "     ./link_categorizer.sh -h"
echo ""
echo "  4. Read documentation:"
echo "     cat USAGE.md"
echo ""

if [ $MISSING -eq 0 ]; then
    echo -e "${GREEN}✓ Setup complete! Ready to use.${NC}"
else
    echo -e "${RED}! Please install missing required tools before using.${NC}"
    exit 1
fi
