#!/usr/bin/env bash
# lib.sh — Shared function library for all orchestrators
# Usage: source "$SCRIPT_DIR/scripts/lib.sh"  (from repo)
#        source "$PROJECT_DIR/scripts/lib.sh"  (from installed copy)

# ── Color constants ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── Project constants ──
PROJECT_DIR="$HOME/.hermes-android"
BIN_DIR="$PROJECT_DIR/bin"
PLATFORM_MARKER="$PROJECT_DIR/.platform"
HERMES_REPO_URL="https://github.com/rodrigoelias/hermes-agent.git"
HERMES_REPO_DIR="$PROJECT_DIR/hermes-agent"
REPO_BASE_ORIGIN="https://raw.githubusercontent.com/rodrigoelias/hermes-android/main"
REPO_BASE_MIRRORS=(
    "https://ghfast.top/https://raw.githubusercontent.com/rodrigoelias/hermes-android/main"
    "https://ghproxy.net/https://raw.githubusercontent.com/rodrigoelias/hermes-android/main"
    "https://mirror.ghproxy.com/https://raw.githubusercontent.com/rodrigoelias/hermes-android/main"
)
PYPI_INDEX_ORIGIN="https://pypi.org/simple/"
PYPI_INDEX_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple/"
PYPI_INDEX_CACHE="$PROJECT_DIR/.pypi-index"

# Detect reachable REPO_BASE (origin first, then mirrors)
resolve_repo_base() {
    if curl -sI --connect-timeout 3 "$REPO_BASE_ORIGIN/ha.sh" >/dev/null 2>&1; then
        REPO_BASE="$REPO_BASE_ORIGIN"
        return 0
    fi
    for mirror in "${REPO_BASE_MIRRORS[@]}"; do
        if curl -sI --connect-timeout 3 "$mirror/ha.sh" >/dev/null 2>&1; then
            echo -e "  ${YELLOW}[MIRROR]${NC} Using mirror: ${mirror%%/ha.sh*}"
            REPO_BASE="$mirror"
            return 0
        fi
    done
    # Fallback to origin even if unreachable
    REPO_BASE="$REPO_BASE_ORIGIN"
    return 1
}

# Detect reachable PyPI index and export PIP_INDEX_URL (origin first, then mirror)
resolve_pypi_index() {
    local choice
    local cache_file="$PYPI_INDEX_CACHE"
    local reachable=0
    if curl -sI --connect-timeout 5 "$PYPI_INDEX_ORIGIN" >/dev/null 2>&1; then
        choice="$PYPI_INDEX_ORIGIN"
        reachable=1
    elif curl -sI --connect-timeout 5 "$PYPI_INDEX_MIRROR" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[MIRROR]${NC} Using PyPI mirror: ${PYPI_INDEX_MIRROR}"
        choice="$PYPI_INDEX_MIRROR"
        reachable=1
    else
        choice="$PYPI_INDEX_ORIGIN"
    fi
    mkdir -p "$(dirname "$cache_file")"
    printf '%s' "$choice" > "$cache_file.tmp" && mv "$cache_file.tmp" "$cache_file"
    export PIP_INDEX_URL="$choice"
    if [ "$reachable" -eq 1 ]; then
        return 0
    fi
    return 1
}

# Initialize REPO_BASE
REPO_BASE="$REPO_BASE_ORIGIN"

BASHRC_MARKER_START="# >>> Hermes on Android >>>"
BASHRC_MARKER_END="# <<< Hermes on Android <<<"
HA_VERSION="0.1.0"

# ── Platform detection ──
# 1. Explicit marker file
# 2. Legacy detection via hermes binary
# 3. Detection failure
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

# ── Platform name validation ──
validate_platform_name() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -e "${RED}[FAIL]${NC} Platform name is empty"
        return 1
    fi
    # Only lowercase alphanumeric + hyphens/underscores allowed
    if [[ ! "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        echo -e "${RED}[FAIL]${NC} Invalid platform name: $name"
        return 1
    fi
    return 0
}

# ── User confirmation prompt ──
# Reads from /dev/tty so it works even in curl|bash mode.
ask_yn() {
    local prompt="$1"
    local reply
    if (echo -n "" > /dev/tty) 2>/dev/null; then
        read -rp "$prompt [Y/n] " reply < /dev/tty
    else
        read -rp "$prompt [Y/n] " reply
    fi
    [[ "${reply:-}" =~ ^[Nn]$ ]] && return 1
    return 0
}

# ── Load platform config.env ──
# $1: platform name, $2: base directory (parent of platforms/)
load_platform_config() {
    local platform="$1"
    local base_dir="$2"
    local config_path="$base_dir/platforms/$platform/config.env"

    validate_platform_name "$platform" || return 1

    if [ ! -f "$config_path" ]; then
        echo -e "${RED}[FAIL]${NC} Platform config not found: $config_path"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$config_path"
    return 0
}
