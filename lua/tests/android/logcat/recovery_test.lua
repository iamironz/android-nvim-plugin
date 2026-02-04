local M = {}

local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")
local stubs_helper = require("tests.helpers.stubs")

local function state_with(package, filter)
  return logcat_helpers.build_state({
    logcat = { package = package, filter = filter },
  })
end

local function body_lines(vim_state)
  local lines = vim_state.buffers[1].lines or {}
  local start = (vim_state.header_count or 0) + 1
  local result = {}
  for index = start, #lines do
    result[#result + 1] = lines[index]
  end
  while #result > 0 and result[1] == "" do
    table.remove(result, 1)
  end
  return result
end

local function open_without_device_shows_status_line()
  local state = state_with("com.saved", "")
  local stubs = stubs_helper.merge_stubs({
    ["android.devices.adb"] = {
      list = function()
        return {}
      end,
    },
    ["android.actions.defaults"] = {
      select_device_serial = function()
        return nil
      end,
    },
  })

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    local body = body_lines(ctx.vim_state)
    assert.table_eq(body, { "Status: No adb devices found" }, "device status")
    assert.eq(ctx.spawn_calls.count, 0, "no spawn without device")
  end)
end

local function open_without_process_shows_status_line()
  local state = state_with("com.saved", "")
  local stubs = stubs_helper.merge_stubs({
    ["android.command.runner"] = {
      new = function()
        return {
          run = function()
            return { ok = true, stdout = "", stderr = "" }
          end,
        }
      end,
    },
  })

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    local body = body_lines(ctx.vim_state)
    assert.table_eq(body, { "Status: Waiting for process com.saved" }, "process status")
  end)
end

local function trims_unfiltered_output_to_max_lines()
  local job_callbacks = {}
  local state = state_with("", "")
  local stubs = stubs_helper.merge_stubs({
    ["android.command.job"] = {
      spawn = function(_, opts)
        job_callbacks.on_stdout = opts.on_stdout
        return { ok = true, stop = function() end }
      end,
    },
  })

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    local max_lines = ctx.logcat.default_max_lines
    local lines = {}
    for i = 1, max_lines + 2 do
      lines[i] = "line " .. i
    end

    job_callbacks.on_stdout(lines)

    local body = logcat_helpers.body_lines(ctx.vim_state)
    local summary = string.format(
      "%d|%s|%s",
      #body,
      body[1] or "",
      body[#body] or ""
    )
    local expected = string.format(
      "%d|line 3|line %d",
      max_lines,
      max_lines + 2
    )
    assert.eq(summary, expected, "trimmed count")
  end)
end

local function cleanup_keymap_clears_output_and_resets_state()
  local job_callbacks = {}
  local state = state_with("", "")
  local stubs = stubs_helper.merge_stubs({
    ["android.command.job"] = {
      spawn = function(_, opts)
        job_callbacks.on_stdout = opts.on_stdout
        return { ok = true, stop = function() end }
      end,
    },
  })

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    ctx.vim_state.keymaps["n"]["p"]()
    job_callbacks.on_stdout({ "queued line" })

    ctx.vim_state.keymaps["n"]["C"]()
    job_callbacks.on_stdout({ "after cleanup" })

    local body = logcat_helpers.body_lines(ctx.vim_state)
    assert.table_eq(body, { "after cleanup" }, "cleanup resets backlog")
  end)
end

function M.run()
  open_without_device_shows_status_line()
  open_without_process_shows_status_line()
  trims_unfiltered_output_to_max_lines()
  cleanup_keymap_clears_output_and_resets_state()
end

return M
