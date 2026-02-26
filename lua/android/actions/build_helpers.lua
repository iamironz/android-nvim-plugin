local M = {}

local config = require("android.config")
local action_defaults = require("android.actions.defaults")
local gradle_build = require("android.build.gradle")
local quickfix = require("android.build.quickfix")
local stream = require("android.build.stream")
local gradle_cache = require("android.gradle.cache")
local gradle_variants = require("android.gradle.variants")
local gradle_workspace = require("android.gradle.workspace")
local runner_module = require("android.command.runner")
local jobs = require("android.command.jobs")
local strings = require("android.utils.strings")

local cache = gradle_cache.persistent()

local function is_windows(os_name)
  return os_name == "Windows_NT"
end

local function is_dir(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

local function configured_gradle_command()
  local build_config = config.get().build or {}
  local command = build_config.gradle_command
  if type(command) == "string" and command ~= "" then
    return { command }
  end
  if type(command) == "table" and #command > 0 then
    return command
  end
  return nil
end

function M.resolve_gradle_command(root)
  local configured = configured_gradle_command()
  if configured then
    return configured
  end
  local os_name = vim.loop.os_uname().sysname
  local candidates = {}
  if is_windows(os_name) then
    table.insert(candidates, root .. "/gradlew.bat")
  end
  table.insert(candidates, root .. "/gradlew")
  for _, wrapper in ipairs(candidates) do
    local stat = vim.loop.fs_stat(wrapper)
    if stat and stat.type == "file" then
      return { wrapper }
    end
  end
  return { "gradle" }
end

function M.append_args(base, extra)
  local out = {}
  for _, value in ipairs(base or {}) do
    table.insert(out, value)
  end
  for _, value in ipairs(extra or {}) do
    table.insert(out, value)
  end
  return out
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
  local lines = vim.split(result.stdout or "", "\n", { plain = true })
  return gradle_variants.parse(lines)
end

local function fetch_variants_from_modules(root, runner, modules)
  local preferred = action_defaults.select_module(modules)
  local first_error = nil
  local first_task = nil
  local had_error = false
  for _, module in ipairs(merge_modules(preferred, modules)) do
    local task = module .. ":tasks"
    local result = M.run_gradle(root, { task, "--all" }, runner)
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

function M.build_command(root, extra_args)
  return M.append_args(M.resolve_gradle_command(root), extra_args)
end

function M.run_gradle(root, extra_args, runner)
  if not is_dir(root) then
    return {
      ok = false,
      code = 1,
      stdout = "",
      stderr = "root directory not found",
    }
  end
  local exec_runner = runner or runner_module.new()
  local args = M.build_command(root, extra_args)
  return exec_runner.run(args, { cwd = root })
end

function M.run_gradle_async(root, extra_args, opts)
  local options = opts or {}
  if not is_dir(root) then
    local result = {
      ok = false,
      code = 1,
      stdout = "",
      stderr = "root directory not found",
    }
    if options.on_complete then
      options.on_complete(result)
    end
    return { ok = false, error = "root directory not found" }
  end
  local exec_jobs = options.jobs or jobs
  local args = M.build_command(root, extra_args)
  return exec_jobs.run(args, {
    cwd = root,
    env = options.env,
    on_complete = options.on_complete,
  })
end

function M.fetch_task_lines(root, runner, opts)
  local exec_runner = runner or runner_module.new()
  local options = opts or {}
  local modules = options.modules or cache.modules(root, function()
    return gradle_workspace.load_modules(root)
  end)
  return cache.task_lines(root, modules, function()
    local result = M.run_gradle(root, { "tasks", "--all" }, exec_runner)
    if not result or not result.ok then
      return {
        ok = false,
        code = result and result.code or 1,
        stdout = result and result.stdout or "",
        stderr = result and result.stderr or "",
        lines = {},
      }, false
    end
    local lines = vim.split(result.stdout or "", "\n", { plain = true })
    return {
      ok = true,
      code = result.code,
      stdout = result.stdout,
      stderr = result.stderr,
      lines = lines,
    }
  end)
end

function M.fetch_task_lines_async(root, _, on_complete)
  return M.run_gradle_async(root, { "tasks", "--all" }, {
    on_complete = function(result)
      local lines = {}
      if result and result.ok then
        lines = vim.split(result.stdout or "", "\n", { plain = true })
      end
      if on_complete then
        on_complete({
          ok = result and result.ok or false,
          code = result and result.code or 1,
          stdout = result and result.stdout or "",
          stderr = result and result.stderr or "",
          lines = lines,
        })
      end
    end,
  })
end

function M.fetch_variants(root, runner)
  local exec_runner = runner or runner_module.new()
  local modules = cache.modules(root, function()
    return gradle_workspace.load_modules(root)
  end)
  return cache.variants(root, modules, function()
    local task_result = M.fetch_task_lines(
      root,
      exec_runner,
      { modules = modules }
    )
    local lines = (task_result and task_result.lines) or {}
    local variants = gradle_variants.parse(lines)
    if #variants > 0 then
      return variants
    end
    local fallback, had_error = fetch_variants_from_modules(root, exec_runner, modules)
    if #fallback > 0 then
      return fallback
    end
    if (task_result and task_result.ok == false) or had_error then
      return fallback, false
    end
    return fallback
  end)
end

function M.module_entries(modules)
  local entries = { { label = "Root project", value = "" } }
  for _, module in ipairs(modules or {}) do
    table.insert(entries, { label = module, value = module })
  end
  return entries
end

local function notify_result(result)
  if result and result.ok then
    vim.notify("Android build completed", vim.log.levels.INFO)
    return
  end
  local message = "Android build failed"
  if result and result.stderr and result.stderr ~= "" then
    message = message .. ": " .. result.stderr
  end
  vim.notify(message, vim.log.levels.ERROR)
end

local function update_quickfix(lines)
  local items = quickfix.parse(lines or {})
  vim.fn.setqflist(items, "r", { title = "Android build errors" })
  if #items > 0 then
    vim.cmd("copen")
  end
end

function M.run_build(root, module, variant, on_complete)
  if not variant or variant == "" then
    vim.notify("Build variant required", vim.log.levels.WARN)
    return
  end

  local module_value = module
  if module_value == "" then
    module_value = nil
  end
  local gradle_cmd = M.resolve_gradle_command(root)
  local assemble_cmd = gradle_build.assemble_command(
    gradle_cmd,
    module_value,
    variant
  )
  if not assemble_cmd then
    vim.notify("Unable to build assemble task", vim.log.levels.ERROR)
    return
  end

  return stream.start_build_job(root, assemble_cmd, function(result)
    notify_result(result)
    if result and not result.ok then
      update_quickfix(result.lines)
    end
    if on_complete then
      on_complete(result)
    end
  end, {
    panel = {
      module = module_value or "root",
      variant = variant,
      task = assemble_cmd[#assemble_cmd],
    },
  })
end

return M
