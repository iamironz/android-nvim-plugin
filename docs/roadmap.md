# Roadmap and Feature Parity

## Purpose

Track feature coverage against Android Studio and identify planned gaps.

## Legend

- `Yes`: implemented
- `No`: not implemented
- `Partial`: partially implemented
- `Planned`: targeted but not yet implemented

## Feature Parity Matrix

| Capability | Android Studio | Plugin | Planned |
| --- | --- | --- | --- |
| Logcat filters (pkg/level/text/regex) | Yes | Yes | - |
| Logcat controls (pause/clear/restart) | Yes | Yes | - |
| Logcat auto reconnect + wait for process | Yes | Yes | - |
| Logcat highlight by level | Yes | Yes | - |
| Logcat filter history + saved settings | Yes | Yes | - |
| Logcat package picker from running procs | Yes | Yes | - |
| Package auto-detect for deploy/logcat | Yes | Yes | - |
| Stack trace navigation from logcat | Yes | Yes | - |
| Build output panel + filter + quickfix | Yes | Yes | - |
| Build variants + module selection | Yes | Yes | - |
| Build + deploy (install/launch) | Yes | Yes | - |
| ADB wait for device + boot completion | Yes | Yes | - |
| Assemble-only build | Yes | Yes | - |
| APK list + copy path | Yes | Yes | - |
| Gradle tasks browser + run | Yes | Yes | - |
| Gradle clean | Yes | Yes | - |
| Emulator + AVD management | Yes | Yes | - |
| Advanced emulator controls (snapshots, GPS) | Yes | Yes | - |
| Device select + app management | Yes | Yes | - |
| ADB device discovery (serial/state/model) | Yes | Yes | - |
| Run configs (Android/JVM/Gradle) | Yes | Yes | - |
| Run config selection + persistence | Yes | Yes | - |
| Run control (run current/stop) | Yes | Yes | - |
| Run all multi-target | Yes | Yes | - |
| iOS build + deploy (xcodebuild) | No | Yes | - |
| Workspace defaults (module/variant/device/logcat) | Yes | Yes | - |
| Autosave + external change prompts | Yes | Yes | - |
| Health check (SDK/Gradle tooling) | Yes | Yes | - |
| Project model sync for LSP | Yes | No | Planned |
| Debugger (DAP attach, breakpoints) | Yes | No | Planned |
| Test runner (unit/instrumented) | Yes | No | Planned |
| Test results + coverage | Yes | No | Planned |
| Gradle sync + project model import | Yes | Partial | Planned |
| Build analyzer + task graph | Yes | No | Planned |
| Android Lint integration | Yes | No | Planned |
| Dependency search + insert (Maven) | Yes | No | Planned |
| Resource + manifest helpers | Yes | No | Planned |
| Manifest merge viewer | Yes | No | Planned |
| APK analyzer | Yes | No | Planned |
| SDK manager | Yes | No | Planned |
| Device file explorer + push/pull | Yes | No | Planned |
| ADB shell utilities (screenshot/record) | Yes | No | Planned |
| Layout/Compose preview | Yes | No | Planned |
| App inspectors (DB/network/layout) | Yes | No | Planned |
| ProGuard/R8 mapping tools | Yes | No | Planned |

Source baseline for planned gaps: feature-gap notes from 2026-02-01.
