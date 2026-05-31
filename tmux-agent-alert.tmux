#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/tmux.sh
. "$CURRENT_DIR/lib/tmux.sh"

install_status_styles() {
  original_format="$(tmux show-option -gqv "@agent-alert-original-window-status-format")"
  original_current_format="$(tmux show-option -gqv "@agent-alert-original-window-status-current-format")"
  original_style="$(tmux show-option -gqv "@agent-alert-original-window-status-style")"
  original_current_style="$(tmux show-option -gqv "@agent-alert-original-window-status-current-style")"

  if [ -z "$original_format" ]; then
    original_format="$(tmux show-option -gqv "window-status-format")"
  fi

  if [ -z "$original_current_format" ]; then
    original_current_format="$(tmux show-option -gqv "window-status-current-format")"
  fi

  original_format="$(strip_agent_alert_status_prefix "$original_format")"
  original_current_format="$(strip_agent_alert_status_prefix "$original_current_format")"

  if [ -z "$original_style" ]; then
    original_style="$(strip_agent_alert_status_style "$(tmux show-option -gqv "window-status-style")")"
  fi

  if [ -z "$original_current_style" ]; then
    original_current_style="$(strip_agent_alert_status_style "$(tmux show-option -gqv "window-status-current-style")")"
  fi

  tmux set-option -gq "@agent-alert-original-window-status-format" "$original_format"
  tmux set-option -gq "@agent-alert-original-window-status-current-format" "$original_current_format"
  tmux set-option -gq "@agent-alert-original-window-status-style" "$original_style"
  tmux set-option -gq "@agent-alert-original-window-status-current-style" "$original_current_style"

  tmux set-option -gq "window-status-format" "$original_format"
  tmux set-option -gq "window-status-current-format" "$original_current_format"
  tmux set-option -gq "window-status-style" "$(agent_alert_status_style "$original_style")"
  tmux set-option -gq "window-status-current-style" "$(agent_alert_status_style "$original_current_style")"
}

strip_agent_alert_status_prefix() {
  local value="$1"
  local old_prefix='#{?#{==:#{@agent-alert-attention},red},#[fg=red,bold],#{?#{==:#{@agent-alert-attention},yellow},#[fg=yellow,bold],}}'
  local red_yellow_prefix='#{?#{==:#{@agent-alert-attention},red},#[bg=red,fg=black,bold],#{?#{==:#{@agent-alert-attention},yellow},#[bg=yellow,fg=black,bold],}}'
  local red_green_black_prefix='#{?#{==:#{@agent-alert-attention},red},#[bg=red,fg=black,bold],#{?#{==:#{@agent-alert-attention},green},#[bg=green,fg=black,bold],}}'
  local red_green_prefix

  red_green_prefix="$(agent_alert_status_prefix)"

  case "$value" in
    "$old_prefix"*)
      value="${value#"$old_prefix"}"
      ;;
    "$red_yellow_prefix"*)
      value="${value#"$red_yellow_prefix"}"
      ;;
    "$red_green_black_prefix"*)
      value="${value#"$red_green_black_prefix"}"
      ;;
    "$red_green_prefix"*)
      value="${value#"$red_green_prefix"}"
      ;;
  esac

  printf '%s\n' "$value"
}

agent_alert_status_prefix() {
  printf '%s' '#{?#{==:#{@agent-alert-attention},red},#[bg=red,fg=white,bold],#{?#{==:#{@agent-alert-attention},green},#[bg=green,fg=white,bold],}}'
}

strip_agent_alert_status_style() {
  local value="$1"

  case "$value" in
    *"@agent-alert-attention"*)
      printf '%s\n' ""
      ;;
    *)
      printf '%s\n' "$value"
      ;;
  esac
}

escape_tmux_format_commas() {
  printf '%s' "$1" | sed 's/,/#,/g'
}

agent_alert_status_style() {
  local original_style="$1"

  printf '%s' "#{?#{==:#{@agent-alert-attention},red},bg=red#,fg=white#,bold,#{?#{==:#{@agent-alert-attention},green},bg=green#,fg=white#,bold,$(escape_tmux_format_commas "$original_style")}}"
}

main() {
  enabled="$(get_tmux_option "@agent-alert-enabled" "on")"
  key="$(get_tmux_option "@agent-alert-key" "A")"
  inspect_key="$(get_tmux_option "@agent-alert-inspect-key" "M-i")"

  if ! is_enabled "$enabled"; then
    return
  fi

  install_status_styles

  tmux bind-key "$key" run-shell -b "$CURRENT_DIR/bin/agent-alert toggle"
  tmux bind-key "$inspect_key" display-popup -E "$CURRENT_DIR/bin/agent-alert inspect-pane #{pane_id}; printf '\nPress enter to close...'; read _"
  tmux set-hook -g 'pane-exited[90]' "run-shell -b '$CURRENT_DIR/bin/agent-alert pane-exited #{pane_id}'"
  tmux run-shell -b "$CURRENT_DIR/bin/agent-alert start"
}

main
