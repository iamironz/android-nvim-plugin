local M = {}

-- Wide enough for common tag, package, and short message filters without a
-- config knob for one prompt helper.
local MIN_WIDTH = 56

local function display_width(value)
  if not value or value == "" then
    return 0
  end

  return vim.fn.strdisplaywidth(value)
end

local function calc_width(prompt, default, title)
  local content_width = display_width(prompt) + display_width(default)
  local title_width = display_width(title)
  local base = math.max(content_width + 4, title_width + 4, MIN_WIDTH)
  local max = math.max(20, vim.o.columns - 4)
  return math.min(base, max)
end

local function strip_prompt(value, prompt)
  if not value or value == "" then
    return ""
  end
  if prompt ~= "" and value:sub(1, #prompt) == prompt then
    return value:sub(#prompt + 1)
  end
  return value
end

local function center_position(width, height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return row, col
end

function M.prompt(opts)
  local options = opts or {}
  local prompt = options.prompt or ""
  local title = options.title or "Input"
  local default = options.default or ""
  local on_submit = options.on_submit
  local on_cancel = options.on_cancel
  local on_change = options.on_change

  local buf = vim.api.nvim_create_buf(false, true)
  if not buf or buf == 0 then
    return
  end

  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].bufhidden = "wipe"
  vim.fn.prompt_setprompt(buf, prompt)
  if default ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  end

  local width = calc_width(prompt, default, title)
  local height = 1
  local row, col = center_position(width, height)
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

  local closed = false
  local last_value = default
  local function close_window()
    if closed then
      return
    end
    closed = true
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.fn.prompt_setcallback(buf, function(value)
    close_window()
    if on_submit then
      on_submit(value or "")
    end
  end)

  vim.keymap.set("i", "<Esc>", function()
    close_window()
    if on_cancel then
      on_cancel()
    end
  end, { buffer = buf, silent = true })

  if on_change then
    local function current_value()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
      local raw = lines[1] or ""
      return strip_prompt(raw, prompt)
    end

    local function notify_change()
      if closed then
        return
      end
      local value = current_value()
      if value == last_value then
        return
      end
      last_value = value
      local function run()
        if closed then
          return
        end
        on_change(value)
      end
      if vim.in_fast_event and vim.in_fast_event() and vim.schedule then
        vim.schedule(run)
      else
        run()
      end
    end

    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
      buffer = buf,
      callback = notify_change,
    })
  end

  vim.cmd("startinsert!")
end

return M
