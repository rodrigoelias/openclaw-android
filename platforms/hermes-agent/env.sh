#!/usr/bin/env bash
# env.sh — hermes-agent platform environment variables
# Called by setup-env.sh; stdout is inserted into .bashrc block.
# Uses single-quoted heredoc to prevent variable expansion at install time
# (variables must expand at shell load time).

cat << 'EOF'
export HERMES_HOME="$HOME/.hermes"
EOF
