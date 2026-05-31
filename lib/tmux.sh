#!/usr/bin/env bash

get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local value

  value="$(tmux show-option -gqv "$option" 2>/dev/null || true)"

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$default_value"
  fi
}

set_tmux_option() {
  local option="$1"
  local value="$2"

  tmux set-option -gq "$option" "$value"
}

is_enabled() {
  local value="${1:-}"

  case "$value" in
    1|on|true|yes|enabled)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

tmux_has_session() {
  tmux list-sessions >/dev/null 2>&1
}

