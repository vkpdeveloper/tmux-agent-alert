#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tmux-agent-alert-tests.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

export XDG_CONFIG_HOME="$TMP_DIR/config"
export AGENT_ALERT_STATE_DIR="$TMP_DIR/state"
mkdir -p "$XDG_CONFIG_HOME" "$AGENT_ALERT_STATE_DIR"

# shellcheck source=bin/agent-alert
. "$ROOT_DIR/bin/agent-alert"

TEST_COUNT=0

ok() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf 'ok %d - %s\n' "$TEST_COUNT" "$1"
}

not_ok() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf 'not ok %d - %s\n' "$TEST_COUNT" "$1" >&2
  printf '  expected: %s\n' "$2" >&2
  printf '       got: %s\n' "$3" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local description="$3"

  if [ "$actual" = "$expected" ]; then
    ok "$description"
  else
    not_ok "$description" "$expected" "$actual"
  fi
}

assert_success() {
  local description="$1"
  shift

  if "$@" >/dev/null; then
    ok "$description"
  else
    not_ok "$description" "success" "failure"
  fi
}

assert_failure() {
  local description="$1"
  shift

  if "$@" >/dev/null; then
    not_ok "$description" "failure" "success"
  else
    ok "$description"
  fi
}

detected_state() {
  local detection="$1"
  printf '%s\n' "${detection%%$'\t'*}"
}

numbered_lines() {
  local count="$1"
  local prefix="${2:-line}"
  local index

  for ((index = 1; index <= count; index++)); do
    printf '%s %s\n' "$prefix" "$index"
  done
}

test_detection() {
  local detection
  local kiro_sample

  detection="$(detect_agent "codex" "" "" "codex,claude,opencode,pi")"
  assert_eq "$detection" "codex" "detects Codex from pane command"

  detection="$(detect_agent "zsh" "node /usr/local/bin/opencode" "" "codex,claude,opencode,pi")"
  assert_eq "$detection" "opencode" "detects OpenCode from process tree"

  detection="$(detect_agent "zsh" "" "Ask Codex"$'\n'"What would you like to do next" "codex")"
  assert_eq "$detection" "codex" "detects Codex from pane text hints"

  detection="$(detect_agent "kiro-cli" "" "" "codex,claude,opencode,pi,kiro")"
  assert_eq "$detection" "kiro" "detects Kiro from pane command"

  detection="$(detect_agent "zsh" "node /usr/local/bin/kiro-cli chat" "" "codex,claude,opencode,pi,kiro")"
  assert_eq "$detection" "kiro" "detects Kiro from process tree"

  detection="$(detect_agent "zsh" "" "Kiro is working · type to queue a message" "kiro")"
  assert_eq "$detection" "kiro" "detects Kiro from pane text hints"

  assert_failure "skips disabled agents" detect_agent "codex" "" "" "claude"

  detection="$(detect_silent_state "codex" "Would you like to run the following command?")"
  assert_eq "$(detected_state "$detection")" "WAITING_FOR_PERMISSION" "detects silent permission prompt"

  detection="$(detect_silent_state "codex" "What would you like to do next")"
  assert_eq "$(detected_state "$detection")" "DONE_WAITING_FOR_NEXT_PROMPT" "detects silent completion prompt"

  detection="$(detect_silent_state "codex" "esc to interrupt")"
  assert_eq "$(detected_state "$detection")" "RUNNING" "detects silent running state"

  detection="$(detect_active_state "codex" "Would you like to run the following command?")"
  assert_eq "$(detected_state "$detection")" "WAITING_FOR_PERMISSION" "detects active permission prompt"

  detection="$(detect_active_state "codex" "What would you like to do next")"
  assert_eq "$(detected_state "$detection")" "DONE_WAITING_FOR_NEXT_PROMPT" "detects active completion prompt"

  detection="$(detect_active_state "codex" "new pane output")"
  assert_eq "$(detected_state "$detection")" "RUNNING" "treats changed output as running"

  detection="$(detect_silent_state "codex" "Would you like to run the following command?"$'\n'"$(numbered_lines 45 filler)"$'\n'"What would you like to do next")"
  assert_eq "$(detected_state "$detection")" "DONE_WAITING_FOR_NEXT_PROMPT" "ignores stale permission text outside recent permission window"

  detection="$(detect_silent_state "codex" "What would you like to do next"$'\n'"$(numbered_lines 10 filler)"$'\n'"esc to interrupt")"
  assert_eq "$(detected_state "$detection")" "RUNNING" "prefers recent running indicator over stale completion text"

  detection="$(detect_silent_state "kiro" "Kiro is working · type to queue a message")"
  assert_eq "$(detected_state "$detection")" "RUNNING" "detects Kiro working state"

  kiro_sample=$'KIRO\nInitializing...'
  detection="$(detect_silent_state "kiro" "$kiro_sample")"
  assert_eq "$(detected_state "$detection")" "RUNNING" "detects Kiro initializing state"

  kiro_sample=$'Press (↑↓) to navigate (⏎) to select scope\n> Full command          -> git status\n  Partial command       -> git *'
  detection="$(detect_silent_state "kiro" "$kiro_sample")"
  assert_eq "$(detected_state "$detection")" "WAITING_FOR_PERMISSION" "detects Kiro trust scope picker"

  kiro_sample=$'Read (4 files)\nYes · Trust · No'
  detection="$(detect_silent_state "kiro" "$kiro_sample")"
  assert_eq "$(detected_state "$detection")" "WAITING_FOR_PERMISSION" "detects Kiro yes trust no permission bar"

  detection="$(detect_silent_state "kiro" "Kiro >")"
  assert_eq "$(detected_state "$detection")" "DONE_WAITING_FOR_NEXT_PROMPT" "detects Kiro prompt"

  detection="$(detect_silent_state "kiro" "ask a question or describe a task ↵")"
  assert_eq "$(detected_state "$detection")" "DONE_WAITING_FOR_NEXT_PROMPT" "detects Kiro input placeholder"
}

test_transition_helpers() {
  assert_success "notifies permission transitions" should_notify_transition "RUNNING" "WAITING_FOR_PERMISSION" "off"
  assert_success "notifies completion transitions" should_notify_transition "RUNNING" "DONE_WAITING_FOR_NEXT_PROMPT" "off"
  assert_failure "does not notify unchanged states" should_notify_transition "RUNNING" "RUNNING" "on"
  assert_failure "keeps silent unknown disabled by default" should_notify_transition "RUNNING" "SILENT_UNKNOWN" "off"
  assert_success "can notify running to silent unknown when enabled" should_notify_transition "RUNNING" "SILENT_UNKNOWN" "on"
  assert_failure "does not notify unknown to silent unknown" should_notify_transition "UNKNOWN" "SILENT_UNKNOWN" "on"

  assert_success "permission ignores min runtime" state_notification_ignores_min_runtime "WAITING_FOR_PERMISSION"
  assert_success "completion ignores min runtime" state_notification_ignores_min_runtime "DONE_WAITING_FOR_NEXT_PROMPT"
  assert_failure "silent unknown respects min runtime" state_notification_ignores_min_runtime "SILENT_UNKNOWN"
}

TEST_NOW=1000
TEST_CONTENT=""
TEST_NOTIFICATIONS=0

get_tmux_option() {
  local _option="$1"
  local default_value="$2"

  printf '%s\n' "$default_value"
}

capture_clean_pane() {
  local _pane="$1"
  local _capture_lines="$2"

  printf '%s\n' "$TEST_CONTENT"
}

process_tree_text() {
  local _root_pid="$1"

  printf '%s\n' "codex"
}

now_epoch() {
  printf '%s\n' "$TEST_NOW"
}

notify_user() {
  TEST_NOTIFICATIONS=$((TEST_NOTIFICATIONS + 1))
  return 0
}

show_tmux_alert_fallback() {
  return 0
}

refresh_visual_alert_for_pane() {
  return 0
}

run_check() {
  check_pane "%1" "work" "agent" "1" "0" "12345" "codex" "$ROOT_DIR" "1" "no"
}

pane_state_value() {
  local key="$1"
  local file

  file="$(state_file_for_pane "%1")"
  state_get "$file" "$key" ""
}

test_check_pane_transitions() {
  TEST_CONTENT="Codex"$'\n'"esc to interrupt"
  TEST_NOW=1000
  run_check
  assert_eq "$(pane_state_value "state")" "UNKNOWN" "records first observation without classifying"
  assert_eq "$TEST_NOTIFICATIONS" "0" "does not notify on first observation"

  TEST_NOW=1003
  run_check
  assert_eq "$(pane_state_value "state")" "RUNNING" "classifies stable running output after silence threshold"
  assert_eq "$TEST_NOTIFICATIONS" "0" "does not notify running state"

  TEST_CONTENT="Codex"$'\n'"Would you like to run the following command?"
  TEST_NOW=1004
  run_check
  assert_eq "$(pane_state_value "state")" "WAITING_FOR_PERMISSION" "transitions changed output to permission"
  assert_eq "$(pane_state_value "visual_alert")" "red" "marks permission alert red"
  assert_eq "$TEST_NOTIFICATIONS" "1" "notifies permission transition once"

  TEST_NOW=1005
  run_check
  assert_eq "$(pane_state_value "state")" "WAITING_FOR_PERMISSION" "keeps permission state while unchanged"
  assert_eq "$TEST_NOTIFICATIONS" "1" "does not duplicate permission notification"

  TEST_CONTENT="Codex"$'\n'"What would you like to do next"
  TEST_NOW=1006
  run_check
  assert_eq "$(pane_state_value "state")" "DONE_WAITING_FOR_NEXT_PROMPT" "transitions changed completion text to done"
  assert_eq "$TEST_NOTIFICATIONS" "2" "notifies completion transition without waiting for stability"

  TEST_NOW=1009
  run_check
  assert_eq "$(pane_state_value "state")" "DONE_WAITING_FOR_NEXT_PROMPT" "transitions stable completion text to done"
  assert_eq "$(pane_state_value "visual_alert")" "green" "marks completion alert green"
  assert_eq "$TEST_NOTIFICATIONS" "2" "does not duplicate completion notification"
}

test_detection
test_transition_helpers
test_check_pane_transitions

printf '1..%d\n' "$TEST_COUNT"
