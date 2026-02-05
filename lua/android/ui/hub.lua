local M = {}

local function block_label(block)
  local title = block and block.title or ""
  local count = block and block.items and #block.items or 0
  local desc = block and block.desc or ""
  local suffix = desc ~= "" and string.format(" | %s", desc) or ""
  if count > 0 then
    return string.format("%s (%d)%s", title, count, suffix)
  end
  return string.format("%s%s", title, suffix)
end

local function build_search_keys()
  local keys = {}
  for digit = 0, 9 do
    keys[#keys + 1] = tostring(digit)
  end
  for code = string.byte("a"), string.byte("z") do
    local key = string.char(code)
    -- Keep j/k available for default navigation.
    if key ~= "j" and key ~= "k" then
      keys[#keys + 1] = key
    end
  end
  return keys
end

local function build_lines(summary_lines, blocks)
  local lines = {}
  for _, line in ipairs(summary_lines or {}) do
    lines[#lines + 1] = line
  end
  if summary_lines and #summary_lines > 0 then
    lines[#lines + 1] = ""
  end
  for _, block in ipairs(blocks or {}) do
    lines[#lines + 1] = block_label(block)
  end
  return lines
end

local function create_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf or buf == 0 then
    return nil
  end

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  return buf
end

local function max_line_width(lines)
  local width = 0
  for _, line in ipairs(lines or {}) do
    local length = vim.fn.strdisplaywidth(line)
    if length > width then
      width = length
    end
  end
  return width
end

local function clamp(value, min, max)
  if value < min then
    return min
  end
  if value > max then
    return max
  end
  return value
end

local function calc_dimensions(lines, title)
  local base_width = max_line_width(lines)
  local title_width = title and vim.fn.strdisplaywidth(title) or 0
  local width = math.max(base_width, title_width) + 4
  local max_width = math.max(20, vim.o.columns - 4)
  width = clamp(width, 20, max_width)
  local height = #lines
  if height < 1 then
    height = 1
  end
  local max_height = math.max(3, vim.o.lines - 4)
  height = clamp(height, 1, max_height)
  return width, height
end

local function center_position(width, height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return row, col
end

local function open_window(buf, width, height, row, col, title)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title,
  })
  if not win or win == 0 then
    return nil
  end

  vim.wo[win].cursorline = true

  return win
end

local function block_start(summary_lines)
  local count = #(summary_lines or {})
  if count == 0 then
    return 0
  end
  return count + 1
end

local function current_index(blocks, summary_lines, win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return nil
  end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local line_index = cursor[1]
  local start = block_start(summary_lines)
  local block_index = line_index - start
  if block_index < 1 or block_index > #blocks then
    return nil
  end
  return block_index
end

local function initial_line(summary_lines, block_count, initial_index)
  if block_count == 0 then
    return 1
  end
  local index = tonumber(initial_index) or 1
  if index < 1 then
    index = 1
  elseif index > block_count then
    index = block_count
  end
  return block_start(summary_lines) + index
end

local function set_initial_cursor(win, lines, summary_lines, blocks, initial_index)
  if #lines == 0 or #blocks == 0 then
    return
  end
  local line = initial_line(summary_lines, #blocks, initial_index)
  if line > #lines then
    line = #lines
  elseif line < 1 then
    line = 1
  end
  vim.api.nvim_win_set_cursor(win, { line, 0 })
end

local function set_keymaps(buf, close_window, select_current, on_search, handle_search, on_cancel)
  local function handle_cancel()
    close_window("cancel")
    if on_cancel then
      on_cancel()
    end
  end

  vim.keymap.set("n", "q", function()
    close_window("close")
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", handle_cancel, { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", select_current, { buffer = buf, silent = true })
  if on_search then
    for _, key in ipairs(build_search_keys()) do
      local map_key = key
      vim.keymap.set("n", map_key, function()
        handle_search(map_key)
      end, { buffer = buf, silent = true })
    end
  end
end

local function set_buffer_lines(buf, lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function resize_window(win, lines, title)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local width, height = calc_dimensions(lines, title)
  local row, col = center_position(width, height)
  vim.api.nvim_win_set_config(win, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title,
  })
end

local function clamp_cursor(win, lines)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local line = cursor[1]
  local max_line = #lines
  if max_line < 1 then
    max_line = 1
  end
  if line < 1 then
    line = 1
  elseif line > max_line then
    line = max_line
  end
  vim.api.nvim_win_set_cursor(win, { line, 0 })
end

function M._build_lines(summary_lines, blocks)
  return build_lines(summary_lines, blocks)
end

function M._search_keys()
  return build_search_keys()
end

function M._initial_line(summary_lines, block_count, initial_index)
  return initial_line(summary_lines, block_count, initial_index)
end

function M.open(opts)
  local options = opts or {}
  local blocks = options.blocks or {}
  local summary_lines = options.summary_lines or {}
  local title = options.title or "Android Hub"
  local on_select = options.on_select
  local on_search = options.on_search
  local initial_index = options.initial_index
  local on_cancel = options.on_cancel
  local on_close = options.on_close
  local state = { blocks = blocks, summary_lines = summary_lines }

  local lines = build_lines(state.summary_lines, state.blocks)
  local buf = create_buffer(lines)
  if not buf then
    return
  end

  local width, height = calc_dimensions(lines, title)
  local row, col = center_position(width, height)
  local win = open_window(buf, width, height, row, col, title)
  if not win then
    return
  end

  set_initial_cursor(win, lines, state.summary_lines, state.blocks, initial_index)

  local closed = false
  local function close_window(reason)
    if closed then
      return
    end
    closed = true
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if on_close and reason then
      on_close(reason)
    end
  end

  local function select_current()
    local index = current_index(state.blocks, state.summary_lines, win)
    local block = index and state.blocks[index] or nil
    close_window()
    if on_select and block then
      on_select(block, index)
    end
  end

  local function handle_search(char)
    local index = current_index(state.blocks, state.summary_lines, win)
    close_window()
    if on_search then
      on_search(char, index)
    end
  end

  set_keymaps(buf, close_window, select_current, on_search, handle_search, on_cancel)

  return {
    buf = buf,
    win = win,
    close = close_window,
    state = state,
  }
end

function M.update(handle, opts)
  local options = opts or {}
  local buf = handle and handle.buf or nil
  local win = handle and handle.win or nil
  local state = handle and handle.state or nil
  if not buf or not win then
    return
  end
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local blocks = options.blocks or {}
  local summary_lines = options.summary_lines or {}
  local title = options.title or "Android Hub"
  if not state then
    state = { blocks = blocks, summary_lines = summary_lines }
    handle.state = state
  else
    state.blocks = blocks
    state.summary_lines = summary_lines
  end

  local lines = build_lines(state.summary_lines, state.blocks)
  set_buffer_lines(buf, lines)
  resize_window(win, lines, title)
  clamp_cursor(win, lines)
end

return M
