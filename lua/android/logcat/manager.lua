local M = {}
local panel = require("android.ui.panel")
local picker = require("android.ui.picker")
local run_registry = require("android.run.registry")
local discovery = require("android.sdk.discovery")
local runner_module = require("android.command.runner")
local context = require("android.actions.context")
local package_resolver = require("android.logcat.package")
local session_module = require("android.logcat.session")

M.default_max_lines = session_module.default_max_lines

local sessions = {}
local active_config_id = nil
local DEFAULT_CONTROL_HEIGHT = 3

local function workspace_root_from_sessions()
  for _, session in pairs(sessions) do
    if session and type(session.root) == "string" and session.root ~= "" then
      return session.root
    end
  end
  return nil
end

local function is_exiting()
  local exiting = vim.v and vim.v.exiting
  return type(exiting) == "number" and exiting ~= 0
end

local function set_restore_on_startup(workspace_root, state, enabled)
  if not workspace_root or workspace_root == "" then
    return state
  end
  local next_state = state or context.load_state(workspace_root) or {}
  next_state.logcat = next_state.logcat or {}
  if next_state.logcat.restore_on_startup == enabled then
    return next_state
  end
  next_state.logcat.restore_on_startup = enabled
  context.save_state(workspace_root, next_state)
  return next_state
end

local function state_config_id(state)
  local run_state = state and state.run or nil
  local config_id = run_state and run_state.config_id or nil
  if type(config_id) == "string" and config_id ~= "" then
    return config_id
  end
  return nil
end

local function restore_on_startup_enabled(state)
  local logcat_state = state and state.logcat or nil
  return logcat_state and logcat_state.restore_on_startup == true
end

local function resolve_logcat_state(state, config_id)
  local next_state = state or {}
  next_state.logcat = next_state.logcat or {}
  local sessions_state = next_state.logcat.sessions
  if sessions_state and sessions_state[config_id] then
    local saved = sessions_state[config_id]
    if saved.filter_history == nil then
      saved.filter_history = next_state.logcat.filter_history or {}
    end
    return saved, next_state
  end
  if not sessions_state then
    return {
      package = next_state.logcat.package or "",
      filter = next_state.logcat.filter or "",
      filter_history = next_state.logcat.filter_history or {},
      level = next_state.logcat.level or "",
      serial = next_state.logcat.serial,
    }, next_state
  end
  return {
    package = "",
    filter = "",
    filter_history = next_state.logcat.filter_history or {},
    level = next_state.logcat.level or "",
    serial = next_state.logcat.serial,
  }, next_state
end

local function persist_logcat_state(root, state, config_id, updates, opts)
  local options = opts or {}
  local next_state = state or {}
  next_state.logcat = next_state.logcat or {}
  local sessions_state = next_state.logcat.sessions or {}
  local entry = sessions_state[config_id] or {}
  local changed = false
  for key, value in pairs(updates or {}) do
    if entry[key] ~= value then
      entry[key] = value
      changed = true
    end
    if key == "package"
        or key == "filter"
        or key == "filter_history"
        or key == "level"
        or key == "serial" then
      if next_state.logcat[key] ~= value then
        next_state.logcat[key] = value
        changed = true
      end
    end
  end
  if sessions_state[config_id] == nil or changed then
    sessions_state[config_id] = entry
    next_state.logcat.sessions = sessions_state
  end
  if changed and options.persist ~= false then
    context.save_state(root, next_state)
  end
  return next_state
end

local function stop_all_sessions()
  for _, session in pairs(sessions) do
    session_module.stop(session)
  end
  if is_exiting() then
    return
  end
  set_restore_on_startup(workspace_root_from_sessions(), nil, false)
end

local function close_panel()
  stop_all_sessions()
  panel.close()
end

local function activate_session(session)
  if active_config_id and sessions[active_config_id] then
    session_module.deactivate(sessions[active_config_id])
  end
  active_config_id = session.config_id
  session_module.activate(session)
end

local function switch_config(session)
  local list = run_registry.list(session.workspace) or {}
  local items = {}
  for _, config in ipairs(list) do
    items[#items + 1] = { label = config.label or config.id, value = config.id }
  end
  picker.select_from_list({
    title = "Select run config",
    items = items,
    on_select = function(config_id)
      if not config_id then
        return
      end
      run_registry.select(session.workspace, config_id)
      M.activate(config_id, session.origin_win)
    end,
  })
end

local function configure_session(session, workspace, state, origin_win, config_id)
  local sdk = discovery.new({ root = workspace.root })
  local tools = sdk.tools()
  local runner = runner_module.new()
  local saved, next_state = resolve_logcat_state(state, config_id)
  local default_package = package_resolver.resolve_default_package({
    workspace = workspace,
    saved_package = saved.package,
    aapt2_path = sdk.aapt2(),
    runner = runner,
  })
  local package_name = saved.package
  if package_name == nil or package_name == "" then
    package_name = default_package or ""
  end
  local filter_text = saved.filter or ""
  local level = saved.level or ""
  session.persist_state = function(updates, persist_opts)
    session.state = persist_logcat_state(
      session.root,
      session.state,
      config_id,
      updates,
      persist_opts
    )
  end
  session_module.configure(session, {
    root = workspace.root,
    workspace = workspace,
    origin_win = origin_win,
    buf = session.buf,
    win = session.win,
    control_buf = session.control_buf,
    control_win = session.control_win,
    runner = runner,
    state = next_state,
    package = package_name,
    filter = filter_text,
    filter_history = saved.filter_history,
    level = level,
    adb_path = tools.adb,
    serial = saved.serial,
  })
  if not tools.adb then
    session_module.show_status(session, "Status: adb not found in Android SDK")
    return
  end
  local serial = session_module.resolve_device_serial(runner, tools.adb, saved.serial)
  if not serial then
    session.serial = nil
    session_module.show_status(session, "Status: No adb devices found")
    return
  end
  session.serial = serial
  session.state = persist_logcat_state(session.root, session.state, config_id, {
    package = session.package,
    filter = session.filter,
    level = session.level,
    serial = serial,
  })
end

local function ensure_session(workspace, config_id, origin_win, state, panel_handle)
  local buf = (panel_handle and panel_handle.buf) or vim.api.nvim_get_current_buf()
  local win = (panel_handle and panel_handle.win) or vim.api.nvim_get_current_win()
  local control_buf = panel_handle and panel_handle.control_buf or nil
  local control_win = panel_handle and panel_handle.control_win or nil
  local session = sessions[config_id]
  if not session then
    session = session_module.new({
      config_id = config_id,
      workspace = workspace,
      root = workspace.root,
      origin_win = origin_win,
      buf = buf,
      win = win,
      control_buf = control_buf,
      control_win = control_win,
      package = "",
      filter = "",
      level = "",
      serial = nil,
      adb_path = nil,
      runner = nil,
      state = state,
      on_close = function() close_panel() end,
      on_switch = function() switch_config(session) end,
      persist_state = nil,
    })
    sessions[config_id] = session
  else
    session.buf = buf
    session.win = win
    session.control_buf = control_buf
    session.control_win = control_win
    session.root = workspace.root
    session.workspace = workspace
    session.origin_win = origin_win
    session.on_close = function() close_panel() end
    session.on_switch = function() switch_config(session) end
  end
  configure_session(session, workspace, state, origin_win, config_id)
  session_module.setup_autocmds(session, stop_all_sessions)
  return session
end

function M.activate(config_id, origin_win)
  local workspace = context.workspace()
  if not workspace then
    return
  end
  local state = context.load_state(workspace.root)
  state = set_restore_on_startup(workspace.root, state, true)
  local handle = panel.handle and panel.handle() or nil
  local current_win = handle and handle.win or vim.api.nvim_get_current_win()
  local session = ensure_session(workspace, config_id, origin_win or current_win, state, handle)
  activate_session(session)
  session_module.ensure_started(session, { preserve_body = true })
end

function M.open(opts)
  local options = opts or {}
  local workspace = options.workspace or context.workspace()
  if not workspace then
    return
  end
  local origin_win = options.origin_win or vim.api.nvim_get_current_win()
  local handle = options.panel_handle or panel.open({
    layout = "dock",
    control_height = DEFAULT_CONTROL_HEIGHT,
  })
  local state = options.state or context.load_state(workspace.root)
  state = set_restore_on_startup(workspace.root, state, true)
  local config_id = options.config_id or state_config_id(state)
  if not config_id then
    local config = run_registry.resolve(workspace)
    config_id = (config and config.id) or "default"
  end
  local session = ensure_session(workspace, config_id, origin_win, state, handle)
  activate_session(session)
  session_module.ensure_started(session, { preserve_body = session.logcat_job ~= nil })
end

function M.should_restore_on_startup(workspace_root, state)
  if not workspace_root or workspace_root == "" then
    return false
  end
  local next_state = state or context.load_state(workspace_root) or {}
  return restore_on_startup_enabled(next_state)
end

function M.restore_on_startup(workspace_root, opts)
  local options = opts or {}
  local state = options.state or context.load_state(workspace_root) or {}
  if not M.should_restore_on_startup(workspace_root, state) then
    return false
  end
  M.open({
    workspace = options.workspace,
    state = state,
    config_id = state_config_id(state),
  })
  return true
end

return M
