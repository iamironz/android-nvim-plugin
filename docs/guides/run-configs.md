# Run Configs Guide

## Purpose

Explain how run configurations are discovered, merged, and selected.

## Config File Resolution

- Default file: `.android.nvim.json`
- Override path: `run.config_path`
- If file is missing or invalid, built-in providers remain available.

## Built-In Providers

Providers are detected in this order:

1. Android: one entry per Android module using saved variant.
1. iOS: one entry per Xcode scheme in workspace.
1. JVM: server/JVM run entry when detected.
1. Gradle task: task-based run entries.
1. Shell: custom entries from JSON file.

Run configs are sorted by provider priority and label.
Gradle task configs are shown in Gradle tasks menu but hidden from the main run list.

## Shell Config Schema

Required fields:

- `id`: stable identifier
- `command` or `args`

Optional fields:

- `label`: display name

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
