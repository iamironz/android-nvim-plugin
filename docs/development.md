# Development

## Local setup

Use a local path with your plugin manager.

```lua
{
  dir = "/path/to/android-nvim-plugin",
  lazy = false,
  config = function()
    require("android").setup()
  end,
}
```

## Tests

```bash
./scripts/run-tests.sh
./scripts/run-tests.sh tests.android.build.apk_test
```

## Health checks

Run `:checkhealth android` from the project root to validate:

- SDK root discovery and command line tools
- adb and emulator availability
- aapt2 from installed build tools
- Gradle command resolution
- xcodebuild and xcrun on macOS

## Style

- 2-space indentation
- Double quotes for strings
- `local M = {}` modules with `return M`
- Keep files focused by domain

## Planning notes (2026-02-05)

- Plan: Selectively port Esc/back modal navigation from fix-esc-modal-back into main.
- Keep main UI strings/defaults and menu/loading indicator behavior; only add on_cancel/back handling where missing.
- Exclude docs/plans content.
- Verification: run the full test suite after port.
