#!/usr/bin/env sh

get_tmux_option() {
  option="$1"
  default_value="$2"

  value="$(tmux show-option -gqv "$option")"

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
    return
  fi

  printf '%s\n' "$default_value"
}

set_tmux_option() {
  option="$1"
  value="$2"

  tmux set-option -gq "$option" "$value"
}

is_enabled() {
  value="$1"

  case "$value" in
    1|on|true|yes|enabled)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

