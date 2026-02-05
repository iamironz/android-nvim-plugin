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

Fix:

- Ensure `namespace` exists when relying on namespace detection.

### Telescope Missing

Quick checks:

- Confirm Telescope is installed if you expect Telescope UI.

Fix:

- Plugin will use `vim.ui` fallback automatically.

### Run Configs Not Loading

Quick checks:

- Confirm `run.config_path` points to valid JSON.
- Confirm path is absolute or workspace-relative as intended.

### APK Not Found

Quick checks:

- Confirm selected variant was built.

Fix:

- Enable `build.scan_all_apk_outputs = true` for recursive output scan fallback.

## Related Docs

- Getting started: [../getting-started.md](../getting-started.md)
- Run config guide: [../guides/run-configs.md](../guides/run-configs.md)
