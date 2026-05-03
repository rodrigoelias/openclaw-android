#!/usr/bin/env bash
# install-gateway-service.sh - Configure hermes gateway as a runit service (termux-services)
# Idempotent — re-running rewrites the run scripts but preserves existing logs.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/lib.sh"

if ! command -v sv &>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} termux-services not installed (sv missing). Run: pkg install termux-services"
    exit 1
fi

if ! command -v hermes &>/dev/null; then
    echo -e "${RED}[FAIL]${NC} hermes binary not found on PATH. Install hermes-agent first."
    exit 1
fi

SERVICE_DIR="$PREFIX/var/service/hermes-gateway"
mkdir -p "$SERVICE_DIR/log"

cat > "$SERVICE_DIR/run" << 'RUN'
#!/data/data/com.termux/files/usr/bin/sh
exec 2>&1
cd "$HOME"
exec hermes gateway run
RUN
chmod 700 "$SERVICE_DIR/run"

cat > "$SERVICE_DIR/log/run" << 'LOGRUN'
#!/data/data/com.termux/files/usr/bin/sh
pwd=${PWD%/*}
service=${pwd##*/}
mkdir -p "$LOGDIR/sv/$service"
exec svlogd -tt "$LOGDIR/sv/$service"
LOGRUN
chmod 700 "$SERVICE_DIR/log/run"

echo -e "${GREEN}[OK]${NC}   hermes-gateway runit service installed at $SERVICE_DIR"
echo ""
echo "Manage with:"
echo "  sv up hermes-gateway       # start"
echo "  sv status hermes-gateway   # status"
echo "  sv down hermes-gateway     # stop"
echo "  tail -f \$PREFIX/var/log/sv/hermes-gateway/current"
