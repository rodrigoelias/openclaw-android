#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../scripts/lib.sh"

PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
check_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
check_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

echo "=== Hermes on Android - Installation Verification ==="
echo ""

if command -v python &>/dev/null; then
    PY_VER=$(python --version 2>/dev/null | awk '{print $2}')
    if python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
        check_pass "Python $PY_VER (>= 3.11)"
    else
        check_fail "Python $PY_VER (need >= 3.11)"
    fi
else
    check_fail "Python not found"
fi

if command -v pip &>/dev/null; then
    check_pass "pip $(pip --version 2>/dev/null | awk '{print $2}')"
else
    check_fail "pip not found"
fi

if [ -n "${TMPDIR:-}" ]; then
    check_pass "TMPDIR=$TMPDIR"
else
    check_warn "TMPDIR not set"
fi

for DIR in "$PROJECT_DIR" "$PREFIX/tmp"; do
    if [ -d "$DIR" ]; then
        check_pass "Directory $DIR exists"
    else
        check_fail "Directory $DIR missing"
    fi
done

if grep -qF "Hermes on Android" "$HOME/.bashrc" 2>/dev/null; then
    check_pass ".bashrc contains environment block"
else
    check_fail ".bashrc missing environment block"
fi

if [ -f "$PREFIX/bin/ha" ]; then
    check_pass "ha CLI installed"
else
    check_fail "ha CLI not installed at $PREFIX/bin/ha"
fi

PLATFORM=$(detect_platform) || true
PLATFORM_VERIFY="$PROJECT_DIR/platforms/$PLATFORM/verify.sh"
if [ -n "$PLATFORM" ] && [ -f "$PLATFORM_VERIFY" ]; then
    if bash "$PLATFORM_VERIFY"; then
        check_pass "Platform verifier passed ($PLATFORM)"
    else
        check_fail "Platform verifier failed ($PLATFORM)"
    fi
else
    check_warn "Platform verifier not found (platform=${PLATFORM:-none})"
fi

echo ""
echo "==============================="
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo "==============================="
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Installation verification FAILED.${NC}"
    echo "Please check the errors above and re-run install.sh"
    exit 1
else
    echo -e "${GREEN}Installation verification PASSED!${NC}"
fi
