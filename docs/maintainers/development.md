# Development Guide

## Purpose

Define local contributor workflow, quality gates, and documentation update policy.

## Local Setup

Use a local path with your plugin manager:

```lua
{
  dir = "/path/to/android-nvim-plugin",
  lazy = false,
  config = function()
    require("android").setup()
  end,
}
```

## Test Workflow

Run the full suite before PRs:

```bash
./scripts/run-tests.sh
```

Run single module while iterating:

```bash
./scripts/run-tests.sh tests.android.build.apk_test
```

Use `:checkhealth android` for local environment issues.

## Code Style

- 2-space indentation
- Double quotes for strings
- `local M = {}` modules with `return M`
- Small focused files by domain

## Docs Update Policy

- Canonical docs live under `docs/` by intent:
  - `guides/`, `reference/`, `support/`, `maintainers/`
- Follow [docs-writing.md](docs-writing.md) for structure and explanation style.
- Preserve legacy doc paths as compatibility redirects when moving pages.
- Update `docs/README.md` navigation for added/renamed docs pages.

## Change Checklist

- Run tests locally.
- Update docs for behavior/config changes.
- Update `CHANGELOG.md` for user-visible changes.
- Keep commit scope focused.
