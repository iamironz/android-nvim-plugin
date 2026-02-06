local M = {}

local assert = require("tests.helpers.assert")
local stubs = require("tests.helpers.stubs")

local function create_saver()
  local saved = {}

  local function save(tbl, key)
    saved[tbl] = saved[tbl] or {}
    if saved[tbl][key] == nil then
      saved[tbl][key] = tbl[key]
    end
  end

  local function restore()
    for tbl, keys in pairs(saved) do
      for key, value in pairs(keys) do
        tbl[key] = value
      end
    end
  end

  return save, restore
end

local function find_map(calls, lhs)
  for _, call in ipairs(calls or {}) do
    if call.lhs == lhs then
      return call
    end
  end
  return nil
end

local function find_command(calls, name)
  for _, call in ipairs(calls or {}) do
    if call.name == name then
      return call
    end
  end
  return nil
end

local function is_zero_arg(opts)
  if type(opts) ~= "table" then
    return false
  end
  return opts.nargs == nil or opts.nargs == 0 or opts.nargs == "0"
end

local function with_saved_vim_stubs(command_stub, keymap_stub, run)
  local save, restore = create_saver()
  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")

  vim.api.nvim_create_user_command = command_stub
  vim.keymap.set = keymap_stub

  local ok, err = pcall(run)
  restore()
  if not ok then
    error(err, 0)
  end
end

local function new_action_calls()
  return {
    menu = 0,
    targets = 0,
    tools = 0,
    actions = 0,
    build = 0,
    run_current = 0,
    run_stop = 0,
    logcat = 0,
    build_prompt = 0,
    build_assemble = 0,
    gradle_tasks = 0,
    ios_build = 0,
    ios_deploy = 0,
  }
end

local command_surface_expectations = {
  {
    name = "AndroidMenu",
    plug = "AndroidMenu",
    key = "menu",
    default_lhs = "<leader>am",
  },
  {
    name = "AndroidTargets",
    plug = "AndroidTargets",
    key = "targets",
    default_lhs = "<leader>at",
  },
  {
    name = "AndroidTools",
    plug = "AndroidTools",
    key = "tools",
    default_lhs = "<leader>ao",
  },
  {
    name = "AndroidActions",
    plug = "AndroidActions",
    key = "actions",
    default_lhs = "<leader>aa",
  },
  {
    name = "AndroidBuild",
    plug = "AndroidBuild",
    key = "build",
    default_lhs = "<leader>ab",
  },
  { name = "AndroidRun", plug = "AndroidRun", key = "run_current" },
  { name = "AndroidRunStop", plug = "AndroidRunStop", key = "run_stop" },
  { name = "AndroidLogcat", plug = "AndroidLogcat", key = "logcat" },
  {
    name = "AndroidBuildPrompt",
    plug = "AndroidBuildPrompt",
    key = "build_prompt",
  },
  {
    name = "AndroidBuildAssemble",
    plug = "AndroidBuildAssemble",
    key = "build_assemble",
  },
  {
    name = "AndroidGradleTasks",
    plug = "AndroidGradleTasks",
    key = "gradle_tasks",
  },
  { name = "AndroidIOSBuild", plug = "AndroidIOSBuild", key = "ios_build" },
  {
    name = "AndroidIOSDeploy",
    plug = "AndroidIOSDeploy",
    key = "ios_deploy",
  },
}

local function default_leader_expectations()
  local expectations = {}
  for _, entry in ipairs(command_surface_expectations) do
    if entry.default_lhs then
      expectations[entry.default_lhs] = "<Plug>(" .. entry.plug .. ")"
    end
  end
  return expectations
end

local function expected_default_leader_count()
  local count = 0
  for _, entry in ipairs(command_surface_expectations) do
    if entry.default_lhs then
      count = count + 1
    end
  end
  return count
end

local function android_setup_stubs(action_calls)
  local function bump(key, return_value)
    return function()
      action_calls[key] = action_calls[key] + 1
      return return_value
    end
  end

  return {
    ["android.gradle.workspace"] = {
      find_root = function()
        return nil
      end,
    },
    ["android.project.detect"] = {
      detect = function()
        return nil
      end,
    },
    ["android.ui.autosave"] = {
      setup = function() end,
    },
    ["android.ui.file_watcher"] = {
      setup = function() end,
    },
    ["android.ui.menu"] = {
      show_main_menu = bump("menu"),
      show_targets_menu = bump("targets"),
      show_tools_menu = bump("tools"),
      show_actions_menu = bump("actions"),
    },
    ["android.actions.build"] = {
      build_default = bump("build"),
      build_prompt = bump("build_prompt"),
      build_pure = bump("build_assemble"),
    },
    ["android.run.executor"] = {
      execute_default = bump("run_current"),
      stop_active = bump("run_stop", true),
    },
    ["android.actions.logcat"] = {
      open = bump("logcat"),
    },
    ["android.actions.gradle_tasks"] = {
      open = bump("gradle_tasks"),
    },
    ["android.actions.ios.build"] = {
      build = bump("ios_build"),
      deploy = bump("ios_deploy"),
    },
  }
end

local function setup_restores_vim_stubs_when_wrapped_block_errors()
  local original_create_user_command = vim.api.nvim_create_user_command
  local original_keymap_set = vim.keymap.set

  local ok, err = pcall(function()
    with_saved_vim_stubs(function()
      return nil
    end, function()
      return nil
    end, function()
      error("forced failure")
    end)
  end)

  assert.eq(ok, false, "wrapped block should fail")
  assert.contains(err, "forced failure", "wrapped block error propagated")
  assert.eq(
    vim.api.nvim_create_user_command,
    original_create_user_command,
    "user command stub restored"
  )
  assert.eq(vim.keymap.set, original_keymap_set, "keymap stub restored")
end

local function setup_registers_existing_and_new_commands()
  local command_calls = {}
  local action_calls = new_action_calls()

  with_saved_vim_stubs(function(name, callback, opts)
    table.insert(command_calls, {
      name = name,
      callback = callback,
      opts = opts or {},
    })
  end, function()
    return nil
  end, function()
    stubs.with_stubs(android_setup_stubs(action_calls), function()
      package.loaded["android"] = nil
      require("android").setup()

      for _, expectation in ipairs(command_surface_expectations) do
        local command = find_command(command_calls, expectation.name)
        assert.is_true(command ~= nil, expectation.name .. " command")
        assert.is_true(is_zero_arg(command.opts), expectation.name .. " is zero arg")
        command.callback()
        assert.eq(action_calls[expectation.key], 1, expectation.name .. " callback")
      end
    end)
  end)
end

local function setup_registers_new_plug_mappings_without_new_defaults()
  local map_calls = {}

  with_saved_vim_stubs(function()
    return nil
  end, function(mode, lhs, rhs, opts)
    table.insert(map_calls, {
      mode = mode,
      lhs = lhs,
      rhs = rhs,
      opts = opts or {},
    })
  end, function()
    stubs.with_stubs(android_setup_stubs(new_action_calls()), function()
      package.loaded["android"] = nil
      require("android").setup()
    end)

    for _, expectation in ipairs(command_surface_expectations) do
      local lhs = "<Plug>(" .. expectation.plug .. ")"
      local rhs = "<Cmd>" .. expectation.name .. "<CR>"
      local mapping = find_map(map_calls, lhs)
      assert.is_true(mapping ~= nil, lhs .. " mapping")
      assert.eq(mapping.mode, "n", lhs .. " mode")
      assert.eq(mapping.rhs, rhs, lhs .. " rhs")
      assert.eq(mapping.opts.silent, true, lhs .. " silent")
      assert.is_true(mapping.opts.remap ~= true, lhs .. " no remap")
      local has_desc = type(mapping.opts.desc) == "string" and mapping.opts.desc ~= ""
      assert.is_true(has_desc, lhs .. " desc")
    end

    local leader_expectations = default_leader_expectations()
    local default_leader_count = 0
    for _, call in ipairs(map_calls) do
      local is_leader = type(call.lhs) == "string" and call.lhs:find("<leader>", 1, true) == 1
      local is_android_plug =
        type(call.rhs) == "string" and call.rhs:find("<Plug>(Android", 1, true) == 1
      if is_leader and is_android_plug then
        default_leader_count = default_leader_count + 1
      end
    end

    assert.eq(
      default_leader_count,
      expected_default_leader_count(),
      "default leader mappings unchanged"
    )

    for lhs, rhs in pairs(leader_expectations) do
      local mapping = find_map(map_calls, lhs)
      assert.is_true(mapping ~= nil, lhs .. " mapping")
      assert.eq(mapping.mode, "n", lhs .. " mode")
      assert.eq(mapping.rhs, rhs, lhs .. " rhs")
      assert.eq(mapping.opts.silent, true, lhs .. " silent")
      assert.eq(mapping.opts.remap, true, lhs .. " remap")
      local has_desc = type(mapping.opts.desc) == "string" and mapping.opts.desc ~= ""
      assert.is_true(has_desc, lhs .. " desc")
    end
  end)
end

function M.run()
  setup_restores_vim_stubs_when_wrapped_block_errors()
  setup_registers_existing_and_new_commands()
  setup_registers_new_plug_mappings_without_new_defaults()
end

return M
