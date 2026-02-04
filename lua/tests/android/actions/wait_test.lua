local M = {}

local assert = require("tests.helpers.assert")

local function waits_for_connected_device_with_defaults()
  local wait = require("android.actions.wait")
  local adb = require("android.devices.adb")

  local original_wait = vim.wait
  local original_list = adb.list

  local captured = {
    timeout = nil,
    interval = nil,
    list_calls = 0,
  }

  adb.list = function()
    captured.list_calls = captured.list_calls + 1
    if captured.list_calls == 1 then
      return { { serial = "emulator-5554", state = "offline" } }
    end
    return { { serial = "emulator-5554", state = "device" } }
  end

  vim.wait = function(timeout, condition, interval)
    captured.timeout = timeout
    captured.interval = interval
    if condition() then
      return true
    end
    return condition()
  end

  local result = wait.wait_for_device({ run = function() end }, "/sdk/adb")

  adb.list = original_list
  vim.wait = original_wait

  assert.eq(result.ok, true, "wait ok")
  assert.eq(captured.timeout, 120000, "default timeout")
  assert.eq(captured.interval, 1000, "default interval")
  assert.eq(captured.list_calls, 2, "poll count")
end

local function returns_timeout_when_no_device()
  local wait = require("android.actions.wait")
  local adb = require("android.devices.adb")

  local original_wait = vim.wait
  local original_list = adb.list

  local captured = {
    timeout = nil,
    interval = nil,
    list_calls = 0,
  }

  adb.list = function()
    captured.list_calls = captured.list_calls + 1
    return {}
  end

  vim.wait = function(timeout, condition, interval)
    captured.timeout = timeout
    captured.interval = interval
    condition()
    return false
  end

  local result = wait.wait_for_device(
    { run = function() end },
    "/sdk/adb",
    { timeout = 5000, interval = 250 }
  )

  adb.list = original_list
  vim.wait = original_wait

  assert.eq(result.ok, false, "wait timeout")
  assert.eq(captured.timeout, 5000, "custom timeout")
  assert.eq(captured.interval, 250, "custom interval")
  assert.eq(captured.list_calls, 1, "poll count")
end

local function waits_for_boot_property_with_defaults()
  local wait = require("android.actions.wait")

  local captured = {
    timeout = nil,
    interval = nil,
    calls = 0,
    commands = {},
  }

  local runner = {
    run = function(cmd)
      captured.calls = captured.calls + 1
      captured.commands[captured.calls] = cmd
      if captured.calls == 1 then
        return { ok = true, stdout = "0\n" }
      end
      return { ok = true, stdout = "1\n" }
    end,
  }

  local wait_fn = function(timeout, condition, interval)
    captured.timeout = timeout
    captured.interval = interval
    if condition() then
      return true
    end
    return condition()
  end

  local result = wait.wait_for_boot(
    runner,
    "/sdk/adb",
    "emulator-5554",
    { wait_fn = wait_fn }
  )

  assert.eq(result.ok, true, "boot ok")
  assert.eq(result.booted, true, "booted")
  assert.eq(captured.timeout, 120000, "default timeout")
  assert.eq(captured.interval, 1000, "default interval")
  assert.eq(captured.calls, 2, "poll count")
  assert.table_eq(
    captured.commands[1],
    { "/sdk/adb", "-s", "emulator-5554", "shell", "getprop", "sys.boot_completed" },
    "adb command"
  )
end

local function returns_timeout_when_boot_incomplete()
  local wait = require("android.actions.wait")

  local captured = {
    timeout = nil,
    interval = nil,
    calls = 0,
  }

  local runner = {
    run = function()
      captured.calls = captured.calls + 1
      return { ok = true, stdout = "0" }
    end,
  }

  local wait_fn = function(timeout, condition, interval)
    captured.timeout = timeout
    captured.interval = interval
    condition()
    return false
  end

  local result = wait.wait_for_boot(
    runner,
    "/sdk/adb",
    "emulator-5554",
    { timeout = 5000, interval = 250, wait_fn = wait_fn }
  )

  assert.eq(result.ok, false, "boot timeout")
  assert.eq(result.booted, false, "booted")
  assert.eq(captured.timeout, 5000, "custom timeout")
  assert.eq(captured.interval, 250, "custom interval")
  assert.eq(captured.calls, 1, "poll count")
end

function M.run()
  waits_for_connected_device_with_defaults()
  returns_timeout_when_no_device()
  waits_for_boot_property_with_defaults()
  returns_timeout_when_boot_incomplete()
end

return M
