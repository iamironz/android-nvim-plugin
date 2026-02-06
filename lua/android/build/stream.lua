local M = {}

local jobs = require("android.command.jobs")
local panel = require("android.ui.panel")
local panel_header = require("android.ui.panel_header")
local picker = require("android.ui.picker")
local context = require("android.actions.context")
local history = require("android.state.history")
local filters = require("android.logcat.filters")
local keymaps = require("android.utils.keymaps")
local strings = require("android.utils.strings")
local DEFAULT_MAX_LINES = 2000
local DEFAULT_CONTROL_HEIGHT = 1

local function lowercase_first(value)
  if not value or value == "" then
    return value
  end
  return value:sub(1, 1):lower() .. value:sub(2)
end

local function parse_task_context(task)
  if type(task) ~= "string" or task == "" then
    return { task = nil, module = nil, variant = nil }
  end

  local module, name = task:match("^(:.+):([^:]+)$")
  local task_name = name or task
  local variant_suffix = task_name:match("^assemble(.+)$")
    or task_name:match("^bundle(.+)$")

  return {
    task = task_name,
    module = module,
    variant = lowercase_first(variant_suffix),
  }
end

local function resolve_task_argument(args)
  for i = 2, #(args or {}) do
    local value = args[i]
    if type(value) == "string" and value ~= "" and value:sub(1, 1) ~= "-" then
      return value
    end
  end
  return nil
end

local function resolve_panel_context(args, opts)
  local options = opts or {}
  local task = options.task or resolve_task_argument(args)
  local parsed = parse_task_context(task)

  return {
    task = options.task or parsed.task,
    module = options.module or parsed.module,
    variant = options.variant or parsed.variant,
  }
end

local function trim_lines(lines, max_lines)
  local overflow = #lines - max_lines
  if overflow <= 0 then
    return lines
  end
  local trimmed = {}
  for i = overflow + 1, #lines do
    trimmed[#trimmed + 1] = lines[i]
  end
  return trimmed
end

local function normalize_input(value)
  if value == nil then
    return ""
  end
  return strings.trim(tostring(value))
end

local function render_header(session)
  if panel.set_names then
    panel.set_names(panel_header.build_panel_names({
      module = session.module,
      variant = session.variant,
      task = session.task,
      filter = session.filter,
    }))
  end
  panel.set_header_lines(panel_header.build_lines({ filter = session.filter }))
end

local function render_body(session)
  local filtered = filters.filter_lines(session.output.all, session.filter)
  panel.replace_body(filtered)
end

local function update_filter(session, value)
  local next_filter = normalize_input(value)
  if next_filter == session.filter then
    return
  end
  session.filter = next_filter
  render_header(session)
  render_body(session)
end

local function load_filter_history(root)
  if not root or root == "" then
    return {}, nil
  end
  local state = context.load_state(root) or {}
  local build_state = state.build or {}
  return build_state.filter_history or {}, state
end

local function persist_filter_history(root, state, list)
  if not root or root == "" then
    return
  end
  local next_state = state or {}
  next_state.build = next_state.build or {}
  next_state.build.filter_history = list
  context.save_state(root, next_state)
end

local function commit_filter_history(session, state, value)
  local next_history = history.push(session.filter_history or {}, value, { limit = 20 })
  session.filter_history = next_history
  persist_filter_history(session.root, state, next_history)
end

local function start_filter_edit(session)
  local filter_history, state = load_filter_history(session.root)
  session.filter_history = filter_history
  picker.filter_input({
    prompt_title = "Build filter",
    items = filter_history,
    default = session.filter,
    on_change = function(value) update_filter(session, value) end,
    on_accept = function(value)
      update_filter(session, value)
      commit_filter_history(session, state, value)
    end,
    on_cancel = function()
      commit_filter_history(session, state, session.filter)
    end,
  })
end

local function handle_header_enter(session, line)
  if line == 1 then
    start_filter_edit(session)
    return true
  end
  return false
end

local function setup_keymaps(session)
  local function map(lhs, fn)
    local buffers = keymaps.buffer_targets(session.buf, session.control_buf)
    for _, buffer in ipairs(buffers) do
      vim.keymap.set("n", lhs, fn, { buffer = buffer, silent = true })
    end
  end

  map("f", function()
    start_filter_edit(session)
  end)
  map("<CR>", function()
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(current_win)
    local line = cursor and cursor[1] or 0
    local separate_header_buf = session.control_buf and session.control_buf ~= session.buf
    local header_buf = separate_header_buf and session.control_buf or session.buf
    if current_buf == header_buf then
      if line <= session.header_count then
        handle_header_enter(session, line)
        return
      end
      if separate_header_buf then
        return
      end
    end
  end)
end

local function create_session(root, args, opts)
  local metadata = resolve_panel_context(args, opts)
  local handle = panel.open({
    layout = "dock",
    control_height = DEFAULT_CONTROL_HEIGHT,
  })
  panel.clear()

  local buf = handle and handle.buf or vim.api.nvim_get_current_buf()
  local win = handle and handle.win or vim.api.nvim_get_current_win()
  local session = {
    buf = buf,
    win = win,
    control_buf = handle and handle.control_buf or nil,
    control_win = handle and handle.control_win or nil,
    root = root,
    module = metadata.module,
    variant = metadata.variant,
    task = metadata.task,
    filter = "",
    header_count = 1,
    max_lines = DEFAULT_MAX_LINES,
    output = { all = {}, stdout = {}, stderr = {} },
  }

  render_header(session)
  setup_keymaps(session)
  return session
end

local function handle_output(session, lines, target)
  if not lines or #lines == 0 then
    return
  end
  local filtered = filters.filter_lines(lines, session.filter)
  panel.append(filtered)
  for _, line in ipairs(lines) do
    table.insert(session.output.all, line)
    table.insert(session.output[target], line)
  end
  if session.max_lines and session.max_lines > 0 then
    session.output.all = trim_lines(session.output.all, session.max_lines)
    session.output[target] = trim_lines(session.output[target], session.max_lines)
    panel.trim_body(session.max_lines)
  end
end

local function finalize_build_result(code, output)
  return {
    ok = code == 0,
    code = code,
    stdout = table.concat(output.stdout, "\n"),
    stderr = table.concat(output.stderr, "\n"),
    lines = output.all,
  }
end

function M.build_shell_command(_, args)
  local command = {}
  for _, arg in ipairs(args or {}) do
    table.insert(command, arg)
  end
  return command
end

function M.start_build_job(root, args, on_complete, opts)
  local options = opts or {}
  local session = create_session(root, args, options.panel)
  local cmd = M.build_shell_command(root, args)
  local build_job = jobs.start(cmd, {
    cwd = root,
    on_stdout = function(lines)
      handle_output(session, lines, "stdout")
    end,
    on_stderr = function(lines)
      handle_output(session, lines, "stderr")
    end,
    on_exit = function(code)
      local result = finalize_build_result(code, session.output)
      if on_complete then
        on_complete(result)
      end
    end,
  })

  if not build_job.ok then
    vim.notify("Failed to start Android build", vim.log.levels.ERROR)
    if on_complete then
      on_complete({ ok = false, code = 1, stdout = "", stderr = "", lines = {} })
    end
    return nil
  end

  return build_job
end

return M
