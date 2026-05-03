#!/usr/bin/env bash
# Hermes Android — Post-Bootstrap Setup
# Standalone installer that runs after a fresh Termux bootstrap (no `pkg` cache,
# no git, no curl). Bootstraps the minimum to clone hermes-android and chain
# into install.sh.
#
# Bundled with the standalone APK (android/app/src/main/assets/post-setup.sh).
# The "production" install path on a real Termux uses bootstrap.sh + install.sh.

set -eo pipefail

: "${PREFIX:?PREFIX not set}"
: "${HOME:?HOME not set}"
: "${TMPDIR:=$(dirname "$PREFIX")/tmp}"

HA_DIR="$HOME/.hermes-android"
INSTALLER_DIR="$HA_DIR/installer"
MARKER="$HA_DIR/.post-setup-done"
HERMES_ANDROID_TARBALL="https://github.com/rodrigoelias/hermes-android/archive/refs/heads/main.tar.gz"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── GitHub mirror fallback (for restricted networks) ──
REPO_BASE_ORIGIN="https://raw.githubusercontent.com/rodrigoelias/hermes-android/main"
REPO_BASE="$REPO_BASE_ORIGIN"
resolve_repo_base() {
    if curl -sI --connect-timeout 3 "$REPO_BASE_ORIGIN/ha.sh" >/dev/null 2>&1; then
        REPO_BASE="$REPO_BASE_ORIGIN"; return 0
    fi
    local mirrors=(
        "https://ghfast.top/$REPO_BASE_ORIGIN"
        "https://ghproxy.net/$REPO_BASE_ORIGIN"
        "https://mirror.ghproxy.com/$REPO_BASE_ORIGIN"
    )
    for m in "${mirrors[@]}"; do
        if curl -sI --connect-timeout 3 "$m/ha.sh" >/dev/null 2>&1; then
            echo -e "  ${YELLOW}[MIRROR]${NC} Using mirror for GitHub downloads"
            REPO_BASE="$m"; return 0
        fi
    done
    return 1
}

if [ -f "$MARKER" ]; then
    echo -e "${GREEN}Post-setup already completed.${NC}"
    exit 0
fi

echo ""
echo "══════════════════════════════════════════════"
echo "  Hermes Android — Bootstrapping"
echo "══════════════════════════════════════════════"
echo ""

mkdir -p "$HA_DIR" "$INSTALLER_DIR" "$TMPDIR"

# ── [1/3] Essentials: curl, git, python ──
echo -e "▸ ${YELLOW}[1/3]${NC} Installing essential packages..."

pkg update -y >/dev/null 2>&1 || true
for p in curl git python; do
    if command -v "$p" &>/dev/null || [ "$p" = python ] && command -v python3 &>/dev/null; then
        echo -e "  ${GREEN}[SKIP]${NC} $p already installed"
    else
        echo "  installing $p..."
        pkg install -y "$p" 2>&1 | tail -1
    fi
done

# ── [2/3] Download hermes-android installer ──
echo -e "▸ ${YELLOW}[2/3]${NC} Downloading installer..."

resolve_repo_base

if ! curl -sfL "$HERMES_ANDROID_TARBALL" | tar xz -C "$INSTALLER_DIR" --strip-components=1; then
    echo -e "  ${RED}✗${NC} Failed to download hermes-android tarball"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Downloaded"

# ── [3/3] Run installer ──
echo -e "▸ ${YELLOW}[3/3]${NC} Running install.sh..."
echo ""

bash "$INSTALLER_DIR/install.sh"

# ── Done ────────────────────────────────────
touch "$MARKER"

echo ""
echo "══════════════════════════════════════════════"
echo -e "  ${GREEN}✓ Bootstrap complete!${NC}"
echo "══════════════════════════════════════════════"
echo ""
echo "  Loading environment..."
# shellcheck source=/dev/null
source "$HOME/.bashrc"
echo ""
echo "  Run 'hermes setup' to configure API keys."
echo ""
