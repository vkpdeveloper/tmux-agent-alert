# tmux-agent-alert

A tmux plugin that watches CLI coding agents across tmux panes and notifies when a pane likely needs user attention.

The first version uses a practical state machine:

```text
capture-pane -> clean ANSI -> hash screen text -> wait for silence -> match rules -> notify once per transition
```

## Supported Agents

Default rules focus on:

- Codex CLI
- Claude Code
- OpenCode
- Pi coding agent

The rules are intentionally editable because agent TUIs change over time and tmux only exposes terminal text, not semantic agent state.

## Install

Using [tpm](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'vkpdeveloper/tmux-agent-alert'
```

Reload tmux config, then press the TPM install binding.

Manual install:

```sh
git clone https://github.com/vkpdeveloper/tmux-agent-alert ~/.tmux/plugins/tmux-agent-alert
run-shell ~/.tmux/plugins/tmux-agent-alert/tmux-agent-alert.tmux
```

## Usage

The watcher starts automatically when the plugin is loaded.

Default bindings:

```text
prefix + A   toggle watcher
prefix + M-i inspect current pane
```

CLI commands:

```sh
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert start
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert stop
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert status
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert inspect-pane %12
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert request-permission
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert test-notify
```

## Options

```tmux
set -g @agent-alert-enabled 'on'
set -g @agent-alert-key 'A'
set -g @agent-alert-inspect-key 'M-i'

set -g @agent-alert-agents 'codex,claude,opencode,pi'
set -g @agent-alert-poll-interval '2'
set -g @agent-alert-silence-threshold '45'
set -g @agent-alert-capture-lines '200'
set -g @agent-alert-min-runtime '8'
set -g @agent-alert-cooldown '300'
set -g @agent-alert-notify-silent-unknown 'off'

set -g @agent-alert-backend 'auto'
set -g @agent-alert-webhook-url ''
set -g @agent-alert-debug 'off'

set -g @agent-alert-request-macos-permission 'on'
set -g @agent-alert-macos-sender-bundle 'auto'

set -g @agent-alert-visual-alert 'on'
set -g @agent-alert-tmux-message-duration '3000'
```

Notification backends:

```text
auto
macos-terminal
terminal-notifier
osascript
notify-send
tmux
bell
```

On macOS, `auto` first tries `macos-terminal`, which detects the terminal app attached to the tmux client and sends the notification through that app bundle. This makes macOS request notification permission for the terminal actually running tmux, such as Ghostty, Terminal.app, iTerm2, WezTerm, kitty, Alacritty, or Warp.

If detection fails, `auto` falls back to `terminal-notifier`, then generic `osascript`, then `notify-send`, then tmux display messages, then terminal bell.

To force a specific macOS sender bundle:

```tmux
set -g @agent-alert-backend 'macos-terminal'
set -g @agent-alert-macos-sender-bundle 'com.mitchellh.ghostty'
```

To trigger the macOS permission prompt manually:

```sh
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert request-permission
```

## Visual Alerts

When an agent needs attention, the plugin also marks the tmux status-bar window item itself, for example `3:AI`. This is useful when your terminal app is already focused and macOS may not show a noticeable notification.

Default behavior:

```text
done/idle       red bold window item
permission      red bold window item
silent unknown  no status marker by default
running again   marker cleared
```

The marker keeps the normal window label, such as `3:AI`, and changes that status-bar item to a red or yellow block. The plugin does not show a tmux message for `RUNNING`. A tmux message is shown for at least 3 seconds only when desktop notification delivery is disabled or fails.

Disable it:

```tmux
set -g @agent-alert-visual-alert 'off'
```

## Custom Rules

Create:

```sh
mkdir -p ~/.config/tmux-agent-alert
$EDITOR ~/.config/tmux-agent-alert/rules.sh
```

Override any rule function from `config/default-rules.sh`.

Example:

```bash
agent_permission_patterns() {
  local agent="$1"

  global_permission_patterns

  case "$agent" in
    codex)
      printf '%s\n' 'approve command' 'allow for this session'
      ;;
    claude)
      printf '%s\n' 'allow this bash command' 'yes, don'\''t ask again'
      ;;
    opencode)
      printf '%s\n' 'bash.*ask' 'edit.*ask'
      ;;
    pi)
      printf '%s\n' 'permission request' 'permissionmode.*ask'
      ;;
  esac
}
```

## Detection Notes

Current public docs confirm that these agents have permission or approval flows:

- Codex CLI exposes approval policies such as `on-request`, `unless-trusted`, `never`, and `on-failure`.
- Claude Code pauses for permission before edits, shell commands, and network requests depending on permission mode.
- OpenCode exposes per-tool permissions with `ask`, `allow`, and `deny`.
- Pi permission layers expose `permissionMode: ask` for prompting and include tmux-aware notification behavior.

Because docs generally describe behavior rather than exact TUI text, the plugin ships with conservative patterns and an inspection command for tuning against real panes.

## Development

Source the plugin from this checkout while iterating:

```tmux
run-shell /Users/vaibhav/Developer/Personal/tmux-agent-alert/tmux-agent-alert.tmux
```

Run syntax checks:

```sh
bash -n tmux-agent-alert.tmux bin/agent-alert lib/*.sh config/default-rules.sh
```

Run lint checks:

```sh
shellcheck -x tmux-agent-alert.tmux bin/agent-alert lib/*.sh config/default-rules.sh
```
