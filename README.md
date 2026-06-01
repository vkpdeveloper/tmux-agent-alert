# tmux-agent-alert

A tmux plugin that watches CLI coding agents across tmux panes and notifies when a pane likely needs user attention.

The first version uses a practical state machine:

```text
capture-pane -> clean ANSI -> hash screen text -> match urgent prompts -> wait for a short stable window -> notify once per transition
```

## Supported Agents

Default rules focus on:

- Codex CLI
- Claude Code
- OpenCode
- Pi coding agent
- Kiro CLI

The rules are intentionally editable because agent TUIs change over time and tmux only exposes terminal text, not semantic agent state.

## Requirements

- tmux
- Bash and standard Unix tools such as `awk`, `sed`, `grep`, `ps`, `pgrep`, and `shasum` or `sha256sum`
- macOS native notifications use a tiny Swift helper app with the stable bundle id `dev.vkp.tmux-agent-alert.notifier`. If `swiftc` is unavailable, the plugin falls back to the terminal app currently attached to tmux, such as Ghostty, Terminal.app, iTerm2, WezTerm, kitty, Alacritty, or Warp.

## Install

Using [tpm](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'vkpdeveloper/tmux-agent-alert'
```

Reload tmux config, then press the TPM install binding, usually `prefix + I`.

Manual install:

```sh
git clone https://github.com/vkpdeveloper/tmux-agent-alert ~/.tmux/plugins/tmux-agent-alert
```

Then add this to `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-agent-alert/tmux-agent-alert.tmux
```

## Setup

After installing the plugin, reload tmux and restart the watcher:

```sh
tmux source-file ~/.tmux.conf
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert restart
```

Request or refresh macOS notification permission:

```sh
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert request-permission
```

Send a test notification:

```sh
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert test-notify
```

Check that the watcher is running:

```sh
~/.tmux/plugins/tmux-agent-alert/bin/agent-alert status
```

If `test-notify` exits but no macOS banner appears, check System Settings -> Notifications and allow notifications for `tmux-agent-alert`. If the native helper could not be built, also check the terminal app running tmux, such as Ghostty, Terminal.app, iTerm2, WezTerm, kitty, Alacritty, or Warp.

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

set -g @agent-alert-agents 'codex,claude,opencode,pi,kiro'
set -g @agent-alert-poll-interval '1'
set -g @agent-alert-silence-threshold '3'
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
macos-native
macos-terminal
notify-send
tmux
bell
```

On macOS, `auto` uses `macos-native` first. The native backend builds `TmuxAgentAlertNotifier.app` into the plugin state directory on first use and sends notifications through Apple’s UserNotifications framework with the stable bundle id `dev.vkp.tmux-agent-alert.notifier`. This gives System Settings a dedicated `tmux-agent-alert` notification entry instead of tying delivery to whichever terminal happens to be attached to tmux.

If the Swift helper cannot be built or native delivery fails, `auto` falls back to `macos-terminal`, which detects the terminal app attached to the tmux client and sends the notification through that app bundle. If terminal-app delivery fails or hangs, the caller falls back to tmux display messages where appropriate, then terminal bell. Native notification commands are timeout-guarded so a stuck helper should not block the agent-alert command indefinitely.

To force the native macOS helper:

```tmux
set -g @agent-alert-backend 'macos-native'
```

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
done/idle       green bold window item
permission      red bold window item
silent unknown  no status marker by default
running again   marker cleared
```

The marker keeps the normal window label, such as `3:AI`, and changes only that status-bar item's background color while leaving the label readable. The plugin does not show a tmux message or status marker for `RUNNING`. Permission prompts show both a desktop notification and a tmux message. Completed prompts show a desktop notification, with a tmux message fallback if desktop notification delivery is disabled or fails.

When you select an alerted pane/window, the marker is acknowledged and cleared. It stays cleared until that pane starts producing new output again.

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
    kiro)
      printf '%s\n' 'yes.*trust.*no' 'select scope' 'per-request'
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
- Kiro CLI uses tool permissions with `Trusted` and `Per-request` states. Its TUI asks for approval with `Yes`, `Trust`, and `No`, and shell/read/write trust pickers can ask the user to select a trust scope.

Because docs generally describe behavior rather than exact TUI text, the plugin ships with conservative patterns and an inspection command for tuning against real panes.

## Development

Source the plugin from this checkout while iterating:

```tmux
run-shell /Users/vaibhav/Developer/Personal/tmux-agent-alert/tmux-agent-alert.tmux
```

Run syntax checks:

```sh
bash -n tmux-agent-alert.tmux bin/agent-alert lib/*.sh config/default-rules.sh tests/run.sh
```

Run lint checks:

```sh
shellcheck -x tmux-agent-alert.tmux bin/agent-alert lib/*.sh config/default-rules.sh tests/run.sh
```

Run the minimal detection and transition harness:

```sh
bash tests/run.sh
```
