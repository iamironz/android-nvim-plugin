local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function with_actions_open(stubs, open_opts)
  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open(open_opts)
  end)
end

local function build_blocks(title, items)
  return { { title = title, items = items } }
end

local function build_default_item(desc)
  local item = { id = "build_default", label = "Build default" }
  if desc then
    item.desc = desc
  end
  return item
end

local function build_run_item()
  return { id = "run_current", label = "Run current", desc = "Run default" }
end

local function run_picker_with(blocks, opts)
  local options = opts or {}
  local picker_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return blocks
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(picker)
        picker_opts = picker
        if options.on_picker then
          options.on_picker(picker)
        end
      end,
    },
    ["android.actions.registry"] = {
      run = options.on_run or function() end,
    },
  }

  if options.summary_lines then
    stubs["android.ui.summary"] = {
      lines = function()
        return options.summary_lines
      end,
    }
  end

  with_actions_open(stubs, options.open_opts)
  return picker_opts
end

local function run_action_picker_with_single_item()
  local selected_action = nil
  local picker_opts = run_picker_with(
    build_blocks("Targets", { build_default_item("Build using defaults") }),
    {
      on_picker = function(opts)
        if opts.on_select then
          opts.on_select("build_default")
        end
      end,
      on_run = function(action_id)
        selected_action = action_id
      end,
    }
  )

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
  local picker_opts = run_picker_with(
    build_blocks("Targets", { build_default_item("Build using defaults") })
  )

  local entry = picker_opts.items[1]
  local formatted = picker_opts.format(entry)
  assert.eq(formatted, "Targets  Build default - Build using defaults", "entry format")
end

local function action_picker_passes_default_query_to_picker()
  local picker_opts = run_picker_with(
    build_blocks("Targets", { build_default_item("Build using defaults") }),
    { open_opts = { default_query = "b" } }
  )

  assert.eq(picker_opts.default, "b", "default query")
end

local function action_picker_formats_entries_without_desc()
  local picker_opts = run_picker_with(build_blocks("Targets", { build_default_item() }))

  local entry = picker_opts.items[1]
  local formatted = picker_opts.format(entry)
  assert.eq(formatted, "Targets  Build default", "entry format without desc")
end

local function action_picker_includes_summary_in_title_when_enabled()
  local picker_opts = run_picker_with(build_blocks("Run", { build_run_item() }), {
    summary_lines = {
      "Summary",
      "Run: Android",
      "Module: app",
      "Variant: debug",
      "Device: emulator-5554",
      "Logcat: none",
    },
    open_opts = { title = "Android Menu", include_summary = true },
  })

  assert.eq(
    picker_opts.title,
    "Android Menu - Run Android | Module app | Variant debug",
    "summary title"
  )
end

local function action_picker_keeps_title_when_summary_empty()
  local picker_opts = run_picker_with(build_blocks("Run", { build_run_item() }), {
    summary_lines = {},
    open_opts = { title = "Android Menu", include_summary = true },
  })

  assert.eq(picker_opts.title, "Android Menu", "summary empty title")
end

local function action_picker_keeps_title_when_summary_unrelated()
  local picker_opts = run_picker_with(build_blocks("Run", { build_run_item() }), {
    summary_lines = { "Summary", "Flavor: local", "Target: device" },
    open_opts = { title = "Android Menu", include_summary = true },
  })

  assert.eq(picker_opts.title, "Android Menu", "summary unrelated title")
end

local function action_picker_skips_none_values_in_summary_title()
  local picker_opts = run_picker_with(build_blocks("Run", { build_run_item() }), {
    summary_lines = {
      "Summary",
      "Run: none",
      "Module: app",
      "Variant: debug",
      "Device: emulator-5554",
    },
    open_opts = { title = "Android Menu", include_summary = true },
  })

  assert.eq(
    picker_opts.title,
    "Android Menu - Module app | Variant debug | Device emulator-5554",
    "summary title skips none"
  )
end

local function action_picker_skips_missing_action_id()
  local called = false
  run_picker_with(build_blocks("Run", { { label = "Run current", desc = "Run default" } }), {
    on_picker = function(opts)
      if opts.on_select then
        opts.on_select(nil)
      end
    end,
    on_run = function()
      called = true
    end,
  })

  assert.eq(called, false, "missing action id")
end

local function action_picker_passes_on_cancel_to_picker()
  local picker_opts = run_picker_with(build_blocks("Run", { { id = "run" } }), {
    open_opts = { on_cancel = function() end },
  })

  assert.eq(type(picker_opts.on_cancel), "function", "on_cancel forwarded")
end

local function action_picker_passes_on_cancel_to_action_run()
  local received_opts = {}
  run_picker_with(build_blocks("Run", { { id = "run" } }), {
    on_picker = function(opts)
      if opts.on_select then
        opts.on_select("run")
      end
    end,
    on_run = function(_, opts)
      received_opts = opts or {}
    end,
  })

  assert.eq(type(received_opts.on_cancel), "function", "on_cancel passed to action run")
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
  action_picker_passes_on_cancel_to_action_run()
end

return M
