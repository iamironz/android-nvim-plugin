# Logcat Guide

## Purpose

Explain logcat panel layout, controls, filter behavior, and expected runtime behavior.

## Default Behavior

`:AndroidBuild` opens logcat automatically after a successful Android deploy and
updates package selection to the deployed app.

## Entry Points

| Entry Point | Default Shortcut | Notes |
| --- | --- | --- |
| `:AndroidLogcat` | None | Opens logcat directly |
| AndroidMenu `Logcat -> Logcat` | `<leader>am` then menu | Same logcat action from hub |
| Successful `:AndroidBuild` | `<leader>ab` | Opens logcat after deploy |

## Dock Layout

Logcat uses a two-layer bottom dock:

- Control strip (fixed): package, filter, level rows
- Stream body: log output

`<CR>` behavior:

- On control strip rows: edit package, filter, or level.
- In stream body: open stack trace navigation when available.

## Controls

| Key | Action |
| --- | --- |
| `q` | Close logcat panel |
| `c` | Clear panel output |
| `C` | Clear output and reset pause state |
| `p` | Pause or resume output |
| `r` | Restart logcat |
| `gp` | Pick package filter |
| `gf` | Edit filter text |
| `gl` | Pick level filter |
| `gs` | Switch run config |

## Filter Rules

- Space-separated terms: every term must match the line.
- Regex pattern: wrap in `/.../`.

Examples:

- `network timeout`
- `/Retrofit|OkHttp/`

## Runtime Behavior

- Logcat reconnect is automatic with retry backoff.
- Status lines report retry/disconnect state.
- Pause keeps incoming lines in backlog and flushes on resume.

## Recommended Flow

1. Open logcat with `:AndroidLogcat`.
1. Set package and level from the control strip.
1. Add a text or regex filter to reduce noise.
1. Pause while inspecting long output, then resume to flush backlog.
1. Press `<CR>` on stack-trace lines to jump to source.

## Related Docs

- Build workflow: [build-and-deploy.md](build-and-deploy.md)
- Keymaps reference: [../reference/keymaps.md](../reference/keymaps.md)
