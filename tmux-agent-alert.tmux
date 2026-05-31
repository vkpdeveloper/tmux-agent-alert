#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/tmux.sh
. "$CURRENT_DIR/lib/tmux.sh"

main() {
  enabled="$(get_tmux_option "@agent-alert-enabled" "on")"
  key="$(get_tmux_option "@agent-alert-key" "A")"
  inspect_key="$(get_tmux_option "@agent-alert-inspect-key" "I")"

  if ! is_enabled "$enabled"; then
    return
  fi

  tmux bind-key "$key" run-shell -b "$CURRENT_DIR/bin/agent-alert toggle"
  tmux bind-key "$inspect_key" display-popup -E "$CURRENT_DIR/bin/agent-alert inspect-pane #{pane_id}; printf '\nPress enter to close...'; read _"
  tmux set-hook -g 'pane-exited[90]' "run-shell -b '$CURRENT_DIR/bin/agent-alert pane-exited #{pane_id}'"
  tmux run-shell -b "$CURRENT_DIR/bin/agent-alert start"
}

main
