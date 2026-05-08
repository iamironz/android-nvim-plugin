local M = {}
local function panel()
  return require("android.ui.panel")
end
local function picker()
  return require("android.ui.picker")
end
local function history()
  return require("android.state.history")
end
local function filters()
  return require("android.logcat.filters")
end
local function render()
  return require("android.logcat.session.render")
end
local function output()
  return require("android.logcat.session.output")
end
local function processes()
  return require("android.logcat.processes")
end
local function stack_trace()
  return require("android.logcat.stack_trace")
end
local function panel_header()
  return require("android.ui.panel_header")
end
local keymaps = require("android.utils.keymaps")
local strings = require("android.utils.strings")

local function normalize_input(value)
  if value == nil then
    return ""
  end
  return strings.trim(tostring(value))
end

local function update_level(session, value, deps)
  local next_level = filters().normalize_level(value or "", "") or ""
  if next_level == session.level then
    return
  end
  session.level = next_level
  if session.persist_state then
    session.persist_state({ level = next_level })
  end
  render().render_header(session)
  deps.restart_logcat(session)
end

local function update_filter(session, value, deps, opts)
  local options = opts or {}
  local next_filter = normalize_input(value)
  if next_filter == session.filter then
    return
  end
  session.filter = next_filter
  session.filter_terms = filters().parse_terms(next_filter)
  if session.persist_state then
    session.persist_state({ filter = next_filter }, { persist = options.persist ~= false })
  end
  session.body_lines = filters().filter_lines(session.raw_lines or {}, session.filter)
  if output().should_trim(session) then
    output().trim(session)
  end
  render().render_session(session)
end

local function update_package(session, value, deps)
  local next_package = normalize_input(value)
  if next_package == session.package then
    return
  end
  session.package = next_package
  if session.persist_state then
    session.persist_state({ package = next_package })
  end
  render().render_header(session)
  deps.restart_logcat(session)
end

local function persist_filter_history(session, value)
  local next_history = history().push(session.filter_history, value, { limit = 20 })
  session.filter_history = next_history
  if session.persist_state then
    session.persist_state({
      filter = session.filter,
      filter_history = next_history,
    })
  end
end

local function resolve_build_context(session)
  local state = session and session.state or nil
  local build = state and state.build or nil
  return {
    module = build and build.module or nil,
    variant = build and build.variant or nil,
  }
end

local function start_filter_edit(session, deps)
  local build_context = resolve_build_context(session)
  picker().filter_input({
    prompt_title = "Logcat filter",
    items = session.filter_history or {},
    default = session.filter,
    panel_names = function(query)
      local value = query
      if value == nil then
        value = session.filter
      end
      return panel_header().logcat_filter_panel_names({
        module = build_context.module,
        variant = build_context.variant,
        package = session.package,
        filter = value,
        level = session.level,
      })
    end,
    on_change = function(value)
      update_filter(session, value, deps, { persist = false })
    end,
    on_accept = function(value)
      update_filter(session, value, deps)
      persist_filter_history(session, value)
    end,
    on_cancel = function()
      persist_filter_history(session, session.filter)
    end,
  })
end

local function select_level(session, deps)
  local levels = {
    { label = "All", value = "" },
    { label = "Verbose (V)", value = "V" },
    { label = "Debug (D)", value = "D" },
    { label = "Info (I)", value = "I" },
    { label = "Warn (W)", value = "W" },
    { label = "Error (E)", value = "E" },
  }
  picker().select_from_list({
    title = "Select logcat level",
    items = levels,
    on_select = function(value)
      update_level(session, value, deps)
    end,
  })
end

local function select_package(session, deps)
  if not session.adb_path or session.adb_path == "" then
    local input = vim.fn.input("Logcat package: ", "")
    update_package(session, input, deps)
    return
  end
  local names = processes().list_packages(session.runner, session.adb_path, session.serial)
  if #names == 0 then
    local input = vim.fn.input("Logcat package: ", "")
    update_package(session, input, deps)
    return
  end
  picker().select_from_list({
    title = "Select package",
    items = names,
    on_select = function(value)
      update_package(session, value, deps)
    end,
  })
end

local function handle_header_enter(session, line, deps)
  if line == 1 then
    select_package(session, deps)
    return true
  end
  if line == 2 then
    start_filter_edit(session, deps)
    return true
  end
  if line == 3 then
    select_level(session, deps)
    return true
  end
  return false
end

local function enqueue(session, lines)
  for _, line in ipairs(lines or {}) do
    table.insert(session.backlog, line)
  end
end

local function flush_backlog(session)
  if #session.backlog == 0 then
    return
  end
  local pending = session.backlog
  session.backlog = {}
  local filtered = filters().filter_lines(pending, session.filter)
  output().append_lines(session, filtered)
end

local function handle_output(session, lines, deps)
  if session.stopped then
    return
  end
  output().append_raw_lines(session, lines)
  local filtered = filters().filter_lines(lines, session.filter)
  if session.status_message and #filtered > 0 then
    session.status_message = nil
    session.body_lines = {}
    if session.active then
      panel().clear_body()
    end
  end
  if lines and #lines > 0 then
    deps.reset_reconnect(session)
  end
  if session.paused then
    enqueue(session, lines)
    return
  end
  output().append_lines(session, filtered)
end

local function toggle_pause(session)
  session.paused = not session.paused
  if session.paused then
    vim.notify("Logcat paused", vim.log.levels.INFO)
  else
    vim.notify("Logcat resumed", vim.log.levels.INFO)
    flush_backlog(session)
  end
end

local function clear_panel(session)
  output().clear_body(session)
end

local function reset_output(session)
  session.paused = false
  output().clear_body(session)
end

local function setup_keymaps(session, deps)
  if session.keymaps_ready then
    return
  end
  local function map(lhs, fn)
    local buffers = keymaps.buffer_targets(session.buf, session.control_buf)
    for _, buffer in ipairs(buffers) do
      vim.keymap.set("n", lhs, fn, { buffer = buffer, silent = true })
    end
  end
  map("q", function() session.on_close() end)
  map("c", function() clear_panel(session) end)
  map("C", function() reset_output(session) end)
  map("p", function() toggle_pause(session) end)
  map("r", function() deps.restart_logcat(session) end)
  map("gp", function() select_package(session, deps) end)
  map("gf", function() start_filter_edit(session, deps) end)
  map("gl", function() select_level(session, deps) end)
  map("gs", function() session.on_switch() end)
  map("<CR>", function()
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(current_win)
    local line = cursor and cursor[1] or 0
    local separate_header_buf = session.control_buf and session.control_buf ~= session.buf
    local header_buf = separate_header_buf and session.control_buf or session.buf
    if current_buf == header_buf then
      if line <= session.header_count then
        handle_header_enter(session, line, deps)
        return
      end
      if separate_header_buf then
        return
      end
    end
    stack_trace().open_stack_trace(session.root, session.origin_win)
  end)
  session.keymaps_ready = true
end

M.update_filter = update_filter
M.update_package = update_package
M.update_level = update_level
M.start_filter_edit = start_filter_edit
M.select_level = select_level
M.select_package = select_package
M.handle_header_enter = handle_header_enter
M.enqueue = enqueue
M.flush_backlog = flush_backlog
M.handle_output = handle_output
M.toggle_pause = toggle_pause
M.clear_panel = clear_panel
M.reset_output = reset_output
M.setup_keymaps = setup_keymaps

return M
