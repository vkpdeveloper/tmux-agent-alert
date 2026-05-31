#!/usr/bin/env sh

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/helpers.sh"

enabled="$(get_tmux_option "@agent-alert-enabled" "on")"

if is_enabled "$enabled"; then
  set_tmux_option "@agent-alert-enabled" "off"
  tmux display-message "tmux-agent-alert disabled"
else
  set_tmux_option "@agent-alert-enabled" "on"
  tmux display-message "tmux-agent-alert enabled"
fi

