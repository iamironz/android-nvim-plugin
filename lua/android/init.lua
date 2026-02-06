local M = {}
M._schedule = vim.schedule

local keymap_definitions = {
  menu = {
    command = "AndroidMenu",
    plug = "AndroidMenu",
    desc = "Android menu",
  },
  targets = {
    command = "AndroidTargets",
    plug = "AndroidTargets",
    desc = "Android build menu",
  },
  tools = {
    command = "AndroidTools",
    plug = "AndroidTools",
    desc = "Android tools menu",
  },
  actions = {
    command = "AndroidActions",
    plug = "AndroidActions",
    desc = "Android actions picker",
  },
  build = {
    command = "AndroidBuild",
    plug = "AndroidBuild",
    desc = "Android build default",
  },
}

local function set_plug_keymaps()
  for _, entry in pairs(keymap_definitions) do
    vim.keymap.set(
      "n",
      "<Plug>(" .. entry.plug .. ")",
      "<Cmd>" .. entry.command .. "<CR>",
      { silent = true, desc = entry.desc }
    )
  end
end

local function resolve_default_keymaps(config)
  local defaults = {
    menu = "<leader>am",
    targets = "<leader>at",
    tools = "<leader>ao",
    actions = "<leader>aa",
    build = "<leader>ab",
  }
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
      local entry = keymap_definitions[key]
      if entry then
        vim.keymap.set(
          "n",
          lhs,
          "<Plug>(" .. entry.plug .. ")",
          { silent = true, desc = entry.desc, remap = true }
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
  M._schedule(function()
    local state = load_restore_state(workspace_root)
    if not state then
      return
    end
    local ok, manager = pcall(require, "android.logcat.manager")
    if not ok or not manager or type(manager.restore_on_startup) ~= "function" then
      return
    end
    manager.restore_on_startup(workspace_root, { state = state })
  end)
end

function M.setup(opts)
  local config = require("android.config").setup(opts or {})

  local menu = require("android.ui.menu")
  local build = require("android.actions.build")
  local autosave = require("android.ui.autosave")
  local file_watcher = require("android.ui.file_watcher")
  local ui_config = type(config.ui) == "table" and config.ui or nil
  local autosave_enabled = ui_config == nil or ui_config.autosave ~= false
  local file_watcher_enabled = ui_config == nil or ui_config.file_watcher ~= false

  local workspace_root = resolve_workspace_root()
  if workspace_root then
    if autosave_enabled then
      autosave.setup()
    end
    if file_watcher_enabled then
      file_watcher.setup({ workspace_root = workspace_root })
    end
  end
  schedule_logcat_restore(workspace_root, ui_config)

  vim.api.nvim_create_user_command("AndroidMenu", function()
    menu.show_main_menu()
  end, { desc = "Show Android menu" })

  vim.api.nvim_create_user_command("AndroidTargets", function()
    menu.show_targets_menu()
  end, { desc = "Show Android targets menu" })

  vim.api.nvim_create_user_command("AndroidTools", function()
    menu.show_tools_menu()
  end, { desc = "Show Android tools menu" })

  vim.api.nvim_create_user_command("AndroidActions", function()
    menu.show_actions_menu()
  end, { desc = "Open Android actions picker" })

  vim.api.nvim_create_user_command("AndroidBuild", function()
    build.build_default()
  end, { desc = "Build Android with defaults" })

  set_plug_keymaps()
  set_default_keymaps(config.keymaps)
end

return M
