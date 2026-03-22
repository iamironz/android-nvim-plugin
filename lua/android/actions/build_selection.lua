local action_defaults = require("android.actions.defaults")
local menu_prefetch = require("android.state.menu_prefetch")
local state_defaults = require("android.state.selection_defaults")

local M = {}

local function resolve_module(workspace, state)
  local build = state_defaults.build_defaults(state)
  if build.module and build.module ~= "" then
    return build.module
  end
  return action_defaults.select_module(workspace.modules)
end

local function resolve_variant(root, state, runner, module, opts)
  local options = opts or {}
  local build = state_defaults.build_defaults(state)
  if build.variant and build.variant ~= "" then
    return build.variant
  end

  local variants = options.fetch_variants(
    root,
    runner,
    menu_prefetch.cached_variant_fetch_opts(root, module)
  )
  local default_hint = nil
  if options.default_hint then
    default_hint = options.default_hint(root, module)
  end
  return action_defaults.select_variant(variants, default_hint)
end

local function apply_build_defaults(state, module, variant)
  local build = state_defaults.build_defaults(state)
  if build.module == module and build.variant == variant then
    return state, false
  end
  return state_defaults.apply_build_defaults(state, module, variant), true
end

function M.resolve(workspace, state, runner, opts)
  local module = resolve_module(workspace, state)
  if not module or module == "" then
    return nil, nil, state
  end

  local variant = resolve_variant(workspace.root, state, runner, module, opts)
  if not variant or variant == "" then
    return module, nil, state
  end

  local next_state, changed = apply_build_defaults(state, module, variant)
  if changed then
    return module, variant, next_state
  end
  return module, variant, state
end

return M
