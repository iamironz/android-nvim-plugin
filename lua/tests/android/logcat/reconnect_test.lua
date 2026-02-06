local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")
local logcat_helpers = require("tests.helpers.logcat_controls")

local function reconnect_schedules_restart()
  logcat_helpers.with_vim_stubs({}, function()
    local spawn_calls = { count = 0, on_exit = nil }
    local scheduler = { count = 0, delay = nil, fn = nil, body = nil }
    local runner = {
      run = function()
        return { ok = true, stdout = "" }
      end,
    }

    local stubs = {
      ["android.command.job"] = {
        spawn = function(_, opts)
          spawn_calls.count = spawn_calls.count + 1
          spawn_calls.on_exit = opts.on_exit
          return { ok = true, stop = function() end }
        end,
      },
      ["android.ui.panel"] = {
        open = function() end,
        clear = function() end,
        append = function() end,
        set_header_lines = function() end,
        clear_body = function() end,
        replace_body = function(lines)
          scheduler.body = lines
        end,
        trim_body = function() end,
        close = function() return true end,
      },
      ["android.ui.panel_header"] = {
        logcat_lines = function()
          return { "Package: com.app", "Filter: ", "Level: " }
        end,
      },
      ["android.logcat.command"] = {
        build = function()
          return { "adb", "logcat" }
        end,
      },
      ["android.logcat.filters"] = {
        parse_terms = function()
          return {}
        end,
        normalize_level = function(value)
          return value
        end,
        build = function(options)
          return { level = options and options.level }
        end,
        filter_lines = function(lines)
          return lines or {}
        end,
      },
      ["android.logcat.processes"] = {
        list_packages = function()
          return {}
        end,
      },
      ["android.logcat.stack_trace"] = {
        open_stack_trace = function() end,
      },
      ["android.devices.adb"] = {
        list = function()
          return { { serial = "device-1", state = "device" } }
        end,
      },
      ["android.actions.defaults"] = {
        select_device_serial = function()
          return "device-1"
        end,
      },
    }

    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.logcat.session"] = nil
      local session = require("android.logcat.session")
      local instance = session.new({
        config_id = "android",
        workspace = { root = "/workspace" },
        root = "/workspace",
        origin_win = 1,
        buf = 1,
        win = 1,
        package = "com.app",
        filter = "",
        serial = "device-1",
        adb_path = "/bin/adb",
        runner = runner,
        state = {},
        reconnect = {
          base_delay = 1000,
          max_delay = 1000,
          jitter = 0,
          max_attempts = 2,
          random = function() return 0 end,
          schedule = function(delay, fn)
            scheduler.count = scheduler.count + 1
            scheduler.delay = delay
            scheduler.fn = fn
          end,
        },
      })

      instance.active = true
      session.start(instance)
      assert.eq(spawn_calls.count, 1, "initial spawn")
      spawn_calls.on_exit(1)
      assert.eq(scheduler.delay, 1000, "reconnect delay")
      assert.contains(scheduler.body[1], "Logcat disconnected", "status message")

      scheduler.fn()
      assert.eq(spawn_calls.count, 2, "reconnect spawn")
    end)
  end)
end

local function reconnect_stops_after_max_attempts()
  logcat_helpers.with_vim_stubs({}, function()
    local spawn_calls = { count = 0, on_exit = nil }
    local scheduler = { count = 0, queue = {}, body = nil }
    local runner = {
      run = function()
        return { ok = true, stdout = "" }
      end,
    }

    local stubs = {
      ["android.command.job"] = {
        spawn = function(_, opts)
          spawn_calls.count = spawn_calls.count + 1
          spawn_calls.on_exit = opts.on_exit
          return { ok = true, stop = function() end }
        end,
      },
      ["android.ui.panel"] = {
        open = function() end,
        clear = function() end,
        append = function() end,
        set_header_lines = function() end,
        clear_body = function() end,
        replace_body = function(lines)
          scheduler.body = lines
        end,
        trim_body = function() end,
        close = function() return true end,
      },
      ["android.ui.panel_header"] = {
        logcat_lines = function()
          return { "Package: com.app", "Filter: ", "Level: " }
        end,
      },
      ["android.logcat.command"] = {
        build = function()
          return { "adb", "logcat" }
        end,
      },
      ["android.logcat.filters"] = {
        parse_terms = function()
          return {}
        end,
        normalize_level = function(value)
          return value
        end,
        build = function(options)
          return { level = options and options.level }
        end,
        filter_lines = function(lines)
          return lines or {}
        end,
      },
      ["android.logcat.processes"] = {
        list_packages = function()
          return {}
        end,
      },
      ["android.logcat.stack_trace"] = {
        open_stack_trace = function() end,
      },
      ["android.devices.adb"] = {
        list = function()
          return { { serial = "device-1", state = "device" } }
        end,
      },
      ["android.actions.defaults"] = {
        select_device_serial = function()
          return "device-1"
        end,
      },
    }

    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.logcat.session"] = nil
      local session = require("android.logcat.session")
      local instance = session.new({
        config_id = "android",
        workspace = { root = "/workspace" },
        root = "/workspace",
        origin_win = 1,
        buf = 1,
        win = 1,
        package = "com.app",
        filter = "",
        serial = "device-1",
        adb_path = "/bin/adb",
        runner = runner,
        state = {},
        reconnect = {
          base_delay = 1000,
          max_delay = 1000,
          jitter = 0,
          max_attempts = 2,
          random = function() return 0 end,
          schedule = function(_, fn)
            scheduler.count = scheduler.count + 1
            table.insert(scheduler.queue, fn)
          end,
        },
      })

      instance.active = true
      session.start(instance)
      assert.eq(spawn_calls.count, 1, "initial spawn")

      spawn_calls.on_exit(1)
      assert.eq(scheduler.count, 1, "first reconnect scheduled")
      local retry1 = table.remove(scheduler.queue, 1)
      retry1()
      assert.eq(spawn_calls.count, 2, "first reconnect spawn")

      spawn_calls.on_exit(1)
      assert.eq(scheduler.count, 2, "second reconnect scheduled")
      local retry2 = table.remove(scheduler.queue, 1)
      retry2()
      assert.eq(spawn_calls.count, 3, "second reconnect spawn")

      spawn_calls.on_exit(1)
      assert.eq(scheduler.count, 2, "no reconnect after max attempts")
      assert.contains(scheduler.body[1], "retry limit reached", "limit message")
    end)
  end)
end

function M.run()
  reconnect_schedules_restart()
  reconnect_stops_after_max_attempts()
end

return M
