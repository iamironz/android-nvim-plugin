local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function run_action_picker_with_single_item()
  local picker_opts = nil
  local selected_action = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Targets",
            items = {
              {
                id = "build_default",
                label = "Build default",
                desc = "Build using defaults",
              },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
        if opts.on_select then
          opts.on_select("build_default")
        end
      end,
    },
    ["android.actions.registry"] = {
      run = function(action_id)
        selected_action = action_id
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open()
  end)

  local label = picker_opts.format(picker_opts.items[1])
  return {
    picker_opts = picker_opts,
    selected_action = selected_action,
    label = label,
  }
end

local function action_picker_sets_title()
  local result = run_action_picker_with_single_item()
  assert.eq(result.picker_opts.title, "Android Actions", "picker title")
end

local function action_picker_formats_selected_label()
  local result = run_action_picker_with_single_item()
  assert.eq(result.label, "Targets  Build default - Build using defaults", "formatted label")
end

local function action_picker_runs_selected_action()
  local result = run_action_picker_with_single_item()
  assert.eq(result.selected_action, "build_default", "selected action")
end

local function action_picker_formats_entries_with_section_and_desc()
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Targets",
            items = {
              {
                id = "build_default",
                label = "Build default",
                desc = "Build using defaults",
              },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
      end,
    },
    ["android.actions.registry"] = {
      run = function() end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open()
  end)

  local entry = picker_opts.items[1]
  local formatted = picker_opts.format(entry)
  assert.eq(formatted, "Targets  Build default - Build using defaults", "entry format")
end

local function action_picker_passes_default_query_to_picker()
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Targets",
            items = {
              {
                id = "build_default",
                label = "Build default",
                desc = "Build using defaults",
              },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
      end,
    },
    ["android.actions.registry"] = {
      run = function() end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open({ default_query = "b" })
  end)

  assert.eq(picker_opts.default, "b", "default query")
end

local function action_picker_formats_entries_without_desc()
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Targets",
            items = {
              {
                id = "build_default",
                label = "Build default",
              },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
      end,
    },
    ["android.actions.registry"] = {
      run = function() end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open()
  end)

  local entry = picker_opts.items[1]
  local formatted = picker_opts.format(entry)
  assert.eq(formatted, "Targets  Build default", "entry format without desc")
end

local function action_picker_includes_summary_in_title_when_enabled()
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Run",
            items = {
              {
                id = "run_current",
                label = "Run current",
                desc = "Run default",
              },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
      end,
    },
    ["android.actions.registry"] = {
      run = function() end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return {
          "Summary",
          "Run: Android",
          "Module: app",
          "Variant: debug",
          "Device: emulator-5554",
          "Logcat: none",
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open({ title = "Android Menu", include_summary = true })
  end)

  assert.eq(
    picker_opts.title,
    "Android Menu - Run Android | Module app | Variant debug",
    "summary title"
  )
end

local function action_picker_keeps_title_when_summary_empty()
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Run",
            items = {
              {
                id = "run_current",
                label = "Run current",
                desc = "Run default",
              },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
      end,
    },
    ["android.actions.registry"] = {
      run = function() end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return {}
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open({ title = "Android Menu", include_summary = true })
  end)

  assert.eq(picker_opts.title, "Android Menu", "summary empty title")
end

local function action_picker_keeps_title_when_summary_unrelated()
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Run",
            items = {
              {
                id = "run_current",
                label = "Run current",
                desc = "Run default",
              },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
      end,
    },
    ["android.actions.registry"] = {
      run = function() end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return {
          "Summary",
          "Flavor: local",
          "Target: device",
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open({ title = "Android Menu", include_summary = true })
  end)

  assert.eq(picker_opts.title, "Android Menu", "summary unrelated title")
end

local function action_picker_skips_none_values_in_summary_title()
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Run",
            items = {
              {
                id = "run_current",
                label = "Run current",
                desc = "Run default",
              },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
      end,
    },
    ["android.actions.registry"] = {
      run = function() end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return {
          "Summary",
          "Run: none",
          "Module: app",
          "Variant: debug",
          "Device: emulator-5554",
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open({ title = "Android Menu", include_summary = true })
  end)

  assert.eq(
    picker_opts.title,
    "Android Menu - Module app | Variant debug | Device emulator-5554",
    "summary title skips none"
  )
end

local function action_picker_skips_missing_action_id()
  local called = false
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Run",
            items = {
              { label = "Run current", desc = "Run default" },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_select then
          opts.on_select(nil)
        end
      end,
    },
    ["android.actions.registry"] = {
      run = function()
        called = true
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open()
  end)

  assert.eq(called, false, "missing action id")
end

local function action_picker_passes_on_cancel_to_picker()
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return { { title = "Run", items = { { id = "run" } } } }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
      end,
    },
    ["android.actions.registry"] = { run = function() end },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open({ on_cancel = function() end })
  end)

  assert.eq(type(picker_opts.on_cancel), "function", "on_cancel forwarded")
end

function M.run()
  action_picker_sets_title()
  action_picker_formats_selected_label()
  action_picker_runs_selected_action()
  action_picker_formats_entries_with_section_and_desc()
  action_picker_passes_default_query_to_picker()
  action_picker_formats_entries_without_desc()
  action_picker_includes_summary_in_title_when_enabled()
  action_picker_keeps_title_when_summary_empty()
  action_picker_keeps_title_when_summary_unrelated()
  action_picker_skips_none_values_in_summary_title()
  action_picker_skips_missing_action_id()
  action_picker_passes_on_cancel_to_picker()
end

return M
