local M = {}
local stubs_helper = require("tests.helpers.stubs")
local function stub_table(target, replacements)
  local saved = {}
  for key, value in pairs(replacements or {}) do
    saved[key] = target[key]
    target[key] = value
  end
  return function()
    for key, value in pairs(saved) do
      target[key] = value
    end
  end
end
local function clone_lines(lines)
  local copy = {}
  for i, line in ipairs(lines or {}) do
    copy[i] = line
  end
  return copy
end
local function ensure_buffer(state, buf)
  if not state.buffers[buf] then
    state.buffers[buf] = { lines = { "" } }
  end
  return state.buffers[buf]
end
local function buffer_get_lines(state, buf, start, end_)
  local buffer = ensure_buffer(state, buf)
  local start_index = math.max(start, 0) + 1
  local end_index = end_ == -1 and #buffer.lines or end_
  local result = {}
  for i = start_index, math.min(end_index, #buffer.lines) do
    result[#result + 1] = buffer.lines[i]
  end
  return result
end
local function buffer_set_lines(state, buf, start, end_, lines)
  local buffer = ensure_buffer(state, buf)
  local start_index = start
  local end_index = end_
  if start_index == -1 then
    start_index = #buffer.lines
  end
  if end_index == -1 then
    end_index = #buffer.lines
  end
  start_index = start_index + 1

  local next_lines = {}
  for i = 1, start_index - 1 do
    next_lines[#next_lines + 1] = buffer.lines[i]
  end
  for _, line in ipairs(lines or {}) do
    next_lines[#next_lines + 1] = line
  end
  for i = end_index + 1, #buffer.lines do
    next_lines[#next_lines + 1] = buffer.lines[i]
  end
  buffer.lines = next_lines

  local attached = state.attached[buf]
  if attached and attached.on_lines then
    attached.on_lines(nil, buf, 0, start, end_, start + #(lines or {}), 0)
  end
end
local function set_header_lines_in_buffer(state, lines)
  local buf = vim.api.nvim_get_current_buf()
  local buffer = ensure_buffer(state, buf)
  local previous_count = state.header_count or 0
  local body_lines = {}
  if previous_count > 0 then
    for i = previous_count + 1, #buffer.lines do
      body_lines[#body_lines + 1] = buffer.lines[i]
    end
  else
    body_lines = clone_lines(buffer.lines)
  end

  local merged = {}
  for _, line in ipairs(lines or {}) do
    merged[#merged + 1] = line
  end
  for _, line in ipairs(body_lines) do
    merged[#merged + 1] = line
  end
  state.header_count = #merged - #body_lines
  buffer_set_lines(state, buf, 0, -1, merged)
end
local function trim_body_lines(state, max_lines)
  if not max_lines or max_lines <= 0 then
    return
  end
  local start = state.header_count or 0
  local body = buffer_get_lines(state, 1, start, -1)
  if #body <= max_lines then
    return
  end
  local trimmed = {}
  for i = #body - max_lines + 1, #body do
    trimmed[#trimmed + 1] = body[i]
  end
  buffer_set_lines(state, 1, start, -1, trimmed)
end
function M.body_lines(state)
  local start = (state.header_count or 0)
  local body = buffer_get_lines(state, 1, start, -1)
  while #body > 0 and body[1] == "" do
    table.remove(body, 1)
  end
  return body
end
local function build_vim_state(options)
  local opts = options or {}
  return {
    cursor_line = opts.cursor_line or 3,
    current_line = opts.current_line or "",
    input_value = opts.input_value or "",
    input_calls = {},
    keymaps = {},
    buffer_keymaps = {},
    keymap_calls = {},
    notify_calls = {},
    buffers = { [1] = { lines = { "" } } },
    attached = {},
    header_count = 0,
  }
end
local function stub_vim_api(state)
  return stub_table(vim.api, {
    nvim_get_current_win = function() return 10 end,
    nvim_get_current_buf = function() return 1 end,
    nvim_win_get_cursor = function() return { state.cursor_line, 0 } end,
    nvim_buf_line_count = function()
      return #ensure_buffer(state, 1).lines
    end,
    nvim_buf_get_lines = function(_, start, end_)
      return buffer_get_lines(state, 1, start, end_)
    end,
    nvim_buf_set_lines = function(_, start, end_, _, lines)
      buffer_set_lines(state, 1, start, end_, lines)
    end,
    nvim_buf_is_valid = function(buf)
      return state.buffers[buf] ~= nil
    end,
    nvim_buf_attach = function(buf, _, opts)
      state.attached[buf] = opts or {}
      return true
    end,
    nvim_buf_detach = function(buf)
      state.attached[buf] = nil
      return true
    end,
    nvim_buf_add_highlight = function() end,
    nvim_buf_clear_namespace = function() end,
    nvim_create_autocmd = function() end,
    nvim_win_is_valid = function() return true end,
    nvim_set_current_win = function() end,
    nvim_win_set_cursor = function() end,
    nvim_get_current_line = function() return state.current_line end,
  })
end

local function stub_vim_fn(state, options)
  local opts = options or {}
  return stub_table(vim.fn, {
    input = function(prompt, default)
      table.insert(state.input_calls, { prompt = prompt, default = default })
      if opts.input_value ~= nil then
        return opts.input_value
      end
      return default or ""
    end,
    findfile = function() return "" end,
  })
end

local function stub_keymap(state)
  return stub_table(vim.keymap, {
    set = function(mode, lhs, rhs, opts)
      state.keymaps[mode] = state.keymaps[mode] or {}
      state.keymaps[mode][lhs] = rhs

      local buffer = opts and opts.buffer or nil
      if buffer then
        state.buffer_keymaps[buffer] = state.buffer_keymaps[buffer] or {}
        state.buffer_keymaps[buffer][mode] = state.buffer_keymaps[buffer][mode] or {}
        state.buffer_keymaps[buffer][mode][lhs] = rhs
      end

      state.keymap_calls[#state.keymap_calls + 1] = {
        mode = mode,
        lhs = lhs,
        buffer = buffer,
      }
    end,
  })
end

local function stub_notify(state)
  return stub_table(vim, {
    notify = function(message, level)
      table.insert(state.notify_calls, { message = message, level = level })
    end,
    cmd = function() end,
  })
end

function M.with_vim_stubs(opts, fn)
  local options = opts or {}
  local state = build_vim_state(options)

  local restore_api = stub_vim_api(state)
  local restore_fn = stub_vim_fn(state, options)
  local restore_keymap = stub_keymap(state)
  local restore_notify = stub_notify(state)

  local ok, err = pcall(fn, state)

  restore_api()
  restore_fn()
  restore_keymap()
  restore_notify()

  if not ok then
    error(err)
  end
end

function M.build_state(overrides)
  local logcat = {
    package = "",
    filter = "",
    level = "",
    serial = "device-1",
  }

  if overrides and overrides.logcat then
    for key, value in pairs(overrides.logcat) do
      logcat[key] = value
    end
  end

  return { logcat = logcat }
end

function M.new_context(options)
  local opts = options or {}
  local ctx = {
    state = opts.state or M.build_state(),
    header_lines = opts.header_lines or { value = nil },
    panel_names = opts.panel_names,
    spawn_calls = opts.spawn_calls or { count = 0 },
    clear_body_calls = opts.clear_body_calls or { count = 0 },
  }
  return ctx
end

function M.with_logcat_context(options, fn)
  local opts = options or {}
  local ctx = M.new_context(opts)
  M.with_vim_stubs(opts.vim_opts or {}, function(vim_state)
    ctx.vim_state = vim_state
    local default_stubs = M.default_stubs(
      vim_state,
      ctx.state,
      ctx.header_lines,
      ctx.panel_names,
      ctx.spawn_calls,
      ctx.clear_body_calls
    )
    local stubs = stubs_helper.merge_stubs(default_stubs, opts.stubs)
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.actions.logcat"] = nil
      package.loaded["android.logcat.manager"] = nil
      package.loaded["android.logcat.session"] = nil
      ctx.logcat = require("android.actions.logcat")
      if opts.open ~= false then
        ctx.logcat.open()
      end
      fn(ctx)
    end)
  end)
end

function M.press_enter(ctx, line)
  ctx.vim_state.cursor_line = line
  ctx.vim_state.keymaps["n"]["<CR>"]()
end

function M.press_retry(ctx)
  ctx.vim_state.keymaps["n"]["r"]()
end

function M.start_filter_edit(ctx)
  ctx.vim_state.keymaps["n"]["gf"]()
end

function M.with_logcat_and_enter(options, line, fn)
  M.with_logcat_context(options, function(ctx)
    M.press_enter(ctx, line)
    fn(ctx)
  end)
end

function M.with_logcat_and_retry(options, fn)
  M.with_logcat_context(options, function(ctx)
    M.press_retry(ctx)
    fn(ctx)
  end)
end

function M.package_picker_stubs(package_name, packages)
  local list = packages or { package_name }
  return {
    ["android.logcat.processes"] = {
      list_packages = function()
        return list
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        opts.on_select(package_name)
      end,
    },
  }
end

function M.no_adb_stubs()
  return {
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function()
            return { adb = nil }
          end,
          aapt2 = function()
            return nil
          end,
        }
      end,
    },
  }
end

function M.empty_package_list_stubs()
  return {
    ["android.logcat.processes"] = {
      list_packages = function()
        return {}
      end,
    },
  }
end

local function context_stubs(state)
  return {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
  }
end

local function discovery_stubs()
  return {
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function()
            return { adb = "/bin/adb" }
          end,
          aapt2 = function()
            return nil
          end,
        }
      end,
    },
  }
end

local function runner_stubs()
  return {
    ["android.command.runner"] = {
      new = function()
        return {
          run = function()
            return { ok = true, stdout = "123", stderr = "" }
          end,
        }
      end,
    },
  }
end

local function adb_stubs()
  return {
    ["android.devices.adb"] = {
      list = function()
        return { { serial = "device-1", state = "device" } }
      end,
    },
  }
end

local function defaults_stubs()
  return {
    ["android.actions.defaults"] = {
      select_device_serial = function(_, saved)
        return saved or "device-1"
      end,
    },
  }
end

local function package_stubs()
  return {
    ["android.logcat.package"] = {
      resolve_default_package = function()
        return "com.default"
      end,
    },
  }
end

local function command_stubs()
  return {
    ["android.logcat.command"] = {
      build = function()
        return { "adb", "logcat" }
      end,
    },
  }
end

local function parser_stubs()
  return {
    ["android.logcat.parser"] = {
      parse_stack_line = function()
        return nil
      end,
    },
  }
end

local function job_stubs(spawn_calls)
  return {
    ["android.command.job"] = {
      spawn = function()
        spawn_calls.count = spawn_calls.count + 1
        return { ok = true, stop = function() end }
      end,
    },
  }
end

local function panel_stubs(vim_state, header_lines, panel_names, clear_body_calls)
  return {
    ["android.ui.panel"] = {
      open = function() end,
      clear = function() end,
      append = function(lines)
        buffer_set_lines(vim_state, 1, -1, -1, lines or {})
      end,
      set_header_lines = function(lines)
        header_lines.value = lines
        set_header_lines_in_buffer(vim_state, lines)
      end,
      set_names = function(names)
        if not panel_names then
          return
        end
        local snapshot = {
          body = names and names.body or nil,
          control = names and names.control or nil,
        }
        panel_names.value = snapshot
        panel_names.history = panel_names.history or {}
        panel_names.history[#panel_names.history + 1] = snapshot
      end,
      clear_body = function()
        clear_body_calls.count = clear_body_calls.count + 1
        buffer_set_lines(vim_state, 1, vim_state.header_count or 0, -1, {})
      end,
      replace_body = function(lines)
        buffer_set_lines(vim_state, 1, vim_state.header_count or 0, -1, lines or {})
      end,
      trim_body = function(max_lines)
        trim_body_lines(vim_state, max_lines)
      end,
      close = function() return true end,
    },
  }
end

function M.default_stubs(vim_state, state, header_lines, panel_names, spawn_calls, clear_body_calls)
  return stubs_helper.merge_stubs(
    context_stubs(state),
    discovery_stubs(),
    runner_stubs(),
    adb_stubs(),
    defaults_stubs(),
    package_stubs(),
    command_stubs(),
    parser_stubs(),
    job_stubs(spawn_calls),
    panel_stubs(vim_state, header_lines, panel_names, clear_body_calls)
  )
end
return M
