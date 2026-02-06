local M = {}
local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")
local stubs_helper = require("tests.helpers.stubs")

local function body_lines(vim_state)
  return logcat_helpers.body_lines(vim_state)
end

local function manager_context(options, fn)
  local opts = options or {}
  logcat_helpers.with_vim_stubs(opts.vim_opts or {}, function(vim_state)
    local state = opts.state or logcat_helpers.build_state()
    local header_lines = { value = nil }
    local spawn_calls = { count = 0 }
    local clear_body_calls = { count = 0 }
    local job_callbacks = {}
    local picker_calls = { count = 0, items = nil, title = nil }
    local selection = { value = nil }
    local registry_calls = { resolve = 0, list = 0, select = {} }
    local configs = opts.configs
      or { { id = "android", label = "Android" }, { id = "ios", label = "iOS" } }
    local resolved = opts.resolved_config or configs[1]

    local run_registry = {
      resolve = function()
        registry_calls.resolve = registry_calls.resolve + 1
        return resolved
      end,
      list = function()
        registry_calls.list = registry_calls.list + 1
        return configs
      end,
      select = function(_, config_id)
        table.insert(registry_calls.select, config_id)
        return config_id
      end,
    }

    local picker = {
      select_from_list = function(picker_opts)
        picker_calls.count = picker_calls.count + 1
        picker_calls.items = picker_opts.items
        picker_calls.title = picker_opts.title
        if selection.value and picker_opts.on_select then
          picker_opts.on_select(selection.value)
        end
      end,
    }

    local base_stubs = logcat_helpers.default_stubs(
      vim_state,
      state,
      header_lines,
      spawn_calls,
      clear_body_calls
    )

    local stubs = stubs_helper.merge_stubs(base_stubs, {
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
      ["android.command.job"] = {
        spawn = function(_, job_opts)
          spawn_calls.count = spawn_calls.count + 1
          job_callbacks.on_stdout = job_opts.on_stdout
          job_callbacks.on_stderr = job_opts.on_stderr
          return { ok = true, stop = function() end }
        end,
      },
      ["android.ui.picker"] = picker,
      ["android.run.registry"] = run_registry,
    }, opts.stubs)

    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.logcat.manager"] = nil
      package.loaded["android.logcat.session"] = nil
      local manager = require("android.logcat.manager")
      fn({
        manager = manager,
        vim_state = vim_state,
        state = state,
        header_lines = header_lines,
        spawn_calls = spawn_calls,
        clear_body_calls = clear_body_calls,
        job_callbacks = job_callbacks,
        picker_calls = picker_calls,
        selection = selection,
        registry_calls = registry_calls,
      })
    end)
  end)
end

local function switcher_preserves_session_body_and_header()
  local state = {
    logcat = {
      sessions = {
        android = { package = "com.android", filter = "Main", serial = "device-1" },
        ios = { package = "com.ios", filter = "Ui", serial = "device-1" },
      },
    },
  }

  manager_context({ state = state }, function(ctx)
    ctx.manager.open()
    assert.is_true(ctx.vim_state.keymaps["n"]["gs"] ~= nil, "switch keymap")
    assert.table_eq(
      ctx.header_lines.value,
      { "Package: com.android", "Filter: Main", "Level: " },
      "initial header"
    )

    ctx.job_callbacks.on_stdout({ "android line" })
    assert.table_eq(body_lines(ctx.vim_state), { "android line" }, "android body")

    ctx.selection.value = "ios"
    ctx.vim_state.keymaps["n"]["gs"]()
    assert.table_eq(
      ctx.header_lines.value,
      { "Package: com.ios", "Filter: Ui", "Level: " },
      "ios header"
    )
    assert.eq(#body_lines(ctx.vim_state), 0, "ios body empty")

    ctx.selection.value = "android"
    ctx.vim_state.keymaps["n"]["gs"]()
    assert.table_eq(body_lines(ctx.vim_state), { "android line" }, "android body restored")

    local selected = table.concat(ctx.registry_calls.select, "|")
    assert.eq(selected, "ios|android", "registry select")
    assert.eq(ctx.registry_calls.resolve, 1, "resolve called")
    assert.eq(ctx.registry_calls.list, 2, "list called")
    assert.eq(ctx.picker_calls.count, 2, "picker used")
    assert.eq(#ctx.picker_calls.items, 2, "picker items")
  end)
end

local function open_uses_dock_panel_layout()
  local open_options = nil

  manager_context({
    stubs = {
      ["android.ui.panel"] = {
        open = function(opts)
          open_options = opts
          return { buf = 1, win = 10, control_buf = 2, control_win = 11 }
        end,
        handle = function()
          return { buf = 1, win = 10, control_buf = 2, control_win = 11 }
        end,
        clear = function() end,
        append = function() end,
        set_header_lines = function() end,
        clear_body = function() end,
        replace_body = function() end,
        trim_body = function() end,
        close = function()
          return true
        end,
      },
    },
  }, function(ctx)
    ctx.manager.open()
    assert.eq(open_options and open_options.layout, "dock", "panel layout")
    assert.eq(open_options and open_options.control_height, 3, "panel control height")
  end)
end

local function open_sets_restore_on_startup_flag()
  manager_context({ state = { logcat = {} } }, function(ctx)
    ctx.manager.open()
    assert.eq(ctx.state.logcat.restore_on_startup, true, "restore flag set")
  end)
end

local function open_uses_saved_run_config_without_resolve()
  manager_context({
    state = {
      run = { config_id = "android" },
      logcat = {},
    },
  }, function(ctx)
    ctx.manager.open()
    assert.eq(ctx.registry_calls.resolve, 0, "resolve skipped")
  end)
end

local function closing_panel_clears_restore_on_startup_flag()
  manager_context({ state = { logcat = {} } }, function(ctx)
    ctx.manager.open()
    assert.eq(ctx.state.logcat.restore_on_startup, true, "restore flag set")
    ctx.vim_state.keymaps["n"]["q"]()
    assert.eq(ctx.state.logcat.restore_on_startup, false, "restore flag cleared")
  end)
end

local function restore_on_startup_opens_logcat_when_enabled()
  manager_context({
    state = {
      logcat = {
        restore_on_startup = true,
      },
    },
  }, function(ctx)
    local restored = ctx.manager.restore_on_startup("/workspace")
    assert.eq(restored, true, "restored")
    assert.eq(ctx.spawn_calls.count, 1, "logcat started")
  end)
end

local function restore_on_startup_skips_when_disabled()
  manager_context({
    state = {
      logcat = {
        restore_on_startup = false,
      },
    },
  }, function(ctx)
    local restored = ctx.manager.restore_on_startup("/workspace")
    assert.eq(restored, false, "skipped")
    assert.eq(ctx.spawn_calls.count, 0, "logcat not started")
  end)
end

function M.run()
  switcher_preserves_session_body_and_header()
  open_uses_dock_panel_layout()
  open_sets_restore_on_startup_flag()
  open_uses_saved_run_config_without_resolve()
  closing_panel_clears_restore_on_startup_flag()
  restore_on_startup_opens_logcat_when_enabled()
  restore_on_startup_skips_when_disabled()
end

return M
