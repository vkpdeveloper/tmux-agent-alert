#!/usr/bin/env sh

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/scripts/helpers.sh"

main() {
  enabled="$(get_tmux_option "@agent-alert-enabled" "on")"
  key="$(get_tmux_option "@agent-alert-key" "A")"

  if ! is_enabled "$enabled"; then
    return
  fi

  tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/toggle.sh"
}

main

