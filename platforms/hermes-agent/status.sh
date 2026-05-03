#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../scripts/lib.sh"

echo ""
echo -e "${BOLD}Platform Components${NC}"

if command -v hermes &>/dev/null; then
    echo "  hermes:      $(hermes --version 2>/dev/null || echo 'installed')"
else
    echo -e "  hermes:      ${RED}not installed${NC}"
fi

if command -v python &>/dev/null; then
    echo "  Python:      $(python --version 2>/dev/null)"
elif command -v python3 &>/dev/null; then
    echo "  Python:      $(python3 --version 2>/dev/null)"
else
    echo -e "  Python:      ${RED}not installed${NC}"
fi

if command -v pip &>/dev/null; then
    echo "  pip:         $(pip --version 2>/dev/null | awk '{print $2}')"
elif command -v pip3 &>/dev/null; then
    echo "  pip:         $(pip3 --version 2>/dev/null | awk '{print $2}')"
else
    echo -e "  pip:         ${RED}not installed${NC}"
fi

if command -v rg &>/dev/null; then
    echo "  ripgrep:     $(rg --version 2>/dev/null | head -1 | awk '{print $2}')"
else
    echo -e "  ripgrep:     ${YELLOW}not installed${NC}"
fi

echo ""
echo -e "${BOLD}Repository${NC}"
if [ -d "$HERMES_REPO_DIR/.git" ]; then
    REPO_HEAD=$(git -C "$HERMES_REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    REPO_BRANCH=$(git -C "$HERMES_REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    echo "  Path:        $HERMES_REPO_DIR"
    echo "  Branch:      $REPO_BRANCH @ $REPO_HEAD"
else
    echo -e "  ${RED}[MISS]${NC} $HERMES_REPO_DIR not a git repository"
fi

echo ""
echo -e "${BOLD}Virtualenv${NC}"
if [ -x "$HERMES_REPO_DIR/venv/bin/python" ]; then
    PYVER=$("$HERMES_REPO_DIR/venv/bin/python" --version 2>/dev/null)
    echo -e "  ${GREEN}[OK]${NC}   venv Python: $PYVER"
else
    echo -e "  ${RED}[MISS]${NC} venv not found at $HERMES_REPO_DIR/venv"
fi

echo ""
echo -e "${BOLD}Hermes data${NC}"
if [ -d "$HOME/.hermes" ]; then
    echo "  Path:        $HOME/.hermes"
    if [ -f "$HOME/.hermes/config.yaml" ]; then
        echo -e "  ${GREEN}[OK]${NC}   config.yaml present"
    else
        echo -e "  ${YELLOW}[WARN]${NC} config.yaml missing — run 'hermes setup'"
    fi
    SKILL_COUNT=$(find "$HOME/.hermes/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    echo "  Skills:      $SKILL_COUNT installed"
else
    echo -e "  ${YELLOW}[MISS]${NC} ~/.hermes not yet created — run 'hermes setup'"
fi

echo ""
echo -e "${BOLD}Gateway service${NC}"
if [ -d "$PREFIX/var/service/hermes-gateway" ]; then
    if command -v sv &>/dev/null; then
        SV_STATUS=$(sv status hermes-gateway 2>/dev/null || echo "unknown")
        echo "  $SV_STATUS"
    else
        echo "  Service definition exists (termux-services not loaded in this shell)"
    fi
else
    echo -e "  ${YELLOW}[INFO]${NC} hermes-gateway runit service not configured"
    echo "         See android/README.md for setup steps"
fi

echo ""
echo -e "${BOLD}Disk${NC}"
if [ -d "$PROJECT_DIR" ]; then
    echo "  ~/.hermes-android:  $(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)"
fi
if [ -d "$HOME/.hermes" ]; then
    echo "  ~/.hermes:          $(du -sh "$HOME/.hermes" 2>/dev/null | cut -f1)"
fi
AVAIL_MB=$(df "${PREFIX:-/}" 2>/dev/null | awk 'NR==2 {print int($4/1024)}') || true
echo "  Available:          ${AVAIL_MB:-unknown}MB"
