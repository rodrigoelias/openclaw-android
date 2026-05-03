#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/lib.sh"

BASHRC="$HOME/.bashrc"
PLATFORM=$(detect_platform) || true

INFRA_VARS="export TMPDIR=\"\$PREFIX/tmp\"
export TMP=\"\$TMPDIR\"
export TEMP=\"\$TMPDIR\""

# pip index re-injection — reads cache file written by resolve_pypi_index.
# Literal \$HOME, \${PIP_INDEX_URL:-}, and \$(cat ...) are preserved for
# runtime expansion in each new shell. -z guard lets users override manually.
PYPI_INDEX_INJECT="# pip index (auto-detected by Hermes Android, safe to override manually)
[ -z \"\${PIP_INDEX_URL:-}\" ] && [ -s \"\$HOME/.hermes-android/.pypi-index\" ] && \\
    export PIP_INDEX_URL=\"\$(cat \"\$HOME/.hermes-android/.pypi-index\")\""

PATH_LINE="export PATH=\"\$HOME/.local/bin:\$PATH\""

PLATFORM_VARS=""
PLATFORM_ENV_SCRIPT="$(dirname "$(dirname "$0")")/platforms/$PLATFORM/env.sh"
if [ -n "$PLATFORM" ] && [ -f "$PLATFORM_ENV_SCRIPT" ]; then
    PLATFORM_VARS=$(bash "$PLATFORM_ENV_SCRIPT")
fi

ENV_BLOCK="${BASHRC_MARKER_START}
# platform: ${PLATFORM:-none}
${PATH_LINE}
${INFRA_VARS}"

if [ -n "$PLATFORM_VARS" ]; then
    ENV_BLOCK="${ENV_BLOCK}
${PLATFORM_VARS}"
fi

ENV_BLOCK="${ENV_BLOCK}
${PYPI_INDEX_INJECT}
${BASHRC_MARKER_END}"

touch "$BASHRC"
if grep -qF "$BASHRC_MARKER_START" "$BASHRC"; then
    sed -i "/${BASHRC_MARKER_START//\//\\/}/,/${BASHRC_MARKER_END//\//\\/}/d" "$BASHRC"
fi
echo "" >> "$BASHRC"
echo "$ENV_BLOCK" >> "$BASHRC"
