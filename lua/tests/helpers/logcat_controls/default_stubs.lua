local M = {}

local stubs_helper = require("tests.helpers.stubs")

local function context_stubs(state)
  return {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
  }
end

local function discovery_stubs()
  return {
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function()
            return { adb = "/bin/adb" }
          end,
          aapt2 = function()
            return nil
          end,
        }
      end,
    },
  }
end

local function runner_stubs()
  return {
    ["android.command.runner"] = {
      new = function()
        return {
          run = function()
            return { ok = true, stdout = "123", stderr = "" }
          end,
        }
      end,
    },
  }
end

local function adb_stubs()
  return {
    ["android.devices.adb"] = {
      list = function()
        return { { serial = "device-1", state = "device" } }
      end,
    },
  }
end

local function defaults_stubs()
  return {
    ["android.actions.defaults"] = {
      select_device_serial = function(_, saved)
        return saved or "device-1"
      end,
    },
  }
end

local function package_stubs()
  return {
    ["android.logcat.package"] = {
      resolve_default_package = function()
        return "com.default"
      end,
    },
  }
end

local function command_stubs()
  return {
    ["android.logcat.command"] = {
      build = function()
        return { "adb", "logcat" }
      end,
    },
  }
end

local function parser_stubs()
  return {
    ["android.logcat.parser"] = {
      parse_stack_line = function()
        return nil
      end,
    },
  }
end

local function job_stubs(spawn_calls)
  return {
    ["android.command.job"] = {
      spawn = function()
        spawn_calls.count = spawn_calls.count + 1
        return { ok = true, stop = function() end }
      end,
    },
  }
end

local function panel_stubs(vim_state, header_lines, panel_names, clear_body_calls, helpers)
  local buffer_set_lines = helpers.buffer_set_lines
  local set_header_lines_in_buffer = helpers.set_header_lines_in_buffer
  local trim_body_lines = helpers.trim_body_lines

  return {
    ["android.ui.panel"] = {
      open = function() end,
      clear = function() end,
      append = function(lines)
        buffer_set_lines(vim_state, 1, -1, -1, lines or {})
      end,
      set_header_lines = function(lines)
        header_lines.value = lines
        set_header_lines_in_buffer(vim_state, lines)
      end,
      set_names = function(names)
        if not panel_names then
          return
        end
        local snapshot = {
          body = names and names.body or nil,
          control = names and names.control or nil,
        }
        panel_names.value = snapshot
        panel_names.history = panel_names.history or {}
        panel_names.history[#panel_names.history + 1] = snapshot
      end,
      clear_body = function()
        clear_body_calls.count = clear_body_calls.count + 1
        buffer_set_lines(vim_state, 1, vim_state.header_count or 0, -1, {})
      end,
      replace_body = function(lines)
        buffer_set_lines(vim_state, 1, vim_state.header_count or 0, -1, lines or {})
      end,
      trim_body = function(max_lines)
        trim_body_lines(vim_state, max_lines)
      end,
      close = function()
        return true
      end,
    },
  }
end

function M.build(opts)
  local options = opts or {}
  return stubs_helper.merge_stubs(
    context_stubs(options.state),
    discovery_stubs(),
    runner_stubs(),
    adb_stubs(),
    defaults_stubs(),
    package_stubs(),
    command_stubs(),
    parser_stubs(),
    job_stubs(options.spawn_calls),
    panel_stubs(
      options.vim_state,
      options.header_lines,
      options.panel_names,
      options.clear_body_calls,
      options.helpers or {}
    )
  )
end

return M
