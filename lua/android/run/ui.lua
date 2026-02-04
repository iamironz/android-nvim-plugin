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

function M.select(workspace)
  local target_workspace = workspace or context.workspace()
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
  })

  return selected
end

return M
