#!/usr/bin/env bash
# install-python.sh - Install Python 3.11+ and pip via Termux pkg manager (L2 conditional)
# Called by orchestrator when config.env PLATFORM_NEEDS_PYTHON=true.
#
# Termux ships an aarch64 Python that uses Bionic libc — no glibc needed.
# Hermes-Agent supports this path via setup-hermes.sh / constraints-termux.txt.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Installing Python ==="
echo ""

if [ -z "${PREFIX:-}" ]; then
    echo -e "${RED}[FAIL]${NC} Not running in Termux (\$PREFIX not set)"
    exit 1
fi

# Pre-check: skip if already at 3.11+
if command -v python &>/dev/null; then
    if python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
        PY_VER=$(python --version 2>/dev/null | awk '{print $2}')
        echo -e "${GREEN}[SKIP]${NC} Python $PY_VER already installed"
    else
        echo -e "${YELLOW}[INFO]${NC} Upgrading Python via pkg..."
        pkg install -y python
    fi
else
    echo "Installing Python..."
    pkg install -y python
fi

# Verify Python is reachable and >= 3.11
if ! command -v python &>/dev/null; then
    echo -e "${RED}[FAIL]${NC} Python install failed — 'python' command still not found"
    exit 1
fi

if ! python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
    PY_VER=$(python --version 2>/dev/null | awk '{print $2}')
    echo -e "${RED}[FAIL]${NC} Termux Python is $PY_VER but hermes-agent requires >= 3.11"
    echo "       Try: pkg upgrade python"
    exit 1
fi

PY_VER=$(python --version 2>/dev/null | awk '{print $2}')
echo -e "${GREEN}[OK]${NC}   Python $PY_VER"

# Ensure pip is functional and reasonably current.
if command -v pip &>/dev/null; then
    PIP_VER=$(pip --version 2>/dev/null | awk '{print $2}')
    echo -e "${GREEN}[OK]${NC}   pip $PIP_VER"
else
    echo -e "${YELLOW}[INFO]${NC} pip not found — installing via ensurepip"
    python -m ensurepip --upgrade
fi

python -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 \
    && echo -e "${GREEN}[OK]${NC}   pip / setuptools / wheel upgraded" \
    || echo -e "${YELLOW}[WARN]${NC} pip self-upgrade failed (non-critical)"

echo ""
echo -e "${GREEN}Python installed successfully.${NC}"
