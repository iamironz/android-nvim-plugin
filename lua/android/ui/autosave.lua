local M = {}

local function default_schedule(ms, fn)
  if vim.fn and vim.fn.timer_start then
    local timer_id = vim.fn.timer_start(ms, function()
      fn()
    end)
    return {
      stop = function()
        if vim.fn.timer_stop then
          vim.fn.timer_stop(timer_id)
        end
      end,
    }
  end

  fn()
  return { stop = function() end }
end

local function buffer_name(buf)
  return vim.api.nvim_buf_get_name(buf)
end

local function is_file_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
    return false
  end
  local name = buffer_name(buf)
  if name == nil or name == "" then
    return false
  end
  return true
end

local function is_writable(buf)
  if not is_file_buffer(buf) then
    return false
  end
  if not vim.api.nvim_buf_get_option(buf, "modifiable") then
    return false
  end
  if vim.api.nvim_buf_get_option(buf, "readonly") then
    return false
  end
  return vim.fn.filewritable(buffer_name(buf)) == 1
end

local function is_modified(buf)
  return vim.api.nvim_buf_get_option(buf, "modified") == true
end

local function default_should_save(buf)
  return is_modified(buf) and is_writable(buf)
end

local function default_save(buf)
  pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd("silent write")
  end)
end

local function build_config(opts)
  local options = opts or {}
  return {
    debounce_ms = options.debounce_ms or 200,
    schedule = options.schedule or default_schedule,
    should_save = options.should_save or default_should_save,
    save = options.save or default_save,
  }
end

function M.new(opts)
  local config = build_config(opts)
  local pending = {}

  local function stop_timer(buf)
    local timer = pending[buf]
    if timer and timer.stop then
      timer.stop()
    end
    pending[buf] = nil
  end

  local function on_event(buf)
    if not config.should_save(buf) then
      stop_timer(buf)
      return false
    end

    stop_timer(buf)
    local timer
    timer = config.schedule(config.debounce_ms, function()
      if pending[buf] ~= timer then
        return
      end
      pending[buf] = nil
      if config.should_save(buf) then
        config.save(buf)
      end
    end)
    pending[buf] = timer
    return true
  end

  local function stop_all()
    for buf, _ in pairs(pending) do
      stop_timer(buf)
    end
  end

  return {
    on_event = on_event,
    stop = stop_all,
  }
end

function M.setup(opts)
  local autosave = M.new(opts)
  local group = vim.api.nvim_create_augroup("AndroidAutosave", { clear = true })

  vim.api.nvim_create_autocmd({ "InsertLeave", "FocusLost" }, {
    group = group,
    callback = function(args)
      autosave.on_event(args.buf)
    end,
  })

  return autosave
end

return M
