# Build and Deploy Guide

## Purpose

Describe build entry points, what each one does, and how to use the build output dock effectively.

## Default Behavior

`:AndroidBuild` uses saved module and variant, deploys to selected device or emulator,
updates logcat package selection, and opens logcat when successful.

Android module and variant discovery prefers cached Gradle snapshot/task data
when available. In composite Gradle workspaces, included builds discovered via
`includeBuild(...)` participate in module and task discovery.

## Build Entry Points

| Entry Point | Default Shortcut | Use It When |
| --- | --- | --- |
| `:AndroidBuild` | `<leader>ab` | You want fast build+deploy with saved defaults |
| `:AndroidBuildPrompt` | None | You want module/variant prompts for one run |
| `:AndroidBuildAssemble` | None | You need output artifacts without deploy |
| `:AndroidGradleTasks` | None | You need a task outside the standard flow |
| `:AndroidIOSBuild` | None | You need to build an iOS workspace/project |
| `:AndroidIOSDeploy` | None | You need to deploy iOS app to simulator/device |
| AndroidMenu `Build default` | `<leader>am` then menu | Same action as `:AndroidBuild` |
| AndroidMenu `Build with prompts` | `<leader>am` then menu | Same action as `:AndroidBuildPrompt` |
| AndroidMenu `Build assemble only` | `<leader>am` then menu | Same action as `:AndroidBuildAssemble` |
| AndroidMenu `Gradle tasks` | `<leader>am` then menu | Same action as `:AndroidGradleTasks` |
| AndroidMenu `iOS build` | `<leader>am` then menu | Same action as `:AndroidIOSBuild` |
| AndroidMenu `iOS deploy` | `<leader>am` then menu | Same action as `:AndroidIOSDeploy` |

## Build Output Dock

Build output is a two-layer bottom dock:

- Control strip (fixed): filter row
- Stream body: build output lines

### Dock Controls

| Key | Action |
| --- | --- |
| `q`, `<Esc>` | Close build output panel |
| `f` | Edit build filter text |
| `<CR>` | On filter row, open filter edit |

Filter syntax supports space-separated terms and `/regex/` patterns.

## Build Errors and Quickfix

- Kotlin/Java build errors are parsed into quickfix entries.
- Use `Show build errors` from AndroidMenu to open the quickfix list.

## Shared Project Overrides

The shared `.android.nvim.json` file can pin build/deploy inputs when Gradle
outputs are non-standard:

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
  }
}
```

- `build.apk_overrides` maps a module+variant to a specific APK path.
- `app.package` provides the package name used by deploy/logcat flows when APK
  or manifest-based detection is not the right source.

## Prefetch Warnings

AndroidMenu starts background Gradle prefetch for run configs, task counts, and
variant data. If that Gradle fetch fails, the plugin shows a warning like
`Gradle tasks failed (exit N): ...` instead of leaving discovery silently stuck.

You can still rerun `:AndroidGradleTasks` or `:AndroidBuildPrompt` after fixing
the Gradle command or workspace issue.

## Recommended Flow

1. Use `:AndroidBuild` during normal Android iteration.
1. Switch to `:AndroidBuildPrompt` only when changing module/variant.
1. Use `:AndroidBuildAssemble` when you only need APK artifacts.
1. Use `:AndroidGradleTasks` for one-off or custom Gradle tasks.
1. Use `:AndroidIOSBuild` and `:AndroidIOSDeploy` for iOS projects.
1. Use filter in dock to isolate failing task output before opening quickfix.

## Related Docs

- Logcat behavior after deploy: [logcat.md](logcat.md)
- Commands and menu items: [../reference/commands.md](../reference/commands.md)
