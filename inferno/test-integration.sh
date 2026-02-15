#!/bin/sh
# Integration test script for Inferno Dish and Limbot

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Llambo Dish + Limbot Integration Tests ==="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo "${GREEN}[TEST]${NC} $1"
}

info() {
    echo "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo "${RED}[ERROR]${NC} $1"
}

# Test 1: Check file structure
log "Test 1: Checking file structure..."
FILES="dish-integration.b limbot.b limbot-cli deploy.sh llamboctl"
for file in $FILES; do
    if [ -f "$file" ]; then
        info "  ✓ $file exists"
    else
        error "  ✗ $file missing"
        exit 1
    fi
done

# Test 2: Check executable permissions
log "Test 2: Checking executable permissions..."
EXECUTABLES="limbot-cli deploy.sh llamboctl"
for file in $EXECUTABLES; do
    if [ -x "$file" ]; then
        info "  ✓ $file is executable"
    else
        error "  ✗ $file not executable"
        exit 1
    fi
done

# Test 3: Validate Limbo syntax (basic check)
log "Test 3: Validating Limbo file structure..."
for file in dish-integration.b limbot.b; do
    if head -n 1 "$file" | grep -q "implement"; then
        info "  ✓ $file has valid module declaration"
    else
        error "  ✗ $file missing module declaration"
        exit 1
    fi
done

# Test 4: Check deploy.sh integration
log "Test 4: Checking deploy.sh integration..."
if grep -q "dish-integration.b" deploy.sh; then
    info "  ✓ deploy.sh includes dish-integration compilation"
else
    warn "  ⚠ deploy.sh may not compile dish-integration"
fi

if grep -q "limbot.b" deploy.sh; then
    info "  ✓ deploy.sh includes limbot compilation"
else
    warn "  ⚠ deploy.sh may not compile limbot"
fi

# Test 5: Check llamboctl integration
log "Test 5: Checking llamboctl integration..."
if grep -q "limbot)" llamboctl; then
    info "  ✓ llamboctl has limbot command"
else
    error "  ✗ llamboctl missing limbot command"
    exit 1
fi

if grep -q "dish)" llamboctl; then
    info "  ✓ llamboctl has dish command"
else
    error "  ✗ llamboctl missing dish command"
    exit 1
fi

# Test 6: Check documentation
log "Test 6: Checking documentation..."
if grep -q "Limbot" README.md; then
    info "  ✓ README.md documents Limbot"
else
    warn "  ⚠ README.md may not document Limbot"
fi

if grep -q "Dish" README.md; then
    info "  ✓ README.md documents Dish"
else
    warn "  ⚠ README.md may not document Dish"
fi

# Test 7: Simulate compilation check (if Inferno available)
log "Test 7: Checking Inferno environment..."
INFERNO_ROOT="${INFERNO_ROOT:-/usr/inferno}"
if [ -d "$INFERNO_ROOT" ]; then
    info "  ✓ Inferno OS found at $INFERNO_ROOT"
    
    if [ -x "$INFERNO_ROOT/Linux/386/bin/emu" ] || [ -x "$INFERNO_ROOT/emu" ]; then
        info "  ✓ Inferno emulator available"
        
        # Try to compile modules
        log "Attempting to compile Limbo modules..."
        ./deploy.sh compile 2>&1 | head -10
    else
        warn "  ⚠ Inferno emulator not found (compilation skipped)"
    fi
else
    warn "  ⚠ Inferno OS not installed (compilation tests skipped)"
    info "    Set INFERNO_ROOT to test compilation"
fi

echo ""
log "All basic structure tests passed!"
echo ""
echo "Next steps:"
echo "  1. Install Inferno OS if not already installed"
echo "  2. Run: ./deploy.sh compile"
echo "  3. Run: ./deploy.sh deploy-local"
echo "  4. Test: llamboctl limbot -h"
echo "  5. Test: llamboctl dish"
echo ""
