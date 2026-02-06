# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to SemVer.

## [Unreleased]

### Added

- Eight direct zero-arg commands with `<Plug>` mappings:
  `:AndroidRun`, `:AndroidRunStop`, `:AndroidLogcat`, `:AndroidBuildPrompt`,
  `:AndroidBuildAssemble`, `:AndroidGradleTasks`, `:AndroidIOSBuild`,
  `:AndroidIOSDeploy`.

### Changed

- Default leader mappings remain unchanged and limited to:
  `<leader>am`, `<leader>at`, `<leader>ao`, `<leader>aa`, `<leader>ab`.
- README, reference docs, and guides now distinguish default-shortcut commands
  from direct commands that have no default shortcut.

## [0.4.0] - 2026-02-06

### Added

- Default variant detection from `isDefault` markers in `buildTypes` and `productFlavors`.
- APK discovery fallback that scans flavor output subdirectories for variant artifacts.
- `ui.restore_logcat` option to reopen the logcat dock on startup when it was open previously.

### Changed

- Android hub startup now uses fast initial blocks while run config discovery and prefetch complete.
- Summary now reports selected target, connected devices, and module/variant fallback resolution.
- Selection state storage now caches reads and skips unchanged writes to reduce startup overhead.

### Fixed

- Dock panel windows are reused across deploys and close together when either dock split closes.
- Hub submenu back navigation now rebinds the active hub handle correctly.
- Logcat reconnect stream handling now preserves partial output chunks safely.
- Logcat restore and stack-trace navigation are more robust across startup and window changes.

## [0.3.0] - 2026-02-06

### Added

- Docked two-layer output panels for logcat and build streams.
- Docs writing standard for page structure, markdown conventions, and explanation style.

### Changed

- Android hub section selection and fallback search flow for clearer navigation.
- Build and logcat panel hotkeys now work from both control strip and output body.
- Documentation reorganized into guides, reference, support, and maintainer sections.
- README quick start and feature highlights refreshed for clearer onboarding.
- Installation docs now prioritize lazy.nvim setup and `:Lazy sync` flow.
- Canonical docs rewritten with consistent `Purpose`, workflow, and `Related Docs` sections.
- Workflow screenshot refreshed.

### Fixed

- Fixed control strips for panel filters and inline header edits in dock mode.
- Header versus body `<CR>` handling so stack-trace jumps stay available in logcat output.
- Menu discoverability and section-entry cues in AndroidMenu.

## [0.2.0] - 2026-02-05

### Added

- Menu prefetch with status summary to keep menus responsive.
- Workspace observing stabilization for menu discovery.

### Changed

- Menu navigation and cancel flow to rely on search-first sections.
- Android menu naming aligned with Android Studio terminology.
- Menu startup performance improvements.
- Workflow screenshot updated.

### Fixed

- Esc/back handling in Android modal pickers.
- Hub selection alignment after summary updates.
- Run configuration selection when invoked from actions.

## [0.1.0] - 2026-02-04

### Added

- Release and triage documentation.
- CI matrix for OS and Neovim versions.
- Documentation link checking in CI.
- PR checks workflow and nightly scheduled tests.
- Labels sync workflow and label definitions.
- README demo image.

### Changed

- README navigation, quick start, and documentation cross-links.
- Feature summary formatting for readability.
- Contributing guidance and issue templates for better diagnostics.
- Security and Code of Conduct reporting guidance.

### Fixed

- Neovim version tagging for CI setup.
- Labels workflow checkout and config format.
