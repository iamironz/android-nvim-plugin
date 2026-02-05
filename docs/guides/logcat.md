# Logcat Guide

## Purpose

Explain logcat panel layout, controls, filter behavior, and expected runtime behavior.

## Opening Logcat

Open logcat from AndroidMenu (`Logcat -> Logcat`) or via successful `AndroidBuild` flow.

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

## Related Docs

- Build workflow: [build-and-deploy.md](build-and-deploy.md)
- Keymaps reference: [../reference/keymaps.md](../reference/keymaps.md)
