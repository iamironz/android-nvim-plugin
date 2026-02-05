# Build and Deploy Guide

## Purpose

Describe build entry points, what each one does, and how to use the build output dock effectively.

## Default Behavior

`AndroidBuild` uses saved module and variant, deploys to selected device or emulator,
updates logcat package selection, and opens logcat when successful.

## Build Entry Points

| Entry | Use It When |
| --- | --- |
| `:AndroidBuild` | You want fast build+deploy with saved defaults |
| Build default | Same as `:AndroidBuild`, from menu |
| Build assemble only | You need output artifacts without deploy |
| Build with prompts | You need to override module/variant for this run |
| Gradle tasks | You need a task outside the standard flow |

## Build Output Dock

Build output is a two-layer bottom dock:

- Control strip (fixed): filter row
- Stream body: build output lines

### Dock Controls

| Key | Action |
| --- | --- |
| `f` | Edit build filter text |
| `<CR>` | On filter row, open filter edit |

Filter syntax supports space-separated terms and `/regex/` patterns.

## Build Errors and Quickfix

- Kotlin/Java build errors are parsed into quickfix entries.
- Use `Show build errors` from AndroidMenu to open the quickfix list.

## Recommended Flow

1. Use `Build default` during normal iteration.
1. Switch to `Build with prompts` only when changing module/variant.
1. Use filter in dock to isolate failing task output before opening quickfix.

## Related Docs

- Logcat behavior after deploy: [logcat.md](logcat.md)
- Commands and menu items: [../reference/commands.md](../reference/commands.md)
