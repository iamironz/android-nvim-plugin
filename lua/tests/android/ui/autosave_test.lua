local M = {}

local assert = require("tests.helpers.assert")

local function create_saver()
  local saved = {}
  local function save(tbl, key)
    saved[tbl] = saved[tbl] or {}
    if saved[tbl][key] == nil then
      saved[tbl][key] = tbl[key]
    end
  end

  local function restore()
    for tbl, keys in pairs(saved) do
      for key, value in pairs(keys) do
        tbl[key] = value
      end
    end
  end

  return save, restore
end

local function build_state()
  return {
    buffers = {
      [1] = {
        modified = true,
        modifiable = true,
        readonly = false,
        buftype = "",
        name = "/tmp/file.txt",
      },
    },
    filewritable = {
      ["/tmp/file.txt"] = 1,
    },
    saves = {},
  }
end

local function with_vim_state(run)
  local state = build_state()
  local save, restore = create_saver()

  save(vim.api, "nvim_buf_is_valid")
  vim.api.nvim_buf_is_valid = function(buf)
    return state.buffers[buf] ~= nil
  end

  save(vim.api, "nvim_buf_get_option")
  vim.api.nvim_buf_get_option = function(buf, name)
    local buffer = state.buffers[buf]
    if not buffer then
      return nil
    end
    if name == "modified" then
      return buffer.modified
    end
    if name == "modifiable" then
      return buffer.modifiable
    end
    if name == "readonly" then
      return buffer.readonly
    end
    if name == "buftype" then
      return buffer.buftype
    end
    return nil
  end

  save(vim.api, "nvim_buf_get_name")
  vim.api.nvim_buf_get_name = function(buf)
    local buffer = state.buffers[buf]
    return buffer and buffer.name or ""
  end

  save(vim.api, "nvim_buf_call")
  vim.api.nvim_buf_call = function(_, fn)
    fn()
  end

  save(vim.fn, "filewritable")
  vim.fn.filewritable = function(path)
    local value = state.filewritable[path]
    if value == nil then
      return 0
    end
    return value
  end

  local ok, err = pcall(run, state)
  restore()
  if not ok then
    error(err)
  end
end

local function build_scheduler()
  local timers = {}
  local function schedule(_, fn)
    local timer = { stopped = false, fn = fn }
    function timer.stop()
      timer.stopped = true
    end
    table.insert(timers, timer)
    return timer
  end
  return schedule, timers
end

local function saves_modified_writable_buffer_after_debounce()
  with_vim_state(function(state)
    local schedule, timers = build_scheduler()
    local autosave = require("android.ui.autosave").new({
      schedule = schedule,
      debounce_ms = 10,
      save = function(buf)
        table.insert(state.saves, buf)
      end,
    })

    autosave.on_event(1)
    assert.eq(#timers, 1, "timer scheduled")
    assert.eq(#state.saves, 0, "no save before debounce")

    timers[1].fn()
    assert.eq(state.saves[1], 1, "save triggered")
  end)
end

local function skips_unmodified_buffer()
  with_vim_state(function(state)
    state.buffers[1].modified = false
    local schedule, timers = build_scheduler()
    local autosave = require("android.ui.autosave").new({
      schedule = schedule,
      debounce_ms = 10,
      save = function(buf)
        table.insert(state.saves, buf)
      end,
    })

    autosave.on_event(1)
    assert.eq(#timers, 0, "no timer for unmodified buffer")
    assert.eq(#state.saves, 0, "no save for unmodified buffer")
  end)
end

local function skips_unwritable_file()
  with_vim_state(function(state)
    state.filewritable["/tmp/file.txt"] = 0
    local schedule, timers = build_scheduler()
    local autosave = require("android.ui.autosave").new({
      schedule = schedule,
      debounce_ms = 10,
      save = function(buf)
        table.insert(state.saves, buf)
      end,
    })

    autosave.on_event(1)
    assert.eq(#timers, 0, "no timer for unwritable file")
    assert.eq(#state.saves, 0, "no save for unwritable file")
  end)
end

local function debounces_multiple_events()
  with_vim_state(function(state)
    local schedule, timers = build_scheduler()
    local autosave = require("android.ui.autosave").new({
      schedule = schedule,
      debounce_ms = 10,
      save = function(buf)
        table.insert(state.saves, buf)
      end,
    })

    autosave.on_event(1)
    autosave.on_event(1)
    assert.eq(#timers, 2, "second timer scheduled")
    assert.is_true(timers[1].stopped, "first timer stopped")

    timers[1].fn()
    assert.eq(#state.saves, 0, "stopped timer ignored")
    timers[2].fn()
    assert.eq(#state.saves, 1, "latest timer saves")
  end)
end

local function skips_when_buffer_becomes_unmodified()
  with_vim_state(function(state)
    local schedule, timers = build_scheduler()
    local autosave = require("android.ui.autosave").new({
      schedule = schedule,
      debounce_ms = 10,
      save = function(buf)
        table.insert(state.saves, buf)
      end,
    })

    autosave.on_event(1)
    state.buffers[1].modified = false
    timers[1].fn()
    assert.eq(#state.saves, 0, "no save after modification cleared")
  end)
end

function M.run()
  saves_modified_writable_buffer_after_debounce()
  skips_unmodified_buffer()
  skips_unwritable_file()
  debounces_multiple_events()
  skips_when_buffer_becomes_unmodified()
end

return M
