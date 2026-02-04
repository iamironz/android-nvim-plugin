local M = {}

local assert = require("tests.helpers.assert")

local function parses_avdmanager_list_output()
  local avd = require("android.devices.avd")
  local entries = avd.parse_avd_list({
    "Available Android Virtual Devices:",
    "    Name: Pixel_6_API_34",
    "  Device: pixel_6 (Google)",
    "    Path: /Users/me/.android/avd/Pixel_6_API_34.avd",
    "  Target: Google APIs (Google Inc.)",
    "          Based on: Android 14 (U) Tag/ABI: " .. "google_apis/x86_64",
    "---------",
    "    Name: Wear_API_30",
    "  Device: wearos_square (Google)",
    "    Path: /Users/me/.android/avd/Wear_API_30.avd",
    "  Target: Android 11 (R)",
    "          Based on: Android 11 (R) Tag/ABI: " .. "default/x86",
  })

  assert.eq(#entries, 2, "avd count")
  assert.eq(entries[1].name, "Pixel_6_API_34", "avd name")
  assert.eq(entries[1].device, "pixel_6 (Google)", "avd device")
  assert.eq(entries[1].path, "/Users/me/.android/avd/Pixel_6_API_34.avd", "avd path")
  assert.eq(entries[1].target, "Google APIs (Google Inc.)", "avd target")
  assert.eq(entries[1].abi, "google_apis/x86_64", "avd abi")
  assert.eq(entries[2].name, "Wear_API_30", "second name")
end

local function lists_avds_via_runner()
  local avd = require("android.devices.avd")
  local runner = {
    run = function(cmd)
      return {
        ok = true,
        stdout = table.concat({
          "Available Android Virtual Devices:",
          "    Name: Test_API_29",
          "    Path: /tmp/Test_API_29.avd",
          "",
        }, "\n"),
        stderr = "",
      }
    end,
  }

  local entries = avd.list(runner, "/sdk/cmdline-tools/latest/bin/avdmanager")
  assert.eq(entries[1].name, "Test_API_29", "runner name")
end

local function parses_avdmanager_device_list_output()
  local avd = require("android.devices.avd")
  local entries = avd.parse_device_list({
    "Available devices definitions:",
    "id: 0 or \"Nexus 5\"",
    "    Name: Nexus 5",
    "    OEM : Google",
    "    Tag : google_apis",
    "---------",
    "id: 1 or \"pixel\"",
    "    Name: Pixel",
    "    OEM : Google",
  })

  assert.eq(#entries, 2, "device count")
  assert.eq(entries[1].id, "0", "device id")
  assert.eq(entries[1].name, "Nexus 5", "device name")
  assert.eq(entries[1].oem, "Google", "device oem")
  assert.eq(entries[1].tag, "google_apis", "device tag")
  assert.eq(entries[2].id, "1", "second id")
end

local function builds_avd_create_command()
  local avd = require("android.devices.avd")
  local result = avd.build_create_command(
    "/sdk/cmdline-tools/latest/bin/avdmanager",
    "Pixel_6_API_34",
    "system-images;android-34;google_apis;x86_64",
    "0",
    { force = true }
  )

  assert.is_true(result.ok, "create command ok")
  assert.table_eq(
    result.cmd,
    {
      "/sdk/cmdline-tools/latest/bin/avdmanager",
      "create",
      "avd",
      "-n",
      "Pixel_6_API_34",
      "-k",
      "system-images;android-34;google_apis;x86_64",
      "-d",
      "0",
      "--force",
    },
    "create command"
  )
end

local function returns_error_when_create_command_missing_name()
  local avd = require("android.devices.avd")
  local result = avd.build_create_command(
    "/sdk/cmdline-tools/latest/bin/avdmanager",
    "",
    "system-images;android-34;google_apis;x86_64",
    "0"
  )
  assert.eq(result.ok, false, "create missing name")
  assert.contains(result.error, "name", "create missing name error")
end

function M.run()
  parses_avdmanager_list_output()
  lists_avds_via_runner()
  parses_avdmanager_device_list_output()
  builds_avd_create_command()
  returns_error_when_create_command_missing_name()
end

return M
