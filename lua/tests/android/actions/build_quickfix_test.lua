local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function with_vim_stubs(fn)
  local original_setqflist = vim.fn.setqflist
  local original_cmd = vim.cmd
  local original_notify = vim.notify

  local state = {
    qflist_items = nil,
    qflist_title = nil,
    copen_called = false,
  }

  vim.fn.setqflist = function(items, _, opts)
    state.qflist_items = items
    state.qflist_title = opts and opts.title or nil
  end

  vim.cmd = function(cmd)
    if cmd == "copen" then
      state.copen_called = true
    end
  end

  vim.notify = function() end

  local ok, err = pcall(function()
    fn(state)
  end)

  vim.fn.setqflist = original_setqflist
  vim.cmd = original_cmd
  vim.notify = original_notify

  if not ok then
    error(err)
  end
end

local function context_stub()
  return {
    workspace = function()
      return { root = "/workspace", modules = { ":app" } }
    end,
    load_state = function()
      return { build = { module = ":app", variant = "debug" } }
    end,
    save_state = function()
      return true
    end,
  }
end

local function job_stub()
  return {
    spawn = function(_, opts)
      if opts.on_stdout then
        opts.on_stdout({ "e: /tmp/Foo.kt: (1, 2): Bad" })
      end
      if opts.on_stderr then
        opts.on_stderr({ "stderr line" })
      end
      if opts.on_exit then
        opts.on_exit(1)
      end
      return { ok = true, stop = function() end }
    end,
  }
end

local function panel_stub(state)
  return {
    open = function()
      state.panel_opened = true
    end,
    clear = function()
      state.panel_cleared = true
    end,
    set_header_lines = function() end,
    replace_body = function() end,
    append = function(lines)
      for _, line in ipairs(lines or {}) do
        table.insert(state.panel_lines, line)
      end
    end,
    trim_body = function(max_lines)
      if not max_lines or max_lines <= 0 then
        return
      end
      local overflow = #state.panel_lines - max_lines
      if overflow <= 0 then
        return
      end
      local trimmed = {}
      for i = overflow + 1, #state.panel_lines do
        trimmed[#trimmed + 1] = state.panel_lines[i]
      end
      state.panel_lines = trimmed
    end,
  }
end

local function quickfix_stub(state)
  return {
    parse = function(lines)
      state.parsed_lines = lines
      return {
        { filename = "/tmp/Foo.kt", lnum = 1, col = 2, text = "Bad" },
      }
    end,
  }
end

local function runner_stub()
  return {
    new = function()
      return {
        run = function()
          return { ok = true, stdout = "", stderr = "" }
        end,
      }
    end,
  }
end

local function gradle_stub()
  return {
    assemble_command = function()
      return { "./gradlew", ":app:assembleDebug" }
    end,
  }
end

local function apk_stub()
  return {
    resolve_apk_path = function()
      return { ok = true, path = "/tmp/app.apk" }
    end,
  }
end

local function deploy_stub(state)
  return {
    deploy = function()
      state.deploy_called = true
      return { ok = true }
    end,
  }
end

local function devices_stub()
  return {
    list = function()
      return {}
    end,
  }
end

local function discovery_stub()
  return {
    new = function()
      return {
        tools = function()
          return { adb = "/bin/adb", emulator = "/bin/emulator" }
        end,
        aapt2 = function()
          return nil
        end,
      }
    end,
  }
end

local function wait_stub()
  return {
    wait_for_device = function()
      return { ok = false }
    end,
    wait_for_boot = function()
      return { ok = false }
    end,
  }
end

local function build_stubs(state)
  return {
    ["android.actions.context"] = context_stub(),
    ["android.command.job"] = job_stub(),
    ["android.ui.panel"] = panel_stub(state),
    ["android.build.quickfix"] = quickfix_stub(state),
    ["android.command.runner"] = runner_stub(),
    ["android.build.gradle"] = gradle_stub(),
    ["android.build.apk"] = apk_stub(),
    ["android.build.deploy"] = deploy_stub(state),
    ["android.devices.adb"] = devices_stub(),
    ["android.sdk.discovery"] = discovery_stub(),
    ["android.actions.wait"] = wait_stub(),
  }
end

local function new_state()
  return {
    panel_opened = false,
    panel_cleared = false,
    panel_lines = {},
    parsed_lines = nil,
    deploy_called = false,
    vim_state = nil,
  }
end

local function run_failed_build()
  local state = new_state()

  with_vim_stubs(function(vim_state)
    state.vim_state = vim_state
    stubs_helper.with_stubs(build_stubs(state), function()
      package.loaded["android.build.stream"] = nil
      package.loaded["android.actions.build_helpers"] = nil
      package.loaded["android.command.jobs"] = nil
      package.loaded["android.actions.build"] = nil
      local build = require("android.actions.build")
      build.build_default()
    end)
  end)

  return state
end

local function opens_and_clears_panel_on_failure()
  local state = run_failed_build()

  assert.is_true(state.panel_opened, "panel opened")
  assert.is_true(state.panel_cleared, "panel cleared")
end

local function appends_build_output_to_panel()
  local state = run_failed_build()

  assert.eq(#state.panel_lines, 2, "panel lines")
  assert.eq(state.panel_lines[1], "e: /tmp/Foo.kt: (1, 2): Bad", "panel stdout")
  assert.eq(state.panel_lines[2], "stderr line", "panel stderr")
end

local function parses_output_for_quickfix()
  local state = run_failed_build()

  assert.eq(state.parsed_lines[1], "e: /tmp/Foo.kt: (1, 2): Bad", "parsed stdout")
  assert.eq(state.parsed_lines[2], "stderr line", "parsed stderr")
end

local function sets_quickfix_list_on_failure()
  local state = run_failed_build()

  assert.eq(#state.vim_state.qflist_items, 1, "qflist count")
  assert.eq(state.vim_state.qflist_items[1].filename, "/tmp/Foo.kt", "qflist filename")
  assert.eq(state.vim_state.qflist_title, "Android build errors", "qflist title")
end

local function opens_quickfix_window_on_failure()
  local state = run_failed_build()

  assert.is_true(state.vim_state.copen_called, "copen called")
end

local function does_not_deploy_on_failure()
  local state = run_failed_build()

  assert.is_true(not state.deploy_called, "deploy not called")
end

function M.run()
  opens_and_clears_panel_on_failure()
  appends_build_output_to_panel()
  parses_output_for_quickfix()
  sets_quickfix_list_on_failure()
  opens_quickfix_window_on_failure()
  does_not_deploy_on_failure()
end

return M
