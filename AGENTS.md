# AGENTS.md

Repository guide for agentic coding tools.

## Quick commands

All tests:

```bash
./scripts/run-tests.sh
```

Single test module:

```bash
./scripts/run-tests.sh tests.android.build.apk_test
```

Headless module run (optional):

```bash
nvim --headless -u NONE \
  "+set rtp+=/path/to/android-nvim-plugin" \
  "+lua require('tests.android.build.apk_test').run()" +q
```

## Build / lint / test

- Build: no repo-level build step
- Lint/format: no configured linter or formatter
- Tests: run via `./scripts/run-tests.sh` (bash required)

## Repository layout

- `lua/android/` plugin code
- `lua/tests/` test modules
- `scripts/run-tests.sh` test runner
- `README.md` public usage and install
- `docs/` public documentation

## Lua style

Structure
- Use `local M = {}` and `return M`
- Keep `require(...)` statements at top, assigned to locals
- Define small helper functions above public API
- Prefer early returns; avoid deep nesting

Naming
- snake_case for locals/functions
- Use `is_*`, `has_*`, `should_*` for booleans
- Module require paths mirror file paths

Formatting
- Indent with 2 spaces
- Double quotes for strings
- Line width: 100 max
- Avoid trailing whitespace

Types and data shapes
- Use plain Lua tables for structured data
- Standard result shape:
  - success: `{ ok = true, ... }`
  - failure: `{ ok = false, error = "message", ... }`
  - warning: `{ ok = true, warning = "message", ... }`
- Keep keys stable; prefer explicit fields over positional arrays

Error handling
- Validate inputs early
- Return `{ ok = false, error = "..." }` for expected failures
- Use `vim.notify(message, vim.log.levels.<LEVEL>)` for user-visible issues
- Keep error messages actionable and specific

Dependencies and imports
- One require per dependency and store in a local
- Avoid cyclic requires between domains
- Keep UI logic under `lua/android/ui/`
- Keep low-level helpers under `lua/android/utils/`

Logging and user feedback
- Use `vim.notify` for failures and completion messages
- Do not silently swallow errors
- Prefer returning result tables over throwing errors

## Android and Gradle conventions

- Module names use Gradle notation, e.g. `:app`
- Module paths are derived from module names by replacing `:` with `/`
- Gradle task introspection should be cached and reused
- Avoid running Gradle in tests; pass task output via options or stubs
- APK discovery prefers explicit overrides, then variant outputs, then fallback scan

## iOS conventions

- Use `xcodebuild -list` to discover schemes
- Prefer scheme matching the workspace/project base name, then "ios"
- Deploy targets prefer booted simulator, then paired physical device
- Build settings may expose app path via `TARGET_BUILD_DIR`,
  `CONFIGURATION_BUILD_DIR`, or `BUILT_PRODUCTS_DIR`
- Always return actionable errors when no simulators or devices are available

## Run configs JSON

- JSON config file path is `run.config_path` and can be workspace-relative
- Shell configs prefer `args` over `command` to avoid shell splitting
- Keep `id` fields stable for user state persistence

## Neovim plugin best practices

- Keep `plugin/<name>.lua` small; defer `require` until a command or mapping runs
- Prefer user commands and `<Plug>` mappings over hardcoded keymaps
- Group commands under a single entry and support subcommands where sensible
- Use `ftplugin/` for filetype-specific behavior; set custom filetype late
- Avoid relying on plugin managers for lazy loading
- Provide health checks in `lua/android/health.lua` for external deps
- Validate config and report actionable errors

## Lua best practices

- Avoid globals; always use `local` and keep module side effects minimal
- Keep public functions on `M` and helpers as `local function`
- Prefer Lua 5.1 compatibility; avoid LuaJIT-only APIs
- Use explicit type checks in config validation for user input
- Keep require names aligned with module path for readability

## Tests

- Tests live under `lua/tests/`
- Each test module exposes `function M.run()` and returns `M`
- Use `tests.helpers.assert` for assertions
- Use `tests.helpers.stubs` for stubbing modules
- Keep tests hermetic; avoid external tools by default
- Follow AAA pattern: Arrange, Act, Assert

## Configuration behavior

- `run.default_module` forces default module selection
- `run.module_preference` tunes default module selection
- `run.run_all` controls target ordering and preferred modules
- `build.gradle_command` overrides gradle resolution
- `build.scan_all_apk_outputs` enables full APK scan fallback

## OS support

- macOS and Linux are primary targets
- Windows support is best-effort

## Safe change checklist

- Add or update tests when behavior changes
- Keep public commands and config backward-compatible
- Prefer small, focused edits
- Update README and docs when public surface changes
