#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"

PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
check_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
check_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

echo "=== hermes-agent Platform Verification ==="
echo ""

if command -v hermes &>/dev/null; then
    HERMES_VER=$(hermes --version 2>/dev/null || true)
    if [ -n "$HERMES_VER" ]; then
        check_pass "hermes $HERMES_VER"
    else
        check_pass "hermes binary present (--version unavailable)"
    fi
else
    check_fail "hermes command not found"
fi

if [ -d "$HERMES_REPO_DIR/.git" ]; then
    check_pass "hermes-agent repo at $HERMES_REPO_DIR"
else
    check_fail "hermes-agent repo missing at $HERMES_REPO_DIR"
fi

if [ -x "$HERMES_REPO_DIR/venv/bin/python" ]; then
    check_pass "Python venv at $HERMES_REPO_DIR/venv"
else
    check_fail "Python venv missing at $HERMES_REPO_DIR/venv"
fi

if "$HERMES_REPO_DIR/venv/bin/python" -c "from hermes_cli.main import main" 2>/dev/null; then
    check_pass "hermes_cli importable"
else
    check_fail "hermes_cli not importable from venv"
fi

if [ -d "$HOME/.hermes" ]; then
    check_pass "Directory $HOME/.hermes exists"
else
    check_warn "Directory $HOME/.hermes missing — run 'hermes setup'"
fi

if [ -L "$PREFIX/bin/hermes" ] || [ -f "$PREFIX/bin/hermes" ]; then
    check_pass "$PREFIX/bin/hermes is on PATH"
else
    check_fail "$PREFIX/bin/hermes missing"
fi

echo ""
echo "==============================="
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo "==============================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
