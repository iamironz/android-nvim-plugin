# Devices and ADB Guide

## Purpose

Describe device/emulator selection and ADB app actions from AndroidMenu.

## Device Manager Actions

| Item | Purpose |
| --- | --- |
| Select device | Set default adb device (serial) |
| Select emulator AVD | Set default emulator profile |
| Start emulator | Launch selected AVD |
| Create AVD | Create a new emulator profile |
| Stop emulator | Stop a running emulator |

## ADB App Actions

| Item | Purpose |
| --- | --- |
| ADB install | Install selected APK to selected device |
| Clear app data | Clear package data on selected device |
| Uninstall app | Remove package from selected device |

## Recommended Sequence

1. Select default device or AVD first.
1. Start emulator if needed.
1. Run build/deploy.
1. Use ADB app actions only when package state must be reset.

## Diagnostic Tips

- Run `:checkhealth android` when adb/emulator tooling is missing.
- Use `adb devices` to verify device online state before deploy.

## Related Docs

- Build and deploy: [build-and-deploy.md](build-and-deploy.md)
- Troubleshooting: [../support/troubleshooting.md](../support/troubleshooting.md)
