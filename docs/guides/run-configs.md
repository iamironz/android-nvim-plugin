# Run Configs Guide

## Purpose

Explain how run configurations are discovered, merged, and selected.

## Config File Resolution

- Default file: `.android.nvim.json`
- Override path: `run.config_path`
- The same JSON file can also provide shared project overrides used outside the
  run list, including `app.package` and `build.apk_overrides`.
- If file is missing or invalid, built-in providers remain available.

## Built-In Providers

Providers are detected in this order:

1. Android: one entry per Android app module using saved variant.
1. iOS: one entry per Xcode scheme in workspace.
1. JVM: server/JVM run entry when detected.
1. Gradle task: task-based run entries.
1. Shell: custom entries from JSON file.

Run configs are sorted by provider priority and label.
Gradle task configs are shown in Gradle tasks menu but hidden from the main run list.

Android discovery prefers cached Gradle snapshot/task metadata when available,
then falls back to module build-file scans. In composite Gradle workspaces,
included builds from `includeBuild(...)` are folded into Android module
discovery, so Android configs can appear as IDs like `android:client:app`.

## Module Selection Sync

`Build Variants -> Select module` updates saved Android build defaults and, when
the active run target is Android, also switches the selected Android run config
to the matching module. Explicit non-Android selections stay unchanged.

This keeps `:AndroidBuild`, `:AndroidRun`, and logcat session selection aligned
after switching modules from the Build Variants menu.

## Shell Config Schema

Required fields:

- `id`: stable identifier
- `command` or `args`

Optional fields:

- `label`: display name

Example:

```json
{
  "app": {
    "package": "com.example.app"
  },
  "build": {
    "apk_overrides": [
      {
        "module": ":app",
        "variant": "debug",
        "path": "artifacts/app-debug.apk"
      }
    ]
  },
  "run": {
    "shell": [
      { "id": "api", "label": "API", "command": "pnpm dev" },
      { "id": "api-args", "label": "API", "args": ["pnpm", "dev", "--port", "3000"] }
    ]
  }
}
```

Use `app.package` when automatic package detection is unreliable, and
`build.apk_overrides` when APKs live outside the default Gradle output layout.

Prefer `args` to avoid shell splitting issues:

```json
{
  "run": {
    "shell": [
      { "id": "web", "label": "Web", "args": ["pnpm", "dev", "--filter", "web"] }
    ]
  }
}
```

## Run All

`Run All` appears when at least one target config exists.
`run.run_all` controls behavior:

- `order`: target execution order
- `target_modules`: preferred modules per target

## Related Docs

- Configuration options: [../reference/configuration.md#run](../reference/configuration.md#run)
- Commands: [../reference/commands.md](../reference/commands.md)
