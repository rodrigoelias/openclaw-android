#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$HOME/.hermes-android"

if [ -f "$HOME/.hermes-android/scripts/lib.sh" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.hermes-android/scripts/lib.sh"
else
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BOLD='\033[1m'
    NC='\033[0m'
    PLATFORM_MARKER="$PROJECT_DIR/.platform"
    BASHRC_MARKER_START="# >>> Hermes on Android >>>"
    BASHRC_MARKER_END="# <<< Hermes on Android <<<"

    ask_yn() {
        local prompt="$1"
        local reply
        read -rp "$prompt [Y/n] " reply < /dev/tty
        [[ "${reply:-}" =~ ^[Nn]$ ]] && return 1
        return 0
    }

    detect_platform() {
        if [ -f "$PLATFORM_MARKER" ]; then
            cat "$PLATFORM_MARKER"
            return 0
        fi
        return 1
    }
fi

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Hermes on Android - Uninstaller${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

reply=""
read -rp "This will remove the installation. Continue? [y/N] " reply < /dev/tty
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

step() {
    echo ""
    echo -e "${BOLD}[$1/4] $2${NC}"
    echo "----------------------------------------"
}

step 1 "Platform uninstall"
PLATFORM=$(detect_platform 2>/dev/null || true)
if [ -z "$PLATFORM" ]; then
    PLATFORM="hermes-agent"
fi

PLATFORM_UNINSTALL="$PROJECT_DIR/platforms/$PLATFORM/uninstall.sh"
if [ -f "$PLATFORM_UNINSTALL" ]; then
    bash "$PLATFORM_UNINSTALL"
else
    echo -e "${YELLOW}[SKIP]${NC} Platform uninstall script not found: $PLATFORM_UNINSTALL"
fi

step 2 "ha and haupdate commands"
if [ -f "${PREFIX:-}/bin/ha" ]; then
    rm -f "${PREFIX:-}/bin/ha"
    echo -e "${GREEN}[OK]${NC}   Removed ${PREFIX:-}/bin/ha"
else
    echo -e "${YELLOW}[SKIP]${NC} ${PREFIX:-}/bin/ha not found"
fi

if [ -f "${PREFIX:-}/bin/haupdate" ]; then
    rm -f "${PREFIX:-}/bin/haupdate"
    echo -e "${GREEN}[OK]${NC}   Removed ${PREFIX:-}/bin/haupdate"
else
    echo -e "${YELLOW}[SKIP]${NC} ${PREFIX:-}/bin/haupdate not found"
fi

step 3 "shell configuration"
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ] && grep -qF "$BASHRC_MARKER_START" "$BASHRC"; then
    sed -i "/${BASHRC_MARKER_START//\//\\/}/,/${BASHRC_MARKER_END//\//\\/}/d" "$BASHRC"
    sed -i '/^$/{ N; /^\n$/d }' "$BASHRC"
    echo -e "${GREEN}[OK]${NC}   Removed environment block from $BASHRC"
else
    echo -e "${YELLOW}[SKIP]${NC} No environment block found in $BASHRC"
fi

step 4 "installation directory"

if [ -d "$PROJECT_DIR" ]; then
    if ask_yn "Remove installation directory (~/.hermes-android)? Includes hermes-agent repo, venv, configs."; then
        rm -rf "$PROJECT_DIR"
        echo -e "${GREEN}[OK]${NC}   Removed $PROJECT_DIR"
    else
        echo -e "${YELLOW}[KEEP]${NC} Keeping $PROJECT_DIR"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} $PROJECT_DIR not found"
fi

echo ""
echo -e "${GREEN}${BOLD}Uninstall complete.${NC}"
echo "Restart your Termux session to clear environment variables."
echo ""
