#!/usr/bin/env bash

# Rules are extended regular expressions, matched case-insensitively against
# cleaned pane text after silence is detected.

# shellcheck disable=SC2034
AGENT_ALERT_KNOWN_AGENTS="codex,claude,opencode,pi,kiro"

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
    kiro)
      printf '%s\n' 'kiro' 'kiro-cli'
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
    kiro)
      printf '%s\n' 'kiro' 'kiro cli' 'kiro is working' 'type to queue a message' 'ask a question or describe a task'
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

global_running_patterns() {
  printf '%s\n' \
    'working\.\.\.' \
    '(^|[[:space:]·])working([[:space:]·])*·' \
    '(^|[[:space:]·])thinking([[:space:]·])*·' \
    '(^|[[:space:]·])processing([[:space:]·])*·'
}

agent_running_patterns() {
  local agent="$1"

  case "$agent" in
    codex)
      printf '%s\n' \
        '(^|[[:space:]·])working([[:space:]·]|$)' \
        'gpt-[^[:space:]]+.*working.*context' \
        'working \([0-9]+s[[:space:]·].*esc to interrupt\)' \
        'esc to interrupt'
      ;;
    claude)
      printf '%s\n' \
        'claude.*working' \
        'working on' \
        'tomfoolering' \
        'running [0-9]+ shell command' \
        'running [0-9]+ shell commands' \
        '↓ [0-9,]+ tokens'
      ;;
    opencode)
      printf '%s\n' \
        'opencode.*working' \
        'thought: .* · [0-9.]+(ms|s)' \
        'esc[[:space:]]+interrupt'
      ;;
    pi)
      printf '%s\n' \
        '[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] working\.\.\.' \
        'working\.\.\.' \
        'type to queue a message'
      ;;
    kiro)
      printf '%s\n' \
        'kiro is working · type to queue a message' \
        'kiro is working' \
        'initializing\.\.\.' \
        'type to queue a message' \
        'esc to cancel'
      ;;
  esac

  global_running_patterns
}

agent_permission_patterns() {
  local agent="$1"

  case "$agent" in
    codex)
      printf '%s\n' \
        'would you like to run the following command\?' \
        'yes, proceed \(y\)' \
        'press enter to confirm or esc to cancel' \
        'reason: .*allow codex' \
        'commands? may require user approval' \
        'approve for me' \
        'approve network access' \
        'ask for approval' \
        'sandbox.*approval' \
        'requesting approval' \
        'command.*approval'
      ;;
    claude)
      printf '%s\n' \
        'do you want to (create|edit|write|run|execute|delete|modify)' \
        'yes, allow all edits during this session' \
        'esc to cancel[[:space:]·]*tab to amend' \
        '^1\. yes$' \
        '^3\. no$' \
        'create file' \
        'write\(' \
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
        'asking for permission' \
        'permission required' \
        'allow once' \
        'allow always' \
        'reject' \
        'enter confirm'
      return
      ;;
    pi)
      printf '%s\n' \
        'permissionmode.*ask' \
        'prompt.*deny without asking' \
        'permission level' \
        'permission request' \
        'systemnotifications'
      ;;
    kiro)
      printf '%s\n' \
        'yes[[:space:]·]+trust[[:space:]·]+no' \
        'yes.*trust.*no' \
        'press.*to navigate.*select scope' \
        'select scope' \
        'full command.*partial command.*base command' \
        'specific paths.*complete directory.*entire tool' \
        'trust(ed)? (tool|permission|pattern|scope)' \
        'per-request' \
        'untrusted' \
        'requires? permission' \
        'ask(ed|ing)? for (your )?(approval|permission)' \
        'approve.*tool' \
        'allow.*tool'
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
        'codex.*ready' \
        '(^|[[:space:]·])ready([[:space:]·]|$)' \
        'context [0-9]+% used.*[0-9]+%.*left' \
        'find and fix a bug in @filename' \
        'gpt-[^[:space:]]+.*ready.*context' \
        'token usage: total=' \
        'to continue this session, run codex resume' \
        'conversation interrupted' \
        '(^|[[:space:]])➜[[:space:]]*$'
      ;;
    claude)
      printf '%s\n' \
        'worked for [0-9]+s' \
        'no task given\. what you want do\?' \
        '^❯[[:space:]]*$' \
        '-- insert --.*for agents' \
        'what can i help' \
        'how can i help' \
        'try .* claude' \
        'claude.*ready'
      ;;
    opencode)
      printf '%s\n' \
        'opencode.*ready' \
        'new message' \
        'send a message' \
        'build · gpt-[^[:space:]]+ · [0-9.]+s' \
        'build · gpt-[^[:space:]]+ github copilot · high' \
        'if you want, i can next:'
      ;;
    pi)
      printf '%s\n' \
        'pi.*ready' \
        'new prompt' \
        'send.*prompt' \
        '↑[0-9.]+[kmg]? .*↓[0-9.]+[kmg]? .*\$[0-9.]+' \
        '\((auto|kiro|sub)\).*((claude|gpt|gemini|opus|sonnet)|xhigh|high)' \
        '^~/.+'
      ;;
    kiro)
      printf '%s\n' \
        'kiro.*ready' \
        'kiro[[:space:]]*>' \
        'ask a question or describe a task' \
        '^>[[:space:]]*$' \
        'type a message' \
        'type your message' \
        '\((auto|kiro|sub)\).*((claude|gpt|gemini|opus|sonnet)|xhigh|high)' \
        '^~/.+'
      ;;
  esac

  global_done_patterns
}
