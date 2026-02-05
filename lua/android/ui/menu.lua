local M = {}

local menu_items = require("android.ui.menu_items")
local actions_picker = require("android.ui.actions")
local hub = require("android.ui.hub")
local summary = require("android.ui.summary")

local nav = { stack = {}, current = nil }

local function apply_back_handler(hub_opts)
  if #nav.stack == 0 then
    hub_opts.on_cancel = nil
    return
  end

  hub_opts.on_cancel = function()
    local previous = table.remove(nav.stack)
    if not previous then
      return
    end
    nav.current = previous
    apply_back_handler(previous)
    hub.open(previous)
  end
end

local function open_hub_with_nav(hub_opts, mode)
  if mode == "root" then
    nav.stack = {}
  elseif mode == "child" then
    if nav.current then
      table.insert(nav.stack, nav.current)
    end
  end

  nav.current = hub_opts
  apply_back_handler(hub_opts)
  hub_opts._hub_handle = hub.open(hub_opts)
end

local function block_index(blocks, block)
  for index, entry in ipairs(blocks or {}) do
    if entry == block then
      return index
    end
  end
  return nil
end

local function tools_search_title(blocks)
  if #blocks == 1 then
    local block_title = blocks[1].title or "Tools"
    return "Android " .. block_title
  end
  return "Android Tools"
end

function M.show_main_menu()
  local blocks = menu_items.top_level_blocks()
  local summary_lines, refresh_summary = summary.lines({ mode = "fast" })
  local hub_opts = {
    title = "Android Menu",
    summary_lines = summary_lines,
    blocks = blocks,
  }
  local function reopen_hub()
    open_hub_with_nav(hub_opts)
  end

  hub_opts.on_select = function(block)
    if not block then
      return
    end
    local index = block_index(blocks, block)
    if index then
      hub_opts.initial_index = index
    end
    local block_title = block.title or "Menu"
    actions_picker.open({
      title = "Android " .. block_title,
      blocks = { block },
      on_cancel = reopen_hub,
    })
  end
  hub_opts.on_search = function(char, index)
    if index then
      hub_opts.initial_index = index
    end
    actions_picker.open({
      title = "Android Menu",
      blocks = blocks,
      default_query = char,
      on_cancel = reopen_hub,
    })
  end

  open_hub_with_nav(hub_opts, "root")

  if refresh_summary then
    refresh_summary(function(updated)
      if nav.current ~= hub_opts then
        return
      end
      hub_opts.summary_lines = updated
      if hub_opts._hub_handle then
        hub.update(hub_opts._hub_handle, hub_opts)
      end
    end)
  end
end

function M.show_targets_menu(opts)
  local options = opts or {}
  local block = menu_items.block_by_title("Build")
  if not block then
    return
  end
  local hub_opts = {
    title = "Android Build",
    blocks = { block },
  }
  local function reopen_hub()
    open_hub_with_nav(hub_opts)
  end

  hub_opts.on_select = function(selected)
    if not selected then
      return
    end
    hub_opts.initial_index = 1
    actions_picker.open({
      title = "Android Build",
      blocks = { selected },
      on_cancel = reopen_hub,
    })
  end
  hub_opts.on_search = function(char)
    hub_opts.initial_index = 1
    actions_picker.open({
      title = "Android Build",
      blocks = { block },
      default_query = char,
      on_cancel = reopen_hub,
    })
  end

  open_hub_with_nav(hub_opts, options.from_action and "child" or "root")
end

function M.show_tools_menu(opts)
  local options = opts or {}
  local block = menu_items.block_by_title("Tools")
  local blocks = {}
  if block then
    blocks = { block }
  else
    local devices = menu_items.block_by_title("Devices")
    local apps = menu_items.block_by_title("Apps")
    if devices then
      table.insert(blocks, devices)
    end
    if apps then
      table.insert(blocks, apps)
    end
  end
  if #blocks == 0 then
    return
  end
  local hub_opts = {
    title = "Android Tools",
    blocks = blocks,
  }
  local function reopen_hub()
    open_hub_with_nav(hub_opts)
  end

  hub_opts.on_select = function(selected)
    if not selected then
      return
    end
    local block_title = selected.title or "Tools"
    local index = block_index(blocks, selected)
    if index then
      hub_opts.initial_index = index
    end
    actions_picker.open({
      title = "Android " .. block_title,
      blocks = { selected },
      on_cancel = reopen_hub,
    })
  end
  hub_opts.on_search = function(char, index)
    if index then
      hub_opts.initial_index = index
    end
    actions_picker.open({
      title = tools_search_title(blocks),
      blocks = blocks,
      default_query = char,
      on_cancel = reopen_hub,
    })
  end

  open_hub_with_nav(hub_opts, options.from_action and "child" or "root")
end

function M.show_actions_menu(opts)
  local options = opts or {}
  local blocks = menu_items.top_level_blocks()
  local hub_opts = {
    title = "Android Actions",
    blocks = blocks,
  }
  local function reopen_hub()
    open_hub_with_nav(hub_opts)
  end

  hub_opts.on_select = function(selected)
    if not selected then
      return
    end
    local block_title = selected.title or "Actions"
    local index = block_index(blocks, selected)
    if index then
      hub_opts.initial_index = index
    end
    actions_picker.open({
      title = "Android " .. block_title,
      blocks = { selected },
      on_cancel = reopen_hub,
    })
  end
  hub_opts.on_search = function(char, index)
    if index then
      hub_opts.initial_index = index
    end
    actions_picker.open({
      title = "Android Actions",
      blocks = blocks,
      default_query = char,
      on_cancel = reopen_hub,
    })
  end

  open_hub_with_nav(hub_opts, options.from_action and "child" or "root")
end

return M
