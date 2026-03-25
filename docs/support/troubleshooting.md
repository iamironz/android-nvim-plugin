# Troubleshooting

## How To Use This Page

1. Match your symptom.
1. Run listed quick checks.
1. Apply fix.
1. Re-run `:checkhealth android` if environment-related.

## Health Check Baseline

Run `:checkhealth android` from project root.

Checks cover SDK discovery, `sdkmanager`, `avdmanager`, `adb`, `emulator`, `aapt2`,
Gradle command resolution, and iOS tooling on macOS.

## Common Symptoms

### SDK Not Found

Quick checks:

- Ensure `ANDROID_SDK_ROOT` or `ANDROID_HOME` is set.
- Confirm `local.properties` has `sdk.dir=/path/to/sdk` when used.

Fix:

- Set `sdk.root` in setup if auto-discovery is not stable in your environment.

### Gradle Not Found

Quick checks:

- Ensure `./gradlew` exists at workspace root.

Fix:

- Set `build.gradle_command` to a valid command or path.

### No Android Targets Detected

Quick checks:

- Ensure `com.android.application` or `com.android.library` plugin is applied.
- For version catalogs, verify plugin alias is one of supported Android forms.
- In composite builds, verify the root `settings.gradle[.kts]` includes the
  expected `includeBuild(...)` entries and each included build has its own
  `settings.gradle[.kts]`.

Fix:

- Ensure `namespace` exists when relying on namespace detection.
- If build-file scans look stale, reopen AndroidMenu or rerun an explicit Gradle
  action so task/snapshot-based discovery can refresh module detection.

### Telescope Missing

Quick checks:

- Confirm Telescope is installed if you expect Telescope UI.

Fix:

- Plugin will use `vim.ui` fallback automatically.

### Run Configs Not Loading

Quick checks:

- Confirm `run.config_path` points to valid JSON.
- Confirm path is absolute or workspace-relative as intended.
- If you use `.android.nvim.json`, validate the whole file: the same JSON may be
  read for run configs, `app.package`, and `build.apk_overrides`.

Fix:

- Correct malformed JSON. The plugin warns once per broken file path with
  `Invalid shared project config JSON in ... Check JSON syntax.`

### APK Not Found

Quick checks:

- Confirm selected variant was built.
- Confirm any `build.apk_overrides` entry matches both module and variant.

Fix:

- Enable `build.scan_all_apk_outputs = true` for recursive output scan fallback.

### Gradle Prefetch Warning

Quick checks:

- Read the warning text; it includes the first useful Gradle failure line.
- Confirm `build.gradle_command` resolves correctly for this workspace.
- Re-run the failing Gradle command manually if you need full output.

Fix:

- Fix the Gradle/workspace issue, then reopen AndroidMenu or rerun
  `:AndroidGradleTasks` / `:AndroidBuildPrompt` to refresh prefetch data.

## Related Docs

- Getting started: [../getting-started.md](../getting-started.md)
- Run config guide: [../guides/run-configs.md](../guides/run-configs.md)
