local M = {}

local context = require("android.actions.context")
local picker = require("android.ui.picker")
local run_registry = require("android.run.registry")

local function build_items(configs)
  local items = {}
  for _, entry in ipairs(configs or {}) do
    items[#items + 1] = {
      label = entry.label or entry.id,
      value = entry.id,
    }
  end
  return items
end

function M.select(workspace_or_opts)
  local opts = nil
  local target_workspace = nil
  if type(workspace_or_opts) == "table"
      and (workspace_or_opts.on_cancel ~= nil or workspace_or_opts.workspace ~= nil) then
    opts = workspace_or_opts
    target_workspace = opts.workspace or context.workspace()
  else
    target_workspace = workspace_or_opts or context.workspace()
  end
  if not target_workspace then
    return nil
  end

  local list = run_registry.list(target_workspace)
  local selected = nil
  picker.select_from_list({
    title = "Run Config",
    items = build_items(list),
    on_select = function(config_id)
      selected = run_registry.select(target_workspace, config_id)
    end,
    on_cancel = opts and opts.on_cancel or nil,
  })

  return selected
end

return M
