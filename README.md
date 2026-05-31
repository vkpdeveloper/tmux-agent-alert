# tmux-agent-alert

A tmux plugin scaffold for agent-related alerts.

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

## Options

```tmux
set -g @agent-alert-enabled 'on'
set -g @agent-alert-key 'A'
```

## Development

Source the plugin from this checkout while iterating:

```tmux
run-shell /Users/vaibhav/Developer/Personal/tmux-agent-alert/tmux-agent-alert.tmux
```

The plugin entrypoint is `tmux-agent-alert.tmux`. Shared shell helpers live in `scripts/helpers.sh`.
