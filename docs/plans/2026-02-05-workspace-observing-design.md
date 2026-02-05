# Workspace Observing Improvements Design

**Date:** 2026-02-05
**Status:** Validated

## Goal
Reduce workspace detection overhead and make file change prompts stable in large
workspaces without changing the default user experience.

## Context
Workspace detection is currently recomputed on each action. In large Gradle
repos, this repeatedly scans settings files, loads module build files, and
derives Android or KMP support. The file watcher reacts to every
FileChangedShellPost by prompting on modified buffers, which can create noisy
prompt floods when files change rapidly or when multiple buffers are open.
The watcher also runs for any file buffer, not just those in the workspace.

## Architecture
Add a lightweight workspace cache in `lua/android/actions/context.lua`. The
cache stores the last detected workspace, the root path, and a fingerprint of
the Gradle settings files. `context.workspace()` checks whether the current
buffer path is under the cached root and whether the settings files have
changed. If both are true, it returns the cached workspace; otherwise it
re-runs detection and refreshes the cache. This keeps repeated actions O(1)
for the common case while ensuring detection stays correct after settings
changes.

Update `lua/android/init.lua` to resolve the workspace root once during setup
and pass it into `file_watcher.setup({ workspace_root = root })`. The watcher
will ignore buffers outside this root and will not prompt on unrelated files.

Add prompt coalescing in `lua/android/ui/file_watcher.lua` by tracking a
per-buffer `last_prompt_at` timestamp and a fixed cooldown window. When a
FileChangedShellPost arrives, the watcher prompts immediately if no recent
prompt was shown; otherwise it skips prompting during the cooldown. This keeps
behavior deterministic and avoids timers or background tasks.

## Data Flow
1. `context.workspace()` reads current path, checks cache validity, and either
   returns cached workspace or re-runs `android.project.detect`.
2. `android.setup()` determines workspace root and passes it to the watcher.
3. `file_watcher` filters events by workspace root, then prompts with reload,
   keep, diff, or force save if the buffer is modified and outside cooldown.

## Error Handling
If detection fails or no Gradle workspace exists, `context.workspace()` keeps
the current warning behavior and returns nil. Cache reads treat missing or
unreadable settings files as changed, forcing a fresh detection instead of
silently reusing stale data. Watcher errors remain wrapped in pcall so reload,
diff, or write failures do not crash the session.

## Testing Plan
- Add `lua/tests/android/actions/context_test.lua` to cover cache hits,
  invalidation on settings changes, and cache bypass when buffer path is
  outside the root.
- Extend `lua/tests/android/ui/file_watcher_test.lua` to assert no prompts
  outside workspace root and to verify prompt coalescing when multiple change
  events fire in quick succession.
- Run `./scripts/run-tests.sh` and ensure all tests pass.

## Out of Scope
- New user configuration options.
- Background timers or async polling for file changes.
- Changing the prompt UI or adding new actions.
