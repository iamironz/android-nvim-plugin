local M = {}
M._schedule = vim.schedule
M._did_enter = function()
  local did_enter = vim.v and vim.v.vim_did_enter
  return type(did_enter) == "number" and did_enter ~= 0
end

local command_definitions = {
  {
    key = "menu",
    command = "AndroidMenu",
    plug = "AndroidMenu",
    keymap_desc = "Android menu",
    command_desc = "Show Android menu",
    default_lhs = "<leader>am",
    run = function(deps)
      deps.menu.show_main_menu()
    end,
  },
  {
    key = "targets",
    command = "AndroidTargets",
    plug = "AndroidTargets",
    keymap_desc = "Android build menu",
    command_desc = "Show Android targets menu",
    default_lhs = "<leader>at",
    run = function(deps)
      deps.menu.show_targets_menu()
    end,
  },
  {
    key = "tools",
    command = "AndroidTools",
    plug = "AndroidTools",
    keymap_desc = "Android tools menu",
    command_desc = "Show Android tools menu",
    default_lhs = "<leader>ao",
    run = function(deps)
      deps.menu.show_tools_menu()
    end,
  },
  {
    key = "actions",
    command = "AndroidActions",
    plug = "AndroidActions",
    keymap_desc = "Android actions picker",
    command_desc = "Open Android actions picker",
    default_lhs = "<leader>aa",
    run = function(deps)
      deps.menu.show_actions_menu()
    end,
  },
  {
    key = "build",
    command = "AndroidBuild",
    plug = "AndroidBuild",
    keymap_desc = "Android build default",
    command_desc = "Build Android with defaults",
    default_lhs = "<leader>ab",
    run = function(deps)
      deps.build.build_default()
    end,
  },
  {
    key = "run",
    command = "AndroidRun",
    plug = "AndroidRun",
    keymap_desc = "Android run current config",
    command_desc = "Run current Android config",
    run = function(deps)
      deps.run_executor.execute_default()
    end,
  },
  {
    key = "run_stop",
    command = "AndroidRunStop",
    plug = "AndroidRunStop",
    keymap_desc = "Android stop run jobs",
    command_desc = "Stop active Android run jobs",
    run = function(deps)
      deps.run_executor.stop_active()
    end,
  },
  {
    key = "logcat",
    command = "AndroidLogcat",
    plug = "AndroidLogcat",
    keymap_desc = "Android open logcat",
    command_desc = "Open Android logcat",
    run = function(deps)
      deps.logcat.open()
    end,
  },
  {
    key = "build_prompt",
    command = "AndroidBuildPrompt",
    plug = "AndroidBuildPrompt",
    keymap_desc = "Android build with prompts",
    command_desc = "Build Android with prompts",
    run = function(deps)
      deps.build.build_prompt()
    end,
  },
  {
    key = "build_assemble",
    command = "AndroidBuildAssemble",
    plug = "AndroidBuildAssemble",
    keymap_desc = "Android build assemble only",
    command_desc = "Build Android assemble only",
    run = function(deps)
      deps.build.build_pure()
    end,
  },
  {
    key = "gradle_tasks",
    command = "AndroidGradleTasks",
    plug = "AndroidGradleTasks",
    keymap_desc = "Android gradle tasks picker",
    command_desc = "Open Android Gradle tasks picker",
    run = function(deps)
      deps.gradle_tasks.open()
    end,
  },
  {
    key = "ios_build",
    command = "AndroidIOSBuild",
    plug = "AndroidIOSBuild",
    keymap_desc = "Android iOS build",
    command_desc = "Build iOS project",
    run = function(deps)
      deps.ios_build.build()
    end,
  },
  {
    key = "ios_deploy",
    command = "AndroidIOSDeploy",
    plug = "AndroidIOSDeploy",
    keymap_desc = "Android iOS deploy",
    command_desc = "Deploy iOS project",
    run = function(deps)
      deps.ios_build.deploy()
    end,
  },
}

local command_by_key = {}
for _, entry in ipairs(command_definitions) do
  command_by_key[entry.key] = entry
end

local function set_plug_keymaps()
  for _, entry in ipairs(command_definitions) do
    vim.keymap.set(
      "n",
      "<Plug>(" .. entry.plug .. ")",
      "<Cmd>" .. entry.command .. "<CR>",
      { silent = true, desc = entry.keymap_desc }
    )
  end
end

local function default_keymaps()
  local defaults = {}
  for _, entry in ipairs(command_definitions) do
    if entry.default_lhs then
      defaults[entry.key] = entry.default_lhs
    end
  end
  return defaults
end

local function resolve_default_keymaps(config)
  local defaults = default_keymaps()
  local mappings = (config and config.mappings) or {}
  local resolved = {}
  for key, value in pairs(defaults) do
    local override = mappings[key]
    if override == false or override == "" then
      resolved[key] = nil
    elseif override == nil then
      resolved[key] = value
    else
      resolved[key] = override
    end
  end
  return resolved
end

local function set_default_keymaps(config)
  if config and config.enabled == false then
    return
  end
  local mappings = resolve_default_keymaps(config)
  for key, lhs in pairs(mappings) do
    if lhs then
      local entry = command_by_key[key]
      if entry then
        vim.keymap.set(
          "n",
          lhs,
          "<Plug>(" .. entry.plug .. ")",
          { silent = true, desc = entry.keymap_desc, remap = true }
        )
      end
    end
  end
end

local function resolve_start_path()
  local name = vim.api.nvim_buf_get_name(0)
  if name == nil or name == "" then
    return vim.fn.getcwd()
  end
  return name
end

local function resolve_workspace_root()
  local start_path = resolve_start_path()

  local ok_workspace, gradle_workspace = pcall(require, "android.gradle.workspace")
  if ok_workspace and gradle_workspace and type(gradle_workspace.find_root) == "function" then
    local root = gradle_workspace.find_root(start_path)
    if type(root) == "string" and root ~= "" then
      return root
    end
  end

  -- Fallback keeps older behavior if fast root lookup is unavailable.
  local ok_project, project = pcall(require, "android.project.detect")
  if not ok_project or not project or type(project.detect) ~= "function" then
    return nil
  end
  local detected = project.detect(start_path)
  if not detected then
    return nil
  end
  if type(detected.root) == "string" and detected.root ~= "" then
    return detected.root
  end
  local gradle = detected.gradle or {}
  if type(gradle.root) == "string" and gradle.root ~= "" then
    return gradle.root
  end
  return nil
end

local function restore_logcat_enabled(ui_config)
  if ui_config == nil then
    return true
  end
  return ui_config.restore_logcat ~= false
end

local function load_restore_state(workspace_root)
  if not workspace_root or workspace_root == "" then
    return nil
  end
  local ok, selection_store = pcall(require, "android.state.selection_store")
  if not ok or not selection_store or type(selection_store.load) ~= "function" then
    return nil
  end
  local state = selection_store.load({ workspace_root = workspace_root }) or {}
  local logcat_state = state.logcat or {}
  if logcat_state.restore_on_startup ~= true then
    return nil
  end
  return state
end

local function schedule_logcat_restore(workspace_root, ui_config)
  if not workspace_root or workspace_root == "" then
    return
  end
  if not restore_logcat_enabled(ui_config) then
    return
  end

  local function restore()
    local state = load_restore_state(workspace_root)
    if not state then
      return
    end
    local ok, manager = pcall(require, "android.logcat.manager")
    if not ok or not manager or type(manager.restore_on_startup) ~= "function" then
      return
    end
    manager.restore_on_startup(workspace_root, { state = state })
  end

  if not M._did_enter() and type(vim.api.nvim_create_autocmd) == "function" then
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        M._schedule(restore)
      end,
    })
    return
  end

  M._schedule(restore)
end

local function setup_workspace_features(config, deps)
  local ui_config = type(config.ui) == "table" and config.ui or nil
  local autosave_enabled = ui_config == nil or ui_config.autosave ~= false
  local file_watcher_enabled = ui_config == nil or ui_config.file_watcher ~= false
  local workspace_root = resolve_workspace_root()

  if workspace_root then
    if autosave_enabled then
      deps.autosave.setup()
    end
    if file_watcher_enabled then
      deps.file_watcher.setup({ workspace_root = workspace_root })
    end
  end

  schedule_logcat_restore(workspace_root, ui_config)
end

local function load_setup_dependencies()
  return {
    menu = require("android.ui.menu"),
    build = require("android.actions.build"),
    run_executor = require("android.run.executor"),
    logcat = require("android.actions.logcat"),
    gradle_tasks = require("android.actions.gradle_tasks"),
    ios_build = require("android.actions.ios.build"),
    autosave = require("android.ui.autosave"),
    file_watcher = require("android.ui.file_watcher"),
  }
end

local function register_user_commands(deps)
  for _, entry in ipairs(command_definitions) do
    vim.api.nvim_create_user_command(entry.command, function()
      entry.run(deps)
    end, { desc = entry.command_desc })
  end
end

function M.setup(opts)
  local config = require("android.config").setup(opts or {})
  local deps = load_setup_dependencies()

  setup_workspace_features(config, deps)
  register_user_commands(deps)
  set_plug_keymaps()
  set_default_keymaps(config.keymaps)
end

return M
