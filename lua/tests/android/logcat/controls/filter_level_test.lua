local M = {}
local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")

local function state_with(package, filter)
  return logcat_helpers.build_state({
    logcat = { package = package, filter = filter },
  })
end

local function with_level_select(callback)
  local state = state_with("com.saved", "Old")
  local stubs = {
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_select then
          opts.on_select("W")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, callback)
end

local function level_picker_restarts_logcat()
  with_level_select(function(ctx)
    ctx.vim_state.keymaps["n"]["gl"]()
    assert.eq(ctx.spawn_calls.count, 2, "spawn after level")
  end)
end

local function level_picker_clears_body()
  with_level_select(function(ctx)
    ctx.vim_state.keymaps["n"]["gl"]()
    assert.eq(ctx.clear_body_calls.count, 1, "clear after level")
  end)
end

local function level_picker_persists_level()
  with_level_select(function(ctx)
    ctx.vim_state.keymaps["n"]["gl"]()
    assert.eq(ctx.state.logcat.level, "W", "level persisted")
  end)
end

local function level_picker_updates_header()
  with_level_select(function(ctx)
    ctx.vim_state.keymaps["n"]["gl"]()
    assert.table_eq(
      ctx.header_lines.value,
      { "Package: com.saved", "Filter: Old", "Level: W" },
      "header after level"
    )
  end)
end

function M.run()
  level_picker_restarts_logcat()
  level_picker_clears_body()
  level_picker_persists_level()
  level_picker_updates_header()
end

return M
