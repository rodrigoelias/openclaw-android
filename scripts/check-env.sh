#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib.sh"

ERRORS=0

echo "=== Hermes on Android - Environment Check ==="
echo ""

if [ -z "${PREFIX:-}" ]; then
    echo -e "${RED}[FAIL]${NC} Not running in Termux (\$PREFIX not set)"
    echo "       This script is designed for Termux on Android."
    exit 1
else
    echo -e "${GREEN}[OK]${NC}   Termux detected (PREFIX=$PREFIX)"
fi

ARCH=$(uname -m)
echo -n "       Architecture: $ARCH"
if [ "$ARCH" = "aarch64" ]; then
    echo -e " ${GREEN}(recommended)${NC}"
elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "arm" ]; then
    echo -e " ${YELLOW}(supported, but aarch64 recommended)${NC}"
elif [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i686" ]; then
    echo -e " ${YELLOW}(emulator detected)${NC}"
else
    echo -e " ${YELLOW}(unknown, may not work)${NC}"
fi

AVAILABLE_MB=$(df "$PREFIX" 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
if [ -n "$AVAILABLE_MB" ] && [ "$AVAILABLE_MB" -lt 2000 ]; then
    echo -e "${YELLOW}[WARN]${NC} Low disk space: ${AVAILABLE_MB}MB available (recommended 2000MB+)"
elif [ -n "$AVAILABLE_MB" ] && [ "$AVAILABLE_MB" -lt 800 ]; then
    echo -e "${RED}[FAIL]${NC} Insufficient disk space: ${AVAILABLE_MB}MB available (need 800MB+)"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}[OK]${NC}   Disk space: ${AVAILABLE_MB:-unknown}MB available"
fi

if command -v python &>/dev/null; then
    PY_VER=$(python --version 2>/dev/null | awk '{print $2}')
    echo -e "${GREEN}[OK]${NC}   Python found: $PY_VER"
    if ! python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
        echo -e "${YELLOW}[WARN]${NC} Python >= 3.11 required. Will be upgraded during install."
    fi
else
    echo -e "${YELLOW}[INFO]${NC} Python not found. Will be installed via 'pkg install python'."
fi

SDK_INT=$(getprop ro.build.version.sdk 2>/dev/null || echo "0")
if [ "$SDK_INT" -ge 31 ] 2>/dev/null; then
    echo -e "${YELLOW}[INFO]${NC} Android 12+ detected — if background processes get killed (signal 9),"
    echo "       see: docs/disable-phantom-process-killer.md"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}Environment check failed with $ERRORS error(s).${NC}"
    exit 1
else
    echo -e "${GREEN}Environment check passed.${NC}"
fi
