local M = {}

local function normalize_entry(entry)
  if type(entry) == "table" then
    return entry
  end
  return { label = tostring(entry), value = entry }
end

local function build_label(entry, format)
  if format then
    return format(entry)
  end
  return entry.label or tostring(entry.value)
end

local function build_results(items)
  local results = {}
  for _, item in ipairs(items) do
    table.insert(results, normalize_entry(item))
  end
  return results
end

local function find_default_selection_index(results, format, default)
  if default == nil or default == "" then
    return nil
  end

  for index, entry in ipairs(results or {}) do
    if entry.value == default or entry.label == default then
      return index
    end

    local label = build_label(entry, format)
    if label == default then
      return index
    end
  end

  return nil
end

local function move_default_to_front(results, format, default)
  local index = find_default_selection_index(results, format, default)
  if not index or index <= 1 then
    return results
  end

  local copy = vim.deepcopy(results)
  local entry = table.remove(copy, index)
  table.insert(copy, 1, entry)
  return copy
end

local function filter_results_by_query(results, format, query)
  if query == nil or query == "" then
    return results
  end

  local needle = tostring(query):lower()
  local filtered = {}
  for _, entry in ipairs(results or {}) do
    local label = build_label(entry, format):lower()
    if label:find(needle, 1, true) then
      table.insert(filtered, entry)
    end
  end
  return filtered
end

local function fallback_filter_input(options)
  if not vim.ui or not vim.ui.input then
    vim.notify("vim.ui.input not available", vim.log.levels.WARN)
    return
  end

  vim.ui.input({
    prompt = options.prompt_title or "Filter",
    default = options.default or "",
  }, function(value)
    if value == nil then
      if options.on_cancel then
        options.on_cancel()
      end
      return
    end
    if options.on_change then
      options.on_change(value)
    end
    if options.on_accept then
      options.on_accept(value)
    end
  end)
end

local function set_buffer_name(buf, name)
  if not buf or type(name) ~= "string" or name == "" then
    return
  end
  if not vim.api
    or type(vim.api.nvim_buf_is_valid) ~= "function"
    or type(vim.api.nvim_buf_set_name) ~= "function"
  then
    return
  end
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  pcall(vim.api.nvim_buf_set_name, buf, name)
end

local function notify_panel_names_error(reason)
  if type(vim.notify) ~= "function" then
    return
  end
  local message = "Failed to resolve filter panel names"
  if reason and reason ~= "" then
    message = message .. ": " .. reason
  end
  vim.notify(message, vim.log.levels.WARN)
end

local function resolve_filter_panel_names(panel_names, query)
  if type(panel_names) == "function" then
    local ok, names = pcall(panel_names, query)
    if not ok then
      notify_panel_names_error(tostring(names))
      return nil
    end
    if names == nil then
      return nil
    end
    if type(names) ~= "table" then
      notify_panel_names_error("expected table return")
      return nil
    end
    return names
  end
  if type(panel_names) == "table" then
    return panel_names
  end
  return nil
end

local function apply_filter_panel_names(prompt_bufnr, action_state, panel_names, query)
  if not prompt_bufnr then
    return
  end
  local names = resolve_filter_panel_names(panel_names, query)
  if not names then
    return
  end

  set_buffer_name(prompt_bufnr, names.prompt)

  local current_picker = nil
  if action_state and type(action_state.get_current_picker) == "function" then
    current_picker = action_state.get_current_picker(prompt_bufnr)
  end
  local results_bufnr = current_picker and current_picker.results_bufnr or nil
  set_buffer_name(results_bufnr, names.results)
end

local function fallback_select_from_list(options)
  if not vim.ui or not vim.ui.select then
    vim.notify("vim.ui.select not available", vim.log.levels.WARN)
    return
  end

  local items = options.items or {}
  if #items == 0 then
    local label = options.title or "Select"
    vim.notify(
      string.format("No entries to select for %s", label),
      vim.log.levels.WARN
    )
    return
  end

  local results = build_results(items)
  local has_default = options.default ~= nil and options.default ~= ""
  if has_default then
    local exact_index = find_default_selection_index(results, options.format, options.default)
    if exact_index then
      results = move_default_to_front(results, options.format, options.default)
    else
      local filtered = filter_results_by_query(results, options.format, options.default)
      if #filtered > 0 then
        results = filtered
      end
    end
  end
  vim.ui.select(results, {
    prompt = options.title or "Select",
    format_item = function(entry)
      return build_label(entry, options.format)
    end,
  }, function(choice)
    if choice == nil then
      if options.on_cancel then
        options.on_cancel()
      end
      return
    end
    if options.on_select and choice then
      options.on_select(choice.value)
    end
  end)
end

local function make_handle_select(actions, action_state, on_accept)
  return function(prompt_bufnr)
    actions.close(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    local value = selection and selection.value or action_state.get_current_line()
    if on_accept then
      on_accept(value)
    end
  end
end

local function make_attach_mappings(actions, on_cancel, handle_select, on_ready)
  return function(prompt_bufnr, map)
    actions.select_default:replace(handle_select)
    if on_ready then
      on_ready(prompt_bufnr)
    end
    if on_cancel then
      local map_fn = map or function() end
      map_fn("i", "<esc>", function()
        actions.close(prompt_bufnr)
        on_cancel()
      end)
      map_fn("n", "<esc>", function()
        actions.close(prompt_bufnr)
        on_cancel()
      end)
    end
    return true
  end
end

local function build_filter_picker(opts)
  return opts.pickers
    .new(opts.theme, {
      prompt_title = opts.title,
      default_text = opts.default,
      finder = opts.finders.new_table({
        results = opts.results,
        entry_maker = function(entry)
          local label = build_label(entry, opts.format)
          return {
            value = entry.value,
            display = label,
            ordinal = label,
          }
        end,
      }),
      sorter = opts.conf.generic_sorter({}),
      on_input_filter_cb = function(prompt)
        if opts.on_change then
          opts.on_change(prompt)
        end
        if opts.on_query then
          opts.on_query(prompt)
        end
        return prompt
      end,
      attach_mappings = opts.attach_mappings,
    })
end

function M.filter_input(opts)
  local options = opts or {}
  local items = options.items or {}
  local title = options.prompt_title or "Filter"
  local default = options.default or ""
  local on_change = options.on_change
  local on_accept = options.on_accept
  local on_cancel = options.on_cancel
  local format = options.format

  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    fallback_filter_input(options)
    return
  end

  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local themes = require("telescope.themes")

  local results = build_results(items)
  local theme = themes.get_dropdown({})
  local active_prompt_bufnr = nil
  local handle_select = make_handle_select(actions, action_state, on_accept)
  local function update_panel_names(query)
    apply_filter_panel_names(active_prompt_bufnr, action_state, options.panel_names, query)
  end
  local attach_mappings = make_attach_mappings(actions, on_cancel, handle_select, function(prompt_bufnr)
    active_prompt_bufnr = prompt_bufnr
    update_panel_names(default)
  end)
  local picker = build_filter_picker({
    pickers = pickers,
    theme = theme,
    title = title,
    default = default,
    finders = finders,
    conf = conf,
    results = results,
    format = format,
    on_change = on_change,
    on_query = update_panel_names,
    attach_mappings = attach_mappings,
  })
  attach_mappings(0)
  picker:find()
end

function M.select_from_list(opts)
  local options = opts or {}
  local items = options.items or {}
  local title = options.title or "Select"
  local on_select = options.on_select
  local on_cancel = options.on_cancel
  local format = options.format
  local default = options.default

  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    fallback_select_from_list(options)
    return
  end

  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local themes = require("telescope.themes")

  if #items == 0 then
    local label = options.title or "Select"
    vim.notify(
      string.format("No entries to select for %s", label),
      vim.log.levels.WARN
    )
    return
  end

  local results = build_results(items)
  local default_selection_index = find_default_selection_index(results, format, default)

  local theme = themes.get_dropdown({})
  if options.file_ignore_patterns ~= nil then
    theme.file_ignore_patterns = options.file_ignore_patterns
  end

  pickers
    .new(theme, {
      prompt_title = title,
      default_selection_index = default_selection_index,
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          local label = build_label(entry, format)
          return {
            value = entry.value,
            display = label,
            ordinal = label,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if on_select and selection then
            on_select(selection.value)
          end
        end)
        if on_cancel and map then
          map("i", "<esc>", function()
            actions.close(prompt_bufnr)
            on_cancel()
          end)
          map("n", "<esc>", function()
            actions.close(prompt_bufnr)
            on_cancel()
          end)
        end
        return true
      end,
    })
    :find()
end

return M
