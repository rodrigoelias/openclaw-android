#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../scripts/lib.sh"

echo "=== Removing hermes-agent Platform ==="
echo ""

step() {
    echo ""
    echo -e "${BOLD}[$1/4] $2${NC}"
    echo "----------------------------------------"
}

step 1 "hermes binary symlink"
if [ -L "$PREFIX/bin/hermes" ] || [ -f "$PREFIX/bin/hermes" ]; then
    rm -f "$PREFIX/bin/hermes"
    echo -e "${GREEN}[OK]${NC}   Removed $PREFIX/bin/hermes"
else
    echo -e "${YELLOW}[SKIP]${NC} $PREFIX/bin/hermes not found"
fi

# Other entry points installed by setup-hermes.sh
for extra in hermes-agent hermes-acp; do
    if [ -L "$PREFIX/bin/$extra" ] || [ -f "$PREFIX/bin/$extra" ]; then
        rm -f "$PREFIX/bin/$extra"
        echo -e "${GREEN}[OK]${NC}   Removed $PREFIX/bin/$extra"
    fi
done

step 2 "hermes-agent repo + venv"
if [ -d "$HERMES_REPO_DIR" ]; then
    rm -rf "$HERMES_REPO_DIR"
    echo -e "${GREEN}[OK]${NC}   Removed $HERMES_REPO_DIR"
else
    echo -e "${YELLOW}[SKIP]${NC} $HERMES_REPO_DIR not found"
fi

step 3 "hermes data directory"
if [ -d "$HOME/.hermes" ]; then
    reply=""
    read -rp "Remove hermes data directory (~/.hermes)? Includes config, memory, skills. [y/N] " reply < /dev/tty
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.hermes"
        echo -e "${GREEN}[OK]${NC}   Removed ~/.hermes"
    else
        echo -e "${YELLOW}[KEEP]${NC} Keeping ~/.hermes"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} ~/.hermes not found"
fi

step 4 "termux-services hermes-gateway service"
if [ -d "$PREFIX/var/service/hermes-gateway" ]; then
    if ask_yn "Remove hermes-gateway termux-service?"; then
        command -v sv &>/dev/null && sv down hermes-gateway 2>/dev/null || true
        rm -rf "$PREFIX/var/service/hermes-gateway"
        echo -e "${GREEN}[OK]${NC}   Removed $PREFIX/var/service/hermes-gateway"
    else
        echo -e "${YELLOW}[KEEP]${NC} Keeping hermes-gateway service"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} hermes-gateway service not installed"
fi
