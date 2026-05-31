#!/usr/bin/env bash

# Rules are extended regular expressions, matched case-insensitively against
# cleaned pane text after silence is detected.

AGENT_ALERT_KNOWN_AGENTS="codex,claude,opencode,pi"

agent_commands() {
  case "$1" in
    codex)
      printf '%s\n' 'codex'
      ;;
    claude)
      printf '%s\n' 'claude' 'claude-code'
      ;;
    opencode)
      printf '%s\n' 'opencode'
      ;;
    pi)
      printf '%s\n' 'pi' 'pi-coding-agent'
      ;;
  esac
}

agent_output_hints() {
  case "$1" in
    codex)
      printf '%s\n' 'codex' 'ask codex' 'what would you like to do next'
      ;;
    claude)
      printf '%s\n' 'claude code' 'claude' '/permissions' 'permission mode'
      ;;
    opencode)
      printf '%s\n' 'opencode' 'open code'
      ;;
    pi)
      printf '%s\n' 'pi coding agent' 'permissionmode' 'pi.dev'
      ;;
  esac
}

global_permission_patterns() {
  printf '%s\n' \
    'permission required' \
    'requires? permission' \
    'needs? (your )?(approval|permission|confirmation)' \
    'waiting for (approval|permission|confirmation)' \
    '(^|[[:space:]])(approve|approval|allow|deny)([[:space:]]|$)' \
    '(approve|allow|deny).*(command|action|tool|operation|request)' \
    'allow (this|the)? ?(command|action|tool|operation)' \
    'confirm (this|the)? ?(command|action|tool|operation|request)' \
    'continue\?' \
    'proceed\?' \
    'run this command' \
    'execute this command' \
    'do you want to (continue|proceed|approve|allow|run|execute)'
}

agent_permission_patterns() {
  local agent="$1"

  case "$agent" in
    codex)
      printf '%s\n' \
        'approve for me' \
        'approve network access' \
        'ask for approval' \
        'sandbox.*approval' \
        'requesting approval' \
        'command.*approval'
      ;;
    claude)
      printf '%s\n' \
        'yes, don'"'"'t ask again' \
        'ask before edits' \
        'permission mode' \
        'bash command' \
        'tool.*approval' \
        'approve the action' \
        'press .* to approve'
      ;;
    opencode)
      printf '%s\n' \
        '"ask".*prompt for approval' \
        'permission.*ask' \
        'allow all operations' \
        'bash.*ask' \
        'tool.*ask'
      ;;
    pi)
      printf '%s\n' \
        'permissionmode.*ask' \
        'prompt.*deny without asking' \
        'permission level' \
        'permission request' \
        'systemnotifications'
      ;;
  esac

  global_permission_patterns
}

global_done_patterns() {
  printf '%s\n' \
    'done' \
    'completed' \
    'finished' \
    'task complete' \
    'ready for (your )?(next )?(prompt|request)' \
    'enter your prompt' \
    'what would you like' \
    'anything else'
}

agent_done_patterns() {
  local agent="$1"

  case "$agent" in
    codex)
      printf '%s\n' \
        'what would you like to do next' \
        'ask codex' \
        'codex.*ready'
      ;;
    claude)
      printf '%s\n' \
        'what can i help' \
        'how can i help' \
        'try .* claude' \
        'claude.*ready'
      ;;
    opencode)
      printf '%s\n' \
        'opencode.*ready' \
        'new message' \
        'send a message'
      ;;
    pi)
      printf '%s\n' \
        'pi.*ready' \
        'new prompt' \
        'send.*prompt'
      ;;
  esac

  global_done_patterns
}
