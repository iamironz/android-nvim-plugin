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

local function normalize_root(root)
  if root == nil or root == "" then
    return nil
  end
  if root:sub(-1) ~= "/" then
    return root .. "/"
  end
  return root
end

local function is_under_root(root, path)
  if not root then
    return true
  end
  if not path or path == "" then
    return false
  end
  local root_path = root:sub(1, -2)
  if path == root_path then
    return true
  end
  return path:sub(1, #root) == root
end

local function default_now()
  if vim.loop and vim.loop.now then
    return vim.loop.now()
  end
  return math.floor(os.clock() * 1000)
end

local function build_config(opts)
  local options = opts or {}
  return {
    confirm = options.confirm or vim.fn.confirm,
    reload = options.reload or reload_buffer,
    save = options.save or save_buffer,
    diff = options.diff or diff_buffer,
    workspace_root = normalize_root(options.workspace_root),
    cooldown_ms = options.cooldown_ms ~= nil and options.cooldown_ms or 1000,
    now = options.now or default_now,
  }
end

function M.new(opts)
  local config = build_config(opts)
  local last_prompt_at = {}

  local function on_change(buf)
    if not is_file_buffer(buf) then
      return false
    end
    if not vim.api.nvim_buf_get_option(buf, "modified") then
      return false
    end

    local path = vim.api.nvim_buf_get_name(buf)
    if not is_under_root(config.workspace_root, path) then
      return false
    end
    if config.cooldown_ms > 0 then
      local now = config.now()
      local last_prompt = last_prompt_at[buf]
      if last_prompt and now - last_prompt < config.cooldown_ms then
        return false
      end
      last_prompt_at[buf] = now
    end
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
