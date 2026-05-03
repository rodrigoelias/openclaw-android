#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/lib.sh"

echo "=== Setting Up Paths ==="
echo ""

mkdir -p "$PREFIX/tmp"
echo -e "${GREEN}[OK]${NC}   Created $PREFIX/tmp"

mkdir -p "$PROJECT_DIR"
echo -e "${GREEN}[OK]${NC}   Created $PROJECT_DIR"

echo ""
echo -e "${GREEN}Path setup complete.${NC}"
