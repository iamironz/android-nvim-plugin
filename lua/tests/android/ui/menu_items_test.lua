local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function load_blocks(workspace, run_label, run_target, config_list)
  local blocks = nil
  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return workspace
      end,
    },
    ["android.run.registry"] = {
      list = function()
        return config_list
          or {
            {
              id = "android:app",
              label = "Android",
              target = "android",
              type = "android",
            },
          }
      end,
      resolve = function()
        if not run_label and not run_target then
          return nil
        end
        return { id = "android:app", label = run_label, target = run_target }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu_items"] = nil
    local items = require("android.ui.menu_items")
    blocks = items.top_level_blocks()
  end)

  return blocks or {}
end

local function block_titles(blocks)
  local titles = {}
  for _, block in ipairs(blocks or {}) do
    table.insert(titles, block.title)
  end
  return titles
end

local function find_block(blocks, title)
  for _, block in ipairs(blocks or {}) do
    if block.title == title then
      return block
    end
  end
  return nil
end

local function collect_ids(blocks)
  local ids = {}
  for _, block in ipairs(blocks or {}) do
    for _, item in ipairs(block.items or {}) do
      ids[item.id] = true
    end
  end
  return ids
end

local function assert_ids_missing(ids, expected, label)
  for _, id in ipairs(expected or {}) do
    assert.is_true(ids[id] == nil, string.format("%s %s hidden", label, id))
  end
end

local function exposes_nested_sections()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
    ios = { root = "/workspace/ios" },
  }, "Android")

  local titles = block_titles(blocks)
  assert.table_eq(
    titles,
    { "Shortcuts", "Configs", "Run", "Build", "Devices", "Apps", "Logs" },
    "block titles"
  )
end

local function run_block_uses_resolved_label()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
  }, "Android")

  local run_block = find_block(blocks, "Run")
  local label = ""
  for _, item in ipairs(run_block.items or {}) do
    if item.id == "run_current" then
      label = item.label
      break
    end
  end

  assert.eq(label, "Run Android", "run label")
end

local function run_block_includes_stop()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
  }, "Android")

  local run_block = find_block(blocks, "Run")
  local found = false
  for _, item in ipairs(run_block.items or {}) do
    if item.id == "run_stop" then
      found = true
      break
    end
  end

  assert.is_true(found, "run stop present")
end

local function run_block_omits_select()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
  }, "Android")

  local run_block = find_block(blocks, "Run")
  local found = false
  for _, item in ipairs(run_block.items or {}) do
    if item.id == "run_select" then
      found = true
      break
    end
  end

  assert.is_true(found == false, "run select removed")
end

local function config_block_hides_gradle_tasks()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
  }, "Android", "android", {
    {
      id = "android:app",
      label = "Android",
      target = "android",
      type = "android",
    },
    {
      id = "gradle_tasks",
      label = "Gradle tasks",
      target = "gradle",
      type = "gradle_task",
    },
  })

  local configs = find_block(blocks, "Configs")
  local ids = {}
  for _, item in ipairs(configs.items or {}) do
    ids[item.id] = true
  end

  assert.is_true(ids["run_select:gradle_tasks"] == nil, "gradle tasks hidden")
  assert.is_true(ids["run_select:android:app"] == true, "android config shown")
end

local function hides_ios_actions_without_ios()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
  }, "Android")

  local ids = collect_ids(blocks)
  assert.is_true(ids.ios_build == nil, "ios build hidden")
  assert.is_true(ids.ios_deploy == nil, "ios deploy hidden")
end

local function shows_ios_actions_with_ios()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
    ios = { root = "/workspace/ios" },
  }, "Android")

  local ids = collect_ids(blocks)
  assert.is_true(ids.ios_build == true, "ios build shown")
  assert.is_true(ids.ios_deploy == true, "ios deploy shown")
end

local function hides_android_actions_without_gradle()
  local blocks = load_blocks({
    root = "/workspace",
    ios = { root = "/workspace/ios" },
  }, "iOS")

  local ids = collect_ids(blocks)
  assert.is_true(ids.build_default == nil, "android build hidden")
  assert.is_true(ids.gradle_tasks == nil, "gradle tasks hidden")
  assert.is_true(ids.logcat == nil, "logcat hidden")
end

local function includes_logcat_in_logs()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
  }, "Android")

  local logs = find_block(blocks, "Logs")
  local found = false
  for _, item in ipairs(logs.items or {}) do
    if item.id == "logcat" then
      found = true
      break
    end
  end

  assert.is_true(found, "logcat in logs")
end

local function includes_shortcuts_block()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
  }, "Android")

  local shortcuts = find_block(blocks, "Shortcuts")
  local ids = {}
  for _, item in ipairs(shortcuts.items or {}) do
    ids[item.id] = true
  end

  assert.is_true(ids.open_targets_menu == true, "shortcuts targets")
  assert.is_true(ids.open_tools_menu == true, "shortcuts tools")
end

local function includes_health_check_in_logs()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
  }, "Android")

  local logs = find_block(blocks, "Logs")
  local found = false
  for _, item in ipairs(logs.items or {}) do
    if item.id == "health_check" then
      found = true
      break
    end
  end

  assert.is_true(found, "health check in logs")
end

local function hides_build_and_deploy_for_jvm_target()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
    ios = { root = "/workspace/ios" },
  }, "Server", "jvm")

  local ids = collect_ids(blocks)
  assert_ids_missing(ids, {
    "build_default",
    "build_pure",
    "build_prompt",
    "gradle_tasks",
    "select_module",
    "select_variant",
    "list_apks",
    "gradle_clean",
    "ios_build",
    "ios_deploy",
  }, "jvm target")

  assert_ids_missing(ids, {
    "select_device",
    "select_avd",
    "start_emulator",
    "create_avd",
    "stop_emulator",
    "adb_install",
    "clear_data",
    "uninstall",
  }, "jvm target")
end

local function hides_android_deploy_for_ios_target()
  local blocks = load_blocks({
    root = "/workspace",
    gradle = { root = "/workspace" },
    android = { root = "/workspace" },
    ios = { root = "/workspace/ios" },
  }, "iOS", "ios")

  local ids = collect_ids(blocks)
  assert_ids_missing(ids, {
    "select_device",
    "select_avd",
    "start_emulator",
    "create_avd",
    "stop_emulator",
    "adb_install",
    "clear_data",
    "uninstall",
  }, "ios target")
  assert.is_true(ids.build_default == true, "android build kept")
end

function M.run()
  exposes_nested_sections()
  run_block_uses_resolved_label()
  run_block_includes_stop()
  run_block_omits_select()
  config_block_hides_gradle_tasks()
  hides_ios_actions_without_ios()
  shows_ios_actions_with_ios()
  hides_android_actions_without_gradle()
  includes_logcat_in_logs()
  includes_shortcuts_block()
  includes_health_check_in_logs()
  hides_build_and_deploy_for_jvm_target()
  hides_android_deploy_for_ios_target()
end

return M
