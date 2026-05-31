#!/usr/bin/env bash

clean_ansi() {
  if command -v perl >/dev/null 2>&1; then
    perl -pe 's/\e\][^\a]*(?:\a|\e\\)//g; s/\e\[[0-9;?]*[ -\/]*[@-~]//g; s/\r/\n/g'
  else
    sed -E $'s/\x1b\\[[0-9;?]*[ -\\/]*[@-~]//g; s/\r/\\\n/g'
  fi
}

content_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

last_visible_line() {
  awk 'NF { line=$0 } END { gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); print line }'
}

matches_any_pattern() {
  local content="$1"
  shift

  local pattern
  for pattern in "$@"; do
    [ -z "$pattern" ] && continue
    if printf '%s\n' "$content" | grep -Eiq "$pattern"; then
      printf '%s\n' "$pattern"
      return 0
    fi
  done

  return 1
}

enabled_agent() {
  local agent="$1"
  local enabled_agents="$2"
  local item

  IFS=',' read -r -a _agent_items <<< "$enabled_agents"
  for item in "${_agent_items[@]}"; do
    item="$(printf '%s' "$item" | tr -d '[:space:]')"
    [ "$item" = "$agent" ] && return 0
  done

  return 1
}

process_tree_text() {
  local root_pid="$1"
  local current="$root_pid"
  local next=""
  local depth=0
  local pid child

  while [ -n "$current" ] && [ "$depth" -lt 5 ]; do
    next=""

    for pid in $current; do
      ps -o command= -p "$pid" 2>/dev/null || true

      if command -v pgrep >/dev/null 2>&1; then
        for child in $(pgrep -P "$pid" 2>/dev/null || true); do
          next="$next $child"
        done
      fi
    done

    current="$next"
    depth=$((depth + 1))
  done
}

detect_agent() {
  local command_text="$1"
  local process_text="$2"
  local content="$3"
  local enabled_agents="$4"
  local haystack
  local agent candidate

  haystack="$(printf '%s\n%s\n%s\n' "$command_text" "$process_text" "$content" | tr '[:upper:]' '[:lower:]')"

  for agent in codex claude opencode pi; do
    enabled_agent "$agent" "$enabled_agents" || continue

    while IFS= read -r candidate; do
      [ -z "$candidate" ] && continue
      if printf '%s\n' "$haystack" | grep -Eiq "(^|[^[:alnum:]_-])${candidate}([^[:alnum:]_-]|$)"; then
        printf '%s\n' "$agent"
        return 0
      fi
    done < <(agent_commands "$agent")
  done

  for agent in codex claude opencode pi; do
    enabled_agent "$agent" "$enabled_agents" || continue

    while IFS= read -r candidate; do
      [ -z "$candidate" ] && continue
      if printf '%s\n' "$haystack" | grep -Eiq "$candidate"; then
        printf '%s\n' "$agent"
        return 0
      fi
    done < <(agent_output_hints "$agent")
  done

  return 1
}

detect_silent_state() {
  local agent="$1"
  local content="$2"
  local pattern
  local patterns=()

  while IFS= read -r pattern; do
    patterns+=("$pattern")
  done < <(agent_permission_patterns "$agent")

  if pattern="$(matches_any_pattern "$content" "${patterns[@]}")"; then
    printf '%s\t%s\n' "WAITING_FOR_PERMISSION" "$pattern"
    return
  fi

  patterns=()
  while IFS= read -r pattern; do
    patterns+=("$pattern")
  done < <(agent_done_patterns "$agent")

  if pattern="$(matches_any_pattern "$content" "${patterns[@]}")"; then
    printf '%s\t%s\n' "DONE_WAITING_FOR_NEXT_PROMPT" "$pattern"
    return
  fi

  printf '%s\t%s\n' "SILENT_UNKNOWN" "no matching idle or permission pattern"
}

