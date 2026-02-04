local M = {}

local assert = require("tests.helpers.assert")

local function parses_adb_devices_output()
  local adb = require("android.devices.adb")
  local devices = adb.parse_devices({
    "List of devices attached",
    "emulator-5554 device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 "
      .. "device:emulator64_arm64 transport_id:1",
    "0123456789ABCDEF unauthorized usb:1-1 transport_id:2",
    "",
  })

  assert.eq(#devices, 2, "device count")
  assert.eq(devices[1].serial, "emulator-5554", "device serial")
  assert.eq(devices[1].state, "device", "device state")
  assert.eq(devices[1].product, "sdk_gphone64_arm64", "device product")
  assert.eq(devices[1].model, "sdk_gphone64_arm64", "device model")
  assert.eq(devices[1].device, "emulator64_arm64", "device name")
  assert.eq(devices[1].transport_id, "1", "device transport")
  assert.eq(devices[2].serial, "0123456789ABCDEF", "second serial")
  assert.eq(devices[2].state, "unauthorized", "second state")
  assert.eq(devices[2].usb, "1-1", "second usb")
end

local function lists_devices_via_runner()
  local adb = require("android.devices.adb")
  local received = { cmd = nil }
  local runner = {
    run = function(cmd)
      received.cmd = cmd
      return {
        ok = true,
        stdout = "List of devices attached\nserial1 device\n",
        stderr = "",
      }
    end,
  }

  local devices = adb.list(runner, "/sdk/platform-tools/adb")
  assert.eq(#devices, 1, "runner device count")
  assert.eq(devices[1].serial, "serial1", "runner serial")
  assert.eq(received.cmd[1], "/sdk/platform-tools/adb", "runner cmd")
end

function M.run()
  parses_adb_devices_output()
  lists_devices_via_runner()
end

return M
