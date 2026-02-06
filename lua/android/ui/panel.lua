local M = {}

local body_buf_id = nil
local body_win_id = nil
local control_buf_id = nil
local control_win_id = nil
local mode = "inline"
local header_lines = {}
local header_count = 0
local group_augroup = nil
local closing_group = false
local body_name = nil
local control_name = nil

local function buffer_valid()
  return body_buf_id and vim.api.nvim_buf_is_valid(body_buf_id)
end

local function control_buffer_valid()
  return control_buf_id and vim.api.nvim_buf_is_valid(control_buf_id)
end

local function controls_enabled()
  return mode == "dock"
end

local function set_buffer_name(buf, name)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if type(name) ~= "string" or name == "" then
    return
  end
  if type(vim.api.nvim_buf_set_name) ~= "function" then
    return
  end
  pcall(vim.api.nvim_buf_set_name, buf, name)
end

local function ensure_body_buffer()
  if body_buf_id and vim.api.nvim_buf_is_valid(body_buf_id) then
    return
  end
  body_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(body_buf_id, "buftype", "nofile")
  vim.api.nvim_buf_set_option(body_buf_id, "swapfile", false)
  vim.api.nvim_buf_set_option(body_buf_id, "filetype", "android-log")
  vim.api.nvim_buf_set_option(body_buf_id, "modifiable", false)
  set_buffer_name(body_buf_id, body_name)
end

local function ensure_control_buffer()
  if control_buf_id and vim.api.nvim_buf_is_valid(control_buf_id) then
    return
  end
  control_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(control_buf_id, "buftype", "nofile")
  vim.api.nvim_buf_set_option(control_buf_id, "swapfile", false)
  vim.api.nvim_buf_set_option(control_buf_id, "filetype", "android-log-controls")
  vim.api.nvim_buf_set_option(control_buf_id, "modifiable", false)
  set_buffer_name(control_buf_id, control_name)
end

local function set_lines(buf, start, finish, lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local was_modifiable = true
  local ok_modifiable, value = pcall(vim.api.nvim_buf_get_option, buf, "modifiable")
  if ok_modifiable then
    was_modifiable = value
  end
  if not was_modifiable then
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
  end
  vim.api.nvim_buf_set_lines(buf, start, finish, false, lines or {})
  if not was_modifiable then
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end
end

local function close_window(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    return true
  end
  return false
end

local function apply_control_height(height)
  if not control_win_id or not vim.api.nvim_win_is_valid(control_win_id) then
    return
  end
  local next_height = tonumber(height) or 1
  if next_height < 1 then
    next_height = 1
  end
  pcall(vim.api.nvim_win_set_height, control_win_id, next_height)
  pcall(vim.api.nvim_win_set_option, control_win_id, "winfixheight", true)
end

local function body_win_valid()
  return body_win_id and vim.api.nvim_win_is_valid(body_win_id)
end

local function control_win_valid()
  return control_win_id and vim.api.nvim_win_is_valid(control_win_id)
end

local function close_control_window()
  if close_window(control_win_id) then
    control_win_id = nil
    return true
  end
  control_win_id = nil
  return false
end

local function close_body_window()
  if close_window(body_win_id) then
    body_win_id = nil
    return true
  end
  body_win_id = nil
  return false
end

local function clear_win_group()
  if group_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, group_augroup)
    group_augroup = nil
  end
end

local function setup_win_group()
  clear_win_group()
  if not body_win_id or not control_win_id then
    return
  end
  group_augroup = vim.api.nvim_create_augroup("AndroidPanelGroup", { clear = true })
  local watched = { [tostring(body_win_id)] = true, [tostring(control_win_id)] = true }
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group_augroup,
    pattern = "*",
    callback = function(ev)
      if closing_group then
        return
      end
      if not watched[ev.match] then
        return
      end
      closing_group = true
      vim.schedule(function()
        M.close()
        closing_group = false
      end)
    end,
  })
end

local function open_dock(options)
  ensure_body_buffer()
  ensure_control_buffer()

  if body_win_valid() and control_win_valid() then
    vim.api.nvim_win_set_buf(body_win_id, body_buf_id)
    vim.api.nvim_win_set_buf(control_win_id, control_buf_id)
    apply_control_height(options and options.control_height or header_count)
    set_lines(control_buf_id, 0, -1, header_lines)
    vim.api.nvim_set_current_win(body_win_id)
    return
  end

  close_control_window()
  close_body_window()

  vim.cmd("botright split")
  body_win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(body_win_id, body_buf_id)

  vim.cmd("aboveleft split")
  control_win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(control_win_id, control_buf_id)

  apply_control_height(options and options.control_height or header_count)
  set_lines(control_buf_id, 0, -1, header_lines)
  vim.api.nvim_set_current_win(body_win_id)
  setup_win_group()
end

local function reset_header()
  header_lines = {}
  header_count = 0
end

local function body_start()
  if controls_enabled() then
    return 0
  end
  return header_count
end

function M.open(opts)
  local options = opts or {}
  mode = options.layout == "dock" and "dock" or "inline"
  if not buffer_valid() then
    reset_header()
  end

  if controls_enabled() then
    open_dock(options)
  else
    ensure_body_buffer()
    close_control_window()
    if body_win_valid() then
      vim.api.nvim_win_set_buf(body_win_id, body_buf_id)
      vim.api.nvim_set_current_win(body_win_id)
    else
      vim.cmd("botright split")
      body_win_id = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(body_win_id, body_buf_id)
    end
  end

  return M.handle()
end

function M.handle()
  return {
    buf = body_buf_id,
    win = body_win_id,
    control_buf = control_buf_id,
    control_win = control_win_id,
    mode = mode,
  }
end

function M.append(lines)
  if not buffer_valid() then
    return
  end

  set_lines(body_buf_id, -1, -1, lines)

  if body_win_id and vim.api.nvim_win_is_valid(body_win_id) then
    local count = vim.api.nvim_buf_line_count(body_buf_id)
    if count > 0 then
      vim.api.nvim_win_set_cursor(body_win_id, { count, 0 })
    end
  end
end

function M.clear()
  if not buffer_valid() then
    return
  end
  reset_header()
  set_lines(body_buf_id, 0, -1, {})
  if control_buffer_valid() then
    set_lines(control_buf_id, 0, -1, {})
  end
end

function M.set_header_lines(lines)
  if not buffer_valid() then
    return
  end
  local new_lines = lines or {}
  local previous_count = header_count
  header_lines = new_lines
  header_count = #new_lines

  if controls_enabled() then
    if control_buffer_valid() then
      set_lines(control_buf_id, 0, -1, header_lines)
    end
    apply_control_height(math.max(1, header_count))
    return
  end

  local existing_lines = vim.api.nvim_buf_get_lines(body_buf_id, 0, -1, false)
  local body_lines = {}
  if previous_count > 0 then
    for i = previous_count + 1, #existing_lines do
      body_lines[#body_lines + 1] = existing_lines[i]
    end
  else
    body_lines = existing_lines
  end

  local merged = {}
  for _, line in ipairs(header_lines) do
    merged[#merged + 1] = line
  end
  for _, line in ipairs(body_lines) do
    merged[#merged + 1] = line
  end
  set_lines(body_buf_id, 0, -1, merged)
end

function M.set_names(names)
  local next_names = names or {}
  body_name = next_names.body
  control_name = next_names.control

  if buffer_valid() then
    set_buffer_name(body_buf_id, body_name)
  end
  if control_buffer_valid() then
    set_buffer_name(control_buf_id, control_name)
  end
end

function M.clear_body()
  if not buffer_valid() then
    return
  end
  local start = body_start()
  set_lines(body_buf_id, start, -1, {})
end

function M.replace_body(lines)
  if not buffer_valid() then
    return
  end
  local start = body_start()
  set_lines(body_buf_id, start, -1, lines or {})
end

function M.trim_body(max_lines)
  if not buffer_valid() then
    return
  end
  if not max_lines or max_lines <= 0 then
    return
  end
  local start = body_start()
  local total = vim.api.nvim_buf_line_count(body_buf_id)
  local body_lines = total - start
  if body_lines <= max_lines then
    return
  end
  local overflow = body_lines - max_lines
  set_lines(body_buf_id, start, start + overflow, {})
end

function M.close()
  clear_win_group()
  local control_closed = close_control_window()
  local body_closed = close_body_window()
  return control_closed or body_closed
end

return M
