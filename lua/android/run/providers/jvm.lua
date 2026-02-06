local build_helpers = require("android.actions.build_helpers")
local gradle_cache = require("android.gradle.cache")
local gradle_tasks = require("android.gradle.tasks")
local gradle_workspace = require("android.gradle.workspace")
local runner_module = require("android.command.runner")

local M = {}

local cache = gradle_cache.persistent()

local function load_tasks(root, runner)
  local modules = cache.modules(root, function()
    return gradle_workspace.load_modules(root)
  end)
  return cache.tasks(root, modules, function()
    local result = build_helpers.run_gradle(root, { "tasks", "--all" }, runner)
    if not result or not result.ok then
      return {}
    end
    return vim.split(result.stdout or "", "\n", { plain = true })
  end)
end

local function detect_run_tasks(lines)
  local tasks = gradle_tasks.parse(lines)
  local seen = {}
  local result = {}
  for _, entry in ipairs(tasks or {}) do
    local module = entry.name and entry.name:match("^:?(.-):run$")
    if module and not seen[module] then
      seen[module] = true
      result[#result + 1] = ":" .. module
    end
  end
  table.sort(result)
  return result
end

local function load_run_modules(root, runner)
  local modules = cache.modules(root, function()
    return gradle_workspace.load_modules(root)
  end)
  return cache.jvm_run_modules(root, modules, function()
    local lines = load_tasks(root, runner)
    return detect_run_tasks(lines)
  end)
end

function M.detect(workspace, _, opts)
  if not workspace or not workspace.gradle then
    return {}
  end

  local modules
  if opts and opts.tasks then
    modules = detect_run_tasks(opts.tasks)
  elseif opts and opts.fast then
    modules = {}
  else
    local runner = (opts and opts.runner) or runner_module.new()
    modules = load_run_modules(workspace.root, runner)
  end
  local configs = {}
  for _, module in ipairs(modules) do
    local task = module .. ":run"
    configs[#configs + 1] = {
      id = "jvm" .. module,
      label = "JVM " .. module,
      target = "jvm",
      type = "jvm",
      meta = { module = module, task = task },
    }
  end
  return configs
end

return M
