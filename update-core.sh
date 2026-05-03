#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_DIR="$HOME/.hermes-android"
PLATFORM_MARKER="$PROJECT_DIR/.platform"
HA_VERSION="0.1.0"

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Hermes on Android - Updater v${HA_VERSION}${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

step() {
    echo ""
    echo -e "${BOLD}[$1/4] $2${NC}"
    echo "----------------------------------------"
}

step 1 "Pre-flight Check"

if [ -z "${PREFIX:-}" ]; then
    echo -e "${RED}[FAIL]${NC} Not running in Termux (\$PREFIX not set)"
    exit 1
fi
echo -e "${GREEN}[OK]${NC}   Termux detected"

if ! command -v curl &>/dev/null; then
    echo -e "${RED}[FAIL]${NC} curl not found. Install it with: pkg install curl"
    exit 1
fi

mkdir -p "$PROJECT_DIR"

if [ -f "$PROJECT_DIR/scripts/lib.sh" ]; then
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/scripts/lib.sh"
fi
command -v resolve_pypi_index >/dev/null 2>&1 && resolve_pypi_index || true

REPO_TARBALL="https://github.com/rodrigoelias/hermes-android/archive/refs/heads/main.tar.gz"

if ! declare -f detect_platform &>/dev/null; then
    detect_platform() {
        if [ -f "$PLATFORM_MARKER" ]; then
            cat "$PLATFORM_MARKER"
            return 0
        fi
        if command -v hermes &>/dev/null; then
            echo "hermes-agent"
            mkdir -p "$(dirname "$PLATFORM_MARKER")"
            echo "hermes-agent" > "$PLATFORM_MARKER"
            return 0
        fi
        echo ""
        return 1
    }
fi

PLATFORM=$(detect_platform) || PLATFORM=""
if [ -z "$PLATFORM" ]; then
    echo -e "${YELLOW}[WARN]${NC} No platform detected — assuming hermes-agent"
    PLATFORM="hermes-agent"
fi
echo -e "${GREEN}[OK]${NC}   Platform: $PLATFORM"

step 2 "Download Latest Release (tarball)"

mkdir -p "$PREFIX/tmp"
RELEASE_TMP=$(mktemp -d "$PREFIX/tmp/ha-update.XXXXXX") || {
    echo -e "${RED}[FAIL]${NC} Failed to create temp directory"
    exit 1
}
trap 'rm -rf "$RELEASE_TMP"' EXIT

echo "Downloading latest scripts..."
if curl -sfL "$REPO_TARBALL" | tar xz -C "$RELEASE_TMP" --strip-components=1; then
    echo -e "${GREEN}[OK]${NC}   Downloaded latest release"
else
    echo -e "${RED}[FAIL]${NC} Failed to download release"
    exit 1
fi

REQUIRED_FILES=(
    "scripts/lib.sh"
    "scripts/setup-env.sh"
    "platforms/$PLATFORM/config.env"
    "platforms/$PLATFORM/update.sh"
)
for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$RELEASE_TMP/$f" ]; then
        echo -e "${RED}[FAIL]${NC} Missing required file: $f"
        exit 1
    fi
done
echo -e "${GREEN}[OK]${NC}   All required files verified"

# shellcheck source=/dev/null
source "$RELEASE_TMP/scripts/lib.sh"

step 3 "Refresh Installed Files"

mkdir -p "$PROJECT_DIR/platforms" "$PROJECT_DIR/scripts"

rm -rf "$PROJECT_DIR/platforms/$PLATFORM"
cp -r "$RELEASE_TMP/platforms/$PLATFORM" "$PROJECT_DIR/platforms/"

cp "$RELEASE_TMP/scripts/lib.sh" "$PROJECT_DIR/scripts/lib.sh"
cp "$RELEASE_TMP/scripts/setup-env.sh" "$PROJECT_DIR/scripts/setup-env.sh"
if [ -f "$RELEASE_TMP/scripts/backup.sh" ]; then
    cp "$RELEASE_TMP/scripts/backup.sh" "$PROJECT_DIR/scripts/backup.sh"
fi

cp "$RELEASE_TMP/ha.sh" "$PREFIX/bin/ha"
chmod +x "$PREFIX/bin/ha"

cp "$RELEASE_TMP/update.sh" "$PREFIX/bin/haupdate"
chmod +x "$PREFIX/bin/haupdate"

cp "$RELEASE_TMP/uninstall.sh" "$PROJECT_DIR/uninstall.sh"
chmod +x "$PROJECT_DIR/uninstall.sh"

bash "$RELEASE_TMP/scripts/setup-env.sh"

# Ensure build env is sourced for current session
export OPENSSL_DIR="${OPENSSL_DIR:-$PREFIX}"
export ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-$(getprop ro.build.version.sdk 2>/dev/null || echo 24)}"
export TMPDIR="$PREFIX/tmp"

PLATFORM_ENV_SCRIPT="$RELEASE_TMP/platforms/$PLATFORM/env.sh"
if [ -f "$PLATFORM_ENV_SCRIPT" ]; then
    eval "$(bash "$PLATFORM_ENV_SCRIPT")"
fi

step 4 "Update Platform"

if [ -f "$RELEASE_TMP/platforms/$PLATFORM/update.sh" ]; then
    bash "$RELEASE_TMP/platforms/$PLATFORM/update.sh"
else
    echo -e "${YELLOW}[WARN]${NC} Platform update script not found"
fi

echo ""
echo -e "${GREEN}${BOLD}  Update Complete!${NC}"
echo ""
echo -e "${YELLOW}Run this to apply environment changes to the current session:${NC}"
echo ""
echo "  source ~/.bashrc"
