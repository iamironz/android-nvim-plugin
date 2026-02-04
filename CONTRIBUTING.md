# Contributing

Thanks for taking the time to contribute.

## Requirements

- Neovim 0.9+ with Lua support
- Android SDK tools and adb for Android workflows
- Xcode tools for iOS workflows

## Local setup

Use a local path with your plugin manager. Example for lazy.nvim:

```lua
{
  dir = "/path/to/android-nvim-plugin",
  lazy = false,
  config = function()
    require("android").setup()
  end,
}
```

## Local development workflow

1. Clone the repo to a local path.
2. Point your plugin manager to the local path using the snippet above.
3. Restart Neovim so commands are registered.
4. If you use lazy loading, run `:Lazy load android-nvim-plugin` once.
5. After edits, run `:Lazy reload android-nvim-plugin` to pick up changes.
6. Run `:AndroidMenu` to confirm the plugin is attached.

## Health checks

- Run `:checkhealth android` from the project root to verify SDK, Gradle, and
  iOS tooling.
- Include the output in bug reports when possible.

## Tests

```bash
./scripts/run-tests.sh
./scripts/run-tests.sh tests.android.build.apk_test
```

## Code style

- 2-space indentation
- Double quotes for strings
- `local M = {}` modules with `return M`
- Keep files focused by domain

## Docs

If you change behavior or add options, update:

- `README.md`
- `docs/configuration.md` or other relevant docs

## Workflow

- Keep changes focused and scoped to a single topic.
- Update `CHANGELOG.md` for user-visible changes.
- Run tests locally before opening a PR.
- Note any config changes or new defaults in the PR description.

## Pull request expectations

- Clear summary of what changed and why.
- Link related issues or discussions.
- Provide steps to test the change.
- Confirm docs and changelog updates when applicable.

## Pull request checklist

- Tests pass
- README and docs updated
- No breaking changes without clear notes

## Triage policy

- Issues are labeled using the triage labels in `docs/triage.md`.
- `triage/needs-info` issues are closed after 14 days without a response.
- Duplicates and out-of-scope requests may be closed with guidance.
