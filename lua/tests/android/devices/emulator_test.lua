local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function with_vim_jobstart_stub(fn)
  local original_jobstart = vim.fn.jobstart
  local state = { calls = {} }

  vim.fn.jobstart = function(cmd, opts)
    table.insert(state.calls, { cmd = cmd, opts = opts })
    return 1
  end

  local ok, err = pcall(function()
    fn(state)
  end)

  vim.fn.jobstart = original_jobstart

  if not ok then
    error(err)
  end
end

local function parses_emulator_avd_list()
  local emulator = require("android.devices.emulator")
  local avds = emulator.parse_emulator_avd_list({
    "Pixel_6_API_34",
    "",
    "Wear_API_30",
  })

  assert.table_eq(avds, { "Pixel_6_API_34", "Wear_API_30" }, "emulator avds")
end

local function builds_emulator_command()
  local emulator = require("android.devices.emulator")
  local cmd = emulator.build_command(
    "/sdk/emulator/emulator",
    "Pixel_6_API_34",
    {
      no_window = true,
      wipe_data = true,
      port = 5556,
      gpu = "swiftshader_indirect",
      args = { "-netdelay", "none" },
    }
  )

  assert.table_eq(
    cmd,
    {
      "/sdk/emulator/emulator",
      "-avd",
      "Pixel_6_API_34",
      "-no-window",
      "-wipe-data",
      "-port",
      "5556",
      "-gpu",
      "swiftshader_indirect",
      "-netdelay",
      "none",
    },
    "emulator command"
  )
end

local function builds_emulator_command_with_no_snapshot()
  local emulator = require("android.devices.emulator")
  local cmd = emulator.build_command(
    "/sdk/emulator/emulator",
    "Pixel_6_API_34",
    {
      no_snapshot = true,
    }
  )

  assert.table_eq(
    cmd,
    {
      "/sdk/emulator/emulator",
      "-avd",
      "Pixel_6_API_34",
      "-no-snapshot",
    },
    "emulator no snapshot"
  )
end

local function lists_avds_via_runner()
  local emulator = require("android.devices.emulator")
  local runner = {
    run = function(cmd)
      return { ok = true, stdout = "Pixel_2\n", stderr = "" }
    end,
  }

  local avds = emulator.list(runner, "/sdk/emulator/emulator")
  assert.table_eq(avds, { "Pixel_2" }, "runner avds")
end

local function boots_emulator_and_returns_serial()
  local boot_serial = nil
  local runner = {
    run = function(cmd)
      if cmd[1] == "pgrep" then
        return { ok = true, stdout = "123\n", stderr = "" }
      end
      return { ok = true, stdout = "", stderr = "" }
    end,
  }

  local stubs = {
    ["android.actions.wait"] = {
      wait_for_device = function()
        return {
          ok = true,
          devices = {
            { serial = "emulator-5554", state = "device" },
            { serial = "emulator-5556", state = "device" },
          },
        }
      end,
      wait_for_boot = function(_, _, serial)
        boot_serial = serial
        return { ok = true, booted = true }
      end,
    },
    ["android.devices.adb"] = {
      list = function()
        return { { serial = "emulator-5554", state = "device" } }
      end,
    },
  }

  with_vim_jobstart_stub(function(state)
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.devices.emulator"] = nil
      local emulator = require("android.devices.emulator")
      local result = emulator.boot({
        runner = runner,
        adb_path = "/bin/adb",
        emulator_path = "/sdk/emulator/emulator",
        avd_name = "Pixel_6_API_34",
        start_delay = 0,
      })

      assert.eq(result.ok, true, "boot ok")
      assert.eq(result.serial, "emulator-5556", "boot serial")
      assert.eq(boot_serial, "emulator-5556", "boot wait serial")
      assert.table_eq(
        state.calls[1].cmd,
        { "/sdk/emulator/emulator", "-avd", "Pixel_6_API_34" },
        "boot command"
      )
      assert.eq(state.calls[1].opts.detach, true, "boot detached")
      assert.eq(state.calls[1].opts.cwd, vim.loop.os_homedir(), "boot cwd")
    end)
  end)
end

local function boot_fails_when_process_missing()
  local wait_called = 0
  local runner = {
    run = function(cmd)
      if cmd[1] == "pgrep" then
        return { ok = true, stdout = "", stderr = "" }
      end
      return { ok = true, stdout = "", stderr = "" }
    end,
  }

  local stubs = {
    ["android.actions.wait"] = {
      wait_for_device = function()
        wait_called = wait_called + 1
        return { ok = true, devices = {} }
      end,
      wait_for_boot = function()
        return { ok = true, booted = true }
      end,
    },
    ["android.devices.adb"] = {
      list = function()
        return {}
      end,
    },
  }

  with_vim_jobstart_stub(function()
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.devices.emulator"] = nil
      local emulator = require("android.devices.emulator")
      local result = emulator.boot({
        runner = runner,
        adb_path = "/bin/adb",
        emulator_path = "/sdk/emulator/emulator",
        avd_name = "Pixel_6_API_34",
        start_delay = 0,
      })

      assert.eq(result.ok, false, "boot failed")
      assert.eq(wait_called, 0, "boot wait skipped")
    end)
  end)
end

local function boot_skips_process_check_on_windows()
  local runner = {
    run = function(cmd)
      if cmd[1] == "pgrep" then
        error("pgrep should be skipped on Windows")
      end
      return { ok = true, stdout = "", stderr = "" }
    end,
  }

  local stubs = {
    ["android.actions.wait"] = {
      wait_for_device = function()
        return {
          ok = true,
          devices = { { serial = "emulator-5554", state = "device" } },
        }
      end,
      wait_for_boot = function()
        return { ok = true, booted = true }
      end,
    },
    ["android.devices.adb"] = {
      list = function()
        return {}
      end,
    },
  }

  with_vim_jobstart_stub(function()
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.devices.emulator"] = nil
      local emulator = require("android.devices.emulator")
      local result = emulator.boot({
        runner = runner,
        adb_path = "/bin/adb",
        emulator_path = "/sdk/emulator/emulator",
        avd_name = "Pixel_6_API_34",
        start_delay = 0,
        os_name = "Windows_NT",
      })

      assert.eq(result.ok, true, "boot ok windows")
      assert.eq(result.serial, "emulator-5554", "boot serial windows")
    end)
  end)
end

local function boot_escapes_avd_name_for_pgrep()
  local captured_pattern = nil
  local runner = {
    run = function(cmd)
      if cmd[1] == "pgrep" then
        captured_pattern = cmd[3]
        return { ok = true, stdout = "123\n", stderr = "" }
      end
      return { ok = true, stdout = "", stderr = "" }
    end,
  }

  local stubs = {
    ["android.actions.wait"] = {
      wait_for_device = function()
        return {
          ok = true,
          devices = { { serial = "emulator-5554", state = "device" } },
        }
      end,
      wait_for_boot = function()
        return { ok = true, booted = true }
      end,
    },
    ["android.devices.adb"] = {
      list = function()
        return {}
      end,
    },
  }

  with_vim_jobstart_stub(function()
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.devices.emulator"] = nil
      local emulator = require("android.devices.emulator")
      local result = emulator.boot({
        runner = runner,
        adb_path = "/bin/adb",
        emulator_path = "/sdk/emulator/emulator",
        avd_name = "Pixel 6+API(34)",
        start_delay = 0,
        os_name = "Darwin",
      })

      assert.eq(result.ok, true, "boot ok escaped")
      assert.eq(captured_pattern, "qemu.*Pixel 6\\+API\\(34\\)", "pgrep pattern")
    end)
  end)
end

function M.run()
  parses_emulator_avd_list()
  builds_emulator_command()
  builds_emulator_command_with_no_snapshot()
  lists_avds_via_runner()
  boots_emulator_and_returns_serial()
  boot_fails_when_process_missing()
  boot_skips_process_check_on_windows()
  boot_escapes_avd_name_for_pgrep()
end

return M
