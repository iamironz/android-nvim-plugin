# Troubleshooting

## Health checks

- Run `:checkhealth android` from the project root.
- Checks include SDK root, sdkmanager, avdmanager, adb, emulator, aapt2 build
  tools, Gradle command resolution, and iOS tooling on macOS.
- Include the output when filing an issue.

## SDK not found

- Set `ANDROID_SDK_ROOT` or `ANDROID_HOME`.
- Add `sdk.dir=/path/to/sdk` to `local.properties`.
- Override with `sdk.root` in setup if needed.

## Gradle not found

- Ensure `./gradlew` exists at workspace root.
- Set `build.gradle_command` to a valid path or command.

## No Android targets detected

- Ensure `com.android.application` or `com.android.library` is applied.
- Version catalog aliases like `alias(libs.plugins.androidApplication)` or
  `alias(libs.plugins.android.application)` are supported.
- If you rely on `namespace` only, ensure it is present in build.gradle.

## Telescope missing

- The picker falls back to `vim.ui` when Telescope is not installed.
- Install Telescope to enable richer pickers.

## Run configs not loading

- Confirm `run.config_path` points to the JSON file.
- Path can be absolute or workspace-relative.

## APK not found

- Ensure you built the variant you selected.
- Set `build.scan_all_apk_outputs = true` to scan output folders.
