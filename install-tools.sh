#!/usr/bin/env bash
# install-tools.sh — install bundled optional tools
#
# Run via: ha --install
# Detects already-installed tools (marked [INSTALLED]) and skips them.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_DIR="$HOME/.hermes-android"
HA_VERSION="0.1.0"
REPO_TARBALL="https://github.com/rodrigoelias/hermes-android/archive/refs/heads/main.tar.gz"

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Hermes on Android - Install Tools${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

if [ -z "${PREFIX:-}" ]; then
    echo -e "${RED}[FAIL]${NC} Not running in Termux (\$PREFIX not set)"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo -e "${RED}[FAIL]${NC} curl not found. Install it with: pkg install curl"
    exit 1
fi

if [ -f "$PROJECT_DIR/scripts/lib.sh" ]; then
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/scripts/lib.sh"
fi

if ! declare -f ask_yn &>/dev/null; then
    ask_yn() {
        local prompt="$1"
        local reply
        read -rp "$prompt [Y/n] " reply < /dev/tty
        [[ "${reply:-}" =~ ^[Nn]$ ]] && return 1
        return 0
    }
fi

# ── Detect installed tools ──
echo -e "${BOLD}Checking installed tools...${NC}"
echo ""

declare -A TOOL_STATUS

check_tool() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        TOOL_STATUS["$name"]="installed"
        echo -e "  ${GREEN}[INSTALLED]${NC} $name"
    else
        TOOL_STATUS["$name"]="not_installed"
        echo -e "  ${YELLOW}[NOT INSTALLED]${NC} $name"
    fi
}

check_tool "tmux" "tmux"
check_tool "ttyd" "ttyd"
check_tool "dufs" "dufs"
check_tool "android-tools" "adb"
check_tool "ripgrep" "rg"
check_tool "termux-services" "sv"

GATEWAY_SERVICE_INSTALLED=false
if [ -d "$PREFIX/var/service/hermes-gateway" ]; then
    GATEWAY_SERVICE_INSTALLED=true
    echo -e "  ${GREEN}[INSTALLED]${NC} hermes-gateway runit service"
else
    echo -e "  ${YELLOW}[NOT INSTALLED]${NC} hermes-gateway runit service"
fi

echo ""

INSTALL_TMUX=false
INSTALL_TTYD=false
INSTALL_DUFS=false
INSTALL_ANDROID_TOOLS=false
INSTALL_RIPGREP=false
INSTALL_TERMUX_SERVICES=false
INSTALL_GATEWAY_SERVICE=false

[ "${TOOL_STATUS[tmux]}" = "not_installed" ]            && ask_yn "  Install tmux (terminal multiplexer)?"     && INSTALL_TMUX=true
[ "${TOOL_STATUS[ttyd]}" = "not_installed" ]            && ask_yn "  Install ttyd (web terminal)?"             && INSTALL_TTYD=true
[ "${TOOL_STATUS[dufs]}" = "not_installed" ]            && ask_yn "  Install dufs (file server)?"              && INSTALL_DUFS=true
[ "${TOOL_STATUS[android-tools]}" = "not_installed" ]   && ask_yn "  Install android-tools (adb)?"             && INSTALL_ANDROID_TOOLS=true
[ "${TOOL_STATUS[ripgrep]}" = "not_installed" ]         && ask_yn "  Install ripgrep (faster file search)?"    && INSTALL_RIPGREP=true
[ "${TOOL_STATUS[termux-services]}" = "not_installed" ] && ask_yn "  Install termux-services (runit)?"         && INSTALL_TERMUX_SERVICES=true

if [ "$GATEWAY_SERVICE_INSTALLED" = false ]; then
    if ask_yn "  Install hermes-gateway runit service (auto-start gateway)?"; then
        INSTALL_GATEWAY_SERVICE=true
    fi
fi

ANYTHING_SELECTED=false
for var in INSTALL_TMUX INSTALL_TTYD INSTALL_DUFS INSTALL_ANDROID_TOOLS INSTALL_RIPGREP INSTALL_TERMUX_SERVICES INSTALL_GATEWAY_SERVICE; do
    if [ "${!var}" = true ]; then
        ANYTHING_SELECTED=true
        break
    fi
done

if [ "$ANYTHING_SELECTED" = false ]; then
    echo ""
    echo "No tools selected."
    exit 0
fi

# Download release tarball if we need install scripts
RELEASE_TMP=""
if [ "$INSTALL_GATEWAY_SERVICE" = true ] && [ ! -f "$PROJECT_DIR/scripts/install-gateway-service.sh" ]; then
    echo ""
    echo "Downloading install scripts..."
    mkdir -p "$PREFIX/tmp"
    RELEASE_TMP=$(mktemp -d "$PREFIX/tmp/ha-install.XXXXXX") || {
        echo -e "${RED}[FAIL]${NC} Failed to create temp directory"
        exit 1
    }
    trap 'rm -rf "$RELEASE_TMP"' EXIT
    curl -sfL "$REPO_TARBALL" | tar xz -C "$RELEASE_TMP" --strip-components=1
fi

echo ""
echo -e "${BOLD}Installing selected tools...${NC}"
echo ""

[ "$INSTALL_TMUX" = true ]            && pkg install -y tmux            && echo -e "${GREEN}[OK]${NC}   tmux installed"
[ "$INSTALL_TTYD" = true ]            && pkg install -y ttyd            && echo -e "${GREEN}[OK]${NC}   ttyd installed"
[ "$INSTALL_DUFS" = true ]            && pkg install -y dufs            && echo -e "${GREEN}[OK]${NC}   dufs installed"
[ "$INSTALL_ANDROID_TOOLS" = true ]   && pkg install -y android-tools   && echo -e "${GREEN}[OK]${NC}   android-tools installed"
[ "$INSTALL_RIPGREP" = true ]         && pkg install -y ripgrep         && echo -e "${GREEN}[OK]${NC}   ripgrep installed"
[ "$INSTALL_TERMUX_SERVICES" = true ] && pkg install -y termux-services && echo -e "${GREEN}[OK]${NC}   termux-services installed"

if [ "$INSTALL_GATEWAY_SERVICE" = true ]; then
    GATEWAY_SCRIPT="$PROJECT_DIR/scripts/install-gateway-service.sh"
    [ -f "$GATEWAY_SCRIPT" ] || GATEWAY_SCRIPT="$RELEASE_TMP/scripts/install-gateway-service.sh"
    if [ -f "$GATEWAY_SCRIPT" ] && bash "$GATEWAY_SCRIPT"; then
        echo -e "${GREEN}[OK]${NC}   hermes-gateway service installed"
    else
        echo -e "${YELLOW}[WARN]${NC} hermes-gateway service install failed (non-critical)"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
echo ""
