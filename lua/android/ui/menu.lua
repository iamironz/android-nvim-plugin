local M = {}

local menu_items = require("android.ui.menu_items")
local actions_picker = require("android.ui.actions")
local hub = require("android.ui.hub")
local summary = require("android.ui.summary")
local context = require("android.actions.context")
local menu_prefetch = require("android.state.menu_prefetch")

local nav = { stack = {}, current = nil }

M._schedule = vim.schedule

local function update_summary(hub_opts, menu_status)
  if not hub_opts then
    return
  end
  local summary_lines, refresh_summary = summary.lines({
    mode = "fast",
    menu_status = menu_status,
  })
  hub_opts.summary_lines = summary_lines
  if hub_opts._hub_handle then
    hub.update(hub_opts._hub_handle, hub_opts)
  end
  if refresh_summary then
    local current = hub_opts
    refresh_summary(function(updated)
      if nav.current ~= current then
        return
      end
      current.summary_lines = updated
      if current._hub_handle then
        hub.update(current._hub_handle, current)
      end
    end)
  end
end

local function update_current_summary(menu_status)
  update_summary(nav.current, menu_status)
end

local function clear_prefetch()
  if nav.prefetch and nav.prefetch.session and nav.prefetch.session.cancel then
    nav.prefetch.session.cancel()
  end
  nav.prefetch = nil
end

local function reset_nav_state()
  clear_prefetch()
  nav.stack = {}
  nav.current = nil
end

local function ensure_prefetch(workspace)
  if not workspace or not workspace.root then
    return nil
  end
  if nav.prefetch and nav.prefetch.root == workspace.root then
    return nav.prefetch.session
  end
  clear_prefetch()
  local session = menu_prefetch.start(workspace, {
    on_update = update_current_summary,
  })
  nav.prefetch = { root = workspace.root, session = session }
  return session
end

local function apply_back_handler(hub_opts)
  if hub_opts._prefer_fallback and hub_opts._fallback_on_cancel then
    hub_opts.on_cancel = function()
      reset_nav_state()
      hub_opts._fallback_on_cancel()
    end
    return
  end
  if #nav.stack == 0 then
    hub_opts.on_cancel = hub_opts._fallback_on_cancel
    return
  end

  hub_opts.on_cancel = function()
    local previous = table.remove(nav.stack)
    if not previous then
      return
    end
    nav.current = previous
    apply_back_handler(previous)
    previous._hub_handle = hub.open(previous)
  end
end

local function apply_close_handler(hub_opts)
  if hub_opts._close_wrapped then
    return
  end
  local original = hub_opts.on_close
  hub_opts.on_close = function(reason)
    if original then
      original(reason)
    end
    if reason == "close" or #nav.stack == 0 then
      clear_prefetch()
      nav.stack = {}
      nav.current = nil
    end
  end
  hub_opts._close_wrapped = true
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
  apply_close_handler(hub_opts)
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
  return "Android Device Manager & ADB"
end

function M.show_main_menu()
  local workspace = context.workspace()
  local cached_status = workspace and menu_prefetch.status(workspace.root) or nil
  local blocks = (menu_items.top_level_blocks_fast and menu_items.top_level_blocks_fast(workspace))
    or menu_items.top_level_blocks(workspace)
  local summary_lines, refresh_summary = summary.lines({
    mode = "fast",
    menu_status = cached_status,
  })
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
    local index = block_index(hub_opts.blocks, block)
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
      blocks = hub_opts.blocks,
      default_query = char,
      on_cancel = reopen_hub,
    })
  end

  open_hub_with_nav(hub_opts, "root")

  M._schedule(function()
    if nav.current ~= hub_opts then
      return
    end
    local session = workspace and ensure_prefetch(workspace) or nil
    local run_snapshot = session and session.run_snapshot
      or (menu_prefetch.cached_run_snapshot and menu_prefetch.cached_run_snapshot(workspace and workspace.root) or nil)
    local new_blocks = menu_items.top_level_blocks(workspace, { run_snapshot = run_snapshot })
    if nav.current ~= hub_opts then
      return
    end
    hub_opts.blocks = new_blocks
    update_summary(hub_opts, session and session.status or cached_status)
  end)

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
  local block = menu_items.block_by_title("Build Variants")
  if not block then
    return
  end
  local workspace = context.workspace()
  local cached_status = workspace and menu_prefetch.status(workspace.root) or nil
  local hub_opts = {
    title = "Android Build Variants",
    summary_lines = summary.lines({ mode = "fast", menu_status = cached_status }),
    blocks = { block },
  }
  if options.on_cancel then
    hub_opts._fallback_on_cancel = options.on_cancel
    hub_opts._prefer_fallback = options.from_action
  end
  local function reopen_hub()
    open_hub_with_nav(hub_opts)
  end

  hub_opts.on_select = function(selected)
    if not selected then
      return
    end
    hub_opts.initial_index = 1
    actions_picker.open({
      title = "Android Build Variants",
      blocks = { selected },
      on_cancel = reopen_hub,
    })
  end
  hub_opts.on_search = function(char)
    hub_opts.initial_index = 1
    actions_picker.open({
      title = "Android Build Variants",
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
    local devices = menu_items.block_by_title("Device Manager")
    local apps = menu_items.block_by_title("ADB")
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
  local workspace = context.workspace()
  local cached_status = workspace and menu_prefetch.status(workspace.root) or nil
  local hub_opts = {
    title = tools_search_title(blocks),
    summary_lines = summary.lines({ mode = "fast", menu_status = cached_status }),
    blocks = blocks,
  }
  if options.on_cancel then
    hub_opts._fallback_on_cancel = options.on_cancel
    hub_opts._prefer_fallback = options.from_action
  end
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
  local workspace = context.workspace()
  local cached_status = workspace and menu_prefetch.status(workspace.root) or nil
  local blocks = (menu_items.top_level_blocks_fast and menu_items.top_level_blocks_fast(workspace))
    or menu_items.top_level_blocks(workspace)
  local hub_opts = {
    title = "Android Actions",
    summary_lines = summary.lines({ mode = "fast", menu_status = cached_status }),
    blocks = blocks,
  }
  if options.on_cancel then
    hub_opts._fallback_on_cancel = options.on_cancel
    hub_opts._prefer_fallback = options.from_action
  end
  local function reopen_hub()
    open_hub_with_nav(hub_opts)
  end

  hub_opts.on_select = function(selected)
    if not selected then
      return
    end
    local block_title = selected.title or "Actions"
    local index = block_index(hub_opts.blocks, selected)
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
      blocks = hub_opts.blocks,
      default_query = char,
      on_cancel = reopen_hub,
    })
  end

  open_hub_with_nav(hub_opts, options.from_action and "child" or "root")

  M._schedule(function()
    if nav.current ~= hub_opts then
      return
    end
    local session = workspace and ensure_prefetch(workspace) or nil
    local run_snapshot = session and session.run_snapshot
      or (menu_prefetch.cached_run_snapshot and menu_prefetch.cached_run_snapshot(workspace and workspace.root) or nil)
    local new_blocks = menu_items.top_level_blocks(workspace, { run_snapshot = run_snapshot })
    if nav.current ~= hub_opts then
      return
    end
    hub_opts.blocks = new_blocks
    update_summary(hub_opts, session and session.status or cached_status)
  end)
end

return M
