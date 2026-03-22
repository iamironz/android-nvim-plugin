local action_defaults = require("android.actions.defaults")
local gradle_snapshot = require("android.gradle.snapshot")
local gradle_variants = require("android.gradle.variants")
local strings = require("android.utils.strings")

local M = {}

local function split_lines(value)
  return vim.split(value or "", "\n", { plain = true })
end

local function merge_modules(preferred, modules)
  local ordered = {}
  local seen = {}
  if preferred and preferred ~= "" then
    table.insert(ordered, preferred)
    seen[preferred] = true
  end
  for _, module in ipairs(modules or {}) do
    if module and module ~= "" and not seen[module] then
      table.insert(ordered, module)
      seen[module] = true
    end
  end
  return ordered
end

local function parse_variants_from_result(result)
  if not result or not result.ok then
    return {}
  end
  return gradle_variants.parse(split_lines(result.stdout))
end

local function copy_list(list)
  local out = {}
  for _, value in ipairs(list or {}) do
    out[#out + 1] = value
  end
  return out
end

local function variants_from_snapshot(snapshot, module)
  local android = snapshot and snapshot.android or nil
  local by_module = android and android.by_module or nil
  if not by_module then
    return {}
  end

  if module and module ~= "" then
    local entry = by_module[module]
    return copy_list(entry and entry.variants or {})
  end

  local seen = {}
  for _, entry in pairs(by_module) do
    for _, variant in ipairs(entry and entry.variants or {}) do
      seen[variant] = true
    end
  end

  local variants = {}
  for variant in pairs(seen) do
    variants[#variants + 1] = variant
  end
  table.sort(variants)
  return variants
end

local function snapshot_has_modules(snapshot)
  local android = snapshot and snapshot.android or nil
  local modules = android and android.modules or nil
  if modules and #modules > 0 then
    return true
  end

  local by_module = android and android.by_module or nil
  if not by_module then
    return false
  end

  return next(by_module) ~= nil
end

function M.from_task_lines(lines, module, snapshot)
  local normalized = snapshot or gradle_snapshot.parse(lines or {})
  local parsed = gradle_variants.parse(lines or {})

  if module and module ~= "" then
    local variants = variants_from_snapshot(normalized, module)
    if #variants > 0 then
      return variants
    end
    if snapshot_has_modules(normalized) then
      return {}
    end
    return parsed
  end

  local merged = {}
  local seen = {}
  for _, variant in ipairs(variants_from_snapshot(normalized)) do
    if not seen[variant] then
      seen[variant] = true
      merged[#merged + 1] = variant
    end
  end
  for _, variant in ipairs(parsed) do
    if not seen[variant] then
      seen[variant] = true
      merged[#merged + 1] = variant
    end
  end
  table.sort(merged)
  return merged
end

function M.fetch_from_modules(root, runner, modules, run_gradle)
  local preferred = action_defaults.select_module(modules)
  local first_error = nil
  local first_task = nil
  local had_error = false

  for _, module in ipairs(merge_modules(preferred, modules)) do
    local task = module .. ":tasks"
    local result = run_gradle(root, { task, "--all" }, runner)
    if not result or not result.ok then
      had_error = true
      if not first_error then
        local message = strings.first_nonempty_line(result and result.stderr)
          or strings.first_nonempty_line(result and result.stdout)
          or "Gradle tasks failed"
        first_error = message
        first_task = task
      end
    else
      local variants = parse_variants_from_result(result)
      if #variants > 0 then
        return variants, had_error
      end
    end
  end

  if first_error then
    local task_label = first_task or "module tasks"
    vim.notify(
      string.format("Gradle tasks failed for %s: %s", task_label, first_error),
      vim.log.levels.WARN
    )
  end

  return {}, had_error
end

return M
