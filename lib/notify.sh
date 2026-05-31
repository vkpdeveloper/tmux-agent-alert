#!/usr/bin/env bash

# shellcheck source=lib/macos.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/macos.sh"

json_escape() {
  local value="$1"

  printf '%s' "$value" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || {
    printf '"%s"' "$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  }
}

osascript_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

notify_user() {
  local title="$1"
  local message="$2"
  local backend="${3:-auto}"
  local webhook_url="${4:-}"
  local state_dir="${5:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-agent-alert}"
  local macos_sender_bundle="${6:-auto}"
  local subtitle="${7:-}"

  if [ -n "$webhook_url" ] && command -v curl >/dev/null 2>&1; then
    local json_message
    json_message="$(json_escape "$message")"
    curl -fsS -X POST "$webhook_url" \
      -H 'Content-Type: application/json' \
      -d "{\"text\":$json_message}" >/dev/null 2>&1 || true
  fi

  case "$backend" in
    off|none|disabled|tmux)
      return 1
      ;;
    macos-terminal)
      macos_display_notification_from_terminal "$title" "$message" "$state_dir" "$macos_sender_bundle" "$subtitle" && return
      ;;
    terminal-notifier)
      command -v terminal-notifier >/dev/null 2>&1 && {
        if [ -n "$subtitle" ]; then
          terminal-notifier -title "$title" -subtitle "$subtitle" -message "$message"
        else
          terminal-notifier -title "$title" -message "$message"
        fi
        return
      }
      ;;
    osascript)
      command -v osascript >/dev/null 2>&1 && {
        if [ -n "$subtitle" ]; then
          osascript -e "display notification \"$(osascript_escape "$message")\" with title \"$(osascript_escape "$title")\" subtitle \"$(osascript_escape "$subtitle")\"" >/dev/null 2>&1
        else
          osascript -e "display notification \"$(osascript_escape "$message")\" with title \"$(osascript_escape "$title")\"" >/dev/null 2>&1
        fi
        return
      }
      ;;
    notify-send)
      command -v notify-send >/dev/null 2>&1 && {
        notify-send "$title" "$message"
        return
      }
      ;;
    bell)
      printf '\a'
      return
      ;;
    auto)
      if is_macos && macos_display_notification_from_terminal "$title" "$message" "$state_dir" "$macos_sender_bundle" "$subtitle"; then
        return
      fi
      ;;
    *)
      ;;
  esac

  if command -v terminal-notifier >/dev/null 2>&1; then
    if [ -n "$subtitle" ]; then
      terminal-notifier -title "$title" -subtitle "$subtitle" -message "$message"
    else
      terminal-notifier -title "$title" -message "$message"
    fi
  elif command -v osascript >/dev/null 2>&1; then
    if [ -n "$subtitle" ]; then
      osascript -e "display notification \"$(osascript_escape "$message")\" with title \"$(osascript_escape "$title")\" subtitle \"$(osascript_escape "$subtitle")\"" >/dev/null 2>&1
    else
      osascript -e "display notification \"$(osascript_escape "$message")\" with title \"$(osascript_escape "$title")\"" >/dev/null 2>&1
    fi
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$message"
  else
    printf '\a'
    return 1
  fi
}
