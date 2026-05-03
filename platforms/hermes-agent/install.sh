#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"

echo "=== Installing hermes-agent Platform Package ==="
echo ""

# Termux's prebuilt wheels for some Python packages need these env vars
export OPENSSL_DIR="${OPENSSL_DIR:-$PREFIX}"
export ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-$(getprop ro.build.version.sdk 2>/dev/null || echo 24)}"

# ── Clone or update the repository ──
if [ -d "$HERMES_REPO_DIR/.git" ]; then
    echo "Existing hermes-agent repo detected — updating..."
    git -C "$HERMES_REPO_DIR" fetch --depth=1 origin main 2>/dev/null \
        || git -C "$HERMES_REPO_DIR" fetch origin main
    git -C "$HERMES_REPO_DIR" reset --hard origin/main
    echo -e "${GREEN}[OK]${NC}   Updated hermes-agent repo"
else
    echo "Cloning hermes-agent from $HERMES_REPO_URL..."
    rm -rf "$HERMES_REPO_DIR"
    if ! git clone --depth=1 "$HERMES_REPO_URL" "$HERMES_REPO_DIR"; then
        echo "  shallow clone failed, retrying with full clone..."
        rm -rf "$HERMES_REPO_DIR"
        git clone "$HERMES_REPO_URL" "$HERMES_REPO_DIR"
    fi
    echo -e "${GREEN}[OK]${NC}   Cloned hermes-agent"
fi

# ── Run setup-hermes.sh from the repo (it's Termux-aware) ──
cd "$HERMES_REPO_DIR"

if [ ! -f "setup-hermes.sh" ]; then
    echo -e "${RED}[FAIL]${NC} setup-hermes.sh not found in $HERMES_REPO_DIR"
    exit 1
fi

# setup-hermes.sh interactively asks "run setup wizard now?" at the end.
# Pre-answer "n" so unattended install completes without blocking.
echo ""
echo "Running setup-hermes.sh (Termux-aware installer from upstream)..."
echo "  (This compiles native wheels — may take 5-15 minutes on first run)"
echo ""
chmod +x setup-hermes.sh
yes n | bash setup-hermes.sh || {
    echo -e "${RED}[FAIL]${NC} setup-hermes.sh failed"
    exit 1
}

# ── Verify hermes is reachable ──
HERMES_BIN="$HERMES_REPO_DIR/venv/bin/hermes"
if [ ! -x "$HERMES_BIN" ]; then
    echo -e "${RED}[FAIL]${NC} hermes binary not found at $HERMES_BIN"
    exit 1
fi

# Symlink into $PREFIX/bin so `hermes` is on PATH everywhere.
# setup-hermes.sh already does this, but reassert in case PATH layering changes.
ln -sf "$HERMES_BIN" "$PREFIX/bin/hermes"
echo -e "${GREEN}[OK]${NC}   Symlinked hermes -> $PREFIX/bin/hermes"

mkdir -p "$HOME/.hermes"

echo ""
echo -e "${GREEN}[OK]${NC}   hermes-agent installed"
hermes --version 2>/dev/null || echo "  (hermes binary registered)"
