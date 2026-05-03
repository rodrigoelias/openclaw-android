#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/scripts/lib.sh"

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Hermes on Android - Installer v${HA_VERSION}${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo "This script installs hermes-agent on Termux with a platform-aware architecture."
echo ""

step() {
    echo ""
    echo -e "${BOLD}[$1/8] $2${NC}"
    echo "----------------------------------------"
}

step 1 "Environment Check"
if command -v termux-wake-lock &>/dev/null; then
    termux-wake-lock 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC}   Termux wake lock enabled"
fi
bash "$SCRIPT_DIR/scripts/check-env.sh"

step 2 "Platform Selection"
SELECTED_PLATFORM="hermes-agent"
echo -e "${GREEN}[OK]${NC}   Platform: Hermes Agent"
load_platform_config "$SELECTED_PLATFORM" "$SCRIPT_DIR"

step 3 "Optional Tools Selection"
INSTALL_TMUX=false
INSTALL_TTYD=false
INSTALL_DUFS=false
INSTALL_ANDROID_TOOLS=false
INSTALL_TERMUX_SERVICES=false
INSTALL_GATEWAY_SERVICE=false

if ask_yn "Install tmux (terminal multiplexer)?"; then INSTALL_TMUX=true; fi
if ask_yn "Install ttyd (web terminal)?"; then INSTALL_TTYD=true; fi
if ask_yn "Install dufs (file server)?"; then INSTALL_DUFS=true; fi
if ask_yn "Install android-tools (adb)?"; then INSTALL_ANDROID_TOOLS=true; fi
if ask_yn "Install termux-services (runit) for background gateway?"; then
    INSTALL_TERMUX_SERVICES=true
    if ask_yn "Configure hermes gateway as a runit service (auto-start)?"; then
        INSTALL_GATEWAY_SERVICE=true
    fi
fi

step 4 "Core Infrastructure"
bash "$SCRIPT_DIR/scripts/install-infra-deps.sh"
bash "$SCRIPT_DIR/scripts/setup-paths.sh"

step 5 "Platform Runtime Dependencies"
if [ "${PLATFORM_NEEDS_PYTHON:-false}" = true ]; then
    bash "$SCRIPT_DIR/scripts/install-python.sh"
fi
if [ "${PLATFORM_NEEDS_BUILD_TOOLS:-false}" = true ]; then
    bash "$SCRIPT_DIR/scripts/install-build-tools.sh"
fi

# Source build env for current session (needed by setup-hermes.sh)
export OPENSSL_DIR="${OPENSSL_DIR:-$PREFIX}"
export ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-$(getprop ro.build.version.sdk 2>/dev/null || echo 24)}"
export TMPDIR="$PREFIX/tmp"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"

# Auto-detect PyPI index for current session
command -v resolve_pypi_index >/dev/null 2>&1 && resolve_pypi_index || true

step 6 "Platform Package Install"
bash "$SCRIPT_DIR/platforms/$SELECTED_PLATFORM/install.sh"

echo ""
echo -e "${BOLD}[6.5] Environment Variables + CLI + Marker${NC}"
echo "----------------------------------------"

mkdir -p "$PROJECT_DIR"
echo "$SELECTED_PLATFORM" > "$PLATFORM_MARKER"

bash "$SCRIPT_DIR/scripts/setup-env.sh"

PLATFORM_ENV_SCRIPT="$SCRIPT_DIR/platforms/$SELECTED_PLATFORM/env.sh"
if [ -f "$PLATFORM_ENV_SCRIPT" ]; then
    eval "$(bash "$PLATFORM_ENV_SCRIPT")"
fi

cp "$SCRIPT_DIR/ha.sh" "$PREFIX/bin/ha"
chmod +x "$PREFIX/bin/ha"
cp "$SCRIPT_DIR/update.sh" "$PREFIX/bin/haupdate"
chmod +x "$PREFIX/bin/haupdate"

cp "$SCRIPT_DIR/uninstall.sh" "$PROJECT_DIR/uninstall.sh"
chmod +x "$PROJECT_DIR/uninstall.sh"

mkdir -p "$PROJECT_DIR/scripts" "$PROJECT_DIR/platforms"
cp "$SCRIPT_DIR/scripts/lib.sh" "$PROJECT_DIR/scripts/lib.sh"
cp "$SCRIPT_DIR/scripts/setup-env.sh" "$PROJECT_DIR/scripts/setup-env.sh"
cp "$SCRIPT_DIR/scripts/backup.sh" "$PROJECT_DIR/scripts/backup.sh"
rm -rf "$PROJECT_DIR/platforms/$SELECTED_PLATFORM"
cp -R "$SCRIPT_DIR/platforms/$SELECTED_PLATFORM" "$PROJECT_DIR/platforms/$SELECTED_PLATFORM"

step 7 "Install Optional Tools"
if [ "$INSTALL_TMUX" = true ]; then pkg install -y tmux; fi
if [ "$INSTALL_TTYD" = true ]; then pkg install -y ttyd; fi
if [ "$INSTALL_DUFS" = true ]; then pkg install -y dufs; fi
if [ "$INSTALL_ANDROID_TOOLS" = true ]; then pkg install -y android-tools; fi
if [ "$INSTALL_TERMUX_SERVICES" = true ]; then
    pkg install -y termux-services
    # shellcheck source=/dev/null
    source "$PREFIX/etc/profile.d/start-services.sh" 2>/dev/null || true
fi

if [ "$INSTALL_GATEWAY_SERVICE" = true ]; then
    bash "$SCRIPT_DIR/scripts/install-gateway-service.sh" || \
        echo -e "${YELLOW}[WARN]${NC} Gateway service install failed (non-critical)"
fi

step 8 "Verification"
bash "$SCRIPT_DIR/tests/verify-install.sh"

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo -e "  $PLATFORM_NAME $($PLATFORM_VERSION_CMD 2>/dev/null || echo '')"
echo ""
echo "Next step:"
echo "  $PLATFORM_POST_INSTALL_MSG"
echo ""
