local M = {}
local function panel()
  return require("android.ui.panel")
end
local job = require("android.command.job")
local adb = require("android.devices.adb")
local defaults = require("android.actions.defaults")
local filters = require("android.logcat.filters")
local highlight = require("android.logcat.highlight")
local render = require("android.logcat.session.render")
local output = require("android.logcat.session.output")
local controls = require("android.logcat.session.controls")
local command = require("android.logcat.command")
local reconnect = require("android.logcat.reconnect")
local strings = require("android.utils.strings")
local DEFAULT_MAX_LINES = 2000
M.default_max_lines = DEFAULT_MAX_LINES
local function resolve_pid(runner, adb_path, package_name)
  if not package_name or package_name == "" then
    return nil
  end
  local result = runner.run({ adb_path, "shell", "pidof", "-s", package_name })
  if not result or not result.ok then
    return nil
  end
  local trimmed = strings.trim(result.stdout)
  if trimmed == "" then
    return nil
  end
  return trimmed:match("^(%d+)")
end
local function normalize_input(value)
  if value == nil then
    return ""
  end
  return strings.trim(tostring(value))
end
local function show_status(session, message)
  session.status_message = message
  if session.active then
    panel().replace_body({ message })
  end
end
local function reset_reconnect(session)
  reconnect.reset(session.reconnect)
end
local function stop_logcat_job(session)
  if session.logcat_job and session.logcat_job.ok then
    session.logcat_job.stop()
  end
  session.logcat_job = nil
end
local function build_logcat_command(session)
  local pid = resolve_pid(session.runner, session.adb_path, session.package)
  if pid then
    session.waiting_for_process = false
  else
    session.waiting_for_process = session.package ~= ""
  end
  return command.build({
    adb_path = session.adb_path,
    serial = session.serial,
    pid = pid,
    package = session.package,
    filters = filters.build({ level = session.level }),
  })
end
local function restart_logcat(session, opts)
  if session.stopped then
    return
  end
  reset_reconnect(session)
  if not session.adb_path or session.adb_path == "" then
    vim.notify("adb not available for logcat", vim.log.levels.WARN)
    return
  end
  session.serial = M.resolve_device_serial(session.runner, session.adb_path, session.serial)
  if not session.serial or session.serial == "" then
    show_status(session, "Status: No adb devices found")
    return
  end
  stop_logcat_job(session)
  if not (opts and opts.preserve_body) then
    output.clear_body(session)
  end
  session.cmd = build_logcat_command(session)
  if session.waiting_for_process then
    show_status(session, "Status: Waiting for process " .. session.package)
  end
  M.spawn(session)
end

local function schedule_reconnect(session)
  if session.stopped then
    return
  end
  local ok = reconnect.schedule(session.reconnect, function()
    if session.stopped then
      return
    end
    restart_logcat(session, { preserve_body = true })
  end)
  if not ok then
    show_status(session, "Status: Logcat retry limit reached")
  end
end
local function handle_exit(session)
  if session.stopped then
    return
  end
  session.logcat_job = nil
  show_status(session, "Status: Logcat disconnected, retrying")
  schedule_reconnect(session)
end

function M.spawn(session)
  session.logcat_job = job.spawn(session.cmd, {
    on_stdout = function(lines)
      controls.handle_output(session, lines, { reset_reconnect = reset_reconnect })
    end,
    on_stderr = function(lines)
      controls.handle_output(session, lines, { reset_reconnect = reset_reconnect })
    end,
    on_exit = function()
      handle_exit(session)
    end,
  })
  if not session.logcat_job.ok then
    vim.notify("Failed to start logcat", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.new(opts)
  highlight.setup()
  return {
    config_id = opts.config_id,
    workspace = opts.workspace,
    root = opts.root,
    origin_win = opts.origin_win,
    buf = opts.buf,
    win = opts.win,
    paused = false,
    backlog = {},
    stopped = false,
    logcat_job = nil,
    package = normalize_input(opts.package),
    filter = normalize_input(opts.filter),
    filter_history = opts.filter_history or {},
    level = filters.normalize_level(opts.level or "", "") or "",
    filter_terms = filters.parse_terms(normalize_input(opts.filter)),
    serial = opts.serial,
    adb_path = opts.adb_path,
    runner = opts.runner,
    state = opts.state,
    header_count = 3,
    max_lines = opts.max_lines or DEFAULT_MAX_LINES,
    status_message = nil,
    waiting_for_process = false,
    raw_lines = {},
    body_lines = {},
    active = false,
    keymaps_ready = false,
    reconnect = reconnect.new(opts.reconnect),
    on_close = opts.on_close or function() end,
    on_switch = opts.on_switch or function() end,
    persist_state = opts.persist_state,
  }
end
function M.configure(session, opts)
  session.root = opts.root
  session.workspace = opts.workspace
  session.origin_win = opts.origin_win
  session.buf = opts.buf
  session.win = opts.win
  session.runner = opts.runner
  session.state = opts.state
  session.package = normalize_input(opts.package)
  session.filter = normalize_input(opts.filter)
  session.filter_terms = filters.parse_terms(session.filter)
  session.level = filters.normalize_level(opts.level or "", "") or ""
  session.adb_path = opts.adb_path
  session.serial = opts.serial
  session.filter_history = opts.filter_history or session.filter_history or {}
  session.raw_lines = session.raw_lines or {}
end
function M.activate(session)
  session.active = true
  render.render_session(session)
  controls.setup_keymaps(session, { restart_logcat = restart_logcat })
end

function M.deactivate(session)
  session.active = false
end

function M.render(session)
  render.render_session(session)
end

function M.start(session)
  session.cmd = build_logcat_command(session)
  if session.waiting_for_process then
    show_status(session, "Status: Waiting for process " .. session.package)
  end
  M.spawn(session)
end

function M.restart(session, opts)
  restart_logcat(session, opts)
end
function M.ensure_started(session, opts)
  if not session.adb_path or session.adb_path == "" then
    show_status(session, "Status: adb not found in Android SDK")
    return
  end
  if session.logcat_job and session.logcat_job.ok then
    return
  end
  if not session.serial then
    restart_logcat(session, opts)
    return
  end
  if not session.logcat_job then
    session.stopped = false
    M.start(session)
    return
  end
  restart_logcat(session, opts)
end

function M.show_status(session, message)
  show_status(session, message)
end

function M.stop(session)
  if session.stopped then
    return
  end
  session.stopped = true
  reset_reconnect(session)
  if session.logcat_job and session.logcat_job.ok then
    session.logcat_job.stop()
  end
end

function M.setup_autocmds(session, stop_all)
  if session.autocmds_ready then
    return
  end
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufHidden" }, {
    buffer = session.buf,
    callback = function()
      stop_all()
    end,
    once = true,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(session.win),
    callback = function()
      stop_all()
    end,
    once = true,
  })
  session.autocmds_ready = true
end

function M.resolve_device_serial(runner, adb_path, saved_serial)
  local devices = adb.list(runner, adb_path)
  return defaults.select_device_serial(devices, saved_serial)
end

return M
