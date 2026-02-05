local M = {}

local build = require("android.actions.build")
local devices = require("android.actions.devices")
local logcat = require("android.actions.logcat")
local gradle_tasks = require("android.actions.gradle_tasks")
local apps = require("android.actions.apps")
local ios_build = require("android.actions.ios.build")
local run_ui = require("android.run.ui")
local run_executor = require("android.run.executor")
local context = require("android.actions.context")
local run_registry = require("android.run.registry")

local function open_menu(name, opts)
  local menu = require("android.ui.menu")
  local action = menu and menu[name]
  if action then
    action(opts)
  end
end

local actions = {
  build_default = build.build_default,
  build_pure = build.build_pure,
  build_prompt = build.build_prompt,
  select_module = build.select_module,
  select_variant = build.select_variant,
  list_apks = build.list_apks,
  gradle_clean = build.clean,
  show_build_errors = build.show_build_errors,
  health_check = function()
    vim.cmd("checkhealth android")
  end,
  gradle_tasks = gradle_tasks.open,
  select_device = devices.select_device,
  select_avd = devices.select_avd,
  start_emulator = devices.start_emulator,
  create_avd = devices.create_avd,
  stop_emulator = devices.stop_emulator,
  logcat = logcat.open,
  ios_build = ios_build.build,
  ios_deploy = ios_build.deploy,
  adb_install = apps.install,
  clear_data = apps.clear_data,
  uninstall = apps.uninstall,
  open_targets_menu = function()
    open_menu("show_targets_menu", { from_action = true })
  end,
  open_tools_menu = function()
    open_menu("show_tools_menu", { from_action = true })
  end,
  run_select = run_ui.select,
  run_current = run_executor.execute_default,
  run_stop = run_executor.stop_active,
}

function M.run(action_id, opts)
  if type(action_id) == "string" then
    local config_id = action_id:match("^run_select:(.+)$")
    if config_id then
      local workspace = context.workspace()
      if workspace then
        run_registry.select(workspace, config_id)
      end
      return
    end
  end
  local action = actions[action_id]
  if not action then
    vim.notify("Unknown Android action: " .. tostring(action_id), vim.log.levels.WARN)
    return
  end
  action(opts)
end

return M
