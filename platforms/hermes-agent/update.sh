#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../scripts/lib.sh"

echo "=== Updating hermes-agent Platform ==="
echo ""

if [ ! -d "$HERMES_REPO_DIR/.git" ]; then
    echo -e "${YELLOW}[WARN]${NC} No existing hermes-agent clone found — running fresh install"
    bash "$SCRIPT_DIR/install.sh"
    exit 0
fi

# ── Capture current revision for change detection ──
OLD_HEAD=$(git -C "$HERMES_REPO_DIR" rev-parse HEAD 2>/dev/null || echo "")

echo "Fetching latest hermes-agent from origin..."
git -C "$HERMES_REPO_DIR" fetch origin main
git -C "$HERMES_REPO_DIR" reset --hard origin/main

NEW_HEAD=$(git -C "$HERMES_REPO_DIR" rev-parse HEAD 2>/dev/null || echo "")

if [ "$OLD_HEAD" = "$NEW_HEAD" ] && [ -x "$HERMES_REPO_DIR/venv/bin/hermes" ]; then
    echo -e "${GREEN}[OK]${NC}   hermes-agent already at latest commit ($NEW_HEAD)"
else
    echo "Updating Python dependencies..."
    cd "$HERMES_REPO_DIR"

    # Reinstall in editable mode against current pyproject.toml.
    # Use the venv pip directly so we don't depend on shell activation.
    VENV_PIP="$HERMES_REPO_DIR/venv/bin/pip"
    if [ ! -x "$VENV_PIP" ]; then
        echo "  venv missing — re-running setup-hermes.sh"
        chmod +x setup-hermes.sh
        yes n | bash setup-hermes.sh
    else
        if [ -f "constraints-termux.txt" ]; then
            "$VENV_PIP" install --upgrade -e ".[termux]" -c constraints-termux.txt \
                || "$VENV_PIP" install --upgrade -e "." -c constraints-termux.txt
        else
            "$VENV_PIP" install --upgrade -e ".[termux]" \
                || "$VENV_PIP" install --upgrade -e "."
        fi
        echo -e "${GREEN}[OK]${NC}   Dependencies updated"
    fi
fi

# ── Re-symlink hermes (paths can drift after venv rebuild) ──
HERMES_BIN="$HERMES_REPO_DIR/venv/bin/hermes"
if [ -x "$HERMES_BIN" ]; then
    ln -sf "$HERMES_BIN" "$PREFIX/bin/hermes"
    echo -e "${GREEN}[OK]${NC}   hermes symlink refreshed"
else
    echo -e "${YELLOW}[WARN]${NC} hermes binary missing at $HERMES_BIN"
fi

# ── Re-sync bundled skills (idempotent) ──
SKILLS_DIR="$HOME/.hermes/skills"
mkdir -p "$SKILLS_DIR"
if [ -x "$HERMES_REPO_DIR/venv/bin/python" ] && [ -f "$HERMES_REPO_DIR/tools/skills_sync.py" ]; then
    "$HERMES_REPO_DIR/venv/bin/python" "$HERMES_REPO_DIR/tools/skills_sync.py" 2>/dev/null \
        && echo -e "${GREEN}[OK]${NC}   Skills synced" \
        || echo -e "${YELLOW}[WARN]${NC} Skills sync skipped"
fi
