#!/usr/bin/env bash
# install-build-tools.sh - Install build tools for compiling native Python wheels (L2 conditional)
# Called by orchestrator when config.env PLATFORM_NEEDS_BUILD_TOOLS=true.
#
# Hermes-Agent has 14 native Python extensions (pydantic-core, jiter, cryptography,
# cffi, aiohttp, PyYAML, MarkupSafe, msgpack, ...). On Termux these compile from
# source — Rust + clang + libffi + openssl headers are required.
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Installing Build Tools ==="
echo ""

PACKAGES=(
    rust            # pydantic-core, jiter, cryptography
    clang           # cffi, aiohttp, PyYAML, MarkupSafe, msgpack
    make
    cmake
    binutils
    libffi          # cffi build dep
    openssl         # cryptography build dep
    pkg-config
    libxml2         # lxml (transitive)
    libxslt         # lxml (transitive)
    libjpeg-turbo   # Pillow (if pulled in)
    zlib            # cryptography build dep
)

echo "Installing packages: ${PACKAGES[*]}"
echo "  (This may take 5-10 minutes depending on network speed)"
pkg install -y "${PACKAGES[@]}"

# Create ar symlink if missing (Termux provides llvm-ar but not ar)
if [ ! -e "$PREFIX/bin/ar" ] && [ -x "$PREFIX/bin/llvm-ar" ]; then
    ln -s "$PREFIX/bin/llvm-ar" "$PREFIX/bin/ar"
    echo -e "${GREEN}[OK]${NC}   Created ar -> llvm-ar symlink"
fi

# Hermes' setup-hermes.sh expects these env vars to find OpenSSL during cryptography build
if ! grep -q '^export OPENSSL_DIR=' "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "# Hermes build env (cryptography needs OpenSSL headers)" >> "$HOME/.bashrc"
    echo "export OPENSSL_DIR=\"\$PREFIX\"" >> "$HOME/.bashrc"
    echo -e "${GREEN}[OK]${NC}   Added OPENSSL_DIR to .bashrc"
fi

# ANDROID_API_LEVEL helps maturin (Rust extensions) target the right Android API
if ! grep -q '^export ANDROID_API_LEVEL=' "$HOME/.bashrc" 2>/dev/null; then
    SDK_INT=$(getprop ro.build.version.sdk 2>/dev/null || echo "24")
    echo "export ANDROID_API_LEVEL=\"$SDK_INT\"" >> "$HOME/.bashrc"
    echo -e "${GREEN}[OK]${NC}   Added ANDROID_API_LEVEL=$SDK_INT to .bashrc"
fi

echo ""
echo -e "${YELLOW}[NOTE]${NC} If installation crashes during pip wheel build,"
echo "       run: termux-wake-lock"
echo ""
echo -e "${GREEN}Build tools installed.${NC}"
