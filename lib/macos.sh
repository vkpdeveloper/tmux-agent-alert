#!/usr/bin/env bash

is_macos() {
  [ "$(uname -s 2>/dev/null || true)" = "Darwin" ]
}

notification_command_timeout() {
  local timeout="${AGENT_ALERT_NOTIFICATION_TIMEOUT:-2}"

  case "$timeout" in
    ''|*[!0-9]*)
      printf '%s\n' "2"
      ;;
    *)
      printf '%s\n' "$timeout"
      ;;
  esac
}

run_notification_command_with_timeout() {
  local timeout="$1"
  shift

  (
    trap - EXIT INT TERM

    if [ "${timeout:-0}" -le 0 ] 2>/dev/null; then
      "$@" >/dev/null 2>&1
      exit "$?"
    fi

    "$@" >/dev/null 2>&1 &
    pid="$!"
    elapsed=0

    while kill -0 "$pid" >/dev/null 2>&1; do
      if [ "$elapsed" -ge "$timeout" ]; then
        kill "$pid" >/dev/null 2>&1 || true
        sleep 0.2
        kill -9 "$pid" >/dev/null 2>&1 || true
        wait "$pid" >/dev/null 2>&1 || true
        exit 124
      fi

      sleep 1
      elapsed=$((elapsed + 1))
    done

    wait "$pid" >/dev/null 2>&1
  ) 2>/dev/null
}

macos_escape_applescript() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

macos_app_path_from_pid() {
  local pid="$1"
  local args app_path

  args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
  app_path="$(printf '%s\n' "$args" | sed -n 's#^\([^[:space:]]*\.app\)/Contents/MacOS/.*#\1#p' | head -1)"

  if [ -n "$app_path" ]; then
    printf '%s\n' "$app_path"
    return 0
  fi

  return 1
}

macos_bundle_id_from_app_path() {
  local app_path="$1"
  local bundle_id=""

  if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
    return 1
  fi

  if command -v mdls >/dev/null 2>&1; then
    bundle_id="$(mdls -raw -name kMDItemCFBundleIdentifier "$app_path" 2>/dev/null || true)"
    [ "$bundle_id" != "(null)" ] || bundle_id=""
  fi

  if [ -z "$bundle_id" ] && command -v plutil >/dev/null 2>&1; then
    bundle_id="$(plutil -extract CFBundleIdentifier raw "$app_path/Contents/Info.plist" 2>/dev/null || true)"
  fi

  if [ -n "$bundle_id" ]; then
    printf '%s\n' "$bundle_id"
    return 0
  fi

  return 1
}

macos_bundle_id_from_app_name() {
  local app_name="$1"
  [ -n "$app_name" ] || return 1

  osascript -e "id of application \"$(macos_escape_applescript "$app_name")\"" 2>/dev/null || true
}

macos_known_terminal_bundle_id() {
  local process_name="$1"

  case "$process_name" in
    Terminal)
      printf '%s\n' "com.apple.Terminal"
      ;;
    iTerm2|iTerm)
      printf '%s\n' "com.googlecode.iterm2"
      ;;
    ghostty|Ghostty)
      printf '%s\n' "com.mitchellh.ghostty"
      ;;
    WezTerm|wezterm-gui)
      printf '%s\n' "com.github.wez.wezterm"
      ;;
    kitty)
      printf '%s\n' "net.kovidgoyal.kitty"
      ;;
    Alacritty|alacritty)
      printf '%s\n' "org.alacritty"
      ;;
    Warp|stable)
      printf '%s\n' "dev.warp.Warp-Stable"
      ;;
    *)
      return 1
      ;;
  esac
}

macos_terminal_bundle_from_tty() {
  local tty="$1"
  local tty_name pid ppid comm app_path bundle_id depth

  is_macos || return 1

  tty_name="${tty#/dev/}"
  [ -n "$tty_name" ] || return 1

  while read -r pid _ppid _comm; do
    [ -n "${pid:-}" ] || continue

    depth=0
    while [ "$pid" != "0" ] && [ -n "$pid" ] && [ "$depth" -lt 20 ]; do
      app_path="$(macos_app_path_from_pid "$pid" || true)"
      if [ -n "$app_path" ]; then
        bundle_id="$(macos_bundle_id_from_app_path "$app_path" || true)"
        if [ -n "$bundle_id" ]; then
          printf '%s\n' "$bundle_id"
          return 0
        fi
      fi

      comm="$(basename "$(ps -p "$pid" -o comm= 2>/dev/null || true)")"
      bundle_id="$(macos_known_terminal_bundle_id "$comm" || true)"
      if [ -n "$bundle_id" ]; then
        printf '%s\n' "$bundle_id"
        return 0
      fi

      ppid="$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d '[:space:]' || true)"
      pid="$ppid"
      depth=$((depth + 1))
    done
  done < <(ps -t "$tty_name" -o pid=,ppid=,comm= 2>/dev/null || true)

  return 1
}

macos_terminal_bundle_from_tmux_clients() {
  local state_dir="$1"
  local cached_file="$state_dir/macos-sender-bundle"
  local tty bundle_id

  is_macos || return 1

  while IFS='|' read -r tty _client_name _client_termname; do
    [ -n "$tty" ] || continue

    bundle_id="$(macos_terminal_bundle_from_tty "$tty" || true)"
    if [ -n "$bundle_id" ]; then
      mkdir -p "$state_dir"
      printf '%s\n' "$bundle_id" > "$cached_file"
      printf '%s\n' "$bundle_id"
      return 0
    fi
  done < <(tmux list-clients -F '#{client_tty}|#{client_name}|#{client_termname}' 2>/dev/null || true)

  if [ -f "$cached_file" ]; then
    bundle_id="$(cat "$cached_file" 2>/dev/null || true)"
    if [ -n "$bundle_id" ]; then
      printf '%s\n' "$bundle_id"
      return 0
    fi
  fi

  return 1
}

macos_application_is_running() {
  local bundle_id="$1"
  local running

  running="$(osascript -e "application id \"$(macos_escape_applescript "$bundle_id")\" is running" 2>/dev/null || true)"
  [ "$running" = "true" ]
}

macos_display_notification_from_bundle() {
  local bundle_id="$1"
  local title="$2"
  local message="$3"
  local require_running="${4:-no}"
  local subtitle="${5:-}"
  local timeout

  is_macos || return 1
  [ -n "$bundle_id" ] || return 1
  command -v osascript >/dev/null 2>&1 || return 1

  if [ "$require_running" = "yes" ] && ! macos_application_is_running "$bundle_id"; then
    return 1
  fi

  timeout="$(notification_command_timeout)"

  if [ -n "$subtitle" ]; then
    run_notification_command_with_timeout "$timeout" osascript \
      -e "tell application id \"$(macos_escape_applescript "$bundle_id")\"" \
      -e "display notification \"$(macos_escape_applescript "$message")\" with title \"$(macos_escape_applescript "$title")\" subtitle \"$(macos_escape_applescript "$subtitle")\"" \
      -e "end tell"
  else
    run_notification_command_with_timeout "$timeout" osascript \
      -e "tell application id \"$(macos_escape_applescript "$bundle_id")\"" \
      -e "display notification \"$(macos_escape_applescript "$message")\" with title \"$(macos_escape_applescript "$title")\"" \
      -e "end tell"
  fi
}

macos_display_notification_from_terminal() {
  local title="$1"
  local message="$2"
  local state_dir="$3"
  local preferred_bundle="${4:-}"
  local subtitle="${5:-}"
  local bundle_id
  local require_running="yes"
  local timeout

  is_macos || return 1

  if [ -n "$preferred_bundle" ] && [ "$preferred_bundle" != "auto" ]; then
    bundle_id="$preferred_bundle"
    require_running="no"
  else
    bundle_id="$(macos_terminal_bundle_from_tmux_clients "$state_dir" || true)"
  fi

  [ -n "$bundle_id" ] || return 1

  timeout="$(notification_command_timeout)"

  if command -v terminal-notifier >/dev/null 2>&1; then
    if [ -n "$subtitle" ]; then
      run_notification_command_with_timeout "$timeout" terminal-notifier -sender "$bundle_id" -title "$title" -subtitle "$subtitle" -message "$message" && return 0
      run_notification_command_with_timeout "$timeout" terminal-notifier -title "$title" -subtitle "$subtitle" -message "$message" && return 0
    else
      run_notification_command_with_timeout "$timeout" terminal-notifier -sender "$bundle_id" -title "$title" -message "$message" && return 0
      run_notification_command_with_timeout "$timeout" terminal-notifier -title "$title" -message "$message" && return 0
    fi
  fi

  macos_display_notification_from_bundle "$bundle_id" "$title" "$message" "$require_running" "$subtitle"
}
