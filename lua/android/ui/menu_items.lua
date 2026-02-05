local M = {}

local context = require("android.actions.context")
local run_registry = require("android.run.registry")

local function resolve_workspace(workspace)
  if workspace ~= nil then
    return workspace
  end
  return context.workspace()
end

local function workspace_flags(workspace)
  return {
    has_gradle = workspace and workspace.gradle ~= nil,
    has_android = workspace and workspace.android ~= nil,
    has_ios = workspace and workspace.ios ~= nil,
    has_kmp = workspace and workspace.kmp ~= nil,
  }
end

local function list_contains(list, value)
  for _, entry in ipairs(list or {}) do
    if entry == value then
      return true
    end
  end
  return false
end

local function menu_flags(workspace, run_config)
  local flags = workspace_flags(workspace)
  local target = run_config and run_config.target or nil
  if target == "multi" then
    target = nil
  end
  flags.run_target = target
  return flags
end

local function target_allowed(item, target)
  if not target then
    return true
  end
  if list_contains(item.exclude_targets, target) then
    return false
  end
  if item.targets and not list_contains(item.targets, target) then
    return false
  end
  return true
end

local function include_item(item, flags)
  if not target_allowed(item, flags.run_target) then
    return false
  end
  for _, requirement in ipairs(item.requires or {}) do
    if requirement == "gradle" and not flags.has_gradle then
      return false
    end
    if requirement == "android" and not flags.has_android then
      return false
    end
    if requirement == "ios" and not flags.has_ios then
      return false
    end
    if requirement == "kmp" and not flags.has_kmp then
      return false
    end
  end
  return true
end

local function filter_items(items, flags)
  local filtered = {}
  for _, item in ipairs(items or {}) do
    if include_item(item, flags) then
      table.insert(filtered, item)
    end
  end
  return filtered
end

local function run_label(run_config)
  if run_config and run_config.label and run_config.label ~= "" then
    return "Run " .. run_config.label
  end
  return "Run current"
end

local function run_items(run_config)
  return {
    {
      id = "run_current",
      label = run_label(run_config),
      desc = "Run the selected configuration",
    },
    {
      id = "run_stop",
      label = "Stop run",
      desc = "Stop the active run jobs",
    },
  }
end

local function format_config_desc(config)
  local meta = config.meta or {}
  local parts = {}
  if config.type then
    parts[#parts + 1] = config.type
  elseif config.target then
    parts[#parts + 1] = config.target
  end
  if meta.module then
    parts[#parts + 1] = meta.module
  end
  if meta.variant then
    parts[#parts + 1] = meta.variant
  end
  if meta.scheme then
    parts[#parts + 1] = "scheme " .. meta.scheme
  end
  if meta.task then
    parts[#parts + 1] = meta.task
  end
  if meta.command then
    parts[#parts + 1] = meta.command
  end
  return table.concat(parts, " · ")
end

local function config_items(snapshot)
  local list = (snapshot and snapshot.list) or {}
  local current_id = snapshot and snapshot.current and snapshot.current.id or nil
  local items = {}
  for _, config in ipairs(list) do
    if config.type ~= "gradle_task" then
      local marker = config.id == current_id and "*" or " "
      local label = string.format("%s %s", marker, config.label or config.id)
      items[#items + 1] = {
        id = "run_select:" .. config.id,
        label = label,
        desc = format_config_desc(config),
      }
    end
  end
  return items
end

local function build_items(flags)
  local android_build_excludes = { "server", "jvm", "gradle", "shell" }
  local ios_build_excludes = { "server", "jvm", "gradle", "shell" }
  local items = {
    {
      id = "build_default",
      label = "Build default",
      desc = "Build using saved module and variant",
      requires = { "android", "gradle" },
      exclude_targets = android_build_excludes,
    },
    {
      id = "build_pure",
      label = "Build assemble only",
      desc = "Assemble default variant without deploy",
      requires = { "android", "gradle" },
      exclude_targets = android_build_excludes,
    },
    {
      id = "build_prompt",
      label = "Build with prompts",
      desc = "Choose module and variant then build",
      requires = { "android", "gradle" },
      exclude_targets = android_build_excludes,
    },
    {
      id = "ios_build",
      label = "iOS build",
      desc = "Build iOS workspace",
      requires = { "ios" },
      exclude_targets = ios_build_excludes,
    },
    {
      id = "ios_deploy",
      label = "iOS deploy",
      desc = "Build and launch in simulator",
      requires = { "ios" },
      exclude_targets = ios_build_excludes,
    },
    {
      id = "gradle_tasks",
      label = "Gradle tasks",
      desc = "Browse and run Gradle tasks",
      requires = { "android", "gradle" },
      exclude_targets = android_build_excludes,
    },
    {
      id = "select_module",
      label = "Select module",
      desc = "Pick default Gradle module",
      requires = { "android", "gradle" },
      exclude_targets = android_build_excludes,
    },
    {
      id = "select_variant",
      label = "Select variant",
      desc = "Pick default build variant",
      requires = { "android", "gradle" },
      exclude_targets = android_build_excludes,
    },
    {
      id = "list_apks",
      label = "Output APKs",
      desc = "List APKs and copy path",
      requires = { "android", "gradle" },
      exclude_targets = android_build_excludes,
    },
    {
      id = "gradle_clean",
      label = "Gradle clean",
      desc = "Run clean to remove build artifacts",
      requires = { "android", "gradle" },
      exclude_targets = android_build_excludes,
    },
  }

  return filter_items(items, flags)
end

local function devices_items(flags)
  local android_deploy_excludes = { "server", "ios", "jvm", "gradle", "shell" }
  local items = {
    {
      id = "select_device",
      label = "Select device",
      desc = "Pick default adb device",
      requires = { "android", "gradle" },
      exclude_targets = android_deploy_excludes,
    },
    {
      id = "select_avd",
      label = "Select emulator AVD",
      desc = "Pick default emulator profile",
      requires = { "android", "gradle" },
      exclude_targets = android_deploy_excludes,
    },
    {
      id = "start_emulator",
      label = "Start emulator",
      desc = "Launch default emulator",
      requires = { "android", "gradle" },
      exclude_targets = android_deploy_excludes,
    },
    {
      id = "create_avd",
      label = "Create AVD",
      desc = "Create emulator profile",
      requires = { "android", "gradle" },
      exclude_targets = android_deploy_excludes,
    },
    {
      id = "stop_emulator",
      label = "Stop emulator",
      desc = "Stop running emulator",
      requires = { "android", "gradle" },
      exclude_targets = android_deploy_excludes,
    },
  }

  return filter_items(items, flags)
end

local function apps_items(flags)
  local android_deploy_excludes = { "server", "ios", "jvm", "gradle", "shell" }
  local items = {
    {
      id = "adb_install",
      label = "ADB install",
      desc = "Install APK on device",
      requires = { "android", "gradle" },
      exclude_targets = android_deploy_excludes,
    },
    {
      id = "clear_data",
      label = "Clear app data",
      desc = "Reset app data on device",
      requires = { "android", "gradle" },
      exclude_targets = android_deploy_excludes,
    },
    {
      id = "uninstall",
      label = "Uninstall app",
      desc = "Remove app from device",
      requires = { "android", "gradle" },
      exclude_targets = android_deploy_excludes,
    },
  }

  return filter_items(items, flags)
end

local function logs_items(flags)
  local items = {
    {
      id = "logcat",
      label = "Logcat",
      desc = "Open device logcat",
      requires = { "android", "gradle" },
      exclude_targets = { "ios", "server", "jvm", "gradle", "shell" },
    },
    {
      id = "health_check",
      label = "Health check",
      desc = "Run :checkhealth android",
    },
    {
      id = "show_build_errors",
      label = "Show build errors",
      desc = "Open build quickfix list",
      requires = { "android", "gradle" },
    },
  }

  return filter_items(items, flags)
end

function M.top_level_blocks(workspace)
  local resolved = resolve_workspace(workspace)
  local snapshot = resolved and run_registry.snapshot(resolved) or {}
  local run_config = snapshot.current
  local flags = menu_flags(resolved, run_config)

  return {
    {
      title = "Run Configurations",
      desc = "Select the active run configuration.",
      items = resolved and config_items(snapshot) or {},
    },
    {
      title = "Run",
      desc = "Run current configuration or stop runs.",
      items = run_items(run_config),
    },
    {
      title = "Build Variants",
      desc = "Select module/variant, build, and Gradle tasks.",
      items = build_items(flags),
    },
    {
      title = "Device Manager",
      desc = "Select devices/AVDs and manage emulators.",
      items = devices_items(flags),
    },
    {
      title = "ADB",
      desc = "Install APKs, clear data, uninstall apps.",
      items = apps_items(flags),
    },
    {
      title = "Logcat",
      desc = "Open logcat and diagnostics.",
      items = logs_items(flags),
    },
  }
end

function M.block_by_title(title)
  for _, block in ipairs(M.top_level_blocks()) do
    if block.title == title then
      return block
    end
  end
  return nil
end

return M
