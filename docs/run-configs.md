# Run Configs

Run configs are loaded from a JSON file per workspace. The path defaults to
`.android.nvim.json` and can be overridden via `run.config_path`. If the file
is missing or invalid, only built-in configs are used.

## Built-in configs

The plugin detects configs from providers in this order:

- Android: one entry per Android module using the saved variant.
- iOS: one entry per Xcode scheme in the workspace.
- JVM: a server or JVM run entry when detected.
- Gradle task: task-based entries for quick execution.
- Shell: entries defined in the JSON file.

Configs are sorted by provider priority and label. Gradle task configs are
available via the Gradle tasks menu but hidden from the main run config list
to keep the picker focused.

## Shell configs

Shell configs let you define custom commands. These are merged with built-in
configs when the JSON file is present.

Required fields:

- `id` Unique identifier
- `command` or `args`

Optional fields:

- `label` Display label

Example:

```json
{
  "run": {
    "shell": [
      { "id": "api", "label": "API", "command": "pnpm dev" },
      { "id": "api-args", "label": "API", "args": ["pnpm", "dev", "--port", "3000"] }
    ]
  }
}
```

If you only need one entry, prefer `args` to avoid shell splitting issues:

```json
{
  "run": {
    "shell": [
      { "id": "web", "label": "Web", "args": ["pnpm", "dev", "--filter", "web"] }
    ]
  }
}
```

## Run all

Run-all targets are configured in `run.run_all` within setup:

- `order` determines target ordering
- `target_modules` lets you prefer modules per target

When at least one target config is found, a `Run All` entry is appended. It
invokes the selected targets in the configured order.
