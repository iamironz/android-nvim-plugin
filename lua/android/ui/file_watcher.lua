local M = {}

local function is_file_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == nil or name == "" then
    return false
  end
  return true
end

local function reload_buffer(buf)
  pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd("edit!")
  end)
end

local function save_buffer(buf)
  pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd("silent write!")
  end)
end

local function diff_buffer(buf, path)
  local escaped = vim.fn.fnameescape(path)
  pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd("vert diffsplit " .. escaped)
  end)
end

local function build_prompt(path)
  return string.format("File changed on disk: %s", path)
end

local function build_config(opts)
  local options = opts or {}
  return {
    confirm = options.confirm or vim.fn.confirm,
    reload = options.reload or reload_buffer,
    save = options.save or save_buffer,
    diff = options.diff or diff_buffer,
  }
end

function M.new(opts)
  local config = build_config(opts)

  local function on_change(buf)
    if not is_file_buffer(buf) then
      return false
    end
    if not vim.api.nvim_buf_get_option(buf, "modified") then
      return false
    end

    local path = vim.api.nvim_buf_get_name(buf)
    local choice = config.confirm(
      build_prompt(path),
      "&Reload\n&Keep\n&Diff\n&Force Save",
      2
    )
    if choice == 1 then
      config.reload(buf)
      return "reload"
    end
    if choice == 3 then
      config.diff(buf, path)
      return "diff"
    end
    if choice == 4 then
      config.save(buf)
      return "save"
    end
    return "keep"
  end

  return {
    on_change = on_change,
  }
end

function M.setup(opts)
  local watcher = M.new(opts)
  local group = vim.api.nvim_create_augroup("AndroidFileWatcher", { clear = true })

  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
    group = group,
    callback = function()
      vim.cmd("checktime")
    end,
  })

  vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = group,
    callback = function(args)
      watcher.on_change(args.buf)
    end,
  })

  return watcher
end

return M
